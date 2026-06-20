//
// Ported from VirtualBuddy 2.2-b2 / UTM.
// Not compiled in App Store builds (private SPI + non-sandboxed only).

#if defined(USE_VIRTUAL_INSTALL_BACKEND) && defined(__arm64__)

#import "VIWaitForDevice.h"
#import "MobileDeviceShim.h"

@import os.log;

NSString * const kVirtualInstallationSubsystem = @"com.aldunelabs.caker.VirtualInstall";

NSString *RUCopyRestorableDeviceStateStringFromState(AMRestorableDeviceState state);

typedef void(^VIWaitForDeviceBlock)(AMRestorableDeviceRef device, AMRestorableClientID clientID);

typedef struct {
    VIWaitForDeviceBlock callback;
    AMRestorableClientID clientID;
    dispatch_queue_t queue;
} VIWaitForDeviceContext;

void __VIWaitForDeviceEventCallback(AMRestorableDeviceRef device, AMRestorableDeviceEvent event, void *context);
void __VIInvalidateContext(VIWaitForDeviceContext context);

AMRestorableDeviceRef _Nullable VIWaitForDeviceWithECID(uint64_t ecid, AMRestorableDeviceState state, int timeoutInMilliseconds)
{
    os_log_t log = os_log_create(kVirtualInstallationSubsystem.UTF8String, "VIWaitForDevice");
    os_log_debug(log, "BEGIN wait for device %@", @(ecid));

    __block AMRestorableDeviceRef outDevice = NULL;
    // Guarded by an atomic compare-and-swap so concurrent AMRestore callbacks
    // on multiple threads can't both claim the "found" slot.
    __block volatile int32_t finalized = 0;

    NSString *label = [NSString stringWithFormat:@"WaitForDevice(%@)", @(ecid)];
    dispatch_queue_t queue = dispatch_queue_create(label.UTF8String, dispatch_queue_attr_make_with_qos_class(NULL, QOS_CLASS_USER_INTERACTIVE, 0));
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    VIWaitForDeviceBlock callback = ^(AMRestorableDeviceRef device, AMRestorableClientID cid) {
        if (VIMDGetECID(device) != ecid) return;

        AMRestorableDeviceState deviceState = VIMDGetState(device);
        if (state != kAMRestorableDeviceStateUnknown && deviceState != state) {
            os_log_debug(log, "Found device %@, but its state is %@ instead of %@. Keep waiting...", @(ecid), RUCopyRestorableDeviceStateStringFromState(deviceState), RUCopyRestorableDeviceStateStringFromState(state));
            return;
        }

        // Atomically claim the "found" slot. Bail if another concurrent callback
        // already succeeded so outDevice is written exactly once and the
        // semaphore is signalled exactly once.
        if (!__sync_bool_compare_and_swap(&finalized, 0, 1)) return;

        os_log_debug(log, "Found target device %@ with state %@", @(ecid), RUCopyRestorableDeviceStateStringFromState(deviceState));

        // Retain before signalling so the caller owns a +1 reference regardless
        // of when the framework releases the device after the callback returns.
        outDevice = (AMRestorableDeviceRef)CFRetain(device);

        dispatch_async(queue, ^{
            dispatch_semaphore_signal(sema);
        });
    };

    __block VIWaitForDeviceContext context = {
        callback,
        VIMDInvalidClientID(),
        queue
    };

    dispatch_async(queue, ^{
        // Initialize to NULL so the log call below is safe even if the
        // framework doesn't write to `error` on failure.
        CFErrorRef error = NULL;
        context.clientID = VIMDRegisterForNotifications(__VIWaitForDeviceEventCallback, (void *)&context, &error);

        if (context.clientID == VIMDInvalidClientID()) {
            os_log_fault(log, "Error registering for restorable device notifications. %{public}@", error);
            dispatch_semaphore_signal(sema);
        }
        if (error) CFRelease(error);
    });

    intptr_t result = dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeoutInMilliseconds * NSEC_PER_MSEC)));

    if (result == 0) {
        os_log_debug(log, "END wait for device %@ with %@", @(ecid), [NSString stringWithFormat:@"%@", outDevice]);
    } else {
        os_log_error(log, "END wait for device %@: timed out after %dms", @(ecid), timeoutInMilliseconds);
    }

    // Unregister synchronously before returning. This guarantees that
    // VIMDUnregisterForNotifications completes — and the context pointer can
    // no longer be delivered to __VIWaitForDeviceEventCallback — before the
    // __block `context` storage is released, preventing a use-after-free.
    dispatch_sync(queue, ^{
        __VIInvalidateContext(context);
    });

    return outDevice;
}

void __VIWaitForDeviceEventCallback(AMRestorableDeviceRef device, AMRestorableDeviceEvent event, void *context)
{
    if (!context) return;

    if (event == AMRestorableDeviceEventFound) {
        VIWaitForDeviceContext *deviceContext = (VIWaitForDeviceContext *)context;

        assert(deviceContext != NULL);
        if (!deviceContext) return;

        deviceContext->callback(device, deviceContext->clientID);
    }
}

void __VIInvalidateContext(VIWaitForDeviceContext context)
{
    if (context.clientID == VIMDInvalidClientID()) return;

    // Called from inside dispatch_sync(queue, …) so we must unregister directly
    // rather than dispatching back to the same queue (which would deadlock).
    VIMDUnregisterForNotifications(context.clientID);
}

void VIReleaseDevice(AMRestorableDeviceRef _Nullable device)
{
    if (device) CFRelease(device);
}

NSString *RUCopyRestorableDeviceStateStringFromState(AMRestorableDeviceState state)
{
    switch(state) {
    case kAMRestorableDeviceStateUnknown: return @"Unknown";
    case kAMRestorableDeviceStateDFU: return @"DFU";
    case kAMRestorableDeviceStateRecovery: return @"Recovery";
    case kAMRestorableDeviceStateRestoreOS: return @"RestoreOS";
    case kAMRestorableDeviceStateBootedOS: return @"BootedOS";
    default: return [NSString stringWithFormat:@"Unexpected state %@", @(state)];
    }
}

#endif
