// UEFI boot service driver that gives Windows a linear framebuffer on Virtualization.framework.
//
// Apple's firmware exposes the virtual GPU only as a Blt-capable graphics output (PixelBltOnly, no
// FrameBufferBase). Windows Boot Manager and the Windows kernel's boot display draw straight into the
// framebuffer the firmware reports, so on such firmware the first pixel they write faults and the VM
// dies. This driver reserves a framebuffer in RAM, replaces the graphics output protocol with one that
// reports it, and copies whatever changed to the real GPU from a timer, much like QEMU's ramfb does in
// hardware. Windows' own display driver takes over once it loads.
//
// Written from the UEFI 2.x specification; no code is shared with other projects.

#include "efi.h"

#ifndef FLUSH_INTERVAL_100NS
#define FLUSH_INTERVAL_100NS 400000 // 40 ms
#endif

static EFI_GUID GraphicsOutputGuid = {0x9042a9de, 0x23dc, 0x4a38, {0x96, 0xfb, 0x7a, 0xde, 0xd0, 0x80, 0x51, 0x6a}};

static EFI_BOOT_SERVICES *BS;
static EFI_HANDLE GopHandle;
static EFI_GRAPHICS_OUTPUT_PROTOCOL *RealGop;

static EFI_GRAPHICS_OUTPUT_PROTOCOL OurGop;
static EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE OurMode;
static EFI_GRAPHICS_OUTPUT_MODE_INFORMATION OurInfo;

static UINT8 *Framebuffer; // what Windows draws into
static UINT8 *Shadow;      // what was last sent to the real GPU
static UINTN Width, Height, Stride; // in pixels / bytes per row
static BOOLEAN Flushing;
static BOOLEAN Installed;
static EFI_EVENT FlushTimer;
static EFI_EVENT GopNotify;
static VOID *GopRegistration;

void *memcpy(void *dst, const void *src, UINTN n) {
  UINT8 *d = dst;
  const UINT8 *s = src;
  while (n--) *d++ = *s++;
  return dst;
}

void *memmove(void *dst, const void *src, UINTN n) {
  UINT8 *d = dst;
  const UINT8 *s = src;
  if (d < s) {
    while (n--) *d++ = *s++;
  } else {
    d += n;
    s += n;
    while (n--) *--d = *--s;
  }
  return dst;
}

void *memset(void *dst, int c, UINTN n) {
  UINT8 *d = dst;
  while (n--) *d++ = (UINT8)c;
  return dst;
}


#ifdef DEBUG_MARKS
// Bring-up aid: paints squares straight on the real GPU (never through our own framebuffer) so a
// screenshot shows how far boot got: Mark() slots along the top, a tick counter and the last Blt status.
static UINTN Ticks, LastBltStatus;

static VOID MarkAt(UINTN x, UINTN y, UINT32 color) {
  EFI_GRAPHICS_OUTPUT_PROTOCOL *gop = RealGop;
  if (!gop) {
    EFI_GUID guid = {0x9042a9de, 0x23dc, 0x4a38, {0x96, 0xfb, 0x7a, 0xde, 0xd0, 0x80, 0x51, 0x6a}};
    if (EFI_ERROR(BS->LocateProtocol(&guid, NULL, (VOID **)&gop))) return;
  }
  EFI_GRAPHICS_OUTPUT_BLT_PIXEL pixel = *(EFI_GRAPHICS_OUTPUT_BLT_PIXEL *)&color;
  gop->Blt(gop, &pixel, EfiBltVideoFill, 0, 0, x, y, 12, 12, 0);
}
#define MARK(slot, color) MarkAt((slot) * 16, 0, color)
#else
#define MARK(slot, color)
#endif

static BOOLEAN RowsDiffer(const UINT8 *a, const UINT8 *b, UINTN bytes) {
  const UINT64 *x = (const UINT64 *)a;
  const UINT64 *y = (const UINT64 *)b;
  UINTN words = bytes / 8;
  for (UINTN i = 0; i < words; i++) {
    if (x[i] != y[i]) return TRUE;
  }
  return FALSE;
}

