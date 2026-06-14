import Foundation
import GRPCLib
import Virtualization
import CakeAgentLib

public struct SpawnHandler {
	public static func spawn(options: SpawnOptions, runMode: Utils.RunMode) async -> BuildedReply {
		do {
			let storageLocation = StorageLocation(runMode: runMode)

			if storageLocation.exists(options.name) {
				return BuildedReply(name: options.name, builded: false, reason: String(localized: "VM already exists"))
			}

			if options.bridgedNetwork {
				guard try CakedKeyConfig.bridgedNetwork.get() != nil else {
					return BuildedReply(name: options.name, builded: false, reason: String(localized: "Any bridged network is not configured"))
				}
			}

			let tempVMLocation: VMLocation = try VMLocation.tempDirectory(runMode: runMode)
			let tmpVMDirLock = try FileLock(lockURL: tempVMLocation.rootURL)
			try tmpVMDirLock.lock()

			do {
				try await withTaskCancellationHandler(
					operation: {
						do {
							try await createVM(location: tempVMLocation, options: options)
							try storageLocation.relocate(options.name, from: tempVMLocation)
						} catch {
							try? FileManager.default.removeItem(at: tempVMLocation.rootURL)
							throw error
						}
					},
					onCancel: {
						try? FileManager.default.removeItem(at: tempVMLocation.rootURL)
					}
				)
			} catch {
				return BuildedReply(name: options.name, builded: false, reason: error.reason)
			}

			return BuildedReply(name: options.name, builded: true, reason: String(localized: "VM created"))
		} catch {
			return BuildedReply(name: options.name, builded: false, reason: error.reason)
		}
	}

	private static func createVM(location: VMLocation, options: SpawnOptions) async throws {
		let expandedRoot = options.root.expandingTildeInPath

		guard FileManager.default.fileExists(atPath: expandedRoot) else {
			throw ServiceError(String(localized: "Root disk not found: \(options.root)"))
		}

		#if arch(arm64)
		if options.os == .darwin {
			if let nvram = options.nvram {
				try FileManager.default.copyItem(atPath: nvram.expandingTildeInPath, toPath: location.nvramURL.path)
			} else {
				let restoreImage = try await VZMacOSRestoreImage.latestSupported
				guard let hardwareModel = restoreImage.mostFeaturefulSupportedConfiguration?.hardwareModel else {
					throw ServiceError(String(localized: "Unable to determine hardware model for macOS VM from latest supported restore image"))
				}
				_ = try VZMacAuxiliaryStorage(creatingStorageAt: location.nvramURL, hardwareModel: hardwareModel)
			}
		} else {
			_ = try VZEFIVariableStore(creatingVariableStoreAt: location.nvramURL)
		}
		#else
		_ = try VZEFIVariableStore(creatingVariableStoreAt: location.nvramURL)
		#endif

		let config = CakeConfig(
			location: location.rootURL,
			rootDisk: expandedRoot,
			os: options.os,
			autostart: options.autostart,
			configuredUser: options.user,
			configuredPassword: options.password,
			configuredGroup: "adm",
			configuredGroups: ["sudo"],
			configuredPlatform: .unknown,
			clearPassword: false,
			displayRefit: options.displayRefit,
			ifname: options.netIfnames,
			cpuCountMin: options.cpu,
			memorySize: options.memory * MoB,
			memorySizeMin: VMBuilder.memoryMinSize,
			screenSize: options.screenSize
		)

		config.useCloudInit = false
		config.agent = false
		config.nested = options.nested
		config.suspendable = options.suspendable && options.os == .darwin
		config.attachedDisks = options.attachedDisks
		config.networks = options.allNetworks
		config.mounts = options.mounts
		config.sockets = options.sockets
		config.console = options.consoleURL?.description
		config.forwardedPorts = options.forwardedPorts
		config.dynamicPortForwarding = options.dynamicPortForwarding
		config.source = .raw
		config.instanceID = "i-\(String(format: "%x", Int(Date().timeIntervalSince1970)))"

		try config.save()
	}
}
