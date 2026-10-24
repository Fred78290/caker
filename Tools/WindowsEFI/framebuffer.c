// UEFI boot service driver that gives Windows a linear framebuffer on Virtualization.framework.
//
// Apple's firmware exposes the virtual GPU only as a Blt-capable graphics output (PixelBltOnly, no
// FrameBufferBase). Windows Boot Manager and the Windows kernel's boot display draw straight into the
// framebuffer the firmware reports, so on such firmware the first pixel they write faults and the VM
// dies. This driver reserves a framebuffer in RAM, makes the graphics output protocols report it, and
// copies whatever changed to the real GPU from a timer, much like QEMU's ramfb does in hardware. Copying
// stops at ExitBootServices; Windows' own display driver takes over once it loads.
//
// The protocols are patched in place rather than replaced: the console splitter (the graphics output
// Windows Boot Manager actually opens) keeps its own copy of the mode and calls into the GPU's protocol
// through its function pointers, so both have to say the same thing. Every graphics output gets the
// framebuffer in its mode, and only the GPU's Blt is redirected.
//
// The framebuffer is sized for the mode the GPU is in when the driver finds it, up to 1920x1200. The
// firmware picks 8192x4320 for display sizes it doesn't list, which would cost 280 MB of RAM and a
// scan of it every tick, so above the cap the driver first switches to the largest mode within it.
// Larger modes then stay Blt-only and can't be set.
//
// On load, the driver registers itself as a Driver#### option with a short-form device path (no volume),
// so the firmware loads it on every boot from whichever volume holds it: the installation media at
// first, then the Windows EFI system partition.
//
// Written from the UEFI 2.x specification; no code is shared with other projects.

#include "efi.h"

#ifndef FLUSH_INTERVAL_100NS
#define FLUSH_INTERVAL_100NS 400000 // 40 ms
#endif

#define MAX_GOPS 8
#define MAX_WIDTH 1920
#define MAX_HEIGHT 1200

#define DRIVER_OPTION_NUMBER 0xCAFE

static EFI_GUID GraphicsOutputGuid = {0x9042a9de, 0x23dc, 0x4a38, {0x96, 0xfb, 0x7a, 0xde, 0xd0, 0x80, 0x51, 0x6a}};
static EFI_GUID DevicePathGuid = {0x09576e91, 0x6d3f, 0x11d2, {0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b}};
static EFI_GUID ExitBootServicesGroup = {0x27abf055, 0xb1b8, 0x4c26, {0x80, 0x48, 0x74, 0x8f, 0x37, 0xba, 0xa2, 0xdf}};
static EFI_GUID GlobalVariableGuid = {0x8be4df61, 0x93ca, 0x11d2, {0xaa, 0x0d, 0x00, 0xe0, 0x98, 0x03, 0x2b, 0x8c}};
// Installed once the driver is resident, so that a second load (the loader's, then the Driver#### option's) is a no-op
static EFI_GUID ResidentGuid = {0x3c5d0c3e, 0x7a41, 0x4d6b, {0x9e, 0x52, 0x1f, 0x80, 0xb7, 0x6a, 0x24, 0xd1}};

static CHAR16 DriverPath[] = L"\\EFI\\caker\\framebuffer.efi";
static CHAR16 DriverDescription[] = L"Caker framebuffer";

static EFI_BOOT_SERVICES *BS;

static UINT8 *Framebuffer; // what Windows draws into
static UINT8 *Shadow;      // what was last sent to the real GPU
static UINTN FramebufferSize;
static BOOLEAN Active;   // the GPU is there to be drawn to, until ExitBootServices
static BOOLEAN Flushing; // keeps the timer and a Blt from flushing at the same time
static EFI_EVENT FlushTimer;

// The virtual GPU's graphics output, the only one with a device path
static EFI_GRAPHICS_OUTPUT_PROTOCOL *Device;
static EFI_GOP_BLT DeviceBlt;

