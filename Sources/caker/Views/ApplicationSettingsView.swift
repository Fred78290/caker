//
//  ApplicationSettingsView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 11/07/2025.
//

import CakedLib
import ServiceManagement
import SwiftUI

extension Binding where Value == Bool {
	var inverted: Binding<Bool> {
		Binding {
			!wrappedValue
		} set: { newValue in
			wrappedValue = !newValue
		}
	}
}

struct ApplicationSettingsView: View {
	@AppStorage("HideDockIcon") var isDockIconHidden = false
	@AppStorage("ShowMenuIcon") var isMenuIconShown = true

	@State private var state: AppState = AppState.shared
	@State private var loginItemStatus: SMAppService.Status = SMAppService.mainApp.status

	#if USE_AUTHORIZATION_HELPER
		@State private var helperStatus: SMAppService.Status = DirectAuthorizationHelperConnector.daemonStatus
	#endif
	
	var body: some View {
		Form {
			Section {
				HStack(spacing: 20) {
					Spacer()
					ForEach(AppearancePreference.allCases, id: \.self) { pref in
						AppearanceTile(pref: pref, isSelected: state.appearancePreference == pref) {
							if pref == .system {
								state.appearancePreference = NSApplication.shared.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
								DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
									state.appearancePreference = .system
								}
							} else {
								state.appearancePreference = pref
							}
						}
					}
					Spacer()
				}
				.padding(.vertical, 8)
			} header: {
				Label("Appearance", systemImage: "paintbrush")
			}

			Section {
				Toggle(isOn: $isDockIconHidden.inverted) {
					Label("Show dock icon", systemImage: "dock.rectangle")
				}
				.onChange(of: isDockIconHidden) { _, newValue in
					if newValue { isMenuIconShown = true }
				}

				Toggle(isOn: $isMenuIconShown) {
					Label("Show menu bar icon", systemImage: "menubar.rectangle")
				}
				.disabled(isDockIconHidden)
			} header: {
				Label("Dock & Menu Bar", systemImage: "dock.rectangle")
			}

			Section {
				Toggle(isOn: self.openAtLogin) {
					Label("Open Caker at login", systemImage: "power")
				}

				if self.loginItemStatus == .requiresApproval {
					HStack {
						Text("Approval required in System Settings > General > Login Items & Extensions.")
							.font(.caption)
							.foregroundStyle(.secondary)
						Spacer()
						Button("Open Login Items") {
							SMAppService.openSystemSettingsLoginItems()
						}
					}
				}
			} header: {
				Label("Startup", systemImage: "power")
			}

			Section {
				HStack {
					Spacer()
					Button(action: { MainUIAppDelegate.ensurePrivilegedBootstrapFiles() }) {
						Label("Install command-line tools", systemImage: "terminal")
					}
					.disabled(MainUIAppDelegate.isPrivilegedBootstrapFilesInstalled)
					Spacer()
				}
			} header: {
				Label("Developer Tools", systemImage: "wrench.and.screwdriver")
			} footer: {
				Text("Makes caked and cakectl available from Terminal.")
					.font(.caption)
					.foregroundStyle(.secondary)
			}

			#if USE_AUTHORIZATION_HELPER
				if Bundle.isApplicationSandboxed == false {
					Section {
						Toggle(isOn: self.helperRegistered) {
							Label("Register the privileged helper", systemImage: "lock.shield")
						}

						if self.helperStatus == .requiresApproval {
							HStack {
								Text("Approval required in System Settings > General > Login Items & Extensions.")
									.font(.caption)
									.foregroundStyle(.secondary)
								Spacer()
								Button("Open Login Items") {
									SMAppService.openSystemSettingsLoginItems()
								}
							}
						}
					} header: {
						Label("Authorization helper registration", systemImage: "lock.shield")
					} footer: {
						Text("Lets Caker run privileged operations, such as vmnet networks, without asking for sudo.")
							.font(.caption)
							.foregroundStyle(.secondary)
					}
				}
			#endif
		}
		.formStyle(.grouped)
		.scrollDisabled(true)
		.fixedSize(horizontal: false, vertical: true)
		.onAppear {
			self.refreshStatuses()
		}
		.onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
			// The user may have approved the item in System Settings.
			self.refreshStatuses()
		}
	}

	private func refreshStatuses() {
		self.loginItemStatus = SMAppService.mainApp.status

		#if USE_AUTHORIZATION_HELPER
			self.helperStatus = DirectAuthorizationHelperConnector.daemonStatus
		#endif
	}

	private func showError(_ message: String, _ error: Error) {
		let alert = NSGlassEffectAlert()

		alert.messageText = message
		alert.informativeText = error.localizedDescription
		alert.alertStyle = .warning
		alert.addButton(withTitle: String(localized: "OK"))
		alert.runModal()
	}

	/// On while Caker is a login item, including when it still waits for the user's approval.
	private var openAtLogin: Binding<Bool> {
		Binding {
			self.loginItemStatus == .enabled || self.loginItemStatus == .requiresApproval
		} set: { newValue in
			let service = SMAppService.mainApp

			do {
				if newValue {
					try service.register()
				} else {
					try service.unregister()
				}
			} catch {
				self.showError(String(localized: "Unable to change the login item"), error)
			}

			self.loginItemStatus = service.status
		}
	}

	#if USE_AUTHORIZATION_HELPER
		/// On while the daemon is registered, including when it still waits for the user's approval.
		private var helperRegistered: Binding<Bool> {
			Binding {
				self.helperStatus == .enabled || self.helperStatus == .requiresApproval
			} set: { newValue in
				do {
					if newValue {
						try DirectAuthorizationHelperConnector.registerDaemon()
						UserDefaults.standard.removeObject(forKey: DirectAuthorizationHelperConnector.disabledByUserKey)
					} else {
						// Remember the choice only once the daemon is really unregistered.
						try DirectAuthorizationHelperConnector.unregisterDaemon()
						UserDefaults.standard.set(true, forKey: DirectAuthorizationHelperConnector.disabledByUserKey)
					}
				} catch {
					self.showError(String(localized: "Unable to change the privileged helper registration"), error)
				}

				self.helperStatus = DirectAuthorizationHelperConnector.daemonStatus
			}
		}
	#endif
}

