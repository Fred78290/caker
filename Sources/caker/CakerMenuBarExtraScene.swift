//
//  CakerMenuBarExtraScene.swift
//  Caker
//
//  Created by Frederic BOLTZ on 11/07/2025.
//

import SwiftUI

struct CakerMenuBarExtraScene: Scene {
	@ObservedObject var appState: AppState
	@AppStorage("ShowMenuIcon") private var isMenuIconShown: Bool = false
	@AppStorage("HideDockIcon") private var isDockIconHidden: Bool = false
	@Environment(\.openWindow) private var openWindow

	var body: some Scene {
		MenuBarExtra(isInserted: $isMenuIconShown) {
			Divider()
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
			Image("MenuBarExtra")
		}
    }
}

private struct VMMenuItem: View {
	@Environment(\.openWindow) var openWindow
	let url: URL
	@ObservedObject var vm: VirtualMachineDocument
	@ObservedObject var appState: AppState
	@State var createTemplate = false

	var body: some View {
		Menu(vm.name) {
			if vm.status == .stopped || vm.status == .none {
				Button("Start") {
					openWindow(id: "opendocument", value: url)
				}
				Button("Create template") {
					createTemplate = true
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
		.alert("Create template", isPresented: $createTemplate) {
			CreateTemplateView(currentDocument: vm)
		}
	}
}
