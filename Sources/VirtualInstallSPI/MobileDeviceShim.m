//
// dlsym shim implementation for AMRestore private symbols.
// Ported from VirtualBuddy 2.2-b2 / UTM.
// Not compiled in App Store builds (private SPI + non-sandboxed only).

#if !defined(USE_VIRTUAL_INSTALL_BACKEND) && defined(__arm64__)

#import "MobileDeviceShim.h"
#import <dlfcn.h>

@import os.log;

typedef AMRestorableClientID (*VIMDRegFn)(AMRestorableDeviceNotificationCallback, void *, CFErrorRef *);
typedef bool (*VIMDUnregFn)(AMRestorableClientID);
typedef uint64_t (*VIMDGetECIDFn)(AMRestorableDeviceRef);
typedef AMRestorableDeviceState (*VIMDGetStateFn)(AMRestorableDeviceRef);
typedef BOOL (*VIMDSetGlobalLogFn)(CFURLRef);
typedef BOOL (*VIMDSetLogFn)(AMRestorableDeviceRef, CFURLRef, CFStringRef);
typedef void (*VIMDRestoreFn)(AMRestorableDeviceRef, CFDictionaryRef, AMRestorableDeviceProgressCallback, void *);
typedef CFStringRef (*VIMDLocStrFn)(int);

static VIMDRegFn _reg;
static VIMDUnregFn _unreg;
static VIMDGetECIDFn _getECID;
static VIMDGetStateFn _getState;
static VIMDSetGlobalLogFn _setGlobalLog;
static VIMDSetLogFn _setLog;
static VIMDRestoreFn _restore;
static VIMDLocStrFn _locStr;
static AMRestorableClientID _invalidID = -1;
static BOOL _ok = NO;

static void VIMDLoad(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *h = dlopen("/System/Library/PrivateFrameworks/MobileDevice.framework/MobileDevice", RTLD_LAZY | RTLD_GLOBAL);
        if (!h) {
            os_log_error(OS_LOG_DEFAULT, "VIMD: failed to load MobileDevice.framework: %{public}s", dlerror());
            return;
        }
        _reg = (VIMDRegFn)dlsym(h, "AMRestorableDeviceRegisterForNotifications");
        _unreg = (VIMDUnregFn)dlsym(h, "AMRestorableDeviceUnregisterForNotifications");
        _getECID = (VIMDGetECIDFn)dlsym(h, "AMRestorableDeviceGetECID");
        _getState = (VIMDGetStateFn)dlsym(h, "AMRestorableDeviceGetState");
        _setGlobalLog = (VIMDSetGlobalLogFn)dlsym(h, "AMRestorableSetGlobalLogFileURL");
        _setLog = (VIMDSetLogFn)dlsym(h, "AMRestorableDeviceSetLogFileURL");
        _restore = (VIMDRestoreFn)dlsym(h, "AMRestorableDeviceRestore");
        _locStr = (VIMDLocStrFn)dlsym(h, "AMRLocalizedCopyStringForAMROperation");
        void *inv = dlsym(h, "kAMRestorableInvalidClientID");
        if (inv) {
            _invalidID = *(AMRestorableClientID *)inv;
        }
        _ok = _reg && _unreg && _getECID && _getState && _setGlobalLog && _setLog && _restore && _locStr;
        if (!_ok) {
            os_log_error(OS_LOG_DEFAULT, "VIMD: one or more MobileDevice AMRestore symbols are missing");
        }
    });
}

BOOL VIMDAvailable(void) { VIMDLoad(); return _ok; }
AMRestorableClientID VIMDInvalidClientID(void) { VIMDLoad(); return _invalidID; }

AMRestorableClientID VIMDRegisterForNotifications(AMRestorableDeviceNotificationCallback callback, void *context, CFErrorRef *error)
{
    VIMDLoad();
    return _reg ? _reg(callback, context, error) : _invalidID;
}

bool VIMDUnregisterForNotifications(AMRestorableClientID clientID)
{
    VIMDLoad();
    return _unreg ? _unreg(clientID) : false;
}

uint64_t VIMDGetECID(AMRestorableDeviceRef device)
{
    VIMDLoad();
    return _getECID ? _getECID(device) : 0;
}

AMRestorableDeviceState VIMDGetState(AMRestorableDeviceRef device)
{
    VIMDLoad();
    return _getState ? _getState(device) : kAMRestorableDeviceStateUnknown;
}

BOOL VIMDSetGlobalLogFileURL(CFURLRef url)
{
    VIMDLoad();
    return _setGlobalLog ? _setGlobalLog(url) : NO;
}

BOOL VIMDSetLogFileURL(AMRestorableDeviceRef device, CFURLRef url, CFStringRef type)
{
    VIMDLoad();
    return _setLog ? _setLog(device, url, type) : NO;
}

void VIMDDeviceRestore(AMRestorableDeviceRef device, CFDictionaryRef options, AMRestorableDeviceProgressCallback callback, void *refCon)
{
    VIMDLoad();
    if (_restore) {
        _restore(device, options, callback, refCon);
    }
}

CFStringRef VIMDLocalizedStringForOperation(int operation)
{
    VIMDLoad();
    if (_locStr) {
        return _locStr(operation);
    }
    return CFStringCreateWithFormat(NULL, NULL, CFSTR("Operation %d"), operation);
}

#endif
