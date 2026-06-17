//
// Private Virtualization.framework SPI needed to boot a VM into DFU/restore mode
// so the AMRestore framework can flash an IPSW onto it.
// Ported from VirtualBuddy 2.2-b2 / UTM.

#pragma once

#import <Virtualization/Virtualization.h>

NS_ASSUME_NONNULL_BEGIN

/// Setting `_forceDFU = YES` in the start options makes the guest boot into DFU
/// mode, where the host's AppleMobileDeviceRestore framework can see it as a
/// restorable device.
@interface VZMacOSVirtualMachineStartOptions (VZPrivate)

@property (assign, setter=_setForceDFU:) BOOL _forceDFU;

@end

NS_ASSUME_NONNULL_END
