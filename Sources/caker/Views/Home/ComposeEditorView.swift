//
//  ComposeEditorView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 27/09/2026.
//

import CakedLib
import GRPCLib
import SwiftUI
import Yams

/// Raw-YAML editor for a `compose.yml`-shaped `ComposeFile` — the "Compose Editor" part of this
/// feature. `ComposeFile`'s real shape is polymorphic enough (`ComposeDepends`/`ComposeEnvironment`/
/// `ComposePort`/`ComposeVolume`, nested `ComposeNetwork`/`ComposeDeploy`) that a fully structured
/// form for every field is out of proportion for a first pass — this is a `TextEditor` seeded from
/// `ComposeFile.template` (new project) or a best-effort reconstruction of an existing project's
/// known services (edit), with a live "parses OK"/"parse error: …" indicator (debounced ~300ms) and
/// a small "Add service" quick-add sheet that inserts a formatted YAML block rather than replacing
/// hand-editing entirely.
///
/// Saving always calls `ComposeHandler.up(...)` — there's no separate "register without starting"
/// RPC, and `compose up` is itself idempotent/incremental (already-installed services are just
/// (re)started, only new/changed ones are built), so this is also the correct way to apply an edit
/// to an already-registered project, not just to create a new one.
struct ComposeEditorView: View {
	@Environment(\.dismiss) private var dismiss

	let client: CakedServiceClient?
	let runMode: Utils.RunMode
	let existingProject: ComposeReplyList.ComposeInfo?
	var onSaved: (() -> Void)? = nil

	@State private var text: String
	@State private var parseError: String? = nil
	@State private var isSaving: Bool = false
	@State private var showQuickAdd: Bool = false
	@State private var validationTask: Task<Void, Never>? = nil

	init(client: CakedServiceClient?, runMode: Utils.RunMode, existingProject: ComposeReplyList.ComposeInfo? = nil, onSaved: (() -> Void)? = nil) {
		self.client = client
		self.runMode = runMode
		self.existingProject = existingProject
		self.onSaved = onSaved
		self._text = State(initialValue: Self.seedText(for: existingProject))
	}

	private var isNewProject: Bool { self.existingProject == nil }

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			self.header

			Divider()

			self.editor

			Divider()