// Every graphics output advertises the framebuffer, including the console splitter's
static EFI_GRAPHICS_OUTPUT_PROTOCOL *Gops[MAX_GOPS];
static EFI_GOP_SET_MODE GopSetMode[MAX_GOPS];
static EFI_GOP_QUERY_MODE GopQueryMode[MAX_GOPS];
static UINTN GopCount;
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

static BOOLEAN MemEqual(const void *a, const void *b, UINTN n) {
  const UINT8 *x = a, *y = b;
  while (n--) {
    if (*x++ != *y++) return FALSE;
  }
  return TRUE;
}

#ifdef DEBUG_MARKS
// Bring-up aid: paints squares straight on the real GPU (never through our own framebuffer) so a
// screenshot shows how far boot got: Mark() slots along the top, a tick counter and the last Blt status.
static UINTN Ticks, LastBltStatus;

static VOID MarkAt(UINTN x, UINTN y, UINT32 color) {
  EFI_GRAPHICS_OUTPUT_PROTOCOL *gop = Device;
  EFI_GOP_BLT blt = DeviceBlt;
  if (!gop) {
    if (EFI_ERROR(BS->LocateProtocol(&GraphicsOutputGuid, NULL, (VOID **)&gop))) return;
    blt = gop->Blt;
  }
  EFI_GRAPHICS_OUTPUT_BLT_PIXEL pixel = *(EFI_GRAPHICS_OUTPUT_BLT_PIXEL *)&color;
  blt(gop, &pixel, EfiBltVideoFill, 0, 0, x, y, 12, 12, 0);
}
#define MARK(slot, color) MarkAt((slot) * 16, 0, color)
#else
#define MARK(slot, color)
#endif

// The size of the GPU's current mode, which follows the VM's display
static UINTN Width(VOID) { return Device->Mode->Info->HorizontalResolution; }
static UINTN Height(VOID) { return Device->Mode->Info->VerticalResolution; }
static UINTN Stride(VOID) { return Width() * 4; }

static UINTN ModeSize(const EFI_GRAPHICS_OUTPUT_MODE_INFORMATION *info) {
  return (UINTN)info->HorizontalResolution * info->VerticalResolution * 4;
}

static BOOLEAN WithinCap(const EFI_GRAPHICS_OUTPUT_MODE_INFORMATION *info) {
  return info->HorizontalResolution <= MAX_WIDTH && info->VerticalResolution <= MAX_HEIGHT;
}

// Whether the framebuffer can back a mode
static BOOLEAN Fits(const EFI_GRAPHICS_OUTPUT_MODE_INFORMATION *info) {
  return Framebuffer && info && WithinCap(info) && ModeSize(info) <= FramebufferSize;
}

static BOOLEAN InBounds(UINTN x, UINTN y, UINTN width, UINTN height) {
  return x <= Width() && width <= Width() - x && y <= Height() && height <= Height() - y;
}

static VOID AdvertiseFramebuffer(EFI_GRAPHICS_OUTPUT_MODE_INFORMATION *info) {
  info->PixelFormat = PixelBlueGreenRedReserved8BitPerColor;
  info->PixelInformation = (EFI_PIXEL_BITMASK){0};
  info->PixelsPerScanLine = info->HorizontalResolution;
}

// Points every adopted graphics output's current mode at the framebuffer, where the mode fits it
static VOID PatchModes(VOID) {
  for (UINTN i = 0; i < GopCount; i++) {
    EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE *mode = Gops[i]->Mode;
    if (!mode || !Fits(mode->Info)) continue;

    AdvertiseFramebuffer(mode->Info);
    mode->FrameBufferBase = (EFI_PHYSICAL_ADDRESS)(UINTN)Framebuffer;
    mode->FrameBufferSize = ModeSize(mode->Info);
  }
}

