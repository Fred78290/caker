import CakedLib
import GRPCLib
import SwiftUI
//
//  Importers.swift
//  CakerAppStore
//
//  Created by Frederic BOLTZ on 02/07/2026.
//
import UniformTypeIdentifiers

struct TartImporter: ImporterDelegate {
	// Provide list of VMs by enumerating the default .tart/vms directory.
	func listVirtualMachines() -> [URL] {
		let dir = FileManager.realHomeDirectoryForCurrentUser.appendingPathComponent(".tart/vms", isDirectory: true)

		guard let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
			return []
		}

		return contents.filter { $0.hasDirectoryPath }
	}

	func browserForVirtualMachine() -> URL? {
		let panel = NSOpenPanel()
		panel.allowsMultipleSelection = false
		panel.canChooseFiles = false
		panel.canChooseDirectories = true
		panel.title = String(localized: "Select Tart Virtual Machine Directory")
		panel.directoryURL = FileManager.realHomeDirectoryForCurrentUser.appendingPathComponent(".tart/vms", isDirectory: true)

		guard panel.runModal() == .OK, let url = panel.url else {
			return nil
		}

		return url
	}

	func doImport(vmPath: String, targetName: String, userName: String, password: String, clearPassword: Bool, sshKey: String?, sshPassphrase: String?, copyDisk: Bool) async -> ImportedReply {
		return AppState.shared.importFromTart(
			source: vmPath,
			name: targetName,
			userName: userName,
			password: password,
			clearPassword: clearPassword,
			sshKey: sshKey,
			sshPassphrase: sshPassphrase,
			copyDisk: copyDisk
		)
	}
}

struct UTMImporter: ImporterDelegate {
	func listVirtualMachines() -> [URL] {
		let dir = FileManager.realHomeDirectoryForCurrentUser.appendingPathComponent("Library/Containers/com.utmapp.UTM/Data/Documents", isDirectory: true)

		guard let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
			return []
		}

		return contents.filter { $0.hasDirectoryPath && $0.pathExtension.lowercased() == "utm" }
	}

	func browserForVirtualMachine() -> URL? {
		let panel = NSOpenPanel()
		panel.allowsMultipleSelection = false
		panel.canChooseFiles = true
		panel.canChooseDirectories = true
		panel.title = String(localized: "Select UTM Virtual Machine")

		if let bundleType = UTType(tag: "utm", tagClass: .filenameExtension, conformingTo: nil) {
			panel.allowedContentTypes = [bundleType]
		}

		panel.directoryURL = FileManager.realHomeDirectoryForCurrentUser.appendingPathComponent("Library/Containers/com.utmapp.UTM/Data/Documents", isDirectory: true)

		guard panel.runModal() == .OK, let url = panel.url else {
			return nil
		}

		return url
	}
	
	func doImport(vmPath: String, targetName: String, userName: String, password: String, clearPassword: Bool, sshKey: String?, sshPassphrase: String?, copyDisk: Bool) async -> ImportedReply {
		return AppState.shared.importFromUTM(
			source: vmPath,
			name: targetName,
			userName: userName,
			password: password,
			clearPassword: clearPassword,
			sshKey: sshKey,
			sshPassphrase: sshPassphrase,
			copyDisk: copyDisk
		)
	}
}

struct VirtualBuddyImporter: ImporterDelegate {
	func listVirtualMachines() -> [URL] {
		let dir = FileManager.realHomeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/VirtualBuddy", isDirectory: true)

		guard let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
			return []
		}

		return contents.filter { $0.hasDirectoryPath && $0.pathExtension.lowercased() == "vbvm" }
	}

	func browserForVirtualMachine() -> URL? {
		let panel = NSOpenPanel()
		panel.allowsMultipleSelection = false
		panel.canChooseFiles = true
		panel.canChooseDirectories = true
		panel.title = String(localized: "Select VirtualBuddy Virtual Machine")

		if let bundleType = UTType(tag: "vbvm", tagClass: .filenameExtension, conformingTo: nil) {
			panel.allowedContentTypes = [bundleType]
		}
		panel.directoryURL = FileManager.realHomeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/VirtualBuddy", isDirectory: true)

		guard panel.runModal() == .OK, let url = panel.url else {
			return nil
		}

		return url
	}

	func doImport(vmPath: String, targetName: String, userName: String, password: String, clearPassword: Bool, sshKey: String?, sshPassphrase: String?, copyDisk: Bool) async -> ImportedReply {
		return AppState.shared.importFromVirtualBuddy(
			source: vmPath,
			name: targetName,
			userName: userName,
			password: password,
			clearPassword: clearPassword,
			sshKey: sshKey,
			sshPassphrase: sshPassphrase,
			copyDisk: copyDisk
		)
	}
}

struct VMWareImporter: ImporterDelegate {
	func listVirtualMachines() -> [URL] {
		// List bundles in the typical VMware directory in the user's home (if present)
		let dirs = [
			FileManager.realHomeDirectoryForCurrentUser.appendingPathComponent("Virtual Machines.localized", isDirectory: true),
			FileManager.realHomeDirectoryForCurrentUser.appendingPathComponent("Documents/Virtual Machines.localized", isDirectory: true)
		]
		var contents: [URL] = []

		for dir in dirs {
			guard let dirContents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
				continue
			}

			contents.append(contentsOf: dirContents)
		}

		// Return only directories with .vmwarevm extension (bundles)
		return contents.filter { $0.hasDirectoryPath && $0.pathExtension.lowercased() == "vmwarevm" }
	}

	private func findVMX(in bundleURL: URL) -> URL? {
		guard let contents = try? FileManager.default.contentsOfDirectory(
			at: bundleURL,
			includingPropertiesForKeys: nil
		) else {
			return nil
		}
		return contents.first { $0.pathExtension.lowercased() == "vmx" }
	}

	func browserForVirtualMachine() -> URL? {
		let panel = NSOpenPanel()
		panel.allowsMultipleSelection = false
		panel.canChooseFiles = true
		panel.canChooseDirectories = true
		panel.title = String(localized: "Select VMware Virtual Machine")

		if let bundleType = UTType(tag: "vmwarevm", tagClass: .filenameExtension, conformingTo: nil) {
			panel.allowedContentTypes = [bundleType]
		}

		guard panel.runModal() == .OK, let url = panel.url else {
			return nil
		}

		guard let vmxURL = findVMX(in: url) else {
			MainActor.assumeIsolated {
				alertError(String(localized: "Invalid VMware VM"), String(localized: "No .vmx file found inside \"\(url.lastPathComponent)\""))
			}
			return nil
		}

		return vmxURL
	}

	// The browser returns the .vmx file inside the bundle, whose name reflects the guest OS
	// rather than the virtual machine; suggest the enclosing bundle's name instead.
	func suggestedName(for url: URL) -> String {
		let parent = url.deletingLastPathComponent()

		if parent.pathExtension.lowercased() == "vmwarevm" {
			return parent.deletingPathExtension().lastPathComponent
		}

		return url.deletingPathExtension().lastPathComponent
	}
	
	func doImport(vmPath: String, targetName: String, userName: String, password: String, clearPassword: Bool, sshKey: String?, sshPassphrase: String?, copyDisk: Bool) async -> ImportedReply {
		return AppState.shared.importFromVMware(
			source: vmPath,
			name: targetName,
			userName: userName,
			password: password,
			clearPassword: clearPassword,
			sshKey: sshKey,
			sshPassphrase: sshPassphrase
		)
	}
}
