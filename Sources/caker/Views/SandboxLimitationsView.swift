//
//  SandboxLimitationsView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 20/07/2026.
//

import CakedLib
import SwiftUI

public struct SandboxLimitationsView: View {
	@Environment(\.dismiss) private var dismiss
	@AppStorage("HasSeenSandboxSplash") private var hasSeenSandboxSplash: Bool = false

	public init() {}

	public var body: some View {
		VStack(spacing: 0) {
			headerSection
			bodySection
			footerSection
		}
		.frame(width: 520, height: 620)
		.shadow(radius: 10)
		.onAppear {
			hasSeenSandboxSplash = true
		}
	}

	private var headerSection: some View {
		VStack(spacing: 12) {
			Image(systemName: "shield.lefthalf.filled")
				.font(.system(size: 40, weight: .medium))
				.foregroundStyle(Color.accentColor)
				.padding(.top, 32)

			Text("Running in the App Sandbox")
				.font(.system(size: 22, weight: .bold, design: .rounded))
				.foregroundStyle(.primary)
		}
		.padding(.bottom, 16)
	}

	private var bodySection: some View {
		VStack(spacing: 16) {
			Text("This App Store build of Caker runs inside the macOS App Sandbox, which restricts which files, sockets, and directories it may access. A few features are limited as a result:")
				.font(.body)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.leading)
				.fixedSize(horizontal: false, vertical: true)

			VStack(alignment: .leading, spacing: 10) {
				LimitationRow(icon: "folder.badge.questionmark", text: String(localized: "Shared directories (Virtio-FS mounts) and additional disks can only point at ~/Documents, ~/Download, ~/Public, or the app's own container"))
				LimitationRow(icon: "point.3.connected.trianglepath.dotted", text: String(localized: "Unix sockets you attach to a VM must resolve inside the app's own container"))
				LimitationRow(icon: "externaldrive.badge.exclamationmark", text: String(localized: "Resizing an ASIF disk and attaching physical block devices from the command line are unavailable"))
				LimitationRow(icon: "network.badge.shield.half.filled", text: String(localized: "Reaching IMDS at the AWS-style 169.254.169.254 address needs a redirect the sandbox blocks"))
			}
			.padding(.horizontal, 8)

			Text("Anything outside those locations is silently skipped rather than causing an error — the VM still starts, just without that mount, disk, or socket.")
				.font(.callout)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.leading)
				.fixedSize(horizontal: false, vertical: true)
		}
		.padding(.horizontal, 24)
	}

	private var footerSection: some View {
		VStack(spacing: 16) {
			Divider()
				.padding(.horizontal)

			Text("Need unrestricted file, socket, or block-device access? Install the direct-download build instead — see the About window for details.")
				.font(.callout)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
				.fixedSize(horizontal: false, vertical: true)
				.padding(.horizontal, 24)

			HStack(spacing: 12) {
				Button(action: openSandboxWiki) {
					Label("Learn more", systemImage: "safari")
				}
				.buttonStyle(.bordered)

				Button("Got it") {
					dismiss()
				}
				.buttonStyle(.borderedProminent)
				.keyboardShortcut(.defaultAction)
			}
		}
		.padding(.bottom, 24)
	}

	private func openSandboxWiki() {
		if let url = URL(string: "https://caker.aldunelabs.com/sandbox") {
			NSWorkspace.shared.open(url)
		}
	}
}

private struct LimitationRow: View {
	let icon: String
	let text: String

	var body: some View {
		HStack(alignment: .top, spacing: 8) {
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

#Preview {
	SandboxLimitationsView()
}