// Sends the rows in [firstRow, firstRow + count) that differ from the shadow copy to the real GPU,
// one run of consecutive changed rows per call.
static VOID FlushRows(UINTN firstRow, UINTN count) {
  if (Flushing || !RealGop) return;
  Flushing = TRUE;

  UINTN end = firstRow + count;
  if (end > Height) end = Height;

  UINTN y = firstRow;
  while (y < end) {
    if (!RowsDiffer(Framebuffer + y * Stride, Shadow + y * Stride, Stride)) {
      y++;
      continue;
    }

    UINTN start = y;
    while (y < end && RowsDiffer(Framebuffer + y * Stride, Shadow + y * Stride, Stride)) y++;

    UINTN rows = y - start;
    EFI_STATUS status = RealGop->Blt(RealGop, (EFI_GRAPHICS_OUTPUT_BLT_PIXEL *)(Framebuffer + start * Stride), EfiBltBufferToVideo, 0, start, 0, start, Width, rows, Stride);
#ifdef DEBUG_MARKS
    LastBltStatus = status;
#endif
    if (!EFI_ERROR(status)) {
      memcpy(Shadow + start * Stride, Framebuffer + start * Stride, rows * Stride);
    }
  }

  Flushing = FALSE;
}

static VOID FlushTick(EFI_EVENT event, VOID *context) {
  FlushRows(0, Height);
#ifdef DEBUG_MARKS
  Ticks++;
  for (UINTN bit = 0; bit < 12; bit++) MarkAt(bit * 16, 40, ((Ticks >> bit) & 1) ? 0x00ffffff : 0x00404040);
  MarkAt(0, 60, EFI_ERROR(LastBltStatus) ? 0x00ff0000 : 0x0000ff00);
#endif
}

static EFI_STATUS OurQueryMode(EFI_GRAPHICS_OUTPUT_PROTOCOL *this, UINT32 modeNumber, UINTN *sizeOfInfo, EFI_GRAPHICS_OUTPUT_MODE_INFORMATION **info) {
  if (modeNumber != 0 || !sizeOfInfo || !info) return EFI_INVALID_PARAMETER;

  EFI_GRAPHICS_OUTPUT_MODE_INFORMATION *copy;
  if (EFI_ERROR(BS->AllocatePool(EfiBootServicesData, sizeof(*copy), (VOID **)&copy))) return EFI_OUT_OF_RESOURCES;

  memcpy(copy, &OurInfo, sizeof(*copy));
  *info = copy;
  *sizeOfInfo = sizeof(*copy);
  return EFI_SUCCESS;
}

static EFI_STATUS OurSetMode(EFI_GRAPHICS_OUTPUT_PROTOCOL *this, UINT32 modeNumber) {
  if (modeNumber != 0) return EFI_UNSUPPORTED;

  memset(Framebuffer, 0, Stride * Height);
  FlushRows(0, Height);
  return EFI_SUCCESS;
}

