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
	@State private var selectedVM: Set<MultipassVMInfo.ID> = []
	@State private var targetName: String = ""
	@State private var userName: String = "ubuntu"
	@State private var password: String = ""
	@State private var showPassword: Bool = false
	@State private var clearPassword: Bool = false
	@State private var sshKey: String = ""
	@State private var sshPassphrase: String = ""
	@State private var showSshPassphrase: Bool = false
	@State private var isLoading: Bool = false
	@State private var isImporting: Bool = false
	@State private var errorMessage: String? = nil
	@State private var requiresAuthentication: Bool = false
	@State private var multipassPassphrase: String = ""
	@State private var showMultipassPassphrase: Bool = false
	@State private var isAuthenticating: Bool = false

	private let storageLocation = StorageLocation(runMode: .app)

	private var importDisabled: Bool {
		guard (selectedVM.isEmpty || targetName.isEmpty || userName.isEmpty || password.isEmpty || isImporting) == false else {
			return true
		}

		return storageLocation.exists(targetName)
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			header
			advisoryBanner
			Divider()
			vmList
			Divider()
			configForm
			errorBanner
			Spacer(minLength: 0)
			Divider()
			footer
		}
		.frame(width: 500)
		.onAppear { loadVMs() }
		.onChange(of: selectedVM) { _, newSelection in
			if let name = newSelection.first, targetName.isEmpty {
				targetName = name
			}
		}
	}

	private var header: some View {
		HStack(spacing: 14) {
			ZStack {
				RoundedRectangle(cornerRadius: 12)
					.fill(Color.orange.gradient)
					.frame(width: 48, height: 48)
				Image(systemName: "arrow.down.circle.fill")
					.font(.system(size: 22, weight: .semibold))
					.foregroundStyle(.white)
			}
			VStack(alignment: .leading, spacing: 2) {
				Text("Import from Multipass")
					.font(.system(size: 16, weight: .semibold))
				Text("Select a Multipass VM to import into Caker.")
					.font(.callout)
					.foregroundStyle(.secondary)
			}
		}
		.padding(.horizontal, 20)
		.padding(.top, 20)
		.padding(.bottom, 16)
	}

	private var advisoryBanner: some View {
		HStack(alignment: .top, spacing: 8) {
			Image(systemName: "exclamationmark.shield.fill")
				.foregroundStyle(.orange)
				.font(.system(size: 14, weight: .semibold))
				.padding(.top, 1)
			VStack(alignment: .leading, spacing: 4) {
				Text("Importing from Multipass requires **root access**. Your user account must be a member of the **wheel** group.")
					.font(.caption)
					.foregroundStyle(.secondary)
					.fixedSize(horizontal: false, vertical: true)
				Text("To add your user to the wheel group, run in Terminal:")
					.font(.caption)
					.foregroundStyle(.secondary)
				Text("sudo dseditgroup -o edit -a $USER -t user wheel")
					.font(.system(size: 11, design: .monospaced))
					.foregroundStyle(.primary)
					.textSelection(.enabled)
				if Bundle.isApplicationSandboxed {
					Spacer()
					Text("You wheel be prompted for your password two times by osascript. Accept the prompt to continue.")
						.font(.caption)
						.foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)
				}
			}
		}
		.padding(.horizontal, 20)
		.padding(.vertical, 10)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(Color.orange.opacity(0.08))
	}

	@ViewBuilder
	private var vmList: some View {
		if isLoading {
			HStack(spacing: 8) {
				ProgressView()
				Text("Loading Multipass VMs…")
					.foregroundStyle(.secondary)
					.font(.callout)
			}
			.frame(maxWidth: .infinity)
			.frame(height: 130)
		} else if requiresAuthentication {
			authenticationPrompt
		} else if vms.isEmpty {
			GeometryReader { geom in
				ContentUnavailableView(
					"No VMs Found",
					systemImage: "tray",
					description: Text("Make sure Multipass is installed and running.")
				)
				.frame(width: geom.size.width, height: 130)
			}
		} else {
			Table(vms, selection: $selectedVM) {
				TableColumn("Name") { vm in
					Text(vm.name)
						.font(.system(size: 13, weight: .medium))
				}
				TableColumn("Release") { vm in
					Text(vm.release)
						.font(.system(size: 13))
						.foregroundStyle(.secondary)
				}
				TableColumn("State") { vm in
					stateBadge(vm.state)
				}
			}
			.alternatingRowBackgrounds()
			.frame(height: 130)
		}
	}

	private var configForm: some View {
		Form {
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

			Section("User optional SSH configuration") {
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
					.lineLimit(nil)
					.fixedSize(horizontal: false, vertical: true)
			}
			.padding(.horizontal, 20)
			.padding(.vertical, 8)
		}
	}

	private var authenticationPrompt: some View {
		VStack(spacing: 10) {
			Label("Multipass Authentication Required", systemImage: "lock.circle.fill")
				.font(.callout.weight(.semibold))
				.foregroundStyle(.orange)
			Text("Enter the Multipass passphrase to authenticate.")
				.font(.caption)
				.foregroundStyle(.secondary)
			HStack(spacing: 6) {
				if showMultipassPassphrase {
					TextField("Passphrase", text: $multipassPassphrase)
						.textFieldStyle(.roundedBorder)
				} else {
					SecureField("Passphrase", text: $multipassPassphrase)
						.textFieldStyle(.roundedBorder)
				}
				Button {
					showMultipassPassphrase.toggle()
				} label: {
					Image(systemName: showMultipassPassphrase ? "eye.fill" : "eye.slash.fill")
				}
				.buttonStyle(.borderless)
			}
			.padding(.horizontal, 80)
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 16)
	}

	private var footer: some View {
		HStack(spacing: 8) {
			if isImporting || isAuthenticating {
				ProgressView()
					.controlSize(.small)
			}
			Spacer()
			Button("Cancel") { dismiss() }
				.buttonStyle(.bordered)
			if requiresAuthentication {
				Button("Authenticate") { doSetPassphrase() }
					.buttonStyle(.borderedProminent)
					.disabled(multipassPassphrase.isEmpty || isAuthenticating)
			} else {
				Button("Import") { doImport() }
					.buttonStyle(.borderedProminent)
					.disabled(importDisabled)
			}
		}
		.padding(.horizontal, 20)
		.padding(.vertical, 12)
	}

	@ViewBuilder
	private func stateBadge(_ state: String) -> some View {
		let lower = state.lowercased()
		let color: Color = lower == "running" ? .green : lower == "stopped" ? .red : .orange

		Text(state)
			.font(.system(size: 11, weight: .medium))
			.foregroundStyle(color)
			.padding(.horizontal, 6)
			.padding(.vertical, 2)
			.background(Capsule().fill(color.opacity(0.12)))
	}

	private func loadVMs() {
		isLoading = true
		errorMessage = nil
		requiresAuthentication = false

		Task.detached(priority: .userInitiated) {
			do {
				let result = try AppState.shared.listMultipassVMs()

				await MainActor.run {
					vms = result
					isLoading = false
				}
			} catch let shellError as ShellError where shellError.error.contains("multipass authenticate") {
				await MainActor.run {
					isLoading = false
					requiresAuthentication = true
				}
			} catch {
				await MainActor.run {
					isLoading = false
					errorMessage = error.localizedDescription
				}
			}
		}
	}

	private func doSetPassphrase() {
		isAuthenticating = true
		errorMessage = nil

		let passphrase = multipassPassphrase

		Task.detached(priority: .userInitiated) {
			do {
				try AppState.shared.authenticateMultipass(passphrase)

				await MainActor.run {
					isAuthenticating = false
					multipassPassphrase = ""
					showMultipassPassphrase = false
				}

				await MainActor.run { loadVMs() }
			} catch {
				await MainActor.run {
					isAuthenticating = false
					errorMessage = (error as? ShellError)?.error ?? error.localizedDescription
				}
			}
		}
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
		guard let source = selectedVM.first, !targetName.isEmpty else { return }

		isImporting = true
		errorMessage = nil

		let name = targetName
		let user = userName
		let pass = password
		let clear = clearPassword
		let key = sshKey.isEmpty ? nil : sshKey
		let passphrase = sshPassphrase.isEmpty ? nil : sshPassphrase

		Task.detached(priority: .userInitiated) {
			let result = AppState.shared.importFromMultipass(
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
	ImportMultipassView()
}
