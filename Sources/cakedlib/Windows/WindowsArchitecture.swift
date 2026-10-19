//
//  WindowsArchitecture.swift
//  Caker
//
//  The CPU architecture of a Windows guest. Virtualization.framework runs guests of the host's own architecture
//  only, so a Windows 11 ARM ISO installs on Apple silicon and a Windows 11 x64 ISO on an Intel Mac. Everything
//  that differs between the two (boot file names, driver folders, the answer file's `processorArchitecture`,
//  the agent build) is a property here, so the installer has no architecture literal left in it.
//

import Foundation

enum WindowsArchitecture: String, CaseIterable, Sendable {
	case arm64
	case amd64

	/// The architecture of the Mac running caked, which is the only one a guest can have.
	static var host: WindowsArchitecture {
		#if arch(arm64)
			return .arm64
		#else
			return .amd64
		#endif
	}

	/// How the architecture is named in messages.
	var displayName: String {
		switch self {
		case .arm64: return "ARM64"
		case .amd64: return "x64"
		}
	}

	/// The firmware's default boot file, as it is spelled in the ISO (which is lower case).
	var bootFile: String {
		switch self {
		case .arm64: return "bootaa64.efi"
		case .amd64: return "bootx64.efi"
		}
	}

	/// Where UEFI looks for a bootable disk's loader when no boot entry exists, as seen from the system partition in Windows.
	var removableBootPath: String {
		"S:\\EFI\\BOOT\\\(self.bootFile.uppercased())"
	}

	/// The folder holding this architecture's drivers under `<driver>/w11/` in the virtio-win ISO.
	var virtioFolder: String {
		switch self {
		case .arm64: return "ARM64"
		case .amd64: return "amd64"
		}
	}

	/// `processorArchitecture` in the answer file's components.
	var unattendArchitecture: String {
		self.rawValue
	}

	/// The suffix of the Windows cakeagent build (`cakeagent-windows-<suffix>.exe`).
	var agentSuffix: String {
		self.rawValue
	}

	/// Whether the guest needs the EFI framebuffer helpers (`Tools/WindowsEFI`). Apple silicon's firmware exposes a
	/// GPU that can only blit, so Windows would draw into nothing. Nobody has checked what the Intel firmware does:
	/// until WINDOWS_INTEL_PLAN.md step 3 says otherwise, an x64 guest boots Windows Boot Manager directly, and the
	/// helpers (built for AArch64 only) are not copied.
	var usesFramebufferShim: Bool {
		self == .arm64
	}

	/// Finds the architecture of a Windows installation ISO from the boot loader it carries (`efi/boot/bootaa64.efi`
	/// or `bootx64.efi`), and refuses one the host can't run. When an ISO has both, the host's wins.
	///
	/// - Parameters:
	///   - exists: tells whether a path relative to the ISO's root exists.
	///   - name: the ISO's name, for the error messages.
	static func detect(name: String, host: WindowsArchitecture = .host, exists: (String) -> Bool) throws -> WindowsArchitecture {
		let candidates = [host] + Self.allCases.filter { $0 != host }

		guard let architecture = candidates.first(where: { exists("efi/boot/\($0.bootFile)") }) else {
			throw ServiceError(String(format: String(localized: "%@ has no ARM64 or x64 Windows boot loader"), name))
		}

		guard architecture == host else {
			throw ServiceError(String(format: String(localized: "%@ is a Windows %@ installation ISO, but this Mac can only run Windows %@"), name, architecture.displayName, host.displayName))
		}

		return architecture
	}
}
