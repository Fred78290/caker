import ArgumentParser
import Cocoa
import Foundation
import GRPCLib
import NIO
import Shout

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
	static func cleanCloudInit(source: VMLocation, config: CakeConfig, runMode: Utils.RunMode) throws -> VMLocation {
		let location = try source.duplicateTemporary(runMode: runMode)
		let runningIP = try StartHandler.internalStartVM(location: location, config: config, waitIPTimeout: 120, startMode: .attach, runMode: runMode)
		let conn = try CakeAgentConnection(eventLoop: Utilities.group.next(), listeningAddress: location.agentURL, runMode: runMode)

		Logger(self).info("Clean cloud-init on \(runningIP)")

		try conn.run(command: cloudInitCleanup.joined(separator: " && ")).log()
		try location.stopVirtualMachine(force: false, runMode: runMode)

		return location
	}

	public static func createTemplate(on: EventLoop, sourceName: String, templateName: String, runMode: Utils.RunMode) -> CreateTemplateReply {
		do {
			let storage = StorageLocation(runMode: runMode, template: true)
			var source: VMLocation = try StorageLocation(runMode: runMode).find(sourceName)
			
			if storage.exists(templateName) {
				return CreateTemplateReply(name: templateName, created: false, reason: "template \(templateName) already exists")
			}
			
			if source.status != .running {
				let lock: FileLock = try FileLock(lockURL: storage.rootURL)
				let config = try source.config()
				let templateLocation = storage.location(templateName)
				
				try lock.lock()
				
				defer {
					try? lock.unlock()
				}
				
				Logger(self).info("Creating template \(templateName) from \(sourceName)")
				
				do {
					if config.os == .linux && config.useCloudInit {
						source = try cleanCloudInit(source: source, config: config, runMode: runMode)
					}
					
					try FileManager.default.createDirectory(at: templateLocation.rootURL, withIntermediateDirectories: true)
					try source.templateTo(templateLocation)
					
					return CreateTemplateReply(name: templateName, created: true, reason: "template created")
				} catch {
					Logger(self).error(error)
					
					if let exists = try? templateLocation.rootURL.exists(), exists {
						try? FileManager.default.removeItem(at: templateLocation.rootURL)
					}
					
					return CreateTemplateReply(name: templateName, created: false, reason: "\(error)")
				}
			} else {
				return CreateTemplateReply(name: templateName, created: false, reason: "source VM \(sourceName) is running")
			}
		} catch {
			return CreateTemplateReply(name: templateName, created: false, reason: "\(error)")
		}
	}

	public static func deleteTemplate(templateName: String, runMode: Utils.RunMode) -> DeleteTemplateReply {
		do {
			let storage = StorageLocation(runMode: runMode, template: true)
			let lock = try FileLock(lockURL: storage.rootURL)
			let doIt: (VMLocation) -> DeleteTemplateReply = { location in
				if location.status != .running {
					try? FileManager.default.removeItem(at: location.rootURL)
					return DeleteTemplateReply(name: location.name, deleted: true, reason: "")
				} else {
					return DeleteTemplateReply(name: location.name, deleted: false, reason: "Template \(templateName) is running")
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
			
			return DeleteTemplateReply(name: templateName, deleted: false, reason: "Template \(templateName) not found")
		} catch {
			return DeleteTemplateReply(name: templateName, deleted: false, reason: "\(error)")
		}
	}

	public static func exists(name: String, runMode: Utils.RunMode) -> Bool {
		let storage = StorageLocation(runMode: runMode, template: true)

		return storage.exists(name)
	}

	public static func listTemplate(runMode: Utils.RunMode) -> ListTemplateReply {
		let storage = StorageLocation(runMode: runMode, template: true)

		do {
			return ListTemplateReply(templates: try storage.list().map { (key: String, value: VMLocation) in
				return TemplateEntry(
					name: key,
					fqn: "template://\(key)",
					diskSize: try value.diskSize(),
					totalSize: try value.allocatedSize()
				)
			}, success: true, reason: "Success")

		} catch {
			return ListTemplateReply(templates: [], success: false, reason: "\(error)")
		}
	}
}