private struct AppearanceTile: View {
	let pref: AppearancePreference
	let isSelected: Bool
	let onTap: () -> Void

	var body: some View {
		Button(action: onTap) {
			VStack(spacing: 6) {
				ZStack {
					RoundedRectangle(cornerRadius: 10)
						.fill(thumbnailBackground)
						.frame(width: 80, height: 54)

					Image(systemName: pref.systemImage)
						.font(.system(size: 22, weight: .medium))
						.foregroundStyle(thumbnailForeground)
				}
				.overlay(
					RoundedRectangle(cornerRadius: 10)
						.strokeBorder(
							isSelected ? Color.accentColor : Color.secondary.opacity(0.25),
							lineWidth: isSelected ? 2.5 : 1
						)
				)
				.shadow(color: .black.opacity(0.12), radius: 3, y: 1)

				Text(pref.title)
					.font(.system(size: 11, weight: isSelected ? .semibold : .regular))
					.foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
			}
		}
		.withButtonStyle(.plain)
	}

	private var thumbnailBackground: Color {
		switch pref {
		case .system: return Color(NSColor.windowBackgroundColor)
		case .light: return Color(white: 0.93)
		case .dark: return Color(white: 0.14)
		}
	}

	private var thumbnailForeground: Color {
		switch pref {
		case .system: return .primary
		case .light: return Color(white: 0.25)
		case .dark: return Color(white: 0.85)
		}
	}
}

#Preview {
	ApplicationSettingsView()
}
