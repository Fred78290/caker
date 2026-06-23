//
//  ImportMultipassView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 22/06/2026.
//

import CakedLib
import SwiftUI

struct ImportMultipassView: View {
	@Environment(\.dismiss) private var dismiss

	@State private var vms: [MultipassVMInfo] = []
	@State private var selectedVM: MultipassVMInfo? = nil
	@State private var targetName: String = ""
	@State private var userName: String = "ubuntu"
	@State private var password: String = "ubuntu"
	@State private var isLoading: Bool = false
	@State private var isImporting: Bool = false
	@State private var errorMessage: String? = nil

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Import from Multipass").font(.headline)

			Group {
				if isLoading {
					HStack {
						ProgressView()
						Text("Loading Multipass VMs…")
							.foregroundStyle(.secondary)
					}
					.frame(maxWidth: .infinity, alignment: .center)
					.frame(height: 100)
				} else if vms.isEmpty {
					Text("No Multipass VMs found. Make sure Multipass is installed and running.")
						.foregroundStyle(.secondary)
						.frame(maxWidth: .infinity, alignment: .center)
						.frame(height: 100)
				} else {
					Table(vms, selection: $selectedVM) {
						TableColumn("Name") { vm in
							Text(vm.name)
						}
						TableColumn("Release") { vm in
							Text(vm.release)
						}
						TableColumn("State") { vm in
							Text(vm.state)
						}
					}
					.frame(height: 130)
				}
			}

			Form {
				TextField("Target name", text: $targetName)
				TextField("Username", text: $userName)
				SecureField("Password", text: $password)
			}

			if let errorMessage {
				Text(errorMessage)
					.font(.callout)
					.foregroundStyle(.red)
			}

			Spacer()

			Divider()

			HStack {
				Spacer()
				if isImporting {
					ProgressView()
						.controlSize(.small)
						.padding(.trailing, 4)
				}
			Button("Import") {
				doImport()
			}
			.disabled(selectedVM.isEmpty || targetName.isEmpty || isImporting)
				Button("Cancel") {
					dismiss()
				}
				.buttonStyle(.borderedProminent)
				Spacer()
			}
		}
		.padding()
		.onAppear {
			loadVMs()
		}
	}

	private func loadVMs() {
		isLoading = true
		errorMessage = nil

		Task.detached(priority: .userInitiated) {
			let result = AppState.shared.listMultipassVMs()

			await MainActor.run {
				vms = result
				isLoading = false
			}
		}
	}

	private func doImport() {
		guard let vm = selectedVM, !targetName.isEmpty else { return }

		isImporting = true
		errorMessage = nil

		let source = vm.name
		let name = targetName
		let user = userName
		let pass = password

		Task.detached(priority: .userInitiated) {
			let result = AppState.shared.importFromMultipass(source: source, name: name, userName: user, password: pass)

			await MainActor.run {
				isImporting = false

				if result.imported {
					AppState.shared.reloadVirtualMachines()
					dismiss()
				} else {
					errorMessage = result.reason
				}
			}
		}
	}
}

#Preview {
	ImportMultipassView()
}
