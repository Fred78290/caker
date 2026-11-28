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
	/// Copies `source` to a temporary VM, resets its cloud-init state and waits for it to shut down.
	/// If anything fails the temporary VM is killed and deleted before the error is thrown; on success
	/// the caller owns it and must call `destroyTemporaryVirtualMachine(runMode:)` when done.
	/// With `cancellation`, cancelling kills the temporary VM, and this throws `CancellationError`.
	static func cleanCloudInit(source: VMLocation, startMode: StartHandler.StartMode, runMode: Utils.RunMode, cancellation: TemporaryVMCancellation? = nil) throws -> VMLocation {
		let temporary = try VMLocation.tempDirectory(runMode: runMode)

		do {
			try cancellation?.register(temporary)
			_ = try source.copyTo(temporary)
			try cancellation?.checkCancellation()
			try cleanCloudInit(temporary: temporary, startMode: startMode, runMode: runMode)
			try cancellation?.checkCancellation()
			// The agent only asked the guest to shut down: don't read its disk while it still runs.
			try temporary.waitTemporaryVirtualMachineExit(runMode: runMode, cancellation: cancellation)
			try cancellation?.checkCancellation()

			return temporary
		} catch {
			temporary.destroyTemporaryVirtualMachine(runMode: runMode)

			throw error
		}
	}

	/// Boots `location` (a temporary copy the caller owns and destroys), resets its cloud-init state through the agent, then stops it.
	@discardableResult
	static func cleanCloudInit(temporary location: VMLocation, startMode: StartHandler.StartMode, runMode: Utils.RunMode) throws -> VMLocation {
		let runningIP = try StartHandler.internalStartVM(location: location, screenSize: nil, vncPassword: nil, vncPort: nil, waitIPTimeout: 120, startMode: startMode, gcd: false, recoveryMode: false, runMode: runMode)
		let conn = try CakeAgentConnection(eventLoop: Utilities.group.next(), listeningAddress: location.agentURL, runMode: runMode)

		Logger(self).info("Clean cloud-init on \(runningIP)")

		try conn.run(command: cloudInitCleanup.joined(separator: " ; ")).log()
		try location.stopVirtualMachine(force: false, runMode: runMode)

		return location
	}

	public static func createTemplate(sourceName: String, templateName: String, startMode: StartHandler.StartMode = .attach, runMode: Utils.RunMode, cancellation: TemporaryVMCancellation? = nil) -> CreateTemplateReply {
		do {
			return try createTemplate(location: StorageLocation(runMode: runMode).find(sourceName), templateName: templateName, startMode: startMode, runMode: runMode, cancellation: cancellation)
		} catch {
			return CreateTemplateReply(name: templateName, created: false, reason: error.reason)
		}
	}

	public static func createTemplate(vmURL: URL, templateName: String, startMode: StartHandler.StartMode = .attach, runMode: Utils.RunMode, cancellation: TemporaryVMCancellation? = nil) -> CreateTemplateReply {
		do {
			return try createTemplate(location: VMLocation.newVMLocation(vmURL: vmURL, runMode: runMode), templateName: templateName, startMode: startMode, runMode: runMode, cancellation: cancellation)
		} catch {
			return CreateTemplateReply(name: templateName, created: false, reason: error.reason)
		}
	}

	public static func createTemplate(location: VMLocation, templateName: String, startMode: StartHandler.StartMode = .attach, runMode: Utils.RunMode, cancellation: TemporaryVMCancellation? = nil) -> CreateTemplateReply {
		return createTemplate(on: Utilities.group.next(), location: location, templateName: templateName, startMode: startMode, runMode: runMode, cancellation: cancellation)
	}

	/// Cancellable form: cancelling the calling task kills and deletes the temporary VM, removes a
	/// template being written, and returns a reply with `created == false` and `cancelledReason`.
	public static func createTemplate(sourceName: String, templateName: String, startMode: StartHandler.StartMode = .attach, runMode: Utils.RunMode) async -> CreateTemplateReply {
		await TemporaryVMCancellation.run(runMode: runMode) { cancellation in
			createTemplate(sourceName: sourceName, templateName: templateName, startMode: startMode, runMode: runMode, cancellation: cancellation)
		}
	}

	/// Cancellable form of `createTemplate(vmURL:...)`, see `createTemplate(sourceName:...) async`.
	public static func createTemplate(vmURL: URL, templateName: String, startMode: StartHandler.StartMode = .attach, runMode: Utils.RunMode) async -> CreateTemplateReply {
		await TemporaryVMCancellation.run(runMode: runMode) { cancellation in
			createTemplate(vmURL: vmURL, templateName: templateName, startMode: startMode, runMode: runMode, cancellation: cancellation)
		}
	}

	public static func createTemplate(on: EventLoop, location: VMLocation, templateName: String, startMode: StartHandler.StartMode = .attach, runMode: Utils.RunMode, cancellation: TemporaryVMCancellation? = nil) -> CreateTemplateReply {
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
						source.destroyTemporaryVirtualMachine(runMode: runMode)
					}
				}

				Logger(self).info("Creating template \(templateName) from \(location.name)")

				do {
					try cancellation?.checkCancellation()

					if config.os == .linux && config.useCloudInit {
						source = try cleanCloudInit(source: source, startMode: startMode, runMode: runMode, cancellation: cancellation)
						delete = true
					}

					try FileManager.default.createDirectory(at: templateLocation.rootURL, withIntermediateDirectories: true)
					try source.templateTo(templateLocation)

					// A cancellation that arrived while the template was written removes it (below).
					try cancellation?.commit {}

					return CreateTemplateReply(name: templateName, created: true, reason: String(localized: "template created"))
				} catch {
					let cancelled = error is CancellationError || cancellation?.isCancelled == true

					if cancelled {
						Logger(self).info("Creating template \(templateName) from \(location.name) cancelled")
					} else {
						Logger(self).error(error)
					}

					if let exists = try? templateLocation.rootURL.exists(), exists {
						try? FileManager.default.removeItem(at: templateLocation.rootURL)
					}

					return CreateTemplateReply(name: templateName, created: false, reason: cancelled ? TemporaryVMCancellation.cancelledReason : error.reason)
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
			} else if let u = URL(spaced: templateName), u.scheme == "template", let location = try? StorageLocation(runMode: runMode).find(u.host()!) {
				return doIt(location)
			}

			return DeleteTemplateReply(name: templateName, deleted: false, reason: String(localized: "Template \(templateName) not found"))
		} catch {
			return DeleteTemplateReply(name: templateName, deleted: false, reason: error.reason)
		}
	}

