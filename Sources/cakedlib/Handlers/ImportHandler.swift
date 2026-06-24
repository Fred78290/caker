import ArgumentParser
import CakeAgentLib
import Foundation
import GRPCLib

// /var/root/Library/Application Support/multipassd/qemu/multipassd-vm-instances.json
// /var/root/Library/Application Support/multipassd/qemu/vault/multipassd-instance-image-records.json

public struct ImportHandler {
	public enum ImportSource: String, ExpressibleByArgument, CaseIterable, Codable, Sendable {
		case multipass
		case vmdk

		public static let allValueStrings: [String] = Self.allCases.map { "\($0)" }

		public init?(argument: String) {
			switch argument {
			case "multipass":
				self = .multipass
			case "vmdk":
				self = .vmdk
			default:
				return nil
			}
		}

		public var importer: Importer {
			switch self {
			case .multipass:
				return MultipassImporter()
			case .vmdk:
				return VMWareImporter()
			}
		}
	}

	static func runPrivilegedAppleScript(_ script: String) throws -> String {
		let appleScript = "do shell script \"\(script)\" with administrator privileges"

		if Bundle.isApplicationSandboxed {
			let scriptName = UUID().uuidString
			let scriptsDir = try FileManager.default.url(for: .applicationScriptsDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
			let scriptURL = scriptsDir.appendingPathComponent("\(scriptName).applescript")

			try appleScript.write(to: scriptURL, atomically: false, encoding: .utf8)

			let task = try NSUserAppleScriptTask(url: scriptURL)
			var taskResult: Result<String, Error> = .success("")
			let semaphore = DispatchSemaphore(value: 0)

			defer {
				try? FileManager.default.removeItem(at: scriptURL)
			}

			task.execute(withAppleEvent: nil) { descriptor, error in
				if let error {
					taskResult = .failure(error)
				} else {
					taskResult = .success(descriptor?.stringValue ?? "")
				}
				semaphore.signal()
			}

			semaphore.wait()

			return try taskResult.get()
		} else {
			return try Shell.command("/usr/bin/osascript", arguments: ["-e", appleScript])
		}
	}

	public static func importVM(
		importer: Importer, name: String, source: String, userName: String, password: String, clearPassword: Bool, sshPrivateKey: String?, passphrase: String?, uid: UInt32, gid: UInt32, runMode: Utils.RunMode, standardOutput: FileHandle? = nil,
		standardError: FileHandle? = nil
	) -> ImportedReply {
		let storageLocation = StorageLocation(runMode: runMode)

		if importer.needSudo && geteuid() != 0 {
			var arguments = [
				"import",
				name,
				source,
				"--from=\(importer.source)",
				"--user=\(userName)",
				"--password=\(password)",
				"--uid=\(uid)",
				"--gid=\(gid)",
				"--json"
			]

			if let sshPrivateKey {
				arguments.append("--ssh-key=\(sshPrivateKey)")
			}

			if let passphrase {
				arguments.append("--ssh-passphrase=\(passphrase)")
			}

			do {
				if Bundle.isApplicationSandboxed {
					guard var pluginsURL = Bundle.main.cakedBundleURL else {
						throw ServiceError(String(localized: "Caked bundle path is missing"))
					}
					pluginsURL = pluginsURL.appendingPathComponent(Home.cakedCommandName)

					let home = try Home(runMode: runMode).cakeHomeDirectory.path(percentEncoded: false)

					arguments.insert(pluginsURL.path(percentEncoded: false), at: 1)

					let replyString = try runPrivilegedAppleScript(arguments.joined(separator: " "))

					if let data = replyString.data(using: .utf8) {
						do {
							let decoded = try JSONDecoder().decode(ImportedReply.self, from: data)
							
							if decoded.imported {
								
							}

							return decoded
						} catch {
							return ImportedReply(source: source, name: name, imported: false, reason: String(localized: "Failed to decode import reply: \(error.localizedDescription)"))
						}
					} else {
						return ImportedReply(source: source, name: name, imported: false, reason: String(localized: "Invalid response encoding from privileged script"))
					}
				} else {
					let sudo = try SudoCaked(arguments: arguments, runMode: runMode, standardOutput: standardOutput, standardError: standardError)
					let exitCode = try sudo.runAndWait()

					guard exitCode == 0 else {
						var reason: String = ""

						if standardError == nil {
							reason = sudo.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
						}

						return ImportedReply(source: source, name: name, imported: false, reason: reason.isEmpty ? String(localized: "Import failed with exit code \(exitCode)") : reason)
					}
				}
			} catch {
				return ImportedReply(source: source, name: name, imported: false, reason: error.localizedDescription)
			}
		} else if storageLocation.exists(name) {
			return ImportedReply(source: source, name: name, imported: false, reason: String(localized: "VM already exists"))
		} else {
			var tempLocation: VMLocation! = nil

			do {
				tempLocation = try VMLocation.tempDirectory(runMode: runMode)

				try importer.importVM(location: tempLocation, source: source, userName: userName, password: password, clearPassword: clearPassword, sshPrivateKey: sshPrivateKey, passphrase: passphrase, runMode: runMode)
				try FileManager.default.setAttributesRecursively([.ownerAccountID: uid, .groupOwnerAccountID: gid], atPath: tempLocation.rootURL.path)
				try storageLocation.relocate(name, from: tempLocation)
			} catch {
				try? tempLocation?.delete()

				return ImportedReply(source: source, name: name, imported: false, reason: error.reason)
			}
		}

		return ImportedReply(source: source, name: name, imported: true, reason: String(localized: "VM imported successfully"))
	}
}

