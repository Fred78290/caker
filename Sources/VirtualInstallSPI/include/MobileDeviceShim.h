//
// dlsym shim over the private MobileDevice.framework AMRestore symbols.
//
// We resolve the AMRestorable* functions and the kAMRestorableInvalidClientID
// data symbol at runtime via dlopen/dlsym instead of weak-linking them. The
// framework is not in the SDK, and binding the symbols with `-Wl,-U` dynamic
// lookup is unreliable for the *data* symbol under chained fixups (it is bound
// to NULL at launch, before the framework is dlopen'd, which crashes on read).
// Going through dlsym sidesteps all of that and needs no special linker flags.
//
// Ported from VirtualBuddy 2.2-b2 / UTM.

#pragma once

#import <Foundation/Foundation.h>
#import "MobileDeviceSPI.h"

NS_ASSUME_NONNULL_BEGIN

/// YES if MobileDevice.framework loaded and all required symbols resolved.
BOOL VIMDAvailable(void);

/// Value of the framework's `kAMRestorableInvalidClientID` (falls back to -1).
AMRestorableClientID VIMDInvalidClientID(void);

AMRestorableClientID VIMDRegisterForNotifications(AMRestorableDeviceNotificationCallback callback, void *_Nullable context, CFErrorRef _Nullable *_Nullable error);
bool VIMDUnregisterForNotifications(AMRestorableClientID clientID);
uint64_t VIMDGetECID(AMRestorableDeviceRef device);
AMRestorableDeviceState VIMDGetState(AMRestorableDeviceRef device);
BOOL VIMDSetGlobalLogFileURL(CFURLRef url);
BOOL VIMDSetLogFileURL(AMRestorableDeviceRef device, CFURLRef url, CFStringRef type);
void VIMDDeviceRestore(AMRestorableDeviceRef device, CFDictionaryRef options, AMRestorableDeviceProgressCallback callback, void *_Nullable refCon);
CFStringRef VIMDLocalizedStringForOperation(int operation) CF_RETURNS_RETAINED;

NS_ASSUME_NONNULL_END
