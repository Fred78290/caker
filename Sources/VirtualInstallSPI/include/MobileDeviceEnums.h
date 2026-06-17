//
// SPI declarations for the private AppleMobileDeviceRestore ("AMRestore") framework.
// Ported from VirtualBuddy (insidegui/VirtualBuddy, 2.2-b2) / UTM to work around the
// VZMacOSInstaller restore bug that prevents installing macOS 27 guests on macOS 26
// hosts. See Sources/cakedlib/VirtualInstall/DESIGN.md.
//
// These symbols are PRIVATE and only available on Apple Silicon, non-sandboxed builds.

#pragma once

#import <Foundation/Foundation.h>

#ifndef WEAK_IMPORT_ATTRIBUTE
#define WEAK_IMPORT_ATTRIBUTE __attribute__((weak_import))
#endif

/// Unified logging subsystem used by the virtual installation SPI layer.
extern NSString * const kVirtualInstallationSubsystem;

typedef NS_ENUM(int, AMRestorableDeviceEvent) {
    AMRestorableDeviceEventFound,
    AMRestorableDeviceEventLost
};

typedef NS_ENUM(int, AMRestorableDeviceState) {
    kAMRestorableDeviceStateUnknown,
    kAMRestorableDeviceStateDFU,
    kAMRestorableDeviceStateRecovery,
    kAMRestorableDeviceStateRestoreOS,
    kAMRestorableDeviceStateBootedOS
};

typedef NS_ENUM(int, AMRestorableDeviceFusing) {
    AMRestorableDeviceFusingUnknown,
    AMRestorableDeviceFusingDevelopment,
    AMRestorableDeviceFusingProduction,
    AMRestorableDeviceFusingInsecure,
};

typedef NS_ENUM(uint, AMRestorableDeviceClass) {
    AMRestorableDeviceClassUnknown        = 0,
    AMRestorableDeviceClassiPhone         = 1 << 0,
    AMRestorableDeviceClassiPad           = 1 << 1,
    AMRestorableDeviceClassWatch          = 1 << 2,
    AMRestorableDeviceClassTV             = 1 << 3,
    AMRestorableDeviceClassBridge         = 1 << 4,
    AMRestorableDeviceClassAudioAccessory = 1 << 5,
    AMRestorableDeviceClassiPod           = 1 << 6,
    AMRestorableDeviceClassMac            = 1 << 7,
    AMRestorableDeviceClassDarwin         = 1 << 8,
    AMRestorableDeviceClassVision         = 1 << 9,
    AMRestorableDeviceClassComputeModule  = 1 << 10,
};
