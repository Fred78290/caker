//
//  VirtualMachineConfiguration.swift
//  Caker
//
//  Created by Frederic BOLTZ on 02/03/2026.
//
import Foundation
import NIOPortForwarding
import Virtualization
import CakeAgentLib

public typealias DisplaySize = [String: Int]

public enum VirtualizedOS: String, Codable {
	case darwin
	case linux
}

public enum Architecture: String, Codable, CustomStringConvertible {
	public var description: String {
		switch self {
		case .arm64:
			return "aarch64"
		case .amd64:
			return "x86_64"
		case .aarch64:
			return "aarch64"
		case .armv7l:
			return "armv7l"
		case .armhf:
			return "armhf"
		case .i386:
			return "i386"
		case .i686:
			return "i686"
		case .powerpc:
			return "powerpc"
		case .ppc:
			return "ppc"
		case .ppc64el:
			return "ppc64el"
		case .riscv64:
			return "riscv64"
		case .s390x:
			return "s390x"
		case .x86_64:
			return "x86_64"
		}
	}

	public init(rawValue: String) {
		switch rawValue {
		case "arm64":
			self = .arm64
		case "amd64":
			self = .amd64
		case "aarch64":
			self = .aarch64
		case "armv7l":
			self = .armv7l
		case "armhf":
			self = .armhf
		case "i386":
			self = .i386
		case "i686":
			self = .i686
		case "ppc":
			self = .ppc
		case "powerpc":
			self = .powerpc
		case "ppc64el":
			self = .ppc64el
		case "riscv64":
			self = .riscv64
		case "s390x":
			self = .s390x
		case "x86_64":
			self = .x86_64
		default:
			Logger("Architecture").warn("Unknown architecture: \(rawValue)")
			// Default to amd64 if unknown
			// This is a fallback and should be handled better
			// in the future.
			self = .amd64
		}
	}

	case arm64
	case amd64
	case aarch64
	case armv7l
	case armhf
	case i386
	case i686
	case powerpc
	case ppc
	case ppc64el
	case riscv64
	case s390x
	case x86_64

	public static func current() -> Architecture {
		#if arch(arm64)
			return .arm64
		#elseif arch(x86_64)
			return .amd64
		#endif
	}
}

public enum SupportedPlatform: String, CaseIterable {
	case ubuntu
	case centos
	case macos
	case windows
	case debian
	case fedora
	case redhat
	case openSUSE
	case alpine
	case unknown

	public init(rawValue: String) {
		let rawValue = rawValue.lowercased()
		let value = Self.allCases.first {
			rawValue.contains($0.rawValue)
		}

		if let value = value {
			self = value
		} else {
			self = .unknown
		}
	}

	public init(stringValue: String?) {
		if let rawValue = stringValue {
			self.init(rawValue: rawValue)
		} else {
			self = .unknown
		}
	}
}

public protocol VirtualMachineConfiguration {
	var locationURL: URL { get }
	var version: Int { set get }
	var os: VirtualizedOS { set get }
	var arch: Architecture { set get }
	var cpuCountMin: Int { set get }
	var suspendable: Bool { set get }
	var diskSize: Int { set get }
	var cpuCount: Int { set get }
	var memorySizeMin: UInt64 { set get }
	var memorySize: UInt64 { set get }
	var macAddress: String? { set get }
	var source: ImageSource { set get }
	var osName: String? { set get }
	var osRelease: String? { set get }
	var dynamicPortForwarding: Bool { set get }
	var displayRefit: Bool { set get }
	var instanceID: String { set get }
	var dhcpClientID: String? { set get }
	var sshPrivateKeyPath: String? { set get }
	var sshPrivateKeyPassphrase: String? { set get }
	var configuredUser: String { set get }
	var configuredPassword: String? { set get }
	var configuredGroup: String { set get }
	var configuredGroups: [String]? { set get }
	var configuredPlatform: SupportedPlatform { set get }
	var clearPassword: Bool { set get }
	var ifname: Bool { set get }
	var autostart: Bool { set get }
	var agent: Bool { set get }
	var firstLaunch: Bool { set get }
	var nested: Bool { set get }
	var attachedDisks: [DiskAttachement] { set get }
	var mounts: DirectorySharingAttachments { set get }
	var networks: [BridgeAttachement] { set get }
	var useCloudInit: Bool { set get }
	var sockets: [SocketDevice] { set get }
	var console: ConsoleAttachment? { set get }
	var forwardedPorts: [TunnelAttachement] { set get }
	var runningIP: String? { set get }
	var display: DisplaySize { set get }
	var vncPassword: String { set get }
	var ecid: Data? /*VZMacMachineIdentifier*/  { set get }
	var hardwareModel: Data? /*VZMacHardwareModel?*/ { set get }
}

extension VirtualMachineConfiguration {

}
