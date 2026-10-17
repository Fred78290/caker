// UEFI application installed as \EFI\BOOT\BOOTAA64.EFI on the Windows installation media and on the
// installed system's EFI system partition. It starts the framebuffer driver (\EFI\caker\framebuffer.efi
// on the same volume), then Windows Boot Manager, which is kept as \EFI\BOOT\windows.efi so the firmware
// never starts it on its own.
//
// Written from the UEFI 2.x specification.

#include "efi.h"

static EFI_GUID LoadedImageGuid = {0x5b1b31a1, 0x9562, 0x11d2, {0x8e, 0x3f, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b}};
static EFI_GUID DevicePathGuid = {0x09576e91, 0x6d3f, 0x11d2, {0x8e, 0x39, 0x00, 0xa0, 0xc9, 0x69, 0x72, 0x3b}};

static EFI_BOOT_SERVICES *BS;

void *memcpy(void *dst, const void *src, UINTN n) {
  UINT8 *d = dst;
  const UINT8 *s = src;
  while (n--) *d++ = *s++;
  return dst;
}

static UINTN StringSize(const CHAR16 *s) {
  UINTN n = 0;
  while (s[n]) n++;
  return (n + 1) * sizeof(CHAR16);
}

static UINTN NodeLength(const EFI_DEVICE_PATH_PROTOCOL *node) {
  return node->Length[0] | (node->Length[1] << 8);
}

// The device path of `path` on `volume`: the volume's own path, a file path node and an end node.
static EFI_DEVICE_PATH_PROTOCOL *FilePath(EFI_HANDLE volume, const CHAR16 *path) {
  EFI_DEVICE_PATH_PROTOCOL *volumePath;
  if (EFI_ERROR(BS->HandleProtocol(volume, &DevicePathGuid, (VOID **)&volumePath))) return NULL;

  UINTN volumeSize = 0;
  for (EFI_DEVICE_PATH_PROTOCOL *node = volumePath; node->Type != END_DEVICE_PATH_TYPE; node = (EFI_DEVICE_PATH_PROTOCOL *)((UINT8 *)node + NodeLength(node))) {
    volumeSize += NodeLength(node);
  }

  UINTN pathSize = StringSize(path);
  UINT16 fileNodeLength = (UINT16)(sizeof(EFI_DEVICE_PATH_PROTOCOL) + pathSize);
  UINT8 *result;
  if (EFI_ERROR(BS->AllocatePool(EfiBootServicesData, volumeSize + fileNodeLength + sizeof(EFI_DEVICE_PATH_PROTOCOL), (VOID **)&result))) return NULL;

  memcpy(result, volumePath, volumeSize);

  EFI_DEVICE_PATH_PROTOCOL *file = (EFI_DEVICE_PATH_PROTOCOL *)(result + volumeSize);
  file->Type = MEDIA_DEVICE_PATH;
  file->SubType = MEDIA_FILEPATH_DP;
  file->Length[0] = (UINT8)(fileNodeLength & 0xff);
  file->Length[1] = (UINT8)(fileNodeLength >> 8);
  memcpy((UINT8 *)file + sizeof(EFI_DEVICE_PATH_PROTOCOL), path, pathSize);

  EFI_DEVICE_PATH_PROTOCOL *end = (EFI_DEVICE_PATH_PROTOCOL *)((UINT8 *)file + fileNodeLength);
  end->Type = END_DEVICE_PATH_TYPE;
  end->SubType = END_ENTIRE_DEVICE_PATH_SUBTYPE;
  end->Length[0] = sizeof(EFI_DEVICE_PATH_PROTOCOL);
  end->Length[1] = 0;

  return (EFI_DEVICE_PATH_PROTOCOL *)result;
}


#ifdef DEBUG_MARKS
// Bring-up aid: paints a 24x24 square on the real GPU so a screenshot shows how far boot got.
static VOID Mark(UINTN slot, UINT32 color) {
  static EFI_GUID gopGuid = {0x9042a9de, 0x23dc, 0x4a38, {0x96, 0xfb, 0x7a, 0xde, 0xd0, 0x80, 0x51, 0x6a}};
  EFI_GRAPHICS_OUTPUT_PROTOCOL *gop;
  if (EFI_ERROR(BS->LocateProtocol(&gopGuid, NULL, (VOID **)&gop))) return;
  EFI_GRAPHICS_OUTPUT_BLT_PIXEL pixel = *(EFI_GRAPHICS_OUTPUT_BLT_PIXEL *)&color;
  gop->Blt(gop, &pixel, EfiBltVideoFill, 0, 0, slot * 28, 0, 24, 24, 0);
}
#define MARK(slot, color) Mark(slot, color)
#else
#define MARK(slot, color)
#endif

static EFI_STATUS Load(EFI_HANDLE parent, EFI_HANDLE volume, const CHAR16 *path, EFI_HANDLE *image) {
  EFI_DEVICE_PATH_PROTOCOL *devicePath = FilePath(volume, path);
  if (!devicePath) return EFI_NOT_FOUND;

  EFI_STATUS status = BS->LoadImage(FALSE, parent, devicePath, NULL, 0, image);
  BS->FreePool(devicePath);
  return status;
}

EFI_STATUS EFIAPI efi_main(EFI_HANDLE image, EFI_SYSTEM_TABLE *systemTable) {
  BS = systemTable->BootServices;
  MARK(0, 0x00ffffff);

  EFI_LOADED_IMAGE_PROTOCOL *loaded;
  if (EFI_ERROR(BS->HandleProtocol(image, &LoadedImageGuid, (VOID **)&loaded))) return EFI_LOAD_ERROR;

  // A missing or failing driver must not stop Windows from starting
  EFI_HANDLE driver;
  if (!EFI_ERROR(Load(image, loaded->DeviceHandle, L"\\EFI\\caker\\framebuffer.efi", &driver))) {
    MARK(1, 0x00ffff00);
    BS->StartImage(driver, NULL, NULL);
  }

  EFI_HANDLE bootManager;
  EFI_STATUS status = Load(image, loaded->DeviceHandle, L"\\EFI\\BOOT\\windows.efi", &bootManager);
  if (EFI_ERROR(status)) return status;

  return BS->StartImage(bootManager, NULL, NULL);
}
