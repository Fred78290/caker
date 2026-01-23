import CakedLib
import Foundation
import GRPC
import GRPCLib
import SwiftUI

typealias VirtualMachineDocumentByURL = [URL: VirtualMachineDocument]

extension VirtualMachineDocumentByURL {
	var vms: [PairedVirtualMachineDocument] {
		self.compactMap {
			PairedVirtualMachineDocument(id: $0.key, name: $0.value.name, document: $0.value)
		}.sorted(using: PairedVirtualMachineDocumentComparator())
	}
}

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
	private var agentStatusTimer: Timer?
	private static var _shared: AppState! = nil

	static var shared: AppState {
		guard let shared = _shared else {
			_shared = AppState()
			return _shared
		}

		return shared
	}

	@AppStorage("VMLaunchMode") var launchVMExternally = false
	@AppStorage("ClipboardRedirectionEnabled") var isClipboardRedirectionEnabled = false
	@AppStorage("DebugVNCMessageEnabled") var debugVNCMessageEnabled: Bool = false

	@Published var cakedServiceInstalled: Bool = false
	@Published var cakedServiceRunning: Bool = false
	@Published var currentDocument: VirtualMachineDocument!
	@Published var isAgentInstalling: Bool = false
	@Published var isStopped: Bool = true
	@Published var isSuspendable: Bool = false
	@Published var isRunning: Bool = false
	@Published var isPaused: Bool = false
	@Published var remotes: [RemoteEntry] = []
	@Published var templates: [TemplateEntry] = []
	@Published var networks: [BridgedNetwork] = []
	@Published var virtualMachines: [URL: VirtualMachineDocument] = [:]

	deinit {
		agentStatusTimer?.invalidate()
	}

	init() {
		let machines = Self.loadVirtualMachines()

		self.virtualMachines = machines
		self.networks = Self.loadNetworks()
		self.remotes = Self.loadRemotes()
		self.templates = Self.loadTemplates()
		self.cakedServiceInstalled = ServiceHandler.isAgentInstalled
		self.cakedServiceRunning = ServiceHandler.isAgentRunning

		// Start polling agent running status every second
		self.agentStatusTimer?.invalidate()
		self.agentStatusTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
			guard let self = self else { return }

			let running = ServiceHandler.isAgentRunning
			let installed = ServiceHandler.isAgentInstalled

			if self.cakedServiceInstalled != installed || self.cakedServiceRunning != running {
				DispatchQueue.main.async {
					self.cakedServiceInstalled = installed
					self.cakedServiceRunning = running
				}
			}
		}
	}

	static func loadNetworks() -> [BridgedNetwork] {
		let result = NetworksHandler.networks(runMode: .app)

		if result.success {
			return result.networks.sorted(using: BridgedNetworkComparator())
		}

		return []
	}

	static func loadRemotes() -> [RemoteEntry] {
		let result = RemoteHandler.listRemote(runMode: .app)

		if result.success {
			return result.remotes.sorted(using: RemoteHandlerComparator())
		}

		return []
	}

	static func loadTemplates() -> [TemplateEntry] {
		let result = TemplateHandler.listTemplate(runMode: .app)

		if result.success {
			return result.templates.sorted(using: TemplateEntryComparator())
		}

		return []
	}

	static func loadVirtualMachines() -> ([URL: VirtualMachineDocument]) {
		let result = ListHandler.list(vmonly: true, runMode: .app)
		var vms: [URL: VirtualMachineDocument] = [:]

		if result.success {
			let storage = StorageLocation(runMode: .app)

			result.infos.compactMap {
				if let location = try? storage.find($0.name) {
					return location
				}

				return nil
			}.forEach { location in
				if let vm = try? VirtualMachineDocument(location: location) {
					vms[location.rootURL] = vm
				}
			}
		}

		return vms
	}

	func reloadNetworks() {
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

	func addVirtualMachineDocument(_ location: VMLocation) {
		if self.virtualMachines[location.rootURL] == nil {
			if let vm = try? VirtualMachineDocument(location: location) {
				self.virtualMachines[location.rootURL] = vm
			}
		}
	}

	func removeVirtualMachineDocument(_ url: URL) {
		if self.virtualMachines[url] != nil {
			self.virtualMachines.removeValue(forKey: url)
		}
	}

	func haveVirtualMachinesRunning() -> Bool {
		return virtualMachines.values.first { vm in
			vm.status == .running && vm.externalRunning == false
		} != nil
	}

	func replaceVirtualMachineDocument(_ url: URL, with document: VirtualMachineDocument) {
		DispatchQueue.main.async {
			self.virtualMachines[url] = document
		}
	}

	func createTemplate(document vm: VirtualMachineDocument) {
		let alert = NSAlert()
		let txt = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))

		alert.messageText = "Create template"
		alert.informativeText = "Name of the new template"
		alert.alertStyle = .informational
		alert.addButton(withTitle: "Create")
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
				self.reloadTemplates()
			}
		}
	}

	func duplicateVirtualMachine(document vm: VirtualMachineDocument) {
		let alert = NSAlert()
		let txt = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))

		alert.messageText = "Duplicate virtual machine"
		alert.informativeText = "Name of the new vm"
		alert.alertStyle = .informational
		alert.addButton(withTitle: "Duplicate")
		alert.addButton(withTitle: "Cancel")

		alert.accessoryView = txt

		if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
			let result = vm.duplicateFromUI(name: txt.stringValue)

			if result.duplicated == false {
				let alert = NSAlert()

				alert.messageText = "Failed to duplicate virtual machine"
				alert.informativeText = result.reason
				alert.runModal()
			} else {
				let location = StorageLocation(runMode: .app).location(txt.stringValue)

				self.addVirtualMachineDocument(location)
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
				NotificationCenter.default.post(name: VirtualMachineDocument.DeleteVirtualMachine, object: vm.name, userInfo: ["document": vm.name])

				let result = try DeleteHandler.delete(names: [vm.name], runMode: .app)

				if let first = result.first {
					if first.deleted {
						let location = StorageLocation(runMode: .app).location(vm.name)

						self.removeVirtualMachineDocument(location.rootURL)
					} else {
						DispatchQueue.main.async {
							alertError(ServiceError(first.reason))
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

	func deleteNetwork(name: String) {
		let alert = NSAlert()

		alert.messageText = "Delete network"
		alert.informativeText = "Are you sure you want to delete network \(name)? This action cannot be undone."
		alert.alertStyle = .critical
		alert.addButton(withTitle: "Delete")
		alert.addButton(withTitle: "Cancel")

		if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
			let result = NetworksHandler.delete(networkName: name, runMode: .app)

			if result.deleted {
				self.reloadNetworks()
			} else {
				DispatchQueue.main.async {
					alertError(ServiceError(result.reason))
				}
			}
		}
	}

	func deleteTemplate(name: String) {
		let alert = NSAlert()

		alert.messageText = "Delete template"
		alert.informativeText = "Are you sure you want to delete template \(name)? This action cannot be undone."
		alert.alertStyle = .critical
		alert.addButton(withTitle: "Delete")
		alert.addButton(withTitle: "Cancel")

		if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
			let result = TemplateHandler.deleteTemplate(templateName: name, runMode: .app)

			if result.deleted {
				self.reloadTemplates()
			} else {
				DispatchQueue.main.async {
					alertError(ServiceError(result.reason))
				}
			}
		}
	}

	func deleteRemote(name: String) {
		let alert = NSAlert()

		alert.messageText = "Delete remote"
		alert.informativeText = "Are you sure you want to delete remote \(name)? This action cannot be undone."
		alert.alertStyle = .critical
		alert.addButton(withTitle: "Delete")
		alert.addButton(withTitle: "Cancel")

		if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
			let result = RemoteHandler.deleteRemote(name: name, runMode: .app)

			if result.deleted {
				self.reloadTemplates()
			} else {
				DispatchQueue.main.async {
					alertError(ServiceError(result.reason))
				}
			}
		}
	}

	func installCakedService() {
		do {
			try ServiceHandler.installAgent(runMode: .app)
		} catch {
			DispatchQueue.main.async {
				alertError(error)
			}
		}
	}

	func removeCakedService() {
		do {
			try ServiceHandler.uninstallAgent(runMode: .app)
		} catch {
			DispatchQueue.main.async {
				alertError(error)
			}
		}
	}

	func stopCakedService() {
		do {
			try ServiceHandler.stopAgent(runMode: .app)
		} catch {
			DispatchQueue.main.async {
				alertError(error)
			}
		}
	}

	func startCakedService() {
		do {
			try ServiceHandler.launchAgent(runMode: .app)
		} catch {
			DispatchQueue.main.async {
				alertError(error)
			}
		}
	}
}
