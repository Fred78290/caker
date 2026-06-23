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
	@State private var password: String = ""
	@State private var showPassword: Bool = false
	@State private var clearPassword: Bool = false
	@State private var sshKey: String = ""
	@State private var sshPassphrase: String = ""
	@State private var showSshPassphrase: Bool = false
	@State private var isImporting: Bool = false
	@State private var errorMessage: String? = nil

	private var importDisabled: Bool {
		vmxPath.isEmpty || targetName.isEmpty || isImporting
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			header
			Divider()
			configForm
			errorBanner
			Spacer(minLength: 0)
			Divider()
			footer
		}
		.frame(minWidth: 480)
		.onChange(of: vmxPath) { _, newPath in
			guard targetName.isEmpty, !newPath.isEmpty else { return }
			targetName = URL(fileURLWithPath: newPath).deletingPathExtension().lastPathComponent
		}
	}

	private var header: some View {
		HStack(spacing: 14) {
			ZStack {
				RoundedRectangle(cornerRadius: 12)
					.fill(Color.blue.gradient)
					.frame(width: 48, height: 48)
				Image(systemName: "square.and.arrow.down.fill")
					.font(.system(size: 22, weight: .semibold))
					.foregroundStyle(.white)
			}
			VStack(alignment: .leading, spacing: 2) {
				Text("Import from VMware")
					.font(.system(size: 16, weight: .semibold))
				Text("Select a VMware .vmx configuration file to import into Caker.")
					.font(.callout)
					.foregroundStyle(.secondary)
			}
		}
		.padding(.horizontal, 20)
		.padding(.top, 20)
		.padding(.bottom, 16)
	}

	private var configForm: some View {
		Form {
			Section("VMware configuration") {
				LabeledContent("VMWare virtual machine") {
					HStack(spacing: 6) {
						TextField("Choose a .vmwarevm bundle…", text: $vmxPath)
							.rounded(.leading)
						Button {
							browseForVMwareVM()
						} label: {
							Image(systemName: "folder")
						}
						.buttonStyle(.borderless)
					}
				}
			}

			Section("Target configuration") {
				LabeledContent("Target name") {
					TextField("", text: $targetName)
						.rounded(.leading)
				}
				LabeledContent("Username") {
					TextField("", text: $userName)
						.rounded(.leading)
				}
				LabeledContent("Password") {
					HStack {
						if showPassword {
							TextField("", text: $password)
								.rounded(.leading)
						} else {
							SecureField("", text: $password)
								.rounded(.leading)
						}
						Button {
							showPassword.toggle()
						} label: {
							Image(systemName: showPassword ? "eye.fill" : "eye.slash.fill")
						}
						.buttonStyle(.borderless)
					}
				}
			}

			Section("SSH configuration") {
				Toggle(isOn: $clearPassword) {
					Label("Allow password authentication for SSH", systemImage: "key")
				}

				LabeledContent("SSH private key") {
					HStack(spacing: 6) {
						TextField("Optional private key path", text: $sshKey)
							.rounded(.leading)
						Button {
							browseForSSHKey()
						} label: {
							Image(systemName: "key.fill")
						}
						.buttonStyle(.borderless)
					}
				}

				LabeledContent("SSH passphrase") {
					HStack {
						if showSshPassphrase {
							TextField("", text: $sshPassphrase)
								.rounded(.leading)
						} else {
							SecureField("", text: $sshPassphrase)
								.rounded(.leading)
						}
						Button {
							showSshPassphrase.toggle()
						} label: {
							Image(systemName: showSshPassphrase ? "eye.fill" : "eye.slash.fill")
						}
						.buttonStyle(.borderless)
					}
				}
			}
		}
		.formStyle(.grouped)
		.scrollDisabled(true)
		.fixedSize(horizontal: false, vertical: true)
	}

	@ViewBuilder
	private var errorBanner: some View {
		if let errorMessage {
			HStack(spacing: 6) {
				Image(systemName: "exclamationmark.triangle.fill")
					.foregroundStyle(.red)
					.font(.callout)
				Text(errorMessage)
					.font(.callout)
					.foregroundStyle(.red)
			}
			.padding(.horizontal, 20)
			.padding(.vertical, 8)
		}
	}

	private var footer: some View {
		HStack(spacing: 8) {
			if isImporting {
				ProgressView()
					.controlSize(.small)
			}
			Spacer()
			Button("Cancel") { dismiss() }
				.buttonStyle(.bordered)
			Button("Import") { doImport() }
				.buttonStyle(.borderedProminent)
				.disabled(importDisabled)
		}
		.padding(.horizontal, 20)
		.padding(.vertical, 12)
	}

	private func browseForVMwareVM() {
		let panel = NSOpenPanel()
		panel.allowsMultipleSelection = false
		panel.canChooseFiles = true
		panel.canChooseDirectories = true

		if let bundleType = UTType(tag: "vmwarevm", tagClass: .filenameExtension, conformingTo: nil) {
			panel.allowedContentTypes = [bundleType]
		}
		panel.title = String(localized: "Select VMware Virtual Machine")

		guard panel.runModal() == .OK, let url = panel.url else { return }

		guard let vmxURL = findVMX(in: url) else {
			errorMessage = String(localized: "No .vmx file found inside \"\(url.lastPathComponent)\"")
			return
		}

		if targetName.isEmpty {
			targetName = url.deletingPathExtension().lastPathComponent
		}
		vmxPath = vmxURL.path(percentEncoded: false)
	}

	private func findVMX(in bundleURL: URL) -> URL? {
		guard let contents = try? FileManager.default.contentsOfDirectory(
			at: bundleURL,
			includingPropertiesForKeys: nil
		) else {
			return nil
		}
		return contents.first { $0.pathExtension.lowercased() == "vmx" }
	}

	private func browseForSSHKey() {
		let panel = NSOpenPanel()
		panel.allowsMultipleSelection = false
		panel.canChooseFiles = true
		panel.canChooseDirectories = false
		panel.title = String(localized: "Select SSH Private Key")

		if panel.runModal() == .OK, let url = panel.url {
			sshKey = url.path(percentEncoded: false)
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
		let clear = clearPassword
		let key = sshKey.isEmpty ? nil : sshKey
		let passphrase = sshPassphrase.isEmpty ? nil : sshPassphrase

		Task.detached(priority: .userInitiated) {
			let result = AppState.shared.importFromVMware(
				source: source,
				name: name,
				userName: user,
				password: pass,
				clearPassword: clear,
				sshKey: key,
				sshPassphrase: passphrase
			)

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
