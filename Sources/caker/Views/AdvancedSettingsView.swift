//
//  AdvancedSettingsView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 02/07/2026.
//

import GRPCLib
import SwiftUI
import Virtualization

struct AdvancedSettingsView: View {
	private static let noneNetwork = "none"

	@State private var bridgedNetwork: String = AdvancedSettingsView.noneNetwork
	@State private var primaryName: String = String.empty
	@State private var passphrase: String = String.empty
	@State private var showPassphrase: Bool = false
	@State private var errorMessage: String? = nil

	private var bridgedInterfaces: [VZBridgedNetworkInterface] {
		VZBridgedNetworkInterface.networkInterfaces
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
		}
		.formStyle(.grouped)
		.scrollDisabled(true)
		.fixedSize(horizontal: false, vertical: true)
		.onAppear(perform: load)
		.alert(errorMessage ?? String.empty, isPresented: Binding(get: { errorMessage != nil }, set: { if $0 == false { errorMessage = nil } })) {
			Button("OK", role: .cancel) {}
		}
	}

	private func load() {
		bridgedNetwork = ((try? CakedKeyConfig.bridgedNetwork.get()) ?? nil) ?? Self.noneNetwork
		primaryName = ((try? CakedKeyConfig.primaryName.get()) ?? nil) ?? String.empty
		passphrase = ((try? CakedKeyConfig.passphrase.get()) ?? nil) ?? String.empty
	}

	private func save(_ key: CakedKeyConfig, _ value: String?) {
		do {
			try key.set(value)
		} catch {
			errorMessage = error.localizedDescription
		}
	}
}

#Preview {
	AdvancedSettingsView()
}
