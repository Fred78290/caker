//
// Ported from VirtualBuddy 2.2-b2 / UTM.

#pragma once

#import <Foundation/Foundation.h>
#import "MobileDeviceSPI.h"

/// Blocks the current thread and waits for a restorable device with the given
/// ECID (and optionally state) to appear. Returns the device with a +1 retain
/// count (CF_RETURNS_RETAINED), or nil if `timeoutInMilliseconds` elapses first.
/// The caller must release the returned device with `VIReleaseDevice`.
///
/// - Pass `kAMRestorableDeviceStateUnknown` for `state` to accept any state.
/// - Do NOT call from the main thread.
AMRestorableDeviceRef _Nullable VIWaitForDeviceWithECID(uint64_t ecid, AMRestorableDeviceState state, int timeoutInMilliseconds) __attribute__((cf_returns_retained));

/// Releases a device reference obtained from `VIWaitForDeviceWithECID`.
void VIReleaseDevice(AMRestorableDeviceRef _Nullable device);