static EFI_STATUS OurBlt(EFI_GRAPHICS_OUTPUT_PROTOCOL *this, EFI_GRAPHICS_OUTPUT_BLT_PIXEL *buffer, EFI_GRAPHICS_OUTPUT_BLT_OPERATION operation,
                         UINTN sourceX, UINTN sourceY, UINTN destX, UINTN destY, UINTN width, UINTN height, UINTN delta) {
  if (operation >= EfiGraphicsOutputBltOperationMax) return EFI_INVALID_PARAMETER;
  if (width == 0 || height == 0) return EFI_SUCCESS;

  UINTN bufferStride = delta ? delta : width * 4;
  UINTN firstRow = 0, rowCount = 0;

  switch (operation) {
    case EfiBltVideoFill: {
      if (!buffer || destX + width > Width || destY + height > Height) return EFI_INVALID_PARAMETER;

      UINT32 pixel = *(UINT32 *)buffer;
      for (UINTN row = 0; row < height; row++) {
        UINT32 *line = (UINT32 *)(Framebuffer + (destY + row) * Stride) + destX;
        for (UINTN column = 0; column < width; column++) line[column] = pixel;
      }
      firstRow = destY;
      rowCount = height;
      break;
    }
    case EfiBltVideoToBltBuffer:
      if (!buffer || sourceX + width > Width || sourceY + height > Height) return EFI_INVALID_PARAMETER;

      for (UINTN row = 0; row < height; row++) {
        memcpy((UINT8 *)buffer + (destY + row) * bufferStride + destX * 4, Framebuffer + (sourceY + row) * Stride + sourceX * 4, width * 4);
      }
      return EFI_SUCCESS;
    case EfiBltBufferToVideo:
      if (!buffer || destX + width > Width || destY + height > Height) return EFI_INVALID_PARAMETER;

      for (UINTN row = 0; row < height; row++) {
        memcpy(Framebuffer + (destY + row) * Stride + destX * 4, (UINT8 *)buffer + (sourceY + row) * bufferStride + sourceX * 4, width * 4);
      }
      firstRow = destY;
      rowCount = height;
      break;
    case EfiBltVideoToVideo:
      if (sourceX + width > Width || sourceY + height > Height || destX + width > Width || destY + height > Height) return EFI_INVALID_PARAMETER;

      if (destY > sourceY || (destY == sourceY && destX > sourceX)) {
        for (UINTN row = height; row-- > 0;) memmove(Framebuffer + (destY + row) * Stride + destX * 4, Framebuffer + (sourceY + row) * Stride + sourceX * 4, width * 4);
      } else {
        for (UINTN row = 0; row < height; row++) memmove(Framebuffer + (destY + row) * Stride + destX * 4, Framebuffer + (sourceY + row) * Stride + sourceX * 4, width * 4);
      }
      firstRow = destY;
      rowCount = height;
      break;
    default:
      return EFI_INVALID_PARAMETER;
  }

  FlushRows(firstRow, rowCount);
  return EFI_SUCCESS;
}

// Replaces the real graphics output protocol on its handle with ours.
static EFI_STATUS Install(EFI_HANDLE handle, EFI_GRAPHICS_OUTPUT_PROTOCOL *real) {
  if (!real->Mode || !real->Mode->Info) return EFI_NOT_FOUND;

  // Already linear (a different firmware, or another copy of this driver): nothing to add
  if (real->Mode->FrameBufferBase != 0 && real->Mode->Info->PixelFormat != PixelBltOnly) return EFI_SUCCESS;

  Width = real->Mode->Info->HorizontalResolution;
  Height = real->Mode->Info->VerticalResolution;
  Stride = Width * 4;
  if (Width == 0 || Height == 0) return EFI_NOT_FOUND;

  UINTN size = Stride * Height;
  UINTN pages = (size + 4095) / 4096;

  // The framebuffer must survive into the running OS, so it is runtime memory the firmware reserves
  EFI_PHYSICAL_ADDRESS address;
  if (EFI_ERROR(BS->AllocatePages(AllocateAnyPages, EfiRuntimeServicesData, pages, &address))) return EFI_OUT_OF_RESOURCES;
  Framebuffer = (UINT8 *)(UINTN)address;
  memset(Framebuffer, 0, pages * 4096);

  if (EFI_ERROR(BS->AllocatePool(EfiBootServicesData, size, (VOID **)&Shadow))) return EFI_OUT_OF_RESOURCES;
  // The shadow starts different from the framebuffer so the first tick paints everything
  memset(Shadow, 0xff, size);

  OurInfo.Version = 0;
  OurInfo.HorizontalResolution = (UINT32)Width;
  OurInfo.VerticalResolution = (UINT32)Height;
  OurInfo.PixelFormat = PixelBlueGreenRedReserved8BitPerColor;
  OurInfo.PixelsPerScanLine = (UINT32)Width;

  OurMode.MaxMode = 1;
  OurMode.Mode = 0;
  OurMode.Info = &OurInfo;
  OurMode.SizeOfInfo = sizeof(OurInfo);
  OurMode.FrameBufferBase = address;
  OurMode.FrameBufferSize = pages * 4096;

  OurGop.QueryMode = OurQueryMode;
  OurGop.SetMode = OurSetMode;
  OurGop.Blt = OurBlt;
  OurGop.Mode = &OurMode;

  RealGop = real;
  GopHandle = handle;

  EFI_STATUS status = BS->ReinstallProtocolInterface(handle, &GraphicsOutputGuid, real, &OurGop);
  if (EFI_ERROR(status)) {
    RealGop = NULL;
    return status;
  }

  Installed = TRUE;
  MARK(3, 0x0000ff00);

  if (!EFI_ERROR(BS->CreateEvent(EVT_TIMER | EVT_NOTIFY_SIGNAL, TPL_CALLBACK, FlushTick, NULL, &FlushTimer))) {
    BS->SetTimer(FlushTimer, TimerPeriodic, FLUSH_INTERVAL_100NS);
  }

  return EFI_SUCCESS;
}

