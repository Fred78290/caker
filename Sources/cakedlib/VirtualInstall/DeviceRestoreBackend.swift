//
// Types shared across the virtual installation backend.
// Ported from VirtualBuddy 2.2-b2 / UTM, adapted for Caker.
// Not available in the App Store build (private SPI + non-sandboxed only).

#if !APPSTORE

import Foundation

/// A device's unique chip identifier, derived from its `VZMacMachineIdentifier`.
typealias ECID = UInt64

/// The options dictionary passed to `AMRestorableDeviceRestore`.
typealias RestoreOptionsDictionary = [String: AnyHashable]

/// Called for each progress report emitted by the restore engine.
///
/// `info` is the raw progress dictionary as delivered by the AMRestore callback
/// (bridged from `CFDictionary`); parse it with `DeviceRestoreState(info:)`.
typealias DeviceRestoreProgressClosure = @Sendable (_ info: [AnyHashable: Any]) -> Void

/// Optional file-backed log sinks handed to the restore engine so that the
/// global / per-device / host / serial logs are persisted to disk.
struct DeviceRestoreLoggers: @unchecked Sendable {
    var global: RestoreLog? = nil
    var device: RestoreLog? = nil
    var host: RestoreLog? = nil
    var serial: RestoreLog? = nil
}

/// Drives a low-level device restore for a DFU device identified by its `ECID`.
protocol DeviceRestoreBackend: Sendable {
    func restore(deviceECID: ECID,
                 options: RestoreOptionsDictionary,
                 loggers: DeviceRestoreLoggers,
                 progress: @escaping DeviceRestoreProgressClosure) throws
}

#endif
