//
//  CakerMenuBarExtraScene.swift
//  Caker
//
//  Created by Frederic BOLTZ on 11/07/2025.
//

import CakedLib
import GRPCLib
import SwiftUI

struct CakerMenuBarExtraScene: Scene {
	private var appState: AppState = .shared
	@State var model: NavigationModel
	@State private var composeMenuModel = ComposeMenuBarPoller()

	@AppStorage("ShowMenuIcon") private var isMenuIconShown: Bool = false
	@AppStorage("HideDockIcon") private var isDockIconHidden: Bool = false
	@Environment(\.openWindow) private var openWindow
	@Environment(\.openSettings) private var openSettings

#if TRACE_SWIFTUI_DEALLOC
	let tracker = TrackDealloc(from: "CakerMenuBarExtraScene")
#endif

	// Make initializer accessible from other files
	init(model: NavigationModel) {
		self.model = model
	}

	var body: some Scene {
		MenuBarExtra(isInserted: $isMenuIconShown) {
			Button("About Caker") {
				openWindow(id: "about")
			}
			.onAppear {
				// This scene has no live-updating list the way `NavigationModel.documents` does for
				// VMs (no GCD push for compose state) — `composeMenuModel` polls on its own instead,
				// the same least-effort approach `TasksView` uses for its own sidebar category.
				// `start()` is idempotent, so re-running this on every menu open is harmless.
				self.composeMenuModel.start()
			}
			Button("Show Caker") {
				openWindow(id: "home")
			}.keyboardShortcut("H")
				.help("Show the main window.")
			
			Divider()
			
			Menu("Options") {
				Button("Settings") {
					openSettings()
				}
				Divider()
				Button("New virtual machine") {
					openWindow(id: "wizard")
				}.keyboardShortcut("N")
					.help("Create a new virtual machine.")
				Button("Open virtual machine") {
					open()
				}.keyboardShortcut("O")
					.help("Open new virtual machine.")
				
				Toggle("Hide dock icon on next launch", isOn: $isDockIconHidden)
					.help("Requires restarting Caker to take affect.")
			}
			
			Menu("Service") {
				Button("Browser of services") {
					openWindow(id: "remote")
				}.keyboardShortcut("B")
					.help("Show the service browser.")
				Divider()
				if self.appState.cakedServiceInstalled {
					Button("Remove service") {
						MainApp.removeCakedService()
					}
				} else {
					Button("Install service") {
						MainApp.installCakedService()
					}
				}
				
				if self.appState.cakedServiceInstalled {
					if self.appState.cakedServiceRunning {
						Button("Stop service") {
							MainApp.stopCakedService()
						}.disabled(self.appState.cakedServiceInstalled == false)
					} else {
						Button("Start service") {
							MainApp.startCakedService()
						}.disabled(self.appState.cakedServiceInstalled == false)
					}
				} else {
					if self.appState.cakedServiceRunning {
						Button("Stop caked daemon") {
							MainApp.stopCakedDaemon()
						}
					} else {
						Button("Start caked daemon") {
							MainApp.startCakedDaemon()
						}
					}
				}

				// With a caked daemon running, the resolver is embedded in it; otherwise (`.app`
				// mode) nothing hosts one unless a standalone `caked dns` is started. Not offered
				// in a sandboxed build — see `AppState.canManageCakedDns`.
				if self.appState.canManageCakedDns {
					Divider()

					if self.appState.cakedDnsRunning {
						Button("Stop caked DNS") {
							MainApp.stopCakedDns()
						}
					} else {
						Button("Start caked DNS") {
							MainApp.startCakedDns()
						}
					}
				}
			}
			
			Divider()

			if self.model.documents.isEmpty {
				Text("No virtual machines found.")
			} else {
				Menu("Virtual machines") {
					let vms = Array(self.model.documents.values).sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
					ForEach(vms, id: \.url) { vm in
						VMMenuItem(vm: vm)
					}
				}
			}

			if self.composeMenuModel.projects.isEmpty {
				Text("No compose projects found.")
			} else {
				Menu("Compose") {
					ForEach(self.composeMenuModel.projects, id: \.self) { project in
						ComposeProjectMenuItem(project: project, model: self.model)
					}
				}
			}

			Button("New compose project…") {
				self.model.pendingSidebarCategory = .compose
				self.model.pendingNewComposeProject = true
				openWindow(id: "home")
			}

			Divider()
			Button("Quit") {
				NSApp.terminate(self)
			}
			.keyboardShortcut("Q")
			.help("Terminate Caker and stop all running VMs.")
		} label: {
			if let path = Bundle.main.path(forResource: "MenuBarIcon", ofType: "png") {
				Image(nsImage: NSImage(contentsOfFile: path) ?? NSImage()).resizable()
			} else {
				Image("AppIcon")
			}
		}
	}

