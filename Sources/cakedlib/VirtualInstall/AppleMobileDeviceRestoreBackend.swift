//
// `DeviceRestoreBackend` implementation that drives a restore through the private
// `AppleMobileDeviceRestore` ("AMRestore") framework.
//
// Ported from VirtualBuddy 2.2-b2 / UTM, adapted for Caker.
// Not available in the App Store build (private SPI + non-sandboxed only).
//
// Only compiled on Apple Silicon; the AMRestore SPI does not exist on x86_64.

#if !APPSTORE && arch(arm64)

import Foundation
import CakeAgentLib
import VirtualInstallSPI

/// `DeviceRestoreBackend` that drives a real restore through the private
/// `AppleMobileDeviceRestore` ("AMRestore") framework.
final class AppleMobileDeviceRestoreBackend: DeviceRestoreBackend, @unchecked Sendable {
    private let logger = Logger("AppleMobileDeviceRestoreBackend")

    private var progressHandler: DeviceRestoreProgressClosure?

	func restore(deviceECID: ECID, options: RestoreOptionsDictionary, loggers: DeviceRestoreLoggers, progress: @escaping DeviceRestoreProgressClosure) throws {
		guard VIMDAvailable() else {
			logger.error("MobileDevice.framework is not available — AMRestore backend cannot be used")
			throw AppleMobileDeviceRestoreError.frameworkUnavailable
		}

		guard let device = VIWaitForDeviceWithECID(deviceECID, .unknown, 5000) else {
			logger.error("Couldn't find device with ECID \(deviceECID)")
			throw AppleMobileDeviceRestoreError.deviceNotFound
		}
		defer { VIReleaseDevice(device) }

		let deviceState = VIMDGetState(device)
		logger.info("Found device \(deviceECID) with state \(deviceState.rawValue)")
		
		self.progressHandler = progress
		
		if let global = loggers.global {
			if !VIMDSetGlobalLogFileURL(global.fileURL as CFURL) {
				logger.warn("Failed to set global log file URL")
			}
		}
		
		if let serial = loggers.serial {
			if !VIMDSetLogFileURL(device, serial.fileURL as CFURL, "SerialLogType" as CFString) {
				logger.warn("Failed to set serial log file URL")
			}
		}
		
		if let host = loggers.host {
			if !VIMDSetLogFileURL(device, host.fileURL as CFURL, "HostLogType" as CFString) {
				logger.warn("Failed to set host log file URL")
			}
		}
		
		if let deviceLog = loggers.device {
			if !VIMDSetLogFileURL(device, deviceLog.fileURL as CFURL, "DeviceLogType" as CFString) {
				logger.warn("Failed to set device log file URL")
			}
		}
		
		// `self` is passed unretained as the callback refCon. This is safe because
		// VIMDDeviceRestore (AMRestorableDeviceRestore) blocks until the restore finishes,
		// delivering progress on the calling thread, so `self` outlives every callback.
		let refCon = unsafeBitCast(self, to: UnsafeMutableRawPointer.self)
		
		VIMDDeviceRestore(device, options as CFDictionary, { _, info, refCon in
			guard let refCon = refCon else { return }
			let backend = unsafeBitCast(refCon, to: AppleMobileDeviceRestoreBackend.self)
			// `info` is a CFDictionary; bridge to NSDictionary then to Swift dictionary
			let nsInfo = info as NSDictionary
			if let dict = nsInfo as? [AnyHashable: Any] {
				backend.progressHandler?(dict)
			}
		}, refCon)
	}
}

/// Errors surfaced by `AppleMobileDeviceRestoreBackend`.
enum AppleMobileDeviceRestoreError: LocalizedError {
    case deviceNotFound
    case frameworkUnavailable

    var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            return NSLocalizedString(
                "Couldn't find a restorable device to install onto. Make sure the virtual machine is running in DFU mode.",
                comment: "AppleMobileDeviceRestoreBackend")
        case .frameworkUnavailable:
            return NSLocalizedString(
                "MobileDevice.framework could not be loaded. AMRestore-based installation is not available on this system.",
                comment: "AppleMobileDeviceRestoreBackend")
        }
    }
}

#endif

