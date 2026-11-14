//
//  ComposeLibraryView.swift
//  Caker
//

import CakedLib
import SwiftUI

/// The compose template library (`CakedLib.ComposeLibrary`): browse ready-to-use `compose.yml`
/// templates, read one, then either open it in the Compose Editor (`onUse`) or save it as a file.
/// "Sync" updates the library from the GitHub repository; until the templates are published there
/// the copy bundled with the app is used and the sync says so.
struct ComposeLibraryView: View {
	@Environment(\.dismissGlassedSheet) private var dismiss

	/// Called, after the sheet is dismissed, with the template the user wants to edit and start.
	let onUse: (ComposeLibraryTemplate) -> Void

	@State private var library: ComposeLibrary = ComposeLibrary.reloadIfChanged()
	@State private var search: String = ""
	@State private var category: String = ""
	@State private var selection: ComposeLibraryTemplate.ID? = nil
	@State private var isSyncing: Bool = false
	@State private var syncMessage: String? = nil
	@State private var syncFailed: Bool = false

	private var templates: [ComposeLibraryTemplate] {
		self.library.search(self.search, category: self.category)
	}

	private var selectedTemplate: ComposeLibraryTemplate? {
		guard let selection else {
			return nil
		}

		return self.templates.first { $0.id == selection }
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			self.header

			Divider()

			HStack(spacing: 0) {
				self.list
					.frame(width: 300)

				Divider()

				self.preview
			}

			Divider()

			self.footer
		}
		.frame(minWidth: 820, idealWidth: 900, minHeight: 520, idealHeight: 620)
		.onChange(of: self.search) {
			self.keepSelectionVisible()
		}
		.onChange(of: self.category) {
			self.keepSelectionVisible()
		}
		.onAppear {
			self.selection = self.selection ?? self.templates.first?.id
		}
	}

	// MARK: Header

	private var header: some View {
		VStack(alignment: .leading, spacing: 10) {
			HStack(alignment: .top) {
				VStack(alignment: .leading, spacing: 2) {
					Text("Compose template library")
						.font(.system(size: 15, weight: .semibold))

					Text(self.sourceDescription)
						.font(.system(size: 11))
						.foregroundStyle(.secondary)
				}

				Spacer()

				Button {
					self.sync()
				} label: {
					if self.isSyncing {
						ProgressView()
							.controlSize(.small)
					} else {
						Label("Sync", systemImage: "arrow.triangle.2.circlepath")
					}
				}
				.withButtonStyle(.bordered)
				.disabled(self.isSyncing)
				.help("Update the library from the GitHub repository")
			}

			HStack {
				TextField("Search", text: self.$search)
					.withTextFieldStyle(.roundedBorder)

				Picker("Category", selection: self.$category) {
					Text("All categories").tag("")

					ForEach(self.library.categories, id: \.self) { category in
						Text(category).tag(category)
					}
				}
				.labelsHidden()
				.frame(width: 180)
			}

			if let syncMessage {
				HStack(spacing: 6) {
					Image(systemName: self.syncFailed ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
						.foregroundStyle(self.syncFailed ? Color.orange : Color.green)

					Text(syncMessage)
						.font(.system(size: 11))
						.foregroundStyle(.secondary)
						.lineLimit(2)
				}
			}
		}
		.padding(16)
	}

	private var sourceDescription: String {
		if let date = ComposeLibrary.syncedDate {
			return String(format: String(localized: "Synced from GitHub on %@"), date.formatted(date: .abbreviated, time: .shortened))
		}

		return String(localized: "Bundled with Caker")
	}

	// MARK: List

	@ViewBuilder
	private var list: some View {
		if self.templates.isEmpty {
			ContentUnavailableView("No template matches", systemImage: "magnifyingglass")
		} else {
			List(self.templates, selection: self.$selection) { template in
				VStack(alignment: .leading, spacing: 3) {
					HStack {
						Text(template.name)
							.font(.system(size: 13, weight: .medium))

						Spacer()

						Text(template.category)
							.font(.system(size: 10))
							.padding(.horizontal, 6)
							.padding(.vertical, 1)
							.background(Capsule().fill(Color.secondary.opacity(0.15)))
					}

					Text(template.summary)
						.font(.system(size: 11))
						.foregroundStyle(.secondary)
						.lineLimit(2)
				}
				.padding(.vertical, 3)
				.tag(template.id)
			}
			.listStyle(.inset(alternatesRowBackgrounds: true))
		}
	}

	// MARK: Preview

	@ViewBuilder
	private var preview: some View {
		if let template = self.selectedTemplate {
			VStack(alignment: .leading, spacing: 8) {
				VStack(alignment: .leading, spacing: 2) {
					Text(template.name)
						.font(.system(size: 14, weight: .semibold))

					Text(String(format: String(localized: "Services: %@"), template.serviceNames.joined(separator: ", ")))
						.font(.system(size: 11, design: .monospaced))
						.foregroundStyle(.secondary)
				}

				ScrollView([.vertical, .horizontal]) {
					Text((try? template.composeText(projectName: nil)) ?? template.compose)
						.font(.system(size: 11, design: .monospaced))
						.textSelection(.enabled)
						.frame(maxWidth: .infinity, alignment: .leading)
						.padding(8)
				}
				.background(RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.textBackgroundColor)))
				.overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))
			}
			.padding(16)
			.frame(maxWidth: .infinity, maxHeight: .infinity)
		} else {
			ContentUnavailableView("Select a template", systemImage: "square.stack.3d.up")
				.frame(maxWidth: .infinity, maxHeight: .infinity)
		}
	}

	// MARK: Footer

	private var footer: some View {
		HStack {
			Text("Read a template before starting it: it installs packages and runs commands in the new VMs.")
				.font(.system(size: 10))
				.foregroundStyle(.secondary)
				.lineLimit(2)
				.fixedSize(horizontal: false, vertical: true)

			Spacer()

			Button("Close") {
				self.dismiss()
			}
			.withButtonStyle(.bordered)

			Button("Save as…") {
				if let template = self.selectedTemplate {
					self.save(template)
				}
			}
			.withButtonStyle(.bordered)
			.disabled(self.selectedTemplate == nil)

			Button("Use template") {
				if let template = self.selectedTemplate {
					self.dismiss()
					DispatchQueue.main.async {
						self.onUse(template)
					}
				}
			}
			.withButtonStyle(.borderedProminent)
			.disabled(self.selectedTemplate == nil)
		}
		.padding(16)
	}

	// MARK: Actions

	private func keepSelectionVisible() {
		if let selection, self.templates.contains(where: { $0.id == selection }) {
			return
		}

		self.selection = self.templates.first?.id
	}

	private func sync() {
		self.isSyncing = true
		self.syncMessage = nil

		Task {
			do {
				let result = try await ComposeLibrary.refreshFromGitHub()
				
				await MainActor.run {
					self.library = ComposeLibrary.reloadIfChanged()
					self.syncFailed = false
					self.syncMessage = result.changed ? String(format: String(localized: "Library updated: %d templates (%d added, %d updated, %d removed)"), result.templates, result.added.count, result.updated.count, result.removed.count) : String(localized: "The library is up to date")
					self.keepSelectionVisible()
					self.isSyncing = false
				}
			} catch {
				await MainActor.run {
					self.syncFailed = true
					self.syncMessage = error.reason
					self.isSyncing = false
				}
			}
		}
	}

	private func save(_ template: ComposeLibraryTemplate) {
		let panel = NSSavePanel()

		panel.nameFieldStringValue = ComposeFile.filename
		panel.canCreateDirectories = true
		panel.title = String(format: String(localized: "Save %@ as a compose file"), template.name)

		guard panel.runModal() == .OK, let url = panel.url else {
			return
		}

		do {
			// The panel already asked before replacing an existing file.
			try ComposeLibrary.clone(template, to: url, force: true)
		} catch {
			alertError(error)
		}
	}
}