public static func duplicateTemplate(sourceName: String, templateName: String, runMode: Utils.RunMode) -> DuplicateTemplateReply {
		do {
			guard !sourceName.isEmpty,
				  !templateName.isEmpty,
				  sourceName == URL(fileURLWithPath: sourceName).lastPathComponent,
				  templateName == URL(fileURLWithPath: templateName).lastPathComponent,
				  sourceName.contains("..") == false,
				  templateName.contains("..") == false
			else {
				return DuplicateTemplateReply(name: templateName, duplicated: false, reason: String(localized: "Invalid argument"))
			}

			let storage = StorageLocation(runMode: runMode, template: true)
			let lock = try FileLock(lockURL: storage.rootURL)

			try lock.lock()

			defer {
				try? lock.unlock()
			}

			guard storage.exists(templateName) == false else {
				return DuplicateTemplateReply(name: templateName, duplicated: false, reason: String(localized: "template \(templateName) already exists"))
			}

			guard let source = try? storage.find(sourceName) else {
				return DuplicateTemplateReply(name: templateName, duplicated: false, reason: String(localized: "Template \(sourceName) not found"))
			}

			let destination = storage.location(templateName)

			Logger(self).info("Duplicating template \(sourceName) to \(templateName)")

			try FileManager.default.copyItem(at: source.rootURL, to: destination.rootURL)

			return DuplicateTemplateReply(name: templateName, duplicated: true, reason: String(localized: "template duplicated"))
		} catch {
			Logger(self).error(error)

			return DuplicateTemplateReply(name: templateName, duplicated: false, reason: error.reason)
		}
	}

public static func infos(templateName: String, runMode: Utils.RunMode) -> InfoTemplateReply {
		do {
			guard !templateName.isEmpty,
				templateName == URL(fileURLWithPath: templateName).lastPathComponent,
				templateName.contains("..") == false
			else {
				return InfoTemplateReply(success: false, reason: String(localized: "Invalid argument"), infos: nil)
			}

			let location = try StorageLocation(runMode: runMode, template: true).find(templateName)
			let config: CakeConfig = try location.config()
			let infos = try InfosHandler.offlineInfos(location: location, config: config, status: .stopped)

			return InfoTemplateReply(success: true, reason: String(localized: "Success"), infos: infos)
		} catch {
			return InfoTemplateReply(success: false, reason: error.reason, infos: nil)
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
