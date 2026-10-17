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
	/// A Windows guest shares the generic platform and EFI boot of a Linux one, but Windows Boot Manager
	/// needs the CPU features `enableWindowsCPUFeatures(_:)` turns on.
	var windowsGuest: Bool = false

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

		if windowsGuest {
			try Self.enableWindowsCPUFeatures(config)
		}

		return config
	}

	/// Windows Boot Manager never gets past its first instructions unless the virtual CPU emulates the
	/// performance monitoring unit (and the fine-grained traps that go with it). The framework only
	/// offers these as private setters, so they are looked up by selector at run time: a macOS that
	/// dropped them fails the Windows VM up front with a clear error instead of hanging at boot.
	/// Not available in the App Store build, which can't ship private API.
	static func enableWindowsCPUFeatures(_ config: VZGenericPlatformConfiguration) throws {
		#if APPSTORE
			throw ServiceError(String(localized: "Windows VMs are not supported in the App Store build"))
		#else
			Dynamic(config)._setPerformanceMonitoringUnitEmulationEnabled(true)
			Dynamic(config)._setFineGrainedTrapsEmulationEnabled(true)
		/*typealias BoolSetter = @convention(c) (AnyObject, Selector, Bool) -> Void

			for name in ["_setPerformanceMonitoringUnitEmulationEnabled:", "_setFineGrainedTrapsEmulationEnabled:"] {
				let selector = NSSelectorFromString(name)

				guard config.responds(to: selector), let implementation = config.method(for: selector) else {
					throw ServiceError(String(format: String(localized: "Windows VMs are not supported on this version of macOS (missing %@)"), name))
				}

				unsafeBitCast(implementation, to: BoolSetter.self)(config, selector, true)
			}*/
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
