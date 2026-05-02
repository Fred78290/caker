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

	@AppStorage("ShowMenuIcon") private var isMenuIconShown: Bool = false
	@AppStorage("HideDockIcon") private var isDockIconHidden: Bool = false
	@Environment(\.openWindow) private var openWindow
	@Environment(\.openSettings) private var openSettings

#if DEBUG
	let tracker = TrackDealloc(from: "CakerMenuBarExtraScene")
#endif

	// Make initializer accessible from other files
	init(model: NavigationModel) {
		self.model = model
	}

	var body: some Scene {
		MenuBarExtra(isInserted: $isMenuIconShown) {
			Button("About Caker") {
				NSApp.orderFrontStandardAboutPanel(nil)
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
	@State var status: VirtualMachineDocument.Status
	
	init(vm: VirtualMachineDocumentState) {
		self.vm = vm
		self.status = vm.status
	}

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
		.onChange(of: self.vm.status) {
			self.status = self.vm.status
		}
	}

	func openVirtualMachine() async {
		await MainApp.app.openVirtualMachine(self.vm.url)
		NotificationCenter.default.post(name: VirtualMachineDocument.StartVirtualMachine, object: vm, userInfo: ["document": vm.url])
	}
}