static int GopIndex(EFI_GRAPHICS_OUTPUT_PROTOCOL *gop) {
  for (UINTN i = 0; i < GopCount; i++) {
    if (Gops[i] == gop) return (int)i;
  }
  return -1;
}

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
  if (Flushing || !Active || !Fits(Device->Mode->Info)) return;
  Flushing = TRUE;

  UINTN stride = Stride();
  UINTN end = firstRow + count;
  if (end > Height()) end = Height();

  UINTN y = firstRow;
  while (y < end) {
    if (!RowsDiffer(Framebuffer + y * stride, Shadow + y * stride, stride)) {
      y++;
      continue;
    }

    UINTN start = y;
    while (y < end && RowsDiffer(Framebuffer + y * stride, Shadow + y * stride, stride)) y++;

    // The buffer is the whole framebuffer, so the source and destination positions are the same
    UINTN rows = y - start;
    EFI_STATUS status = DeviceBlt(Device, (EFI_GRAPHICS_OUTPUT_BLT_PIXEL *)Framebuffer, EfiBltBufferToVideo, 0, start, 0, start, Width(), rows, stride);
#ifdef DEBUG_MARKS
    LastBltStatus = status;
#endif
    if (!EFI_ERROR(status)) {
      memcpy(Shadow + start * stride, Framebuffer + start * stride, rows * stride);
    }
  }

  Flushing = FALSE;
}

// Windows writes to the framebuffer directly, so the timer pushes whichever rows changed since the last tick
static VOID FlushTick(EFI_EVENT event, VOID *context) {
  if (!Device) return;

  FlushRows(0, Height());
#ifdef DEBUG_MARKS
  Ticks++;
  for (UINTN bit = 0; bit < 12; bit++) MarkAt(bit * 16, 40, ((Ticks >> bit) & 1) ? 0x00ffffff : 0x00404040);
  MarkAt(0, 60, EFI_ERROR(LastBltStatus) ? 0x00ff0000 : 0x0000ff00);
#endif
}

static VOID StopFlushing(EFI_EVENT event, VOID *context) {
  // The GPU driver resets the device at ExitBootServices
  Active = FALSE;
}

static EFI_STATUS OurQueryMode(EFI_GRAPHICS_OUTPUT_PROTOCOL *this, UINT32 modeNumber, UINTN *sizeOfInfo, EFI_GRAPHICS_OUTPUT_MODE_INFORMATION **info) {
  int i = GopIndex(this);
  if (i < 0) return EFI_INVALID_PARAMETER;

  EFI_STATUS status = GopQueryMode[i](this, modeNumber, sizeOfInfo, info);
  if (!EFI_ERROR(status) && info && Fits(*info)) AdvertiseFramebuffer(*info);
  return status;
}

static EFI_STATUS OurSetMode(EFI_GRAPHICS_OUTPUT_PROTOCOL *this, UINT32 modeNumber) {
  int i = GopIndex(this);
  if (i < 0) return EFI_INVALID_PARAMETER;

  // A mode the framebuffer can't back would leave Windows drawing outside of it
  if (Framebuffer) {
    EFI_GRAPHICS_OUTPUT_MODE_INFORMATION *info;
    UINTN size;
    if (EFI_ERROR(GopQueryMode[i](this, modeNumber, &size, &info))) return EFI_UNSUPPORTED;

    BOOLEAN fits = Fits(info);
    BS->FreePool(info);
    if (!fits) return EFI_UNSUPPORTED;
  }

  EFI_STATUS status = GopSetMode[i](this, modeNumber);
  if (!EFI_ERROR(status) && Framebuffer) {
    PatchModes();

    // The mode starts out black; the shadow differs so the next tick paints it all
    memset(Framebuffer, 0, FramebufferSize);
    memset(Shadow, 0xff, FramebufferSize);
  }
  return status;
}

