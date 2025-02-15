import ArgumentParser
import Foundation
import GRPCLib
import NIO
import TextTable

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
	}

	struct DeleteTemplateReply: Codable {
		let name: String
		let deleted: Bool
	}

	static func cleanCloudInit(location: VMLocation, config: CakeConfig) throws {
		let semaphore = DispatchSemaphore(value: 0)

		Task {
			defer {
				semaphore.signal()
			}

			let runningIP = try await StartHandler.startVM(vmLocation: location, waitIPTimeout: 60, foreground: false)

			if runningIP.count > 0 {
				let home = try Home(asSystem: asSystem)
				let cloudInitCleanup = [
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
					"rm -r /tmp/* /tmp/.*-unix /var/tmp/* /var/lib/apt/*",
					"/bin/sync",
					"shutdown now"
				]

				let ssh = try SSH(host: runningIP)
				try ssh.authenticate(username: config.configuredUser, privateKey: home.sshPrivateKey.path(), publicKey: home.sshPublicKey.path(), passphrase: "")
				try ssh.execute("sudo sh -c '\(cloudInitCleanup.joined(separator: ";"))'")
			}
		}

		semaphore.wait()
	}

	static func createTemplate(sourceName: String, templateName: String, asSystem: Bool) throws -> CreateTemplateReply {
		let storage = StorageLocation(asSystem: asSystem, template: true)
		let location: VMLocation = try StorageLocation(asSystem: asSystem).find(sourceName)
		let lock: FileLock = try FileLock(lockURL: storage.rootURL)

		try lock.lock()

		defer {
			try? lock.unlock()
		}

		if storage.exists(templateName) {
			throw ServiceError("template \(templateName) already exists")
		}

		if location.status != .running {
			let config = try location.config()

			if config.os == .linux && config.cloudInit {
				throw cleanCloudInit(location: location, config: config)
			}

			let templateLocation = storage.location(templateName)

			try FileManager.default.createDirectory(at: templateLocation.rootURL, withIntermediateDirectories: true)
			try FileManager.default.copyItem(at: location.diskURL, to: templateLocation.diskURL)

			return .init(name: templateName, created: true)
		}

		return .init(name: templateName, created: false)
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

		return on.submit {
			switch request.command {
			case .add:
				return format.renderSingle(style: Style.grid, uppercased: true, try Self.createTemplate(sourceName: request.create.sourceName, templateName: request.create.templateName, asSystem: runAsSystem))
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