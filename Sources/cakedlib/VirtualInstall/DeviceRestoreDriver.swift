//
// Builds the restore options dictionary and drives a `DeviceRestoreBackend`
// for a single DFU device identified by its ECID.
//
// Ported from VirtualBuddy 2.2-b2 / UTM, adapted for Caker.
// Artifact / log storage goes to `<Application Support>/Caker/VirtualInstall`.
// Not available in the App Store build (private SPI + non-sandboxed only).

#if USE_VIRTUAL_INSTALL_BACKEND && arch(arm64)

import Foundation
import CakeAgentLib

final class DeviceRestoreDriver: @unchecked Sendable {
    private let logger: Logger
    private let ecid: ECID
    private let bundleURL: URL
    private let variantName: String
    private let backend: any DeviceRestoreBackend

    private let personalizedBundleURL: URL

    let artifactStorageURL: URL
    let loggers: DeviceRestoreLoggers

	deinit {
		if !Self.preservePersonalizedBundles {
			try? FileManager.default.removeItem(at: personalizedBundleURL)
		}
	}

	init(ecid: ECID, bundleURL: URL, variantName: String = "Customer Erase Install (IPSW)", backend: any DeviceRestoreBackend) throws {
        self.logger = Logger("DeviceRestoreDriver(\(ecid))")
        self.ecid = ecid
        self.bundleURL = bundleURL
        self.variantName = variantName
        self.backend = backend

        self.artifactStorageURL = try Self.artifactStorageBaseURL()
        self.personalizedBundleURL = try Self.ensureExistingDirectory(
            artifactStorageURL.appendingPathComponent(
                "Personalized_\(bundleURL.deletingPathExtension().lastPathComponent)_\(ecid)_\(Int(Date().timeIntervalSinceReferenceDate))",
                isDirectory: true
            )
        )

        let logBaseURL = try Self.ensureExistingDirectory(
            artifactStorageURL.appendingPathComponent("Logs", isDirectory: true)
        )

        self.loggers = DeviceRestoreLoggers(
            global: RestoreLog(fileURL: logBaseURL.appendingPathComponent("global.log")),
            device: RestoreLog(fileURL: logBaseURL.appendingPathComponent("device.log")),
            host: RestoreLog(fileURL: logBaseURL.appendingPathComponent("host.log")),
            serial: RestoreLog(fileURL: logBaseURL.appendingPathComponent("serial.log"))
        )
    }

    func start(overrideOptions: RestoreOptionsDictionary? = nil, progressHandler: @escaping @Sendable (_ state: DeviceRestoreState) -> Void) throws {
        let options = overrideOptions ?? buildRestoreOptions()
        
		logger.debug("Start with options \(String(describing: options))")

		try backend.restore(deviceECID: ecid, options: options, loggers: loggers) { [weak self] info in
            do {
                let state = try DeviceRestoreState(info: info)
                progressHandler(state)
            } catch {
                self?.logger.error("Failed to parse progress info: \(error.localizedDescription)")
            }
        }
    }

    private static let preservePersonalizedBundles = ProcessInfo.processInfo.environment["VI_PRESERVE_PERSONALIZED_BUNDLES"] == "1"

    private func buildRestoreOptions() -> RestoreOptionsDictionary {
        [
            "AuthInstallDemotionPolicyOverride": "Don't Demote",
            "AuthInstallEnableSso": 0,
            "AuthInstallPreservePersonalizedBundles": Self.preservePersonalizedBundles ? 1 : 0,
            "AuthInstallSigningServerURL": "https://gs.apple.com:443",
            "AuthInstallVariant": variantName,
            "AutoBootDelay": 0,
            "BootImageType": "User",
            "CreateFilesystemPartitions": true,
            "DFUFileType": "RELEASE",
            "EncryptDataPartition": true,
            "FlashNOR": true,
            "InstallDiags": true,
            "InstallRecoveryOS": true,
            "KernelCacheType": "Release",
            "NORImageType": "production",
            "PersonalizedRestoreBundlePath": personalizedBundleURL.safeRestorePath,
            "PostRestoreAction": "Shutdown",
            "ReadOnlyRootFilesystem": true,
            "RecoveryOSFailureIsFatal": true,
            "RecoveryOSOnly": false,
            "RecoveryOSUnpack": false,
            "RelaxedImageVerification": false,
            "RestoreBootArgs": "debug=0x14e serial=3 rd=md0 nand-enable-reformat=1 -progress -restore",
            "RestoreBundlePath": bundleURL.safeRestorePath,
            "SystemImageType": "User",
            "UpdateBaseband": true,
            "WaitForDeviceConnectionToFinishStateMachine": false,
        ]
    }

    // MARK: - Storage helpers

    /// Base directory: `<Application Support>/Caker/VirtualInstall`.
    private static func artifactStorageBaseURL() throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Caker", isDirectory: true)
            .appendingPathComponent("VirtualInstall", isDirectory: true)
        return try ensureExistingDirectory(base)
    }

    @discardableResult
    private static func ensureExistingDirectory(_ url: URL) throws -> URL {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }
}

private extension URL {
    /// Percent-encoding-free file-system path suitable for passing to the restore engine.
    var safeRestorePath: String { absoluteURL.path }
}

#endif
