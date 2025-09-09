import CakedLib
import Foundation
import GRPC
import GRPCLib
import SwiftUI

struct RemoteHandlerComparator: SortComparator {
	var order: SortOrder = .forward

	func compare(_ lhs: RemoteEntry, _ rhs: RemoteEntry) -> ComparisonResult {
		if lhs.name == rhs.name {
			return .orderedSame
		}

		if order == .forward {
			return lhs.name < rhs.name ? .orderedAscending : .orderedDescending
		}

		return lhs.name > rhs.name ? .orderedAscending : .orderedDescending
	}
}

struct BridgedNetworkComparator: SortComparator {
	var order: SortOrder = .forward

	func compare(_ lhs: BridgedNetwork, _ rhs: BridgedNetwork) -> ComparisonResult {
		if lhs.name == rhs.name {
			return .orderedSame
		}

		if order == .forward {
			return lhs.name < rhs.name ? .orderedAscending : .orderedDescending
		}

		return lhs.name > rhs.name ? .orderedAscending : .orderedDescending
	}
}

struct TemplateEntryComparator: SortComparator {
	var order: SortOrder = .forward

	func compare(_ lhs: TemplateEntry, _ rhs: TemplateEntry) -> ComparisonResult {
		if lhs.name == rhs.name {
			return .orderedSame
		}

		if order == .forward {
			return lhs.name < rhs.name ? .orderedAscending : .orderedDescending
		}

		return lhs.name > rhs.name ? .orderedAscending : .orderedDescending
	}
}

extension RemoteEntry {
	var remoteData: RemoteData {
		RemoteData(remote: self.name)
	}
}

struct PairedVirtualMachineDocument: Identifiable {
	let id: URL
	let name: String
	let document: VirtualMachineDocument
}

struct PairedVirtualMachineDocumentComparator: SortComparator {
	var order: SortOrder = .forward

	func compare(_ lhs: PairedVirtualMachineDocument, _ rhs: PairedVirtualMachineDocument) -> ComparisonResult {
		if lhs.name == rhs.name {
			return .orderedSame
		}

		if order == .forward {
			return lhs.name < rhs.name ? .orderedAscending : .orderedDescending
		}

		return lhs.name > rhs.name ? .orderedAscending : .orderedDescending
	}
}

class AppState: ObservableObject, Observable {
	static var shared = AppState()

	@AppStorage("VMLaunchMode") var launchVMExternally = false

	@Published var currentDocument: VirtualMachineDocument!
	@Published var isAgentInstalling: Bool = true
	@Published var isStopped: Bool = true
	@Published var isSuspendable: Bool = false
	@Published var isRunning: Bool = false
	@Published var isPaused: Bool = false
	@Published var names: [String] = []
	@Published var remotes: [RemoteEntry] = []
	@Published var templates: [TemplateEntry] = []
	@Published var networks: [BridgedNetwork] = []
	@Published var selectedRemote: RemoteEntry? = nil
	@Published var selectedTemplate: TemplateEntry? = nil
	@Published var selectedNetwork: BridgedNetwork? = nil

	private var virtualMachines: [URL: VirtualMachineDocument] = [:]

	var vms: [PairedVirtualMachineDocument] {
		self.virtualMachines.compactMap {
			PairedVirtualMachineDocument(id: $0.key, name: $0.value.name, document: $0.value)
		}.sorted(using: PairedVirtualMachineDocumentComparator())
	}

	init() {
		let machines = Self.loadVirtualMachines()

		self.virtualMachines = machines.0
		self.names = machines.1
		self.networks = Self.loadNetworks()
		self.remotes = Self.loadRemotes()
		self.templates = Self.loadTemplates()
	}

	static func loadNetworks() -> [BridgedNetwork] {
		if let networks = try? NetworksHandler.networks(runMode: .app) {
			return networks.sorted(using: BridgedNetworkComparator())
		}

		return []
	}

	static func loadRemotes() -> [RemoteEntry] {
		if let remotes = try? RemoteHandler.listRemote(runMode: .app) {
			return remotes.sorted(using: RemoteHandlerComparator())
		}
		return []
	}

	static func loadTemplates() -> [TemplateEntry] {
		if let templates = try? TemplateHandler.listTemplate(runMode: .app) {
			return templates.sorted(using: TemplateEntryComparator())
		}

		return []
	}

	static func loadVirtualMachines() -> ([URL: VirtualMachineDocument], [String]) {
		var result: [URL: VirtualMachineDocument] = [:]
		var names: [String] = []

		if let vms = try? ListHandler.list(vmonly: true, runMode: .app) {
			let storage = StorageLocation(runMode: .app)

			vms.compactMap {
				if let location = try? storage.find($0.name) {
					return location
				}

				return nil
			}.forEach {
				names.append($0.name)
				result[$0.rootURL] = VirtualMachineDocument(name: $0.name)
			}
		}

		return (result, names)
	}

	func reloadNetworks() throws {
		self.networks = Self.loadNetworks()
	}

	func reloadRemotes() {
		self.remotes = Self.loadRemotes()
	}

	func reloadTemplates() {
		self.templates = Self.loadTemplates()
	}

	func findVirtualMachineDocument(_ url: URL) -> VirtualMachineDocument? {
		self.virtualMachines[url]
	}

	func removeVirtualMachineDocument(_ url: URL) {
		if let vm = self.virtualMachines[url] {
			self.names.removeAll { $0 == vm.name }
			self.virtualMachines.removeValue(forKey: url)
		}
	}

	func replaceVirtualMachineDocument(_ url: URL, with document: VirtualMachineDocument) {
		self.virtualMachines[url] = document
	}

	func createTemplate(document vm: VirtualMachineDocument) {
		let alert = NSAlert()
		let txt = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))

		alert.messageText = "Create template"
		alert.informativeText = "Name of the new template"
		alert.alertStyle = .informational
		alert.addButton(withTitle: "Delete")
		alert.addButton(withTitle: "Cancel")

		alert.accessoryView = txt

		if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
			let templateResult = vm.createTemplateFromUI(name: txt.stringValue)

			if templateResult.created == false {
				let alert = NSAlert()

				alert.messageText = "Failed to create template"
				alert.informativeText = templateResult.reason ?? "Internal error"
				alert.runModal()
			} else {
				self.reloadRemotes()
			}
		}
	}

	func deleteVirtualMachine(document vm: VirtualMachineDocument) {
		let alert = NSAlert()

		alert.messageText = "Delete virtual machine"
		alert.informativeText = "Are you sure you want to delete \(vm.name)? This action cannot be undone."
		alert.alertStyle = .critical
		alert.addButton(withTitle: "Delete")
		alert.addButton(withTitle: "Cancel")

		if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
			do {
				NotificationCenter.default.post(name: VirtualMachineDocument.DeleteVirtualMachine, object: vm.name)

				let result = try DeleteHandler.delete(names: [vm.name], runMode: .app)

				if let first = result.first {
					if first.deleted {
						let location = StorageLocation(runMode: .app).location(vm.name)

						self.removeVirtualMachineDocument(location.rootURL)
					} else {
						DispatchQueue.main.async {
							alertError(ServiceError("VM Not deleted \(first.name): \(first.reason)"))
						}
					}
				}
			} catch {
				DispatchQueue.main.async {
					alertError(error)
				}
			}
		}
	}
}