static EFI_STATUS TryInstall(VOID) {
  if (Installed) return EFI_SUCCESS;

  UINTN count = 0;
  EFI_HANDLE *handles = NULL;
  EFI_STATUS status = BS->LocateHandleBuffer(ByProtocol, &GraphicsOutputGuid, NULL, &count, &handles);
  if (EFI_ERROR(status) || count == 0) return EFI_NOT_FOUND;

  status = EFI_NOT_FOUND;
  for (UINTN i = 0; i < count && EFI_ERROR(status); i++) {
    EFI_GRAPHICS_OUTPUT_PROTOCOL *gop;
    if (EFI_ERROR(BS->HandleProtocol(handles[i], &GraphicsOutputGuid, (VOID **)&gop))) continue;

    status = Install(handles[i], gop);
  }

  BS->FreePool(handles);
  return status;
}

// The firmware may start this driver before it has brought the GPU up
static VOID GopAppeared(EFI_EVENT event, VOID *context) {
  if (!EFI_ERROR(TryInstall()) && GopNotify) {
    BS->CloseEvent(GopNotify);
    GopNotify = NULL;
  }
}

static EFI_GUID LoadedImageGuid = {0x5b1b31a1, 0x9562, 0x11d2, {0x8e, 0x3f, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b}};
static EFI_GUID DevicePathGuid = {0x09576e91, 0x6d3f, 0x11d2, {0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b}};
static EFI_GUID GlobalVariableGuid = {0x8be4df61, 0x93ca, 0x11d2, {0xaa, 0x0d, 0x00, 0xe0, 0x98, 0x03, 0x2b, 0x8c}};

#define DRIVER_OPTION_NUMBER 0xCAFE
#define DRIVER_PATH L"\\EFI\\caker\\framebuffer.efi"

static UINTN NodeLength(const EFI_DEVICE_PATH_PROTOCOL *node) {
  return node->Length[0] | (node->Length[1] << 8);
}

