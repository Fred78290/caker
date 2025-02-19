import ArgumentParser
import Foundation
import GRPCLib
import NIO
import TextTable
import Shout
import Cocoa

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
	"shutdown now"
]

struct TemplateHandler: CakedCommand {
	let request: Caked_TemplateRequest

	struct TemplateEntry: Codable {
		let name: String
		let fqn: String
		let diskSize: String
		let totalSize: String
	}

	struct CreateTemplateReply: Codable {
		let name: String
		let created: Bool
		var reason: String? = nil
	}

	struct DeleteTemplateReply: Codable {
		let name: String
		let deleted: Bool
	}

	static func runTempVM(on: EventLoop, asSystem: Bool, location: VMLocation, config: CakeConfig) throws -> EventLoopFuture<String> {
		on.submit {
			try StartHandler.startVM(vmLocation: location, config: config, waitIPTimeout: 120, foreground: false)
		}
	}

	static func cleanCloudInit(location: VMLocation, config: CakeConfig, asSystem: Bool) throws -> EventLoopFuture<Caked_ExecuteReply> {
		let eventLoop = Root.group.next()
		let runningIP = try runTempVM(on: eventLoop, asSystem: false, location: location, config: config)

		return runningIP.flatMapWithEventLoop { runningIP, on in
			on.makeFutureWithTask {
				let certLocation = try CertificatesLocation(certHome: URL(fileURLWithPath: "agent", isDirectory: true, relativeTo: try Utils.getHome(asSystem: asSystem))).createCertificats()
				let conn = CakeAgentConnection(eventLoop: on.next(),
				                               listeningAddress: location.agentURL,
				                               caCert: certLocation.caCertURL.path(),
				                               tlsCert: certLocation.serverCertURL.path(),
				                               tlsKey: certLocation.serverKeyURL.path())

				return try await conn.execute(request: Caked_ExecuteRequest.with {
					$0.command = cloudInitCleanup.joined(separator: " && ")
				})
			}
		}
	}

	static func createTemplate(on: EventLoop, sourceName: String, templateName: String, asSystem: Bool) throws -> EventLoopFuture<CreateTemplateReply> {
		let storage = StorageLocation(asSystem: asSystem, template: true)
		let source: VMLocation = try StorageLocation(asSystem: asSystem).find(sourceName)

		if storage.exists(templateName) {
			throw ServiceError("template \(templateName) already exists")
		}

		if source.status != .running {
			let lock: FileLock = try FileLock(lockURL: storage.rootURL)
			let config = try source.config()
			let templateLocation = storage.location(templateName)

			try lock.lock()

			try FileManager.default.createDirectory(at: templateLocation.rootURL, withIntermediateDirectories: true)

			if config.os == .linux && config.useCloudInit {
				let tmpVM = try source.duplicateTemporary()

				return try cleanCloudInit(location: tmpVM, config: config, asSystem: asSystem).flatMapThrowing { _ in
					defer {
						try? lock.unlock()
					}
					try FileManager.default.copyItem(at: tmpVM.diskURL, to: templateLocation.diskURL)
					return CreateTemplateReply(name: templateName, created: true, reason: "template created")
				}
			} else {
				return on.submit {
					defer {
						try? lock.unlock()
					}
					try FileManager.default.copyItem(at: source.diskURL, to: templateLocation.diskURL)
					return CreateTemplateReply(name: templateName, created: true, reason: "template created")
				}
			}
		} else {
			throw ServiceError("source VM \(sourceName) is running")
		}
	}

	static func deleteTemplate(templateName: String, asSystem: Bool) throws -> DeleteTemplateReply {
		let storage = StorageLocation(asSystem: asSystem, template: true)
		let lock = try FileLock(lockURL: storage.rootURL)
		var vmLocation: VMLocation? = nil

		try lock.lock()

		defer {
			try? lock.unlock()
		}

		if let location: VMLocation = try? storage.find(templateName) {
			vmLocation = location
		} else if let u = URL(string: templateName), u.scheme == "template" {
			vmLocation = try? StorageLocation(asSystem: false).find(u.host()!)
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

	static func listTemplate(asSystem: Bool) throws -> [TemplateEntry] {
		let storage = StorageLocation(asSystem: asSystem, template: true)

		return try storage.list().map { (key: String, value: VMLocation) in
			return TemplateEntry(
				name: key,
				fqn: "template://\(key)",
				diskSize: try ByteCountFormatter.string(fromByteCount: Int64(value.diskSize()), countStyle: .file),
				totalSize: try ByteCountFormatter.string(fromByteCount: Int64(value.allocatedSize()), countStyle: .file)
			)
		}
	}

	func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<String> {
		let format: Format = request.format == .text ? Format.text : Format.json

		if request.command == .add {
			return try Self.createTemplate(on: on, sourceName: request.create.sourceName, templateName: request.create.templateName, asSystem: runAsSystem).flatMapThrowing { reply in
				return format.renderSingle(style: Style.grid, uppercased: true, reply)
			}
		}

		return on.submit {
			switch request.command {
			case .delete:
				return format.renderSingle(style: Style.grid, uppercased: true, try Self.deleteTemplate(templateName: request.delete, asSystem: runAsSystem))
			case .list:
				return format.renderList(style: Style.grid, uppercased: true, try Self.listTemplate(asSystem: runAsSystem))
			default:
				throw ServiceError("Unknown command \(request.command)")
			}
		}
	}
}
