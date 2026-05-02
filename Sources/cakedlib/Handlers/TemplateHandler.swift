import ArgumentParser
import Cocoa
import Foundation
import GRPCLib
import NIO
import Shout
import CakeAgentLib

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

public struct TemplateHandler {
	static func cleanCloudInit(source: VMLocation, config: CakeConfig, startMode: StartHandler.StartMode, runMode: Utils.RunMode) throws -> VMLocation {
		let location = try source.duplicateTemporary(runMode: runMode)
		let runningIP = try StartHandler.internalStartVM(location: location, screenSize: nil, vncPassword: nil, vncPort: nil, waitIPTimeout: 120, startMode: startMode, gcd: false, recoveryMode: false, runMode: runMode)
		let conn = try CakeAgentConnection(eventLoop: Utilities.group.next(), listeningAddress: location.agentURL, runMode: runMode)

		Logger(self).info("Clean cloud-init on \(runningIP)")

		try conn.run(command: cloudInitCleanup.joined(separator: " ; ")).log()
		try location.stopVirtualMachine(force: false, runMode: runMode)

		return location
	}

	public static func createTemplate(sourceName: String, templateName: String, startMode: StartHandler.StartMode = .attach, runMode: Utils.RunMode) -> CreateTemplateReply {
		do {
			return try createTemplate(location: StorageLocation(runMode: runMode).find(sourceName), templateName: templateName, startMode: startMode, runMode: runMode)
		} catch {
			return CreateTemplateReply(name: templateName, created: false, reason: error.reason)
		}
	}

	public static func createTemplate(vmURL: URL, templateName: String, startMode: StartHandler.StartMode = .attach, runMode: Utils.RunMode) -> CreateTemplateReply {
		do {
			return try createTemplate(location: VMLocation.newVMLocation(vmURL: vmURL, runMode: runMode), templateName: templateName, startMode: startMode, runMode: runMode)
		} catch {
			return CreateTemplateReply(name: templateName, created: false, reason: error.reason)
		}
	}

	public static func createTemplate(location: VMLocation, templateName: String, startMode: StartHandler.StartMode = .attach, runMode: Utils.RunMode) -> CreateTemplateReply {
		return createTemplate(on: Utilities.group.next(), location: location, templateName: templateName, startMode: startMode, runMode: runMode)
	}

	public static func createTemplate(on: EventLoop, location: VMLocation, templateName: String, startMode: StartHandler.StartMode = .attach, runMode: Utils.RunMode) -> CreateTemplateReply {
		do {
			let storage = StorageLocation(runMode: runMode, template: true)
			var source = location

			if storage.exists(templateName) {
				return CreateTemplateReply(name: templateName, created: false, reason: String(localized: "template \(templateName) already exists"))
			}

			if case .running = location.status {
				return CreateTemplateReply(name: templateName, created: false, reason: String(localized: "source VM \(location.name) is running"))
			} else {
				let lock: FileLock = try FileLock(lockURL: storage.rootURL)
				let config = try source.config()
				let templateLocation = storage.location(templateName)
				var delete = false

				try lock.lock()

				defer {
					try? lock.unlock()

					if delete {
						try? source.delete()
					}
				}

				Logger(self).info("Creating template \(templateName) from \(location.name)")

				do {
					if config.os == .linux && config.useCloudInit {
						source = try cleanCloudInit(source: source, config: config, startMode: startMode, runMode: runMode)
						delete = true
					}

					try FileManager.default.createDirectory(at: templateLocation.rootURL, withIntermediateDirectories: true)
					try source.templateTo(templateLocation)

					return CreateTemplateReply(name: templateName, created: true, reason: String(localized: "template created"))
				} catch {
					Logger(self).error(error)

					if let exists = try? templateLocation.rootURL.exists(), exists {
						try? FileManager.default.removeItem(at: templateLocation.rootURL)
					}

					return CreateTemplateReply(name: templateName, created: false, reason: error.reason)
				}
			}
		} catch {
			return CreateTemplateReply(name: templateName, created: false, reason: error.reason)
		}
	}

	public static func deleteTemplate(templateName: String, runMode: Utils.RunMode) -> DeleteTemplateReply {
		do {
			let storage = StorageLocation(runMode: runMode, template: true)
			let lock = try FileLock(lockURL: storage.rootURL)
			let doIt: (VMLocation) -> DeleteTemplateReply = { location in
				if case .running = location.status {
					return DeleteTemplateReply(name: location.name, deleted: false, reason: String(localized: "Template \(templateName) is running"))
				} else {
					try? FileManager.default.removeItem(at: location.rootURL)
					return DeleteTemplateReply(name: location.name, deleted: true, reason: String.empty)
				}
			}

			try lock.lock()

			defer {
				try? lock.unlock()
			}

			if let location: VMLocation = try? storage.find(templateName) {
				return doIt(location)
			} else if let u = URL(string: templateName), u.scheme == "template", let location = try? StorageLocation(runMode: runMode).find(u.host()!) {
				return doIt(location)
			}

			return DeleteTemplateReply(name: templateName, deleted: false, reason: String(localized: "Template \(templateName) not found"))
		} catch {
			return DeleteTemplateReply(name: templateName, deleted: false, reason: error.reason)
		}
	}

	public static func exists(name: String, runMode: Utils.RunMode) -> Bool {
		let storage = StorageLocation(runMode: runMode, template: true)

		return storage.exists(name)
	}

	public static func listTemplate(runMode: Utils.RunMode) -> ListTemplateReply {
		let storage = StorageLocation(runMode: runMode, template: true)

		do {
			return ListTemplateReply(
				templates: try storage.list().map { (key: String, value: VMLocation) in
					return TemplateEntry(
						name: key,
						fqn: "template://\(key)",
						diskSize: try value.diskSize(),
						totalSize: try value.allocatedSize()
					)
				}, success: true, reason: String(localized: "Success"))

		} catch {
			return ListTemplateReply(templates: [], success: false, reason: error.reason)
		}
	}
}
