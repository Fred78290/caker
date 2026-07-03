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
							try await createVM(location: tempVMLocation, options: options, runMode: runMode)
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

	private static func createVM(location: VMLocation, options: SpawnOptions, runMode: Utils.RunMode) async throws {
		let expandedRoot = options.root.expandingTildeInPath

		guard FileManager.default.fileExists(atPath: expandedRoot) else {
			throw ServiceError(String(localized: "Root disk not found: \(options.root)"))
		}

		let diskFormat = Utilities.isASIFDisk(filePath: expandedRoot) ? SupportedDiskFormat.asif : SupportedDiskFormat.raw
		var cpuCountMin = options.cpu
		var memorySize = options.memory * MoB
		var memorySizeMin = VMBuilder.memoryMinSize
		var hardwareModel: Data? = nil
		var ecid: Data? = nil

#if arch(arm64)
		if options.os == .darwin {
			if let nvram = options.nvram {
				try FileManager.default.copyItem(atPath: nvram.expandingTildeInPath, toPath: location.nvramURL.path)
			} else {
				let restoreImage = try await VZMacOSRestoreImage.latestSupported

				guard let requirements = restoreImage.mostFeaturefulSupportedConfiguration else {
					throw ServiceError(String(localized: "Unsupported restore image"))
				}

				cpuCountMin = max(UInt16(requirements.minimumSupportedCPUCount), options.cpu)
				memorySize = max(requirements.minimumSupportedMemorySize, options.memory * MoB)
				memorySizeMin = requirements.minimumSupportedMemorySize
				hardwareModel = requirements.hardwareModel.dataRepresentation
				ecid = VZMacMachineIdentifier().dataRepresentation

				_ = try VZMacAuxiliaryStorage(creatingStorageAt: location.nvramURL, hardwareModel: requirements.hardwareModel)
			}
		} else {
			_ = try VZEFIVariableStore(creatingVariableStoreAt: location.nvramURL)
		}
		#else
		_ = try VZEFIVariableStore(creatingVariableStoreAt: location.nvramURL)
		#endif

		let config = CakeConfig(
			location: location.rootURL,
			rootDisk: options.root,
			diskFormat: diskFormat,
			os: options.os,
			autostart: options.autostart,
			configuredUser: options.user,
			configuredPassword: options.password,
			configuredGroup: options.mainGroup,
			configuredGroups: options.otherGroup,
			configuredPlatform: .unknown,
			clearPassword: options.clearPassword,
			displayRefit: options.displayRefit,
			ifname: options.netIfnames,
			cpuCountMin: cpuCountMin,
			memorySize: memorySize,
			memorySizeMin: memorySizeMin,
			screenSize: options.screenSize
		)

		config.useCloudInit = options.os == .linux && options.useCloudInit
		config.agent = config.useCloudInit
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
		config.hardwareModel = hardwareModel
		config.ecid = ecid

		if config.useCloudInit {
			config.agent = false

			let cloudInit = try CloudInit(
				plateform: SupportedPlatform(rawValue: expandedRoot),
				userName: options.user,
				password: options.password,
				mainGroup: options.mainGroup,
				otherGroups: options.otherGroup,
				clearPassword: options.clearPassword,
				sshAuthorizedKeyPath: options.sshAuthorizedKey,
				vendorDataPath: options.vendorData,
				userDataPath: options.userData,
				networkConfigPath: options.networkConfig,
				netIfnames: options.netIfnames,
				runMode: runMode)

			try cloudInit.createDefaultCloudInit(config: config, name: options.name, cdromURL: URL(fileURLWithPath: cloudInitIso, relativeTo: location.configURL))
		}

		try config.save()
	}
}
