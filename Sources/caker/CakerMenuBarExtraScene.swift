//
//  CakerMenuBarExtraScene.swift
//  Caker
//
//  Created by Frederic BOLTZ on 11/07/2025.
//

import SwiftUI
import CakedLib
import GRPCLib

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
					ForEach(appState.vms) { vm in
						VMMenuItem(url: vm.id, vm: vm.document, appState: appState).environmentObject(appState)
					}
				}
			}

			Divider()
			Button("Quit") {
				NSApp.terminate(self)
			}.keyboardShortcut("Q")
			.help("Terminate UTM and stop all running VMs.")
		} label: {
			if let path = Bundle.main.path(forResource: "MenuBarIcon", ofType: "icns") {
				Image(nsImage: NSImage(contentsOfFile: path) ?? NSImage())
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
					vm.requestStopFromUI()
				}.disabled(vm.canStop == false)

				Button("Stop") {
					vm.stopFromUI()
				}.disabled(vm.canStop == false)

				if vm.suspendable {
					if vm.status == .suspended {
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
			NotificationCenter.default.post(name: NSNotification.StartVirtualMachine, object: vm.name)
		} catch {
			DispatchQueue.main.async {
				vm.alertError(error)
			}
		}
	}

	func createTemplate() {
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
			}
		}
	}

	func deleteVirtualMachine() {
		let alert = NSAlert()

		alert.messageText = "Delete virtual machine"
		alert.informativeText = "Are you sure you want to delete \(vm.name)? This action cannot be undone."
		alert.alertStyle = .critical
		alert.addButton(withTitle: "Delete")
		alert.addButton(withTitle: "Cancel")

		if alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn {
			do {
				NotificationCenter.default.post(name: NSNotification.DeleteVirtualMachine, object: vm.name)

				let result = try DeleteHandler.delete(names: [vm.name], runMode: .app)
				
				if let first = result.first {
					if first.deleted {
						let location = StorageLocation(runMode: .app).location(vm.name)
						
						appState.virtualMachines.removeValue(forKey: location.rootURL)
					} else {
                        DispatchQueue.main.async {
                            vm.alertError(ServiceError("VM Not deleted \(first.name): \(first.reason)"))
                        }
					}
				}
			} catch {
                DispatchQueue.main.async {
                    vm.alertError(error)
                }
			}
		}
	}
}
