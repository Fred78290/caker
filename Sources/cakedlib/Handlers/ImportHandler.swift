import ArgumentParser
import CakeAgentLib
import Foundation
import GRPCLib
import System

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
		let appleScript = """
			do shell script "\(script)" with administrator privileges
			"""

		let scriptName = UUID().uuidString
		let scriptsDir = try FileManager.default.url(for: .applicationScriptsDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
		let scriptURL = scriptsDir.appendingPathComponent("\(scriptName).applescript")

		try appleScript.write(to: scriptURL, atomically: false, encoding: .utf8)

		defer {
			try? FileManager.default.removeItem(at: scriptURL)
		}

		let task = try NSUserAppleScriptTask(url: scriptURL)
		var taskResult: Result<String, Error> = .success("")
		let semaphore = DispatchSemaphore(value: 0)

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
	}

	public static func importVM(
		importer: Importer,
		source: String,
		name: String,
		userName: String,
		password: String,
		clearPassword: Bool,
		sshPrivateKey: String?,
		passphrase: String?,
		uid: UInt32,
		gid: UInt32,
		runMode: Utils.RunMode,
		standardOutput: FileHandle? = nil,
		standardError: FileHandle? = nil
	) -> ImportedReply {
		let storageLocation = StorageLocation(runMode: runMode)
		let isApplicationSandboxed = Bundle.isApplicationSandboxed

		if importer.needSudo && geteuid() != 0 {
			let vmName = isApplicationSandboxed ? UUID().uuidString : name

			func recopySandboxedVM() -> ImportedReply {
				do {
					let rootHome = try Home(URL(fileURLWithPath: "/var/root/.cake/"), runMode: .system, createItIfNotExists: false)
					let rootStorage = StorageLocation(rootHome, runMode: .system)
					let localStorage = StorageLocation(runMode: runMode)

					if rootStorage.exists(vmName) == false {
						return ImportedReply(
							source: source, name: name, imported: false,
							reason: String(
								localized:
									"""
									Imported VM not found in root storage
									Add the user to the wheel group to allow access to the VM
									sudo dseditgroup -o edit -a $USER -t user wheel
									"""))
					}

					let vmLocation = rootStorage.location(vmName)

					try localStorage.relocateByCopy(name, from: vmLocation)
					// Add the user to the wheel group to allow access to the VM
					//"dseditgroup -o edit -a $USER -t user operator"
					if let output = try? runPrivilegedAppleScript("caked --home=/var/root/.cake/ delete \(vmName)") {
						print(output)
					}
				} catch {
					return ImportedReply(source: source, name: name, imported: false, reason: "\(error)")
				}

				return ImportedReply(source: source, name: name, imported: true, reason: String(localized: "VM imported successfully"))
			}

			do {
				if isApplicationSandboxed {
					guard var pluginsURL = Bundle.main.cakedBundleURL else {
						throw ServiceError(String(localized: "Caked bundle path is missing"))
					}

					pluginsURL = pluginsURL.appendingPathComponent(Home.cakedCommandName)

					var arguments = [
						pluginsURL.path(percentEncoded: false),
						"import",
						source,
						vmName,
						"--home=/var/root/.cake/",
						"--from=\(importer.source)",
						"--user=\(userName)",
						"--password=\(password)",
						"--uid=\(uid)",
						"--gid=\(gid)",
						"--json",
					]

					if clearPassword {
						arguments.append("--clear-password")
					}

					if let sshPrivateKey {
						arguments.append("--ssh-key=\(sshPrivateKey)")
					}

					if let passphrase {
						arguments.append("--ssh-passphrase=\(passphrase)")
					}

					let quote: (String) -> String = { v in "'" + v.replacingOccurrences(of: "'", with: "'\\''") + "'" }
					let replyString = try runPrivilegedAppleScript(arguments.map(quote).joined(separator: " "))

					if let data = replyString.data(using: .utf8) {
						do {
							let decoded = try JSONDecoder().decode(ImportedReply.self, from: data)

							if decoded.imported {
								return recopySandboxedVM()
							}

							return decoded
						} catch {
							return ImportedReply(source: source, name: name, imported: false, reason: String(localized: "Failed to decode import reply: \(error.localizedDescription)"))
						}
					} else {
						return ImportedReply(source: source, name: name, imported: false, reason: String(localized: "Invalid response encoding from privileged script"))
					}
				} else {
					var arguments = [
						"import",
						source,
						name,
						"--from=\(importer.source)",
						"--user=\(userName)",
						"--password=\(password)",
						"--uid=\(uid)",
						"--gid=\(gid)",
						"--json",
					]

					if clearPassword {
						arguments.append("--clear-password")
					}

					if let sshPrivateKey {
						arguments.append("--ssh-key=\(sshPrivateKey)")
					}

					if let passphrase {
						arguments.append("--ssh-passphrase=\(passphrase)")
					}

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
			} catch let shellError as ShellError {
				return ImportedReply(source: source, name: name, imported: false, reason: shellError.error)
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
