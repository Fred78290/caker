import CakeAgentLib
import CakedLib
import Foundation
import GRPC
import GRPCLib
import NIO
import NIOPortForwarding

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

extension Caked.Configuration.ConsoleAttachment {
	init(_ attachment: ConsoleAttachment) {
		self = .with {
			$0.url = attachment.description
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

extension Caked_Caked.Configuration.TunnelAttachement {
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

extension Caked_Caked.Configuration.ImageSource {
	init(_ source: VMBuilder.ImageSource) {
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

extension CakeConfig {
	var caked: Caked.Configuration {
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
			
			$0.cpuCount = Int32(self.cpuCount)
			$0.cpuCountMin = Int32(self.cpuCountMin)
			$0.memorySize = UInt64(self.memorySize)
			$0.memorySizeMin = UInt64(self.memorySizeMin)
			$0.macAddress = self.macAddress?.string ?? ""
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
				$0.console = .init(console)
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

			#if arch(arm64)
			$0.ecid = self.ecid.dataRepresentation.base64EncodedString()

			if let hardwareModel {
				$0.hardwareModel = hardwareModel.dataRepresentation.base64EncodedString()
			}
			#endif

			$0.installAgent = self.installAgent
		}
	}
}

struct InfosHandler: CakedCommand {
	var request: Caked_InfoRequest
	var client: CakeAgentConnection

	func replyError(error: any Error) -> Caked_Reply {
		return Caked_Reply.with {
			$0.vms = Caked_VirtualMachineReply.with {
				$0.status = .with {
					$0.success = false
					$0.reason = "\(error)"
				}
			}
		}
	}

	func run(on: EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
		do {
			let result = try CakedLib.InfosHandler.infos(
				name: self.request.name, runMode: runMode, client: CakeAgentHelper(on: on, client: try client.createClient()), callOptions: CallOptions(timeLimit: TimeLimit.timeout(TimeAmount.seconds(5))))
			let reply = VirtualMachineStatusReply(infos: result.infos, success: true, reason: "Success")

			return Caked_Reply.with {
				$0.vms = Caked_VirtualMachineReply.with {
					var caked = reply.caked

					if request.includeConfig {
						caked.config = result.config.caked
					}

					$0.status = caked
				}
			}
		} catch {
			return replyError(error: error)
		}
	}
}

