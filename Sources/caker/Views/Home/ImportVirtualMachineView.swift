//
//  ImportVirtualMachineView.swift
//  Caker
//

import CakedLib
import GRPCLib
import SwiftUI
import UniformTypeIdentifiers

protocol ImporterDelegate {
	func browserForVirtualMachine() -> URL?
	func suggestedName(for url: URL) -> String
	func doImport(vmPath: String, targetName: String, userName: String, password: String, clearPassword: Bool, sshKey: String?, sshPassphrase: String?, copyDisk: Bool) async -> ImportedReply
}

extension ImporterDelegate {
	func suggestedName(for url: URL) -> String {
		url.deletingPathExtension().lastPathComponent
	}
}

struct ImportVirtualMachineView: View {
	@Environment(\.dismiss) private var dismiss

	@State private var vmPath: String = ""
	@State private var targetName: String = ""
	@State private var userName: String = "admin"
	@State private var password: String = ""
	@State private var showPassword: Bool = false
	@State private var clearPassword: Bool = false
	@State private var sshKey: String = ""
	@State private var sshPassphrase: String = ""
	@State private var showSshPassphrase: Bool = false
	@State private var copyDisk: Bool = true
	@State private var isImporting: Bool = false
	@State private var errorMessage: String? = nil

	private let storageLocation = StorageLocation(runMode: .app)
	private let description: LocalizedStringKey
	private let appName: String
	private let mustCopyImageDisk: Bool
	private let delegate: ImporterDelegate

	private var importDisabled: Bool {
		guard (vmPath.isEmpty || targetName.isEmpty || userName.isEmpty || password.isEmpty || isImporting) == false else {
			return true
		}

		return storageLocation.exists(targetName)
	}

	init(_ text: LocalizedStringKey, appName: String, mustCopyImageDisk: Bool, delegate: ImporterDelegate) {
		self.description = text
		self.appName = appName
		self.mustCopyImageDisk = mustCopyImageDisk
		self.delegate = delegate
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
		.frame(width: 500)
		.onChange(of: vmPath) { _, newPath in
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
				Text("Import from \(appName)")
					.font(.system(size: 16, weight: .semibold))
				Text(description)
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
			Section("\(appName) virtual machine") {
				LabeledContent("Virtual machine path") {
					HStack(spacing: 6) {
						TextField("", text: $vmPath)
							.rounded(.leading)
							.frame(width: 213)
						Button {
							if let url = self.delegate.browserForVirtualMachine() {
								self.vmPath = url.path(percentEncoded: false)

								if targetName.isEmpty {
									targetName = self.delegate.suggestedName(for: url)
								}
							}
						} label: {
							Image(systemName: "folder")
						}
						.frame(width: 20)
						.buttonStyle(.borderless)
					}
				}
			}

			Section("Target configuration") {
				LabeledContent("Target name") {
					TextField("", text: $targetName)
						.frame(width: 243)
						.rounded(.leading)
				}
				LabeledContent("Username") {
					TextField("", text: $userName)
						.frame(width: 243)
						.rounded(.leading)
				}
				LabeledContent("Password") {
					HStack {
						if showPassword {
							TextField("", text: $password)
								.frame(width: 213)
								.rounded(.leading)
						} else {
							SecureField("", text: $password)
								.frame(width: 213)
								.rounded(.leading)
						}
						Button {
							showPassword.toggle()
						} label: {
							Image(systemName: showPassword ? "eye.fill" : "eye.slash.fill")
						}
						.frame(width: 20)
						.buttonStyle(.borderless)
					}
				}

				if mustCopyImageDisk == false {
					Toggle(isOn: $copyDisk) {
						Label("Copy disk image", systemImage: "doc.on.doc")
					}
					Text("When the option is off, the imported VM references the original disk image in place instead of copying it. Don't delete or move the original VM.")
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}

			Section("Optional SSH user configuration") {
				Toggle(isOn: $clearPassword) {
					Label("Allow password authentication for SSH", systemImage: "key")
				}

				LabeledContent("SSH private key") {
					HStack(spacing: 6) {
						TextField("Optional private key path", text: $sshKey)
							.frame(width: 213)
							.rounded(.leading)
						Button {
							browseForSSHKey()
						} label: {
							Image(systemName: "key.fill")
						}
						.frame(width: 20)
						.buttonStyle(.borderless)
					}
				}

				LabeledContent("SSH passphrase") {
					HStack {
						if showSshPassphrase {
							TextField("", text: $sshPassphrase)
								.frame(width: 213)
								.rounded(.leading)
						} else {
							SecureField("", text: $sshPassphrase)
								.frame(width: 213)
								.rounded(.leading)
						}
						Button {
							showSshPassphrase.toggle()
						} label: {
							Image(systemName: showSshPassphrase ? "eye.fill" : "eye.slash.fill")
						}
						.frame(width: 20)
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
					.lineLimit(nil)
					.fixedSize(horizontal: false, vertical: true)
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
		guard !vmPath.isEmpty, !targetName.isEmpty else { return }

		isImporting = true
		errorMessage = nil

		let delegate = self.delegate
		let source = vmPath
		let name = targetName
		let user = userName
		let pass = password
		let clear = clearPassword
		let key = sshKey.isEmpty ? nil : sshKey
		let passphrase = sshPassphrase.isEmpty ? nil : sshPassphrase
		let copy = copyDisk

		Task.detached(priority: .userInitiated) {
			let result = await delegate.doImport(
				vmPath: source,
				targetName: name,
				userName: user,
				password: pass,
				clearPassword: clear,
				sshKey: key,
				sshPassphrase: passphrase,
				copyDisk: copy)

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
