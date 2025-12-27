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

	func bootLoader() throws -> VZBootLoader {
		let result = VZEFIBootLoader()

		result.variableStore = VZEFIVariableStore(url: nvramURL)

		return result
	}

	func platform() throws -> VZPlatformConfiguration {
		let config: VZGenericPlatformConfiguration = VZGenericPlatformConfiguration()

		if #available(macOS 15, *) {
			config.isNestedVirtualizationEnabled = needsNestedVirtualization
		}

		return config
	}

	func graphicsDevice(screenSize: CGSize) -> VZGraphicsDeviceConfiguration {
		let result: VZVirtioGraphicsDeviceConfiguration = VZVirtioGraphicsDeviceConfiguration()

		#if DEBUG
			Logger(self).debug("Create graphics device configuration for \(screenSize.width)x\(screenSize.height)")
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
				throw ServiceError("Unsupported hardware model")
			}

			result.hardwareModel = hardwareModel

			return result
		}

		func graphicsDevice(screenSize: CGSize) -> VZGraphicsDeviceConfiguration {
			let result: VZMacGraphicsDeviceConfiguration = VZMacGraphicsDeviceConfiguration()

			if let hostMainScreen = NSScreen.main {
				let vmScreenSize = NSSize(width: screenSize.width, height: screenSize.height)

				Logger(self).debug("Create graphics device configuration for \(vmScreenSize.width)x\(vmScreenSize.height)")

				result.displays = [
					VZMacGraphicsDisplayConfiguration(for: hostMainScreen, sizeInPoints: vmScreenSize)
				]

				return result
			}

			#if DEBUG
				Logger(self).debug("Create graphics device configuration for \(screenSize.width)x\(screenSize.height)")
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