// Makes the firmware load this driver on every boot, whichever boot manager it starts: Windows creates
// its own firmware boot entry on its first start, after which the loader is no longer in the way. The
// option is a Driver#### variable naming this file on the volume the driver was loaded from.
static VOID RegisterDriverOption(EFI_HANDLE image, EFI_SYSTEM_TABLE *systemTable) {
  EFI_RUNTIME_SERVICES *rt = systemTable->RuntimeServices;
  EFI_LOADED_IMAGE_PROTOCOL *loaded;
  EFI_DEVICE_PATH_PROTOCOL *volumePath;

  if (EFI_ERROR(BS->HandleProtocol(image, &LoadedImageGuid, (VOID **)&loaded)) || !loaded->DeviceHandle) return;
  if (EFI_ERROR(BS->HandleProtocol(loaded->DeviceHandle, &DevicePathGuid, (VOID **)&volumePath))) return;

  UINTN volumeSize = 0;
  for (EFI_DEVICE_PATH_PROTOCOL *node = volumePath; node->Type != END_DEVICE_PATH_TYPE; node = (EFI_DEVICE_PATH_PROTOCOL *)((UINT8 *)node + NodeLength(node))) {
    volumeSize += NodeLength(node);
  }

  const CHAR16 description[] = L"Caker framebuffer";
  const CHAR16 path[] = DRIVER_PATH;
  UINTN fileNodeLength = sizeof(EFI_DEVICE_PATH_PROTOCOL) + sizeof(path);
  UINTN pathListLength = volumeSize + fileNodeLength + sizeof(EFI_DEVICE_PATH_PROTOCOL);
  UINTN optionSize = sizeof(UINT32) + sizeof(UINT16) + sizeof(description) + pathListLength;

  UINT8 *option;
  if (EFI_ERROR(BS->AllocatePool(EfiBootServicesData, optionSize, (VOID **)&option))) return;

  UINT8 *cursor = option;
  UINT32 attributes = LOAD_OPTION_ACTIVE;
  UINT16 listLength = (UINT16)pathListLength;
  memcpy(cursor, &attributes, sizeof(attributes));
  cursor += sizeof(attributes);
  memcpy(cursor, &listLength, sizeof(listLength));
  cursor += sizeof(listLength);
  memcpy(cursor, description, sizeof(description));
  cursor += sizeof(description);
  memcpy(cursor, volumePath, volumeSize);
  cursor += volumeSize;

  EFI_DEVICE_PATH_PROTOCOL *file = (EFI_DEVICE_PATH_PROTOCOL *)cursor;
  file->Type = MEDIA_DEVICE_PATH;
  file->SubType = MEDIA_FILEPATH_DP;
  file->Length[0] = (UINT8)(fileNodeLength & 0xff);
  file->Length[1] = (UINT8)(fileNodeLength >> 8);
  memcpy(cursor + sizeof(EFI_DEVICE_PATH_PROTOCOL), path, sizeof(path));
  cursor += fileNodeLength;

  EFI_DEVICE_PATH_PROTOCOL *end = (EFI_DEVICE_PATH_PROTOCOL *)cursor;
  end->Type = END_DEVICE_PATH_TYPE;
  end->SubType = END_ENTIRE_DEVICE_PATH_SUBTYPE;
  end->Length[0] = sizeof(EFI_DEVICE_PATH_PROTOCOL);
  end->Length[1] = 0;

  const UINT32 attrs = EFI_VARIABLE_NON_VOLATILE | EFI_VARIABLE_BOOTSERVICE_ACCESS | EFI_VARIABLE_RUNTIME_ACCESS;
  CHAR16 name[] = L"Driver0000";
  const CHAR16 hex[] = L"0123456789ABCDEF";
  for (UINTN i = 0; i < 4; i++) name[6 + i] = hex[(DRIVER_OPTION_NUMBER >> (12 - 4 * i)) & 0xf];

  rt->SetVariable(name, &GlobalVariableGuid, attrs, optionSize, option);

  // DriverOrder lists the options the firmware loads, in order
  UINT16 order[64];
  UINTN orderSize = sizeof(order);
  UINT32 orderAttrs;
  if (EFI_ERROR(rt->GetVariable(L"DriverOrder", &GlobalVariableGuid, &orderAttrs, &orderSize, order))) orderSize = 0;

  UINTN count = orderSize / sizeof(UINT16);
  BOOLEAN present = FALSE;
  for (UINTN i = 0; i < count; i++) {
    if (order[i] == DRIVER_OPTION_NUMBER) present = TRUE;
  }
  if (!present && count < 64) {
    order[count++] = DRIVER_OPTION_NUMBER;
    rt->SetVariable(L"DriverOrder", &GlobalVariableGuid, attrs, count * sizeof(UINT16), order);
  }

  BS->FreePool(option);
}

EFI_STATUS EFIAPI efi_main(EFI_HANDLE image, EFI_SYSTEM_TABLE *systemTable) {
  BS = systemTable->BootServices;
  RegisterDriverOption(image, systemTable);
  MARK(2, 0x00ff0000);

  if (!EFI_ERROR(TryInstall())) return EFI_SUCCESS;

  if (EFI_ERROR(BS->CreateEvent(EVT_NOTIFY_SIGNAL, TPL_CALLBACK, GopAppeared, NULL, &GopNotify))) return EFI_LOAD_ERROR;
  if (EFI_ERROR(BS->RegisterProtocolNotify(&GraphicsOutputGuid, GopNotify, &GopRegistration))) return EFI_LOAD_ERROR;

  return EFI_SUCCESS;
}
