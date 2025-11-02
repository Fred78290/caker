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
	@ObservedObject var appState: AppState
	@AppStorage("ShowMenuIcon") private var isMenuIconShown: Bool = false
	@AppStorage("HideDockIcon") private var isDockIconHidden: Bool = false
	@Environment(\.openWindow) private var openWindow

	var body: some Scene {
		MenuBarExtra(isInserted: $isMenuIconShown) {
			Button("Show Caker") {
				openWindow(id: "home")
			}.keyboardShortcut("0")
				.help("Show the main window.")
			Toggle("Hide dock icon on next launch", isOn: $isDockIconHidden)
				.help("Requires restarting Caker to take affect.")

			Divider()
			Button("New virtual machine") {
				openWindow(id: "wizard")
			}.keyboardShortcut("N")
				.help("Create a new virtual machine.")

			if appState.virtualMachines.isEmpty {
				Text("No virtual machines found.")
			} else {
				Menu("Virtual machines") {
					ForEach(appState.virtualMachines.vms) { vm in
						VMMenuItem(url: vm.id, vm: vm.document, appState: appState)
							.environmentObject(appState)
					}
				}
			}

			Divider()
			Button("Quit") {
				NSApp.terminate(self)
			}.keyboardShortcut("Q")
				.help("Terminate UTM and stop all running VMs.")
		} label: {
			if let path = Bundle.main.path(forResource: "MenuBarIcon", ofType: "png") {
				Image(nsImage: NSImage(contentsOfFile: path) ?? NSImage()).resizable()
			} else {
				Image("AppIcon")
			}
		}
	}
}

private struct VMMenuItem: View {
	@Environment(\.openWindow) var openWindow
	@Environment(\.openDocument) private var openDocument
	let url: URL
	@ObservedObject var vm: VirtualMachineDocument
	@ObservedObject var appState: AppState

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
						createTemplate()
					}
				}

				Divider()

				Button("Delete") {
					DispatchQueue.main.async {
						deleteVirtualMachine()
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
		do {
			try await openDocument(at: url)
			NotificationCenter.default.post(name: VirtualMachineDocument.StartVirtualMachine, object: vm.name, userInfo: ["document": vm.name])
		} catch {
			DispatchQueue.main.async {
				alertError(error)
			}
		}
	}

	func createTemplate() {
		appState.createTemplate(document: self.vm)
	}

	func deleteVirtualMachine() {
		appState.deleteVirtualMachine(document: self.vm)
	}
}