			self.footer
		}
		.frame(minWidth: 640, minHeight: 560)
		.onAppear {
			self.validate()
		}
		.sheet(isPresented: self.$showQuickAdd) {
			ComposeQuickAddServiceView { name, image, ports in
				self.insertQuickAddService(name: name, image: image, ports: ports)
			}
		}
	}

	private var header: some View {
		HStack(alignment: .top) {
			VStack(alignment: .leading, spacing: 2) {
				Text(self.isNewProject ? "New compose project" : "Edit compose project")
					.font(.system(size: 15, weight: .semibold))

				if let existingProject {
					Text(existingProject.name)
						.font(.system(size: 11, design: .monospaced))
						.foregroundStyle(.secondary)
				}
			}

			Spacer()

			Button {
				self.showQuickAdd = true
			} label: {
				Label("Add service", systemImage: "plus")
			}
			.withButtonStyle(.bordered)
		}
		.padding(16)
	}

	private var editor: some View {
		VStack(alignment: .leading, spacing: 8) {
			TextEditor(text: self.$text)
				.font(.system(size: 12, design: .monospaced))
				.scrollContentBackground(.hidden)
				.padding(6)
				.background(RoundedRectangle(cornerRadius: 6).fill(Color(NSColor.textBackgroundColor)))
				.overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))
				.onChange(of: self.text) {
					self.scheduleValidation()
				}

			self.statusLine
		}
		.padding(16)
		.frame(maxHeight: .infinity)
	}

	@ViewBuilder
	private var statusLine: some View {
		HStack(spacing: 6) {
			if let parseError {
				Image(systemName: "exclamationmark.triangle.fill")
					.foregroundStyle(.red)
				Text(String(format: String(localized: "Parse error: %@"), parseError))
					.font(.system(size: 11))
					.foregroundStyle(.red)
					.lineLimit(2)
			} else {
				Image(systemName: "checkmark.circle.fill")
					.foregroundStyle(.green)
				Text("Parses OK")
					.font(.system(size: 11))
					.foregroundStyle(.secondary)
			}
		}
	}

	private var footer: some View {
		HStack(alignment: .center) {
			Text("Ports, volumes, environment, networks and depends_on aren't tracked once a project is running — re-add them here if this project needs them.")
				.font(.system(size: 10))
				.foregroundStyle(.secondary)
				.lineLimit(2)
				.fixedSize(horizontal: false, vertical: true)

			Spacer()

			Button("Cancel") {
				self.dismiss()
			}
			.withButtonStyle(.bordered)

			Button {
				self.save()
			} label: {
				if self.isSaving {
					ProgressView()
						.controlSize(.small)
						.frame(width: 70)
				} else {
					Text("Save & Start")
				}
			}
			.withButtonStyle(.borderedProminent)
			.disabled(self.parseError != nil || self.isSaving)
		}
		.padding(16)
	}

	private func scheduleValidation() {
		self.validationTask?.cancel()
		self.validationTask = Task {
			try? await Task.sleep(for: .milliseconds(300))

			guard Task.isCancelled == false else {
				return
			}

			await MainActor.run {
				self.validate()
			}
		}
	}

	private func validate() {
		do {
			let compose = try YAMLDecoder().decode(ComposeFile.self, from: self.text)

			if compose.name.trimmingCharacters(in: .whitespaces).isEmpty {
				self.parseError = String(localized: "A project needs a non-empty 'name'.")
			} else {
				self.parseError = nil
			}
		} catch {
			self.parseError = error.localizedDescription
		}
	}

	private func save() {
		self.validate()

		guard self.parseError == nil, let compose = try? YAMLDecoder().decode(ComposeFile.self, from: self.text) else {
			return
		}

		self.isSaving = true

		Task {
			do {
				let reply = try await ComposeHandler.up(client: self.client, compose: compose, runMode: self.runMode)

				await MainActor.run {
					self.isSaving = false

					if reply.success {
						self.onSaved?()
						self.dismiss()
					} else {
						alertError(String(localized: "Failed to start compose project"), reply.reason)
					}
				}
			} catch {
				await MainActor.run {
					self.isSaving = false
					alertError(error)
				}
			}
		}
	}

	/// Inserts a formatted `services:` YAML block for a quick-added service right after the
	/// `services:` key, rather than requiring the operator to hand-place it correctly.
	private func insertQuickAddService(name: String, image: String, ports: [String]) {
		guard name.isEmpty == false else {
			return
		}

		var block = "  \(name):\n    image: \(image.isEmpty ? "ubuntu:24.04" : image)\n"

		if ports.isEmpty == false {
			block += "    ports:\n"

			for port in ports {
				block += "      - \"\(port)\"\n"
			}
		}

		if let range = self.text.range(of: "services:"), let lineEnd = self.text[range.upperBound...].firstIndex(of: "\n") {
			self.text.insert(contentsOf: "\n" + block, at: self.text.index(after: lineEnd))
		} else if self.text.range(of: "services:") != nil {
			self.text += "\n" + block
		} else {
			self.text += "\nservices:\n" + block
		}

		self.scheduleValidation()
	}

	/// New project → `ComposeFile.template`. Editing a registered project → a best-effort
	/// reconstruction from the names/images the registry still knows about (see the type doc above
	/// for why the rest of the definition can't be recovered).
	static func seedText(for project: ComposeReplyList.ComposeInfo?) -> String {
		guard let project else {
			return ComposeFile.template
		}

		guard let yaml = try? YAMLEncoder().encode(project.reconstructedComposeFile()) else {
			return ComposeFile.template
		}

		return """
			# Reconstructed from "\(project.name)"'s currently registered services.
			# Only each service's image is known once a project is running — ports, volumes,
			# environment, networks and depends_on aren't tracked by the registry, so re-add
			# them here if this project needs them. Saving re-runs `compose up`.
			\(yaml)
			"""
	}
}

/// Lightweight "quick add service" affordance — inserts a formatted YAML block into the editor
/// rather than attempting a fully structured per-field form (out of proportion for `ComposeService`'s
/// real complexity, see `ComposeEditorView`'s own doc comment).
private struct ComposeQuickAddServiceView: View {
	@Environment(\.dismiss) private var dismiss

	@State private var name: String = ""
	@State private var image: String = "ubuntu:24.04"
	@State private var portsText: String = ""

	let onAdd: (_ name: String, _ image: String, _ ports: [String]) -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Add service")
				.font(.system(size: 14, weight: .semibold))

			LabeledContent("Name") {
				TextField("web", text: self.$name)
					.withTextFieldStyle(.roundedBorder)
			}

			LabeledContent("Image") {
				TextField("ubuntu:24.04", text: self.$image)
					.withTextFieldStyle(.roundedBorder)
			}

			LabeledContent("Ports") {
				TextField("8080:80, 2222:22", text: self.$portsText)
					.withTextFieldStyle(.roundedBorder)
			}

			Text("Comma-separated host:container[/proto] pairs.")
				.font(.system(size: 10))
				.foregroundStyle(.secondary)

			HStack {
				Spacer()

				Button("Cancel") {
					self.dismiss()
				}
				.withButtonStyle(.bordered)

				Button("Add") {
					let ports =
						self.portsText
						.split(separator: ",")
						.map { $0.trimmingCharacters(in: .whitespaces) }
						.filter { $0.isEmpty == false }

					self.onAdd(self.name.trimmingCharacters(in: .whitespaces), self.image.trimmingCharacters(in: .whitespaces), ports)
					self.dismiss()
				}
				.withButtonStyle(.borderedProminent)
				.disabled(self.name.trimmingCharacters(in: .whitespaces).isEmpty)
			}
		}
		.padding(20)
		.frame(width: 380)
	}
}

#Preview {
	ComposeEditorView(client: nil, runMode: .app)
}
