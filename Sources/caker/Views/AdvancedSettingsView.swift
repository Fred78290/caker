//
//  AdvancedSettingsView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 02/07/2026.
//

import CakedLib
import GRPCLib
import SwiftUI
import Virtualization

struct AdvancedSettingsView: View {
	private static let noneNetwork = "none"
	private static let imdsFirewallCommand = #"sudo sh -c 'echo "rdr pass inet proto tcp from any to 169.254.169.254 -> 192.168.169.1" > /etc/pf.anchors/caker-alias && echo "load anchor \"com.apple/caker-alias\" from \"/etc/pf.anchors/caker-alias\"" >> /etc/pf.conf && pfctl -e -f /etc/pf.conf'"#

	@AppStorage(CakedKeyConfig.imdsEnabled.rawValue, store: .shared) var awsEC2MetadataEnabled: Bool = true

	@State private var bridgedNetwork: String
	@State private var primaryName: String
	@State private var passphrase: String
	@State private var showPassphrase: Bool = false
	@State private var errorMessage: String? = nil
	@State private var cakeHomePath: String
	@State private var isRelocating: Bool = false

	private var bridgedInterfaces: [VZBridgedNetworkInterface] {
		VZBridgedNetworkInterface.networkInterfaces
	}

	init() {
		bridgedNetwork = CakedKeyConfig.bridgedNetwork.string() ?? Self.noneNetwork
		primaryName = CakedKeyConfig.primaryName.string() ?? String.empty
		passphrase = CakedKeyConfig.passphrase.string() ?? String.empty
		cakeHomePath = (try? CakedLib.CakeHomeHandler.currentHome(runMode: .app).path(percentEncoded: false)) ?? String.empty
	}

	var body: some View {
		Form {
			Section {
				LabeledContent("Bridged network") {
					HStack {
						Spacer()
						Picker("Bridged network", selection: $bridgedNetwork) {
							Text("None").tag(Self.noneNetwork)
							ForEach(bridgedInterfaces, id: \.identifier) { interface in
								Text(interface.localizedDisplayName ?? interface.identifier).tag(interface.identifier)
							}
						}
						.labelsHidden()
					}.frame(width: 220)
				}
				.onChange(of: bridgedNetwork) { _, newValue in
					save(.bridgedNetwork, newValue == Self.noneNetwork ? nil : newValue)
				}
			} header: {
				Label("Networking", systemImage: "network")
			} footer: {
				Text("Host network interface used when a virtual machine is attached to a bridged network.")
					.font(.caption)
					.foregroundStyle(.secondary)
			}

			Section {
				LabeledContent("Primary virtual machine name") {
					TextField("primary", text: $primaryName)
						.rounded(.leading)
						.onSubmit {
							save(.primaryName, primaryName.isEmpty ? nil : primaryName)
						}
				}
			} header: {
				Label("Client", systemImage: "terminal")
			} footer: {
				Text("Default virtual machine name used by commands such as sh and exec when none is specified.")
					.font(.caption)
					.foregroundStyle(.secondary)
			}

			Section {
				LabeledContent("Pass-phrase") {
					HStack {
						if showPassphrase {
							TextField("", text: $passphrase)
								.rounded(.leading)
						} else {
							SecureField("", text: $passphrase)
								.rounded(.leading)
						}
						Button {
							showPassphrase.toggle()
						} label: {
							Image(systemName: showPassphrase ? "eye.fill" : "eye.slash.fill")
						}
						.buttonStyle(.borderless)
					}
					.onSubmit {
						save(.passphrase, passphrase.isEmpty ? nil : passphrase)
					}
				}
			} header: {
				Label("Service", systemImage: "lock.shield")
			} footer: {
				Text("Pass-phrase used to install and manage the privileged caked service.")
					.font(.caption)
					.foregroundStyle(.secondary)
			}

			if Bundle.isApplicationSandboxed == false {
				Section {
					LabeledContent("Cake home") {
						Text(cakeHomePath)
							.font(.callout)
							.foregroundStyle(.secondary)
							.textSelection(.enabled)
							.lineLimit(1)
							.truncationMode(.middle)
					}

					HStack {
						Spacer()
						Button {
							relocateCakeHome()
						} label: {
							if isRelocating {
								ProgressView().controlSize(.small)
							} else {
								Label("Relocate…", systemImage: "externaldrive")
							}
						}
						.disabled(isRelocating)
					}
				} header: {
					Label("Storage", systemImage: "internaldrive")
				} footer: {
					Text("Moves virtual machines, images and caches to another folder or volume. The caked service, all virtual machines and all networks must be stopped first.")
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}

			Section {
				Toggle(isOn: $awsEC2MetadataEnabled) {
					Text("Enable AWS EC2 Metadata")
				}
			} header: {
				Label("AWS EC2 Metadata", systemImage: "cloud.fill")
			} footer: {
				Text("Enable IMDSv2 metadata service for virtual machines running on linux. Need to restart caked daemon to take effect.")
					.font(.caption)
					.foregroundStyle(.secondary)
				if Bundle.isApplicationSandboxed {
					Spacer()
					VStack(alignment: .leading, spacing: 4) {
						Text("""
							To allow access from VM to IMDSv2 metadata service via http://169.254.169.254/latest/meta-data/, you must add somes rules in firewall, else meta data will be accessible only via http://192.168.169.1:28080/latest/meta-data/ .

							Run the following command in Terminal to add the firewall rules:
							""")
							.font(.caption)
							.foregroundStyle(.secondary)
						HStack {
							Text(Self.imdsFirewallCommand)
								.font(.caption.monospaced())
								.textSelection(.enabled)
								.padding(6)
								.background(
									RoundedRectangle(cornerRadius: 6, style: .continuous)
										.strokeBorder(.quaternary, lineWidth: 1)
								)
							Button {
								NSPasteboard.general.clearContents()
								NSPasteboard.general.setString(Self.imdsFirewallCommand, forType: .string)
							} label: {
								Image(systemName: "doc.on.doc")
							}
							.buttonStyle(.borderless)
							.help("Copy command")
						}
					}
				}
			}

		}
		.formStyle(.grouped)
		.scrollDisabled(true)
		.fixedSize(horizontal: false, vertical: true)
		.alert(errorMessage ?? String.empty, isPresented: Binding(get: { errorMessage != nil }, set: { if $0 == false { errorMessage = nil } })) {
			Button("OK", role: .cancel) {}
		}
	}

	private func save(_ key: CakedKeyConfig, _ value: String?) {
		key.set(value)
	}

	private func relocateCakeHome() {
		let blockers = CakedLib.CakeHomeHandler.activeBlockers(runMode: .app)

		guard blockers.isEmpty else {
			errorMessage = String(localized: "Cannot relocate cake home while caked is active (\(blockers.joined(separator: ", "))). Stop the caked service, all virtual machines and all networks first.")
			return
		}

		guard let destination = FileHelpers.selectFolder(withTitle: String(localized: "Choose a new location for the cake home directory")) else {
			return
		}

		isRelocating = true

		Task {
			do {
				let newHome = try await Task.detached(priority: .userInitiated) {
					try CakedLib.CakeHomeHandler.relocate(to: destination.path(percentEncoded: false), runMode: .app)
				}.value

				await MainActor.run {
					cakeHomePath = newHome.path(percentEncoded: false)
					isRelocating = false
				}
			} catch {
				await MainActor.run {
					errorMessage = error.reason
					isRelocating = false
				}
			}
		}
	}
}

#Preview {
	AdvancedSettingsView()
}
