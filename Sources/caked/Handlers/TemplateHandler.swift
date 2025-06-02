import ArgumentParser
import Cocoa
import Foundation
import GRPCLib
import NIO
import Shout
import TextTable

private let cloudInitCleanup = [
	"systemctl disable cakeagent",
	"rm -f /etc/cloud/cloud.cfg.d/50-curtin-networking.cfg",
	"rm /etc/netplan/*",
	"cloud-init clean",
	"cloud-init clean -l",
	"rm -rf /etc/apparmor.d/cache/* /etc/apparmor.d/cache/.features",
	"/usr/bin/truncate --size 0 /etc/machine-id",
	"rm -f /snap/README",
	"find /usr/share/netplan -name __pycache__ -exec rm -r {} +",
	"rm -rf /var/cache/pollinate/seeded /var/cache/snapd/* /var/cache/motd-news",
	"rm -rf /var/lib/cloud /var/lib/dbus/machine-id /var/lib/private /var/lib/systemd/timers /var/lib/systemd/timesync /var/lib/systemd/random-seed",
	"rm -f /var/lib/ubuntu-release-upgrader/release-upgrade-available",
	"rm -f /var/lib/update-notifier/fsck-at-reboot /var/lib/update-notifier/hwe-eol",
	"find /var/log -type f -exec rm -f {} +",
	"rm -rf /tmp/* /tmp/.*-unix /var/tmp/* /var/lib/apt/*",
	"/bin/sync",
	//	"shutdown -h now"
]

struct TemplateHandler: CakedCommand {
	let request: Caked_TemplateRequest

	static func cleanCloudInit(source: VMLocation, config: CakeConfig, runMode: Utils.RunMode) throws -> VMLocation {
		let location = try source.duplicateTemporary(runMode: runMode)
		let runningIP = try StartHandler.internalStartVM(vmLocation: location, config: config, waitIPTimeout: 120, startMode: .attach, runMode: runMode)
		let conn = try CakeAgentConnection(eventLoop: Root.group.next(), listeningAddress: location.agentURL, runMode: runMode)

		Logger(self).info("Clean cloud-init on \(runningIP)")

		try conn.run(command: cloudInitCleanup.joined(separator: " && ")).log()
		try location.stopVirtualMachine(force: false, runMode: runMode)

		return location
	}

	static func createTemplate(on: EventLoop, sourceName: String, templateName: String, runMode: Utils.RunMode) throws -> CreateTemplateReply {
		let storage = StorageLocation(runMode: runMode, template: true)
		var source: VMLocation = try StorageLocation(runMode: runMode).find(sourceName)

		if storage.exists(templateName) {
			throw ServiceError("template \(templateName) already exists")
		}

		if source.status != .running {
			let lock: FileLock = try FileLock(lockURL: storage.rootURL)
			let config = try source.config()
			let templateLocation = storage.location(templateName)

			try lock.lock()

			defer {
				try? lock.unlock()
			}

			try FileManager.default.createDirectory(at: templateLocation.rootURL, withIntermediateDirectories: true)

			if config.os == .linux && config.useCloudInit {
				source = try cleanCloudInit(source: source, config: config, runMode: runMode)
			}

			try source.templateTo(templateLocation)

			return CreateTemplateReply(name: templateName, created: true, reason: "template created")
		} else {
			return CreateTemplateReply(name: templateName, created: false, reason: "source VM \(sourceName) is running")
		}
	}

	static func deleteTemplate(templateName: String, runMode: Utils.RunMode) throws -> DeleteTemplateReply {
		let storage = StorageLocation(runMode: runMode, template: true)
		let lock = try FileLock(lockURL: storage.rootURL)
		var vmLocation: VMLocation? = nil

		try lock.lock()

		defer {
			try? lock.unlock()
		}

		if let location: VMLocation = try? storage.find(templateName) {
			vmLocation = location
		} else if let u = URL(string: templateName), u.scheme == "template" {
			vmLocation = try? StorageLocation(runMode: runMode).find(u.host()!)
		}

		if let location = vmLocation, location.status != .running {
			if location.status != .running {
				try? FileManager.default.removeItem(at: location.rootURL)
				return .init(name: location.name, deleted: true)
			} else {
				return .init(name: location.name, deleted: false)
			}
		}

		return .init(name: templateName, deleted: false)
	}

	static func listTemplate(runMode: Utils.RunMode) throws -> [TemplateEntry] {
		let storage = StorageLocation(runMode: runMode, template: true)

		return try storage.list().map { (key: String, value: VMLocation) in
			return TemplateEntry(
				name: key,
				fqn: "template://\(key)",
				diskSize: try value.diskSize(),
				totalSize: try value.allocatedSize()
			)
		}
	}

	func run(on: EventLoop, runMode: Utils.RunMode) throws -> Caked_Reply {
		switch request.command {
		case .add:
			let result = try Self.createTemplate(on: on, sourceName: request.createRequest.sourceName, templateName: request.createRequest.templateName, runMode: runMode)

			return Caked_Reply.with {
				$0.templates = Caked_Caked.Reply.TemplateReply.with {
					$0.create = result.toCaked_CreateTemplateReply()
				}
			}

		case .delete:
			let result = try Self.deleteTemplate(templateName: request.deleteRequest, runMode: runMode)

			return Caked_Reply.with {
				$0.templates = Caked_TemplateReply.with {
					$0.delete = Caked_DeleteTemplateReply.with {
						$0.name = result.name
						$0.deleted = result.deleted
					}
				}
			}

		case .list:
			let result = try Self.listTemplate(runMode: runMode)

			return Caked_Reply.with {
				$0.templates = Caked_Caked.Reply.TemplateReply.with {
					$0.list = Caked_ListTemplatesReply.with {
						$0.templates = result.map {
							$0.toCaked_TemplateEntry()
						}
					}
				}
			}

		default:
			throw ServiceError("Unknown command \(request.command)")
		}
	}
}
