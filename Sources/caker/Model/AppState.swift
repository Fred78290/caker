import Foundation
import GRPC
import GRPCLib
import CakedLib
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

	@Published var currentDocument: VirtualMachineDocument?
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

	private var virtualMachines: [URL:VirtualMachineDocument] = [:]

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

	static func loadVirtualMachines() -> ([URL:VirtualMachineDocument], [String]) {
		var result: [URL:VirtualMachineDocument] = [:]
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
		self.networks = try NetworksHandler.networks(runMode: .app).sorted { $0.name < $1.name }
	}
	
	func reloadRemotes() throws {
		self.remotes = try RemoteHandler.listRemote(runMode: .app).sorted { $0.name < $1.name }
	}
	
	func reloadTemplates() throws {
		self.templates = try TemplateHandler.listTemplate(runMode: .app)
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
}
