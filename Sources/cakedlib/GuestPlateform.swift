import CakeAgentLib
import Dynamic
import Foundation
import Virtualization

public protocol GuestPlateForm {
	func bootLoader() throws -> VZBootLoader
	func platform() throws -> VZPlatformConfiguration
	func graphicsDevice(screenSize: CGSize) -> VZGraphicsDeviceConfiguration
	func keyboards(_ suspendable: Bool) -> [VZKeyboardConfiguration]
	func pointingDevices(_ suspendable: Bool) -> [VZPointingDeviceConfiguration]
}

struct LinuxPlateform: GuestPlateForm {
	let nvramURL: URL
	let needsNestedVirtualization: Bool
	let machineIdentifier: VZGenericMachineIdentifier

	func bootLoader() throws -> VZBootLoader {
		let result = VZEFIBootLoader()

		result.variableStore = VZEFIVariableStore(url: nvramURL)

		return result
	}

	func platform() throws -> VZPlatformConfiguration {
		let config: VZGenericPlatformConfiguration = VZGenericPlatformConfiguration()

		config.machineIdentifier = self.machineIdentifier

		if #available(macOS 15, *) {
			config.isNestedVirtualizationEnabled = needsNestedVirtualization
		}

		return config
	}

	func graphicsDevice(screenSize: CGSize) -> VZGraphicsDeviceConfiguration {
		let result: VZVirtioGraphicsDeviceConfiguration = VZVirtioGraphicsDeviceConfiguration()

		#if DEBUG
			Logger(self).trace("Create graphics device configuration for \(screenSize.width)x\(screenSize.height)")
		#endif

		result.scanouts = [
			VZVirtioGraphicsScanoutConfiguration(
				widthInPixels: Int(screenSize.width),
				heightInPixels: Int(screenSize.height)
			)
		]

		return result
	}

	func keyboards(_ suspendable: Bool) -> [VZKeyboardConfiguration] {
		[VZUSBKeyboardConfiguration()]
	}

	func pointingDevices(_ suspendable: Bool) -> [VZPointingDeviceConfiguration] {
		[VZUSBScreenCoordinatePointingDeviceConfiguration()]
	}
}

struct WindowsPlatform: GuestPlateForm {
	let nvramURL: URL
	let needsNestedVirtualization: Bool
	let machineIdentifier: VZGenericMachineIdentifier

	func bootLoader() throws -> VZBootLoader {
		let result = VZEFIBootLoader()

		result.variableStore = VZEFIVariableStore(url: nvramURL)

		return result
	}

	func platform() throws -> VZPlatformConfiguration {
		let config: VZGenericPlatformConfiguration = VZGenericPlatformConfiguration()

		config.machineIdentifier = self.machineIdentifier

		if #available(macOS 15, *) {
			config.isNestedVirtualizationEnabled = needsNestedVirtualization
		}

		try self.enableWindowsCPUFeatures(config)

		return config
	}

	/// On Apple silicon, Windows Boot Manager never gets past its first instructions unless the virtual CPU
	/// emulates the performance monitoring unit (and the fine-grained traps that go with it). The framework only
	/// offers these as private setters, so they are called by selector at run time. They are ARM features: an
	/// Intel host calls nothing (WINDOWS_INTEL_PLAN.md step 4 settles whether x64 needs an equivalent).
	/// Not available in the App Store build, which can't ship private API.
	private func enableWindowsCPUFeatures(_ config: VZGenericPlatformConfiguration) throws {
		#if APPSTORE
			throw ServiceError(String(localized: "Windows VMs are not supported in the App Store build"))
		#elseif arch(arm64)
			Dynamic(config)._setPerformanceMonitoringUnitEmulationEnabled(true)
			Dynamic(config)._setFineGrainedTrapsEmulationEnabled(true)
		#endif
	}

	func graphicsDevice(screenSize: CGSize) -> VZGraphicsDeviceConfiguration {
		let result: VZVirtioGraphicsDeviceConfiguration = VZVirtioGraphicsDeviceConfiguration()

		#if DEBUG
			Logger(self).trace("Create graphics device configuration for \(screenSize.width)x\(screenSize.height)")
		#endif

		result.scanouts = [
			VZVirtioGraphicsScanoutConfiguration(
				widthInPixels: Int(screenSize.width),
				heightInPixels: Int(screenSize.height)
			)
		]

		return result
	}

	func keyboards(_ suspendable: Bool) -> [VZKeyboardConfiguration] {
		[VZUSBKeyboardConfiguration()]
	}

	func pointingDevices(_ suspendable: Bool) -> [VZPointingDeviceConfiguration] {
		[VZUSBScreenCoordinatePointingDeviceConfiguration()]
	}
}

#if arch(arm64)
	struct DarwinPlateform: GuestPlateForm {
		let nvramURL: URL
		let ecid: VZMacMachineIdentifier
		let hardwareModel: VZMacHardwareModel

		func bootLoader() throws -> VZBootLoader {
			VZMacOSBootLoader()
		}

		func platform() throws -> VZPlatformConfiguration {
			let result: VZMacPlatformConfiguration = VZMacPlatformConfiguration()

			result.machineIdentifier = ecid
			result.auxiliaryStorage = VZMacAuxiliaryStorage(url: nvramURL)

			if hardwareModel.isSupported == false {
				throw ServiceError(String(localized: "Unsupported hardware model"))
			}

			result.hardwareModel = hardwareModel

			return result
		}

		func graphicsDevice(screenSize: CGSize) -> VZGraphicsDeviceConfiguration {
			let result: VZMacGraphicsDeviceConfiguration = VZMacGraphicsDeviceConfiguration()

			if let hostMainScreen = NSScreen.main {
				let vmScreenSize = NSSize(width: screenSize.width, height: screenSize.height)
				#if DEBUG
					Logger(self).trace("Create graphics device configuration for \(vmScreenSize.width)x\(vmScreenSize.height)")
				#endif

				result.displays = [
					VZMacGraphicsDisplayConfiguration(for: hostMainScreen, sizeInPoints: vmScreenSize)
				]

				return result
			}

			#if DEBUG
				Logger(self).trace("Create graphics device configuration for \(screenSize.width)x\(screenSize.height)")
			#endif

			result.displays = [
				VZMacGraphicsDisplayConfiguration(
					widthInPixels: Int(screenSize.width),
					heightInPixels: Int(screenSize.height),
					pixelsPerInch: 72
				)
			]

			return result
		}

		func keyboards(_ suspendable: Bool) -> [VZKeyboardConfiguration] {
			if #available(macOS 14, *) {
				if suspendable {
					return [VZMacKeyboardConfiguration()]
				} else {
					return [VZUSBKeyboardConfiguration(), VZMacKeyboardConfiguration()]
				}
			} else {
				return [VZUSBKeyboardConfiguration()]
			}
		}

		func pointingDevices(_ suspendable: Bool) -> [VZPointingDeviceConfiguration] {
			if #available(macOS 14, *), suspendable {
				[VZMacTrackpadConfiguration()]
			} else {
				[VZUSBScreenCoordinatePointingDeviceConfiguration(), VZMacTrackpadConfiguration()]
			}
		}
	}
#endif
