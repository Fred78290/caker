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

	public init() {}

	public var body: some View {
		VStack(spacing: 0) {
			headerSection
			mainInfoSection
			componentsSection
			creditsSection
		}
		.frame(width: 520, height: 680)
		.shadow(radius: 10)
	}

	private var headerSection: some View {
		VStack(spacing: 16) {
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
								.foregroundStyle(.white)
						)
						.shadow(radius: 8)
				}
			}

			VStack(spacing: 4) {
				Text("Caker")
					.font(.system(size: 28, weight: .bold, design: .rounded))
					.foregroundStyle(.primary)

				Text("Version \(appVersion)")
					.font(.system(size: 14, weight: .medium))
					.foregroundStyle(.secondary)
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
					.foregroundStyle(.primary)

				Text("Caker is a powerful toolchain for creating and managing virtual machines with Apple's Virtualization framework, focused on simplicity and developer experience.")
					.lineLimit(nil)
					.layoutPriority(1)
					.font(.body)
					.fixedSize(horizontal: false, vertical: true)
					.foregroundStyle(.secondary)
					.multilineTextAlignment(.center)
					.lineSpacing(2)
			}

			VStack(alignment: .leading, spacing: 8) {
				FeatureRow(icon: "network", text: String(localized: "Dynamic TCP/Unix port forwarding"))
				FeatureRow(icon: "globe", text: String(localized: "Bridge, hosted, or NAT mode networks"))
				FeatureRow(icon: "cloud", text: String(localized: "Cloud-Init support for initialization"))
				FeatureRow(icon: "gear", text: String(localized: "Automatic integrated agent"))
				FeatureRow(icon: "terminal", text: String(localized: "Integrated VNC and terminal interfaces"))
				FeatureRow(icon: "bonjour", text: String(localized: "Remote control via CLI and API via GUI and Web"))
			}
			.padding()
		}
		.padding(.horizontal, 24)
	}

	private var componentsSection: some View {
		VStack(spacing: 12) {
			Divider()
				.padding(.horizontal)

			VStack(spacing: 8) {
				Text("Components")
					.font(.headline)
					.foregroundStyle(.primary)

				VStack(alignment: .leading, spacing: 4) {
					ComponentRow(name: String(localized: "caked"), description: String(localized: "VM management daemon"))
					ComponentRow(name: String(localized: "cakectl"), description: String(localized: "Command line interface"))
					ComponentRow(name: String(localized: "Caker.app"), description: String(localized: "macOS GUI application"))
				}
				.padding(.horizontal)
			}
		}
	}

	private var creditsSection: some View {
		VStack(spacing: 12) {
			Divider()
				.padding(.horizontal)

			VStack(spacing: 8) {
				Text("Developed by")
					.font(.headline)
					.foregroundStyle(.primary)

				Text("Fred78290 / Aldune Labs")
					.font(.body)
					.foregroundStyle(Color.accentColor)

				HStack(spacing: 12) {
					Button(action: showLicenseInfo) {
						Label("Licenses", systemImage: "book")
							.font(.caption)
					}
					.buttonStyle(.bordered)

					Button(action: openWebsite) {
						Label("Documentation", systemImage: "safari")
							.font(.caption)
					}
					.buttonStyle(.bordered)

					Button(action: openGitHub) {
						Label("Source Code", systemImage: "curlybraces")
							.font(.caption)
					}
					.buttonStyle(.bordered)

					Button(action: reportIssue) {
						Label("Report Issue", systemImage: "ladybug")
							.font(.caption)
					}
					.buttonStyle(.bordered)
				}
			}
		}
		.padding([.top, .bottom], 16)
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
				.foregroundStyle(Color.accentColor)
				.frame(width: 16)
			Text(text)
				.font(.caption)
				.foregroundStyle(.secondary)
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
				.foregroundStyle(Color.accentColor)
			Text(name)
				.font(.caption)
				.fontWeight(.medium)
				.foregroundStyle(.primary)
			Text("—")
				.foregroundStyle(.secondary)
			Text(description)
				.font(.caption)
				.foregroundStyle(.secondary)
			Spacer()
		}
	}
}

#Preview {
	AboutCakerView()
}
