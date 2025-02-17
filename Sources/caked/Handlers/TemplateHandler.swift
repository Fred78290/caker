import ArgumentParser
import Foundation
import GRPCLib
import NIO
import TextTable
import Shout
import Cocoa

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

	static func cleanCloudInit(location: VMLocation, config: CakeConfig, asSystem: Bool) throws {
		let eventLoop = Root.group.next()
		let promise = eventLoop.makePromise(of: String?.self)
		let configuredUser = config.configuredUser

		promise.futureResult.whenSuccess {
			if let runningIP = $0 {
				do {
					let home: Home = try Home(asSystem: asSystem)
					let cloudInitCleanup = [
						//"systemctl disable cakeagent",
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
					
					let ssh = try SSH(host: runningIP)
					try ssh.authenticate(username: configuredUser, privateKey: home.sshPrivateKey.path(), publicKey: home.sshPublicKey.path(), passphrase: "")
					try ssh.execute("sudo sh -c '\(cloudInitCleanup.joined(separator: ";"))'")
				} catch {
					Logger.error("Failed to clean cloud-init: \(error)")
				}
			}
		}

		promise.futureResult.whenFailure { error in
			Logger.error("Failed to clean cloud-init: \(error)")
		}

		let vm = try location.startVirtualMachine(on: eventLoop.next(), config: config, asSystem: false, promise: promise)

		_ = try promise.futureResult.wait()
		
		try? vm.requestStopVM()
	}

	static func createTemplate(sourceName: String, templateName: String, asSystem: Bool) async throws -> CreateTemplateReply {
		let storage = StorageLocation(asSystem: asSystem, template: true)
		let source: VMLocation = try StorageLocation(asSystem: asSystem).find(sourceName)
		let lock: FileLock = try FileLock(lockURL: storage.rootURL)

		try lock.lock()

		defer {
			try? lock.unlock()
		}

		if storage.exists(templateName) {
			throw ServiceError("template \(templateName) already exists")
		}

		if source.status != .running {
			let config = try source.config()
			let templateLocation = storage.location(templateName)

			try FileManager.default.createDirectory(at: templateLocation.rootURL, withIntermediateDirectories: true)

			if config.os == .linux && config.useCloudInit {
				let tmpVM = try source.duplicateTemporary()
				try cleanCloudInit(location: tmpVM, config: config, asSystem: asSystem)
				try FileManager.default.copyItem(at: tmpVM.diskURL, to: templateLocation.diskURL)
			} else {
				try FileManager.default.copyItem(at: source.diskURL, to: templateLocation.diskURL)
			}

			return .init(name: templateName, created: true, reason: "")
		}

		return .init(name: templateName, created: false, reason: "source VM \(sourceName) is running")
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

		return on.makeFutureWithTask {
			switch request.command {
			case .add:
				return format.renderSingle(style: Style.grid, uppercased: true, try await Self.createTemplate(sourceName: request.create.sourceName, templateName: request.create.templateName, asSystem: runAsSystem))
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