	private func open() {
		let home = StorageLocation(runMode: .app).rootURL

		if let documentURL = FileHelpers.selectSingleInputFile(ofType: [.virtualMachine], withTitle: String(localized: "Open virtual machine"), directoryURL: home) {
			Task {
				await MainApp.app.openVirtualMachine(documentURL)
			}
		}
	}
}

private struct VMMenuItem: View {
	@Environment(\.openWindow) var openWindow
	var vm: VirtualMachineDocumentState

	var body: some View {
		Menu(vm.name) {
			if vm.status == .stopped || vm.status == .none {
				Button("Start") {
					Task {
						await openVirtualMachine()
					}
				}

				Button("Create template") {
					DispatchQueue.main.async {
						vm.createTemplate()
					}
				}

				Divider()

				Button("Delete") {
					DispatchQueue.main.async {
						vm.deleteVirtualMachine()
					}
				}
			} else {
				Button("Request stop") {
					vm.stopFromUI(force: false)
				}.disabled(vm.canStop == false)

				Button("Stop") {
					vm.stopFromUI(force: true)
				}.disabled(vm.canStop == false)

				if vm.suspendable {
					if vm.status == .paused {
						Button("Resume") {
							vm.startFromUI()
						}
					} else {
						Button("Suspend") {
							vm.suspendFromUI()
						}
					}
				}
			}
		}
	}

	func openVirtualMachine() async {
		await MainApp.app.openVirtualMachine(self.vm.url)
		NotificationCenter.default.post(name: VirtualMachineDocument.StartVirtualMachine, object: vm, userInfo: ["document": vm.url])
	}
}

/// Polls `caked`'s registered compose projects for the menu bar's "Compose" submenu.
///
/// `NavigationModel.documents` gets its updates pushed live via GCD, but there is no equivalent
/// push mechanism for compose project state (see `ComposeView`'s own doc comment) — this mirrors
/// `TasksView`'s own "poll on a timer while visible" approach instead, at the same 5s-ish cadence
/// the compose sidebar category polls at, since a stale-by-a-few-seconds menu is an acceptable
/// trade-off for not needing a second live-status channel just for the menu bar.
@Observable
final class ComposeMenuBarPoller {
	private(set) var projects: [ComposeReplyList.ComposeInfo] = []
	private var pollTask: Task<Void, Never>? = nil

	func start() {
		guard self.pollTask == nil else {
			return
		}

		self.pollTask = Task { [weak self] in
			while let self, Task.isCancelled == false {
				self.refresh()

				try? await Task.sleep(for: .seconds(5))
			}
		}
	}

	func refresh() {
		let client = AppState.shared.connectionManager.serviceClient
		let runMode = AppState.shared.connectionManager.connectionMode.runMode

		DispatchQueue.global(qos: .utility).async { [weak self] in
			guard let reply = try? ComposeHandler.list(client: client, runMode: runMode), reply.success else {
				return
			}

			let sorted = reply.composeFiles.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

			DispatchQueue.main.async {
				self?.projects = sorted
			}
		}
	}
}

/// One registered compose project's menu-bar submenu — Start/Stop (whichever is the project's
/// current `primaryAction`) plus an "Open" action that opens (or fronts) the main window on the
/// Compose category with this project selected, the same `openWindow` convention
/// `Button("Show Caker") { openWindow(id: "home") }` above already uses.
private struct ComposeProjectMenuItem: View {
	@Environment(\.openWindow) var openWindow

	let project: ComposeReplyList.ComposeInfo
	let model: NavigationModel

	var body: some View {
		Menu(project.name) {
			Button("Open") {
				self.model.pendingSidebarCategory = .compose
				self.model.pendingComposeProjectName = self.project.name
				self.openWindow(id: "home")
			}

			Divider()

			switch self.project.primaryAction {
			case .start:
				Button("Start") {
					ComposeView.start(self.project) {}
				}
			case .stop:
				Button("Stop") {
					ComposeView.confirmAndStop(self.project) {}
				}
			}
		}
	}
}
