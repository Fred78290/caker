//
//  AboutCakerView.swift
//  Caker
//
//  Created by GitHub Copilot on 02/05/2026.
//

import CakedLib
import SwiftUI

public struct AboutCakerView: View {
	@Environment(\.dismiss) private var dismiss

	private let appVersion = CI.version
	private let appBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"

	public init() {}

	public var body: some View {
		VStack(spacing: 0) {
			// Header avec icône et nom
			headerSection

			// Section principale avec description
			mainInfoSection

			// Section des composants
			componentsSection

			// Section des crédits et liens
			creditsSection
		}
		.frame(width: 520, height: 660)
		.background(Color(NSColor.windowBackgroundColor))
		//.cornerRadius(12)
		.shadow(radius: 10)
	}

	private var headerSection: some View {
		VStack(spacing: 16) {
			// Icône de l'application
			VStack {
				if let appIcon = NSApplication.shared.applicationIconImage {
					Image(nsImage: appIcon)
						.resizable()
						.aspectRatio(contentMode: .fit)
						.frame(width: 96, height: 96)
						.shadow(radius: 8)
				} else {
					RoundedRectangle(cornerRadius: 16)
						.fill(
							LinearGradient(
								colors: [.blue, .purple],
								startPoint: .topLeading,
								endPoint: .bottomTrailing
							)
						)
						.frame(width: 96, height: 96)
						.overlay(
							Image(systemName: "cloud.bolt")
								.font(.system(size: 40, weight: .medium))
								.foregroundColor(.white)
						)
						.shadow(radius: 8)
				}
			}

			// Nom et version
			VStack(spacing: 4) {
				Text("Caker")
					.font(.system(size: 28, weight: .bold, design: .rounded))
					.foregroundColor(.primary)

				Text("Version \(appVersion)")
					.font(.system(size: 14, weight: .medium))
					.foregroundColor(.secondary)
			}
		}
		.padding(.top, 32)
		.padding(.bottom, 24)
	}

	private var mainInfoSection: some View {
		VStack(spacing: 16) {
			VStack(spacing: 12) {
				Text("Virtual Machine Manager")
					.font(.headline)
					.foregroundColor(.primary)

				Text("Caker is a powerful Swift-based tool for creating and managing virtual machines with Apple's Virtualization framework, focused on simplicity and developer experience.")
					.lineLimit(nil)
					.layoutPriority(1)
					.font(.body)
					.fixedSize(horizontal: false, vertical: true)
					.foregroundColor(.secondary)
					.multilineTextAlignment(.center)
					.lineSpacing(2)
			}

			// Fonctionnalités principales
			VStack(alignment: .leading, spacing: 8) {
				FeatureRow(icon: "network", text: String(localized: "Dynamic TCP/Unix port forwarding"))
				FeatureRow(icon: "globe", text: String(localized: "Bridge, hosted, or NAT mode networks"))
				FeatureRow(icon: "cloud", text: String(localized: "Cloud-Init support for initialization"))
				FeatureRow(icon: "gear", text: String(localized: "Automatic integrated agent"))
				FeatureRow(icon: "terminal", text: String(localized: "Integrated VNC and terminal interfaces"))
			}
			.padding()
		}
		.padding(.horizontal, 24)
	}

	private var creditsSection: some View {
		VStack(spacing: 12) {
			Divider()
				.padding(.horizontal)

			VStack(spacing: 8) {
				Text("Developed by")
					.font(.headline)
					.foregroundColor(.primary)

				Text("Fred78290 / Aldune Labs")
					.font(.body)
					.foregroundColor(.blue)

				HStack(spacing: 16) {
					Button(action: showLicenseInfo) {
						HStack(spacing: 4) {
							Image(systemName: "book")
							Text("Licenses")
						}
						.font(.caption)
					}
					.buttonStyle(.bordered)

					Button(action: openWebsite) {
						HStack(spacing: 4) {
							Image(systemName: "safari")
							Text("Documentation")
						}
						.font(.caption)
					}
					.buttonStyle(.bordered)

					Button(action: openGitHub) {
						HStack(spacing: 4) {
							Image(systemName: "curlybraces")
							Text("Source Code")
						}
						.font(.caption)
					}
					.buttonStyle(.bordered)

					Button(action: reportIssue) {
						HStack(spacing: 4) {
							Image(systemName: "ladybug")
							Text("Report Issue")
						}
						.font(.caption)
					}
					.buttonStyle(.bordered)
				}
			}
		}
		.padding([.top, .bottom], 16)
	}

	private var componentsSection: some View {
		VStack(spacing: 12) {
			Divider()
				.padding(.horizontal)

			VStack(spacing: 8) {
				Text("Components")
					.font(.headline)
					.foregroundColor(.primary)

				VStack(alignment: .leading, spacing: 4) {
					ComponentRow(name: String(localized: "caked"), description: String(localized: "VM management daemon"))
					ComponentRow(name: String(localized: "cakectl"), description: String(localized: "Command line interface"))
					ComponentRow(name: String(localized: "Caker.app"), description: String(localized: "macOS GUI application"))
				}
				.padding(.horizontal)
			}
		}
	}

	private func openWebsite() {
		if let url = URL(string: "https://caker.aldunelabs.com") {
			NSWorkspace.shared.open(url)
		}
	}

	private func reportIssue() {
		if let url = URL(string: "https://github.com/Fred78290/caker/issues") {
			NSWorkspace.shared.open(url)
		}
	}

	private func openGitHub() {
		if let url = URL(string: "https://github.com/Fred78290/caker") {
			NSWorkspace.shared.open(url)
		}
	}

	private func showLicenseInfo() {
		let alert = NSAlert()
		alert.messageText = NSLocalizedString(
			"Caker License",
			comment: "Title of the license information alert in the About window"
		)
		alert.informativeText = NSLocalizedString(
			"""
			Caker is free software distributed under the GNU Affero General Public License version 3 (AGPL v3).

			Copyright © 2026 Caker Project

			This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY. See the full license for more details.
			""",
			comment: "Body text of the license information alert in the About window"
		)
		alert.addButton(
			withTitle: NSLocalizedString(
				"OK",
				comment: "Default confirmation button title for the license information alert"
			)
		)
		alert.addButton(
			withTitle: NSLocalizedString(
				"View full license",
				comment: "Button title for opening the full AGPL license from the About window alert"
			)
		)

		let response = alert.runModal()

		if response == .alertSecondButtonReturn {
			if let url = URL(string: "https://www.gnu.org/licenses/agpl-3.0.html") {
				NSWorkspace.shared.open(url)
			}
		}
	}
}

private struct FeatureRow: View {
	let icon: String
	let text: String

	var body: some View {
		HStack(spacing: 8) {
			Image(systemName: icon)
				.foregroundColor(.blue)
				.frame(width: 16)
			Text(text)
				.font(.caption)
				.foregroundColor(.secondary)
			Spacer()
		}
	}
}

private struct ComponentRow: View {
	let name: String
	let description: String

	var body: some View {
		HStack {
			Text("•")
				.foregroundColor(.blue)
			Text(name)
				.font(.caption)
				.fontWeight(.medium)
				.foregroundColor(.primary)
			Text("—")
				.foregroundColor(.secondary)
			Text(description)
				.font(.caption)
				.foregroundColor(.secondary)
			Spacer()
		}
	}
}

#Preview {
	AboutCakerView()
}
