//
//  ImportVMwareView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 22/06/2026.
//

import CakedLib
import SwiftUI
import UniformTypeIdentifiers

struct ImportVMwareView: View {
	@Environment(\.dismiss) private var dismiss

	@State private var vmxPath: String = ""
	@State private var targetName: String = ""
	@State private var userName: String = "admin"
	@State private var password: String = "admin"
	@State private var isImporting: Bool = false
	@State private var errorMessage: String? = nil

	private var importDisabled: Bool {
		vmxPath.isEmpty || targetName.isEmpty || isImporting
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Import from VMware").font(.headline)

			HStack {
				TextField("VMX file path", text: $vmxPath)
				Button("Browse…") {
					browseForVMX()
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
				.disabled(importDisabled)

				Button("Cancel") {
					dismiss()
				}
				.buttonStyle(.borderedProminent)
				Spacer()
			}
		}
		.padding()
	}

	private func browseForVMX() {
		let panel = NSOpenPanel()
		panel.allowsMultipleSelection = false
		panel.canChooseDirectories = false
		panel.canChooseFiles = true
		panel.allowedContentTypes = [UTType(filenameExtension: "vmx") ?? .data]
		panel.title = String(localized: "Select VMware Configuration File")

		if panel.runModal() == .OK, let url = panel.url {
			vmxPath = url.path(percentEncoded: false)
			if targetName.isEmpty {
				targetName = url.deletingPathExtension().lastPathComponent
			}
		}
	}

	private func doImport() {
		guard !vmxPath.isEmpty, !targetName.isEmpty else { return }

		isImporting = true
		errorMessage = nil

		let source = vmxPath
		let name = targetName
		let user = userName
		let pass = password

		Task.detached(priority: .userInitiated) {
			let result = AppState.shared.importFromVMware(source: source, name: name, userName: user, password: pass)

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
	ImportVMwareView()
}
