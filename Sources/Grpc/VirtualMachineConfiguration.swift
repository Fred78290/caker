//
//  VirtualMachineConfiguration.swift
//  Caker
//
//  Created by Frederic BOLTZ on 02/03/2026.
//
import Foundation
import NIOPortForwarding
import CakeAgentLib

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

public enum SupportedPlatform: String, Codable, CaseIterable {
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
	var console: String? { set get }
	var forwardedPorts: [TunnelAttachement] { set get }
	var runningIP: String? { set get }
	var display: ViewSize { set get }
	var vncPassword: String { set get }
	var ecid: Data? /*VZMacMachineIdentifier*/  { set get }
	var hardwareModel: Data? /*VZMacHardwareModel?*/ { set get }
}

extension Caked.Configuration.VirtualizedOS {
	init(_ os: VirtualizedOS) {
		switch os {
		case .linux:
			self = .linux
		case .darwin:
			self = .darwin
		}
	}
}

extension Caked.Configuration.Architecture {
	init(_ arch: Architecture) {
		switch arch {

		case .arm64:
			self = .arm64
		case .amd64:
			self = .amd64
		default:
			self = .other
		}
	}
}

extension Caked.Configuration.SupportedPlatform {
	init(_ platform: SupportedPlatform) {
		switch platform {
		case .ubuntu:
			self = .ubuntu
		case .centos:
			self = .centos
		case .macos:
			self = .macos
		case .windows:
			self = .windows
		case .debian:
			self = .debian
		case .fedora:
			self = .fedora
		case .redhat:
			self = .redhat
		case .openSUSE:
			self = .openSuse
		case .alpine:
			self = .alpine
		case .unknown:
			self = .undefined
		}
	}
}

extension Caked.Configuration.BridgeAttachment {
	init(_ attachment: BridgeAttachement) {
		self = .with {
			$0.network = attachment.network

			if let macAddress = attachment.macAddress {
				$0.macAddress = macAddress
			}

			if let mode = attachment.mode {
				$0.mode = mode.description
			}
		}
	}
}

extension Caked.Configuration.DirectorySharingAttachment {
	init(_ attachment: DirectorySharingAttachment) {
		self = .with {
			$0.source = attachment.source
			$0.readOnly = attachment.readOnly
			
			if let name = attachment._name {
				$0.name = name
			}
			
			if let destination = attachment._destination {
				$0.destination = destination
			}
			
			if let uid = attachment._uid {
				$0.uid = Int32(uid)
			}

			if let gid = attachment._gid {
				$0.gid = Int32(gid)
			}
		}
	}
}

extension Caked.Configuration.DiskAttachment {
	init(_ attachment: DiskAttachement) {
		self = .with {
			$0.diskPath = attachment.diskPath
			$0.diskOptions = .with {
				$0.readOnly = attachment.diskOptions.readOnly
				$0.syncMode = attachment.diskOptions.syncMode.description
				$0.cachingMode = attachment.diskOptions.cachingMode.description
			}
		}
	}
}

extension Caked.Configuration.SocketDevice {
	init(_ device: SocketDevice) {
		self = .with {
			$0.mode = Int32(device.mode.intValue)
			$0.port = Int32(device.port)
			$0.bind = device.bind
		}
	}
}

extension MappedPort.Proto {
	var description: String {
		switch self {
		case .tcp:
			return "tcp"
		case .udp:
			return "udp"
		case .both:
			return "both"
		case .none:
			return "none"
		}
	}
}

extension Caked.Configuration.TunnelAttachement {
	init(_ attachment: TunnelAttachement) {
		self = .with {
			switch attachment.oneOf {
			case .forward(let value):
				$0.forward = .with {
					$0.guestPort = Int32(value.guest)
					$0.hostPort = Int32(value.host)
					$0.protocol = value.proto.description
				}
			case .unixDomain(let unixDomain):
				$0.unixDomain = .with {
					$0.guestPath = unixDomain.guest
					$0.hostPath = unixDomain.host
					$0.protocol = unixDomain.proto.description
				}
			default:
				break
			}
		}
	}
}

extension Caked.Configuration.ImageSource {
	init(_ source: ImageSource) {
		switch source {
		case .raw:
			self = .raw
		case .cloud:
			self = .cloud
		case .oci:
			self = .oci
		case .template:
			self = .template
		case .stream:
			self = .stream
		case .iso:
			self = .iso
		case .ipsw:
			self = .ipsw
		}
	}
}

extension VirtualMachineConfiguration {
	public func hash(into hasher: inout Hasher) {
		hasher.combine(instanceID)
	}

	public var caked: Caked.Configuration {
		Caked.Configuration.with {
			$0.version = Int32(self.version)
			$0.instanceID = self.instanceID
			$0.os = .init(self.os)
			$0.arch = .init(self.arch)
			$0.configuredPlatform = .init(self.configuredPlatform)
			if let osName {
				$0.osName = osName
			}
			
			if let osRelease {
				$0.osRelease = osRelease
			}
			$0.diskSize = UInt32(self.diskSize)
			$0.cpuCount = Int32(self.cpuCount)
			$0.cpuCountMin = Int32(self.cpuCountMin)
			$0.memorySize = UInt64(self.memorySize)
			$0.memorySizeMin = UInt64(self.memorySizeMin)
			if let macAddress {
				$0.macAddress = macAddress
			}
			$0.networks = self.networks.map({.init($0)})
			$0.dynamicPortForwarding = self.dynamicPortForwarding
			$0.display = .with {
				let display = self.display

				$0.width = Int32(display.width)
				$0.height = Int32(display.height)
			}
			$0.displayRefit = self.displayRefit
			$0.mounts = self.mounts.map({.init($0)})
			$0.attachedDisks = self.attachedDisks.map({.init($0)})
			$0.sockets = self.sockets.map({.init($0)})
			if let console {
				$0.console = console
			}
			$0.forwardedPorts = self.forwardedPorts.map({.init($0)})
			$0.configuredUser = self.configuredUser
			if let configuredPassword = self.configuredPassword {
				$0.configuredPassword = configuredPassword
			}
			$0.configuredGroup = self.configuredGroup
			if let configuredGroups {
				$0.configuredGroups = configuredGroups
			}
			
			if let sshPrivateKeyPath {
				$0.sshPrivateKeyPath = sshPrivateKeyPath
			}
			
			if let sshPrivateKeyPassphrase {
				$0.sshPrivateKeyPassphrase = sshPrivateKeyPassphrase
			}
			
			$0.clearPassword_p = self.clearPassword
			$0.source = .init(self.source)
			
			if let dhcpClientID {
				$0.dhcpClientID = dhcpClientID
			}
			
			$0.vncPassword = self.vncPassword
			
			if let runningIP {
				$0.runningIp = runningIP
			}
			
			$0.useCloudInit = self.useCloudInit
			$0.autostart = self.autostart
			$0.agent = self.agent
			$0.firstLaunch = self.firstLaunch
			$0.nested = self.nested
			$0.suspendable = self.suspendable
			$0.ifname = self.ifname
			
			if let ecid {
				$0.ecid = ecid
			}
			
			if let hardwareModel {
				$0.hardwareModel = hardwareModel
			}
		}
	}
}

