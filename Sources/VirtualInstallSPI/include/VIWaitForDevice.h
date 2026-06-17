//
// Ported from VirtualBuddy 2.2-b2 / UTM.

#pragma once

#import <Foundation/Foundation.h>
#import "MobileDeviceSPI.h"

/// Blocks the current thread and waits for a restorable device with the given
/// ECID (and optionally state) to appear. Returns the device, or nil if
/// `timeoutInMilliseconds` elapses first.
///
/// - Pass `kAMRestorableDeviceStateUnknown` for `state` to accept any state.
/// - Do NOT call from the main thread.
AMRestorableDeviceRef _Nullable VIWaitForDeviceWithECID(uint64_t ecid, AMRestorableDeviceState state, int timeoutInMilliseconds);