// Firmware drawing goes to the framebuffer too, so that it stays the single source of truth.
static EFI_STATUS OurBlt(EFI_GRAPHICS_OUTPUT_PROTOCOL *this, EFI_GRAPHICS_OUTPUT_BLT_PIXEL *buffer, EFI_GRAPHICS_OUTPUT_BLT_OPERATION operation,
                         UINTN sourceX, UINTN sourceY, UINTN destX, UINTN destY, UINTN width, UINTN height, UINTN delta) {
  if (!Fits(Device->Mode->Info)) return DeviceBlt(this, buffer, operation, sourceX, sourceY, destX, destY, width, height, delta);

  if (operation >= EfiGraphicsOutputBltOperationMax) return EFI_INVALID_PARAMETER;
  if (width == 0 || height == 0) return EFI_SUCCESS;

  UINTN stride = Stride();
  UINTN bufferStride = delta ? delta : width * 4;
  UINTN firstRow = 0, rowCount = 0;

  switch (operation) {
    case EfiBltVideoFill: {
      if (!buffer || !InBounds(destX, destY, width, height)) return EFI_INVALID_PARAMETER;

      UINT32 pixel = *(UINT32 *)buffer;
      for (UINTN row = 0; row < height; row++) {
        UINT32 *line = (UINT32 *)(Framebuffer + (destY + row) * stride) + destX;
        for (UINTN column = 0; column < width; column++) line[column] = pixel;
      }
      firstRow = destY;
      rowCount = height;
      break;
    }
    case EfiBltVideoToBltBuffer:
      if (!buffer || !InBounds(sourceX, sourceY, width, height)) return EFI_INVALID_PARAMETER;

      for (UINTN row = 0; row < height; row++) {
        memcpy((UINT8 *)buffer + (destY + row) * bufferStride + destX * 4, Framebuffer + (sourceY + row) * stride + sourceX * 4, width * 4);
      }
      return EFI_SUCCESS;
    case EfiBltBufferToVideo:
      if (!buffer || !InBounds(destX, destY, width, height)) return EFI_INVALID_PARAMETER;

      for (UINTN row = 0; row < height; row++) {
        memcpy(Framebuffer + (destY + row) * stride + destX * 4, (UINT8 *)buffer + (sourceY + row) * bufferStride + sourceX * 4, width * 4);
      }
      firstRow = destY;
      rowCount = height;
      break;
    case EfiBltVideoToVideo:
      if (!InBounds(sourceX, sourceY, width, height) || !InBounds(destX, destY, width, height)) return EFI_INVALID_PARAMETER;

      if (destY > sourceY || (destY == sourceY && destX > sourceX)) {
        for (UINTN row = height; row-- > 0;) memmove(Framebuffer + (destY + row) * stride + destX * 4, Framebuffer + (sourceY + row) * stride + sourceX * 4, width * 4);
      } else {
        for (UINTN row = 0; row < height; row++) memmove(Framebuffer + (destY + row) * stride + destX * 4, Framebuffer + (sourceY + row) * stride + sourceX * 4, width * 4);
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

static EFI_STATUS AllocateFramebuffer(const EFI_GRAPHICS_OUTPUT_MODE_INFORMATION *info) {
  UINTN size = ModeSize(info);
  UINTN pages = EFI_SIZE_TO_PAGES(size);

  // Reserved memory, so that the firmware keeps it out of the OS's hands while the OS still has it mapped
  EFI_PHYSICAL_ADDRESS address;
  if (EFI_ERROR(BS->AllocatePages(AllocateAnyPages, EfiReservedMemoryType, pages, &address))) return EFI_OUT_OF_RESOURCES;

  if (EFI_ERROR(BS->AllocatePool(EfiBootServicesData, size, (VOID **)&Shadow))) {
    BS->FreePages(address, pages);
    return EFI_OUT_OF_RESOURCES;
  }

  Framebuffer = (UINT8 *)(UINTN)address;
  FramebufferSize = size;
  memset(Framebuffer, 0, pages * 4096);
  // The shadow starts different from the framebuffer so the first tick paints everything
  memset(Shadow, 0xff, size);
  return EFI_SUCCESS;
}

// Switches the graphics output to its largest mode within the cap if the current one is above it, and
// returns whether the current mode is within the cap
static BOOLEAN LimitMode(UINTN i) {
  EFI_GRAPHICS_OUTPUT_PROTOCOL *gop = Gops[i];
  if (WithinCap(gop->Mode->Info)) return TRUE;

  UINT32 best = gop->Mode->MaxMode;
  UINTN bestSize = 0;
  for (UINT32 mode = 0; mode < gop->Mode->MaxMode; mode++) {
    EFI_GRAPHICS_OUTPUT_MODE_INFORMATION *info;
    UINTN size;
    if (EFI_ERROR(GopQueryMode[i](gop, mode, &size, &info))) continue;

    if (WithinCap(info) && ModeSize(info) > bestSize) {
      best = mode;
      bestSize = ModeSize(info);
    }
    BS->FreePool(info);
  }

  return best < gop->Mode->MaxMode && !EFI_ERROR(GopSetMode[i](gop, best)) && WithinCap(gop->Mode->Info);
}

// Hooks a graphics output's mode functions and, if it's the virtual GPU's, takes over its drawing
static VOID Adopt(EFI_HANDLE handle) {
  EFI_GRAPHICS_OUTPUT_PROTOCOL *gop = NULL;
  VOID *devicePath = NULL;

  if (EFI_ERROR(BS->HandleProtocol(handle, &GraphicsOutputGuid, (VOID **)&gop)) || !gop) return;
  if (GopIndex(gop) >= 0 || GopCount == MAX_GOPS) return;

  UINTN i = GopCount++;
  Gops[i] = gop;
  GopSetMode[i] = gop->SetMode;
  GopQueryMode[i] = gop->QueryMode;
  gop->SetMode = OurSetMode;
  gop->QueryMode = OurQueryMode;

  // Already linear (a different firmware): nothing to add
  BOOLEAN bltOnly = gop->Mode && gop->Mode->Info && (gop->Mode->FrameBufferBase == 0 || gop->Mode->Info->PixelFormat == PixelBltOnly);

  if (!Device && bltOnly && !EFI_ERROR(BS->HandleProtocol(handle, &DevicePathGuid, &devicePath)) && devicePath && LimitMode(i) &&
      !EFI_ERROR(AllocateFramebuffer(gop->Mode->Info))) {
    Device = gop;
    DeviceBlt = gop->Blt;
    gop->Blt = OurBlt;
    Active = TRUE;
    MARK(3, 0x0000ff00);

    BS->SetTimer(FlushTimer, TimerPeriodic, FLUSH_INTERVAL_100NS);
  }

  PatchModes();
}

// The console splitter's graphics output appears after the GPU's, and may appear after this driver starts
static VOID GopAppeared(EFI_EVENT event, VOID *context) {
  EFI_HANDLE *handles;
  UINTN count;

  while (!EFI_ERROR(BS->LocateHandleBuffer(ByRegisterNotify, NULL, GopRegistration, &count, &handles))) {
    for (UINTN i = 0; i < count; i++) Adopt(handles[i]);
    BS->FreePool(handles);
  }
}

static UINT16 PathLength(UINT16 payload) {
  return (UINT16)(sizeof(EFI_DEVICE_PATH_PROTOCOL) + payload);
}

// Makes the firmware load this driver on every boot, whichever boot manager it starts: Windows creates
// its own firmware boot entry on its first start, after which the loader is no longer in the way. The
// option is a Driver#### variable naming DriverPath with no volume (a short-form device path), which the
// firmware expands by searching every file system, so it keeps working when the installation media goes away.
static VOID RegisterDriverOption(EFI_RUNTIME_SERVICES *rt) {
  // EFI_LOAD_OPTION: attributes, file path list length, description, then the file path list
  UINT8 option[sizeof(UINT32) + sizeof(UINT16) + sizeof(DriverDescription) + sizeof(EFI_DEVICE_PATH_PROTOCOL) + sizeof(DriverPath) + sizeof(EFI_DEVICE_PATH_PROTOCOL)];
  UINT16 fileNodeLength = PathLength(sizeof(DriverPath));
  UINT32 attributes = LOAD_OPTION_ACTIVE;
  UINT16 listLength = (UINT16)(fileNodeLength + sizeof(EFI_DEVICE_PATH_PROTOCOL));
  UINT8 *cursor = option;

  memcpy(cursor, &attributes, sizeof(attributes));
  cursor += sizeof(attributes);
  memcpy(cursor, &listLength, sizeof(listLength));
  cursor += sizeof(listLength);
  memcpy(cursor, DriverDescription, sizeof(DriverDescription));
  cursor += sizeof(DriverDescription);

  EFI_DEVICE_PATH_PROTOCOL *file = (EFI_DEVICE_PATH_PROTOCOL *)cursor;
  file->Type = MEDIA_DEVICE_PATH;
  file->SubType = MEDIA_FILEPATH_DP;
  file->Length[0] = (UINT8)(fileNodeLength & 0xff);
  file->Length[1] = (UINT8)(fileNodeLength >> 8);
  memcpy(cursor + sizeof(EFI_DEVICE_PATH_PROTOCOL), DriverPath, sizeof(DriverPath));
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

  // Variables live in flash, so leave an option that's already right alone
  UINT8 stored[sizeof(option)];
  UINTN storedSize = sizeof(stored);
  EFI_STATUS status = rt->GetVariable(name, &GlobalVariableGuid, NULL, &storedSize, stored);
  if (EFI_ERROR(status) || storedSize != sizeof(option) || !MemEqual(stored, option, sizeof(option))) {
    if (EFI_ERROR(rt->SetVariable(name, &GlobalVariableGuid, attrs, sizeof(option), option))) return;
  }

  // DriverOrder lists the options the firmware loads, in order. Leave it be when it can't be read whole
  // (more entries than expected): writing it back would drop the rest.
  UINT16 order[64];
  UINTN orderSize = sizeof(order);
  status = rt->GetVariable(L"DriverOrder", &GlobalVariableGuid, NULL, &orderSize, order);
  if (status == EFI_NOT_FOUND) {
    orderSize = 0;
  } else if (EFI_ERROR(status)) {
    return;
  }

  UINTN count = orderSize / sizeof(UINT16);
  for (UINTN i = 0; i < count; i++) {
    if (order[i] == DRIVER_OPTION_NUMBER) return;
  }
  if (count == 64) return;

  order[count++] = DRIVER_OPTION_NUMBER;
  rt->SetVariable(L"DriverOrder", &GlobalVariableGuid, attrs, count * sizeof(UINT16), order);
}

EFI_STATUS EFIAPI efi_main(EFI_HANDLE image, EFI_SYSTEM_TABLE *systemTable) {
  BS = systemTable->BootServices;
  MARK(2, 0x00ff0000);

  VOID *resident;
  if (!EFI_ERROR(BS->LocateProtocol(&ResidentGuid, NULL, &resident))) {
    RegisterDriverOption(systemTable->RuntimeServices);
    return EFI_ALREADY_STARTED;
  }

  if (EFI_ERROR(BS->CreateEvent(EVT_TIMER | EVT_NOTIFY_SIGNAL, TPL_CALLBACK, FlushTick, NULL, &FlushTimer))) return EFI_LOAD_ERROR;

  EFI_EVENT exitBootServices;
  BS->CreateEventEx(EVT_NOTIFY_SIGNAL, TPL_CALLBACK, StopFlushing, NULL, &ExitBootServicesGroup, &exitBootServices);

  // Ask to hear about graphics outputs first, so none can slip in between looking and listening;
  // adopting one twice does no harm. When loaded as a Driver#### option, they don't exist yet.
  EFI_EVENT gopInstalled;
  if (!EFI_ERROR(BS->CreateEvent(EVT_NOTIFY_SIGNAL, TPL_CALLBACK, GopAppeared, NULL, &gopInstalled))) {
    BS->RegisterProtocolNotify(&GraphicsOutputGuid, gopInstalled, &GopRegistration);
  }

  EFI_HANDLE *handles;
  UINTN count;
  if (!EFI_ERROR(BS->LocateHandleBuffer(ByProtocol, &GraphicsOutputGuid, NULL, &count, &handles))) {
    for (UINTN i = 0; i < count; i++) Adopt(handles[i]);
    BS->FreePool(handles);
  }

  EFI_HANDLE residentHandle = NULL;
  BS->InstallProtocolInterface(&residentHandle, &ResidentGuid, EFI_NATIVE_INTERFACE, NULL);

  RegisterDriverOption(systemTable->RuntimeServices);
  return EFI_SUCCESS;
}
