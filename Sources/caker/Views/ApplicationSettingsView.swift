//
//  ApplicationSettingsView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 11/07/2025.
//

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
	@AppStorage("ShowMenuIcon") var isMenuIconShown = false
	@AppStorage("AppearancePreference") var appearancePreference: AppearancePreference = .system

	var body: some View {
		Form {
			Section {
				HStack(spacing: 20) {
					Spacer()
					ForEach(AppearancePreference.allCases, id: \.self) { pref in
						AppearanceTile(pref: pref, isSelected: appearancePreference == pref) {
							appearancePreference = pref
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
				Button(action: { MainUIAppDelegate.ensurePrivilegedBootstrapFiles() }) {
					Label("Install command-line tools", systemImage: "terminal")
				}
				.disabled(MainUIAppDelegate.isPrivilegedBootstrapFilesInstalled)
			} header: {
				Label("Developer Tools", systemImage: "wrench.and.screwdriver")
			} footer: {
				Text("Makes caked and cakectl available from Terminal.")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
		}
		.formStyle(.grouped)
		.scrollDisabled(true)
		.fixedSize(horizontal: false, vertical: true)
	}
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
		.buttonStyle(.plain)
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
