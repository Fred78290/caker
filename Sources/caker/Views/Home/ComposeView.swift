//
//  ComposeView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 27/09/2026.
//

import CakedLib
import GRPCLib
import SwiftUI

/// Lists registered compose projects and lets the user add/start/stop/delete them — the `HomeView`
/// sidebar category for `caker`'s Compose subsystem (`Sources/cakedlib/ComposeFile.swift`/
/// `Sources/cakedlib/Handlers/ComposeHandler.swift`).
///
/// Modeled on `TasksView.swift` (there's no push-notification mechanism for compose state changes
/// any more than there is for tasks, so this polls on its own while visible) and PR #123's
/// `ImageCacheView.swift` (selection-driven inline row actions, `NSGlassEffectAlert` confirmation
/// for destructive actions, a `static confirmAndDelete` the toolbar's Delete button reuses).
struct ComposeView: View {
	private static let pollInterval: Duration = .seconds(3)

	@Bindable var navigationModel: NavigationModel

	@State private var projects: [ComposeReplyList.ComposeInfo] = []
	@State private var loadError: String? = nil
	@State private var editorTarget: EditorTarget? = nil
	/// Projects with a start/stop/delete in flight: their row buttons are disabled until it is done and the
	/// list has been reloaded, so a second action can't be started on top of the first.
	@State private var busyProjects: Set<String> = []

	enum EditorTarget: Identifiable {
		case new
		case edit(ComposeReplyList.ComposeInfo)

		var id: String {
			switch self {
			case .new: return "new"
			case .edit(let project): return project.name
			}
		}
	}

	var body: some View {
		GeometryReader { geom in
			if self.projects.isEmpty {
				VStack(alignment: .center) {
					if let loadError {
						ContentUnavailableView("Unable to load compose projects", systemImage: "exclamationmark.triangle", description: Text(loadError))
					} else {
						ContentUnavailableView("List empty", systemImage: "tray")
					}
				}.frame(width: geom.size.width)
			} else {
				List(self.projects, id: \.self, selection: self.$navigationModel.selectedComposeProject) { project in
					self.row(project)
				}
				.listStyle(.inset(alternatesRowBackgrounds: true))
				.frame(size: geom.size)
			}
		}
		.task {
			await self.pollLoop()
		}
		.onChange(of: self.navigationModel.composeReloadToken) {
			self.refresh()
		}
		.glassedSheet(item: self.$editorTarget) { target in
			let existingProject: ComposeReplyList.ComposeInfo? = {
				switch target {
				case .new: return nil
				case .edit(let project): return project
				}
			}()

			ComposeEditorView(
				client: AppState.shared.connectionManager.serviceClient,
				runMode: AppState.shared.connectionManager.connectionMode.runMode,
				existingProject: existingProject
			) {
				self.navigationModel.composeReloadToken += 1
			}
			.colorSchemeForColor()
		}
	}

	func newProject() {
		self.editorTarget = .new
	}

	@ViewBuilder
	private func row(_ project: ComposeReplyList.ComposeInfo) -> some View {
		let busy = self.busyProjects.contains(project.name)

		HStack(spacing: 12) {
			ZStack {
				RoundedRectangle(cornerRadius: 9)
					.fill(Color.pink.gradient)
					.frame(width: 38, height: 38)
				Image(systemName: "square.stack.3d.up")
					.resizable()
					.aspectRatio(contentMode: .fit)
					.foregroundStyle(.white)
					.frame(width: 20, height: 20)
			}

			VStack(alignment: .leading, spacing: 2) {
				Text(project.name)
					.font(.system(size: 13, weight: .semibold))

				HStack(spacing: 6) {
					GlossyCircle(color: project.runningServiceCount > 0 ? .green : .gray)
						.frame(width: 8, height: 8)
					Text(project.statusSummary)
				}
				.font(.system(size: 11))
				.foregroundStyle(.secondary)
			}

			Spacer()

			if project == self.navigationModel.selectedComposeProject {
				Button {
					self.editorTarget = .edit(project)
				} label: {
					self.actionIcon("pencil", color: .gray)
				}
				.withButtonStyle(.borderless)
				.controlSize(.small)
				.disabled(busy)
				.help(String(localized: "Edit this compose project"))

				AsyncButton { done in
					self.togglePrimaryAction(project) { _ in
						done()
					}
				} label: {
					self.actionIcon(
						project.primaryAction == .start ? "play.fill" : "stop.fill",
						color: project.primaryAction == .start ? .green : .orange)
				}
				.withButtonStyle(.borderless)
				.controlSize(.small)
				.disabled(busy)
				.help(
					project.primaryAction == .start
						? String(localized: "Start this project's services")
						: String(localized: "Stop this project's services"))

				AsyncButton { done in
					self.delete(project, done: done)
				} label: {
					self.actionIcon("trash", color: .red)
				}
				.withButtonStyle(.borderless)
				.controlSize(.small)
				.disabled(busy)
				.help(String(localized: "Delete this compose project"))
			}
		}
		.padding(.vertical, 4)
		.contentShape(Rectangle())
		// The row is keyed by name only (`ComposeInfo` is `Hashable` on `name`), so without this SwiftUI
		// keeps the old row when a poll or an action changes the services' state, and the counter stays stale.
		.id("\(project.name)#\(project.runningServiceCount)/\(project.totalServiceCount)#\(busy)")
		.contextMenu {
			Button("Edit…") {
				self.editorTarget = .edit(project)
			}
			.disabled(busy)

			AsyncButton(project.primaryAction == .start ? "Start" : "Stop") { done in
				self.togglePrimaryAction(project) { _ in
					done()
				}
			}
			.disabled(busy)

			Divider()

			AsyncButton("Delete…") { done in
				self.delete(project, done: done)
			}
			.disabled(busy)
		}
	}

	private func actionIcon(_ systemImage: String, color: Color) -> some View {
		ZStack {
			RoundedRectangle(cornerRadius: 9)
				.fill(color.gradient)
				.frame(width: 30, height: 30)
			Image(systemName: systemImage)
				.resizable()
				.aspectRatio(contentMode: .fit)
				.foregroundStyle(.white)
				.frame(width: 14, height: 14)
		}
	}

	/// Marks `project` busy (or not). Called from `AsyncButton` actions, which don't run on the main thread.
	private func setBusy(_ project: ComposeReplyList.ComposeInfo, _ busy: Bool) {
		let name = project.name

		DispatchQueue.main.async {
			if busy {
				self.busyProjects.insert(name)
			} else {
				self.busyProjects.remove(name)
			}
		}
	}

	private func togglePrimaryAction(_ project: ComposeReplyList.ComposeInfo, completionHandler: @escaping (_ canceled: Bool) -> Void) {
		self.setBusy(project, true)

		// Busy ends once the list has been reloaded, so the row never shows the old counter with live buttons.
		let finished: (Bool) -> Void = { canceled in
			if canceled {
				self.setBusy(project, false)
				completionHandler(true)
			} else {
				self.refresh {
					self.setBusy(project, false)
					completionHandler(false)
				}
			}
		}

		switch project.primaryAction {
		case .start:
			Self.start(project) {
				finished(false)
			} onCancel: {
				finished(true)
			}
		case .stop:
			Self.confirmAndStop(project) {
				finished(false)
			} onCancel: {
				finished(true)
			}
		}
	}

	private func delete(_ project: ComposeReplyList.ComposeInfo, done: @escaping () -> Void) {
		self.setBusy(project, true)

		Self.confirmAndDelete(project) {
			if self.navigationModel.selectedComposeProject?.name == project.name {
				self.navigationModel.selectedComposeProject = nil
			}

			self.refresh {
				self.setBusy(project, false)
				done()
			}
		} onCancel: {
			self.setBusy(project, false)
			done()
		}
	}

	/// Reconstructs a startable `ComposeFile` from what the registry knows (see
	/// `ComposeReplyList.ComposeInfo.reconstructedComposeFile()`) and calls `compose up` — not
	/// destructive, so no confirmation, unlike stop/delete. The reconstruction is names and images
	/// only, so it must never replace the project's stored definition (`replaceDefinition: false`).
	static func start(_ project: ComposeReplyList.ComposeInfo, onDone: @escaping () -> Void, onCancel: (() -> Void)? = nil) {
		let client = AppState.shared.connectionManager.serviceClient
		let runMode = AppState.shared.connectionManager.connectionMode.runMode

		Task {
			do {
				let reply = try await ComposeHandler.up(client: client, name: project.name, runMode: runMode)

				await MainActor.run {
					if reply.success {
						onDone()
					} else {
						onCancel?()
						alertError(String(localized: "Failed to start compose project"), reply.reason)
					}
				}
			} catch {
				await MainActor.run {
					onCancel?()
					alertError(error)
				}
			}
		}
	}

	/// Asks for confirmation, then stops every service in `project`. `onDone` runs on the main
	/// thread after a successful stop.
	static func confirmAndStop(_ project: ComposeReplyList.ComposeInfo, onDone: @escaping () -> Void, onCancel: (() -> Void)? = nil) {
		DispatchQueue.main.async {
			let alert = NSGlassEffectAlert()

			alert.messageText = String(localized: "Stop compose project")
			alert.informativeText = String(format: String(localized: "Are you sure you want to stop every running service in \"%@\"?"), project.name)
			alert.alertStyle = .warning
			alert.addButton(withTitle: String(localized: "Stop"))
			alert.addButton(withTitle: String(localized: "Cancel"))

			guard alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn else {
				onCancel?()
				return
			}

			let client = AppState.shared.connectionManager.serviceClient
			let runMode = AppState.shared.connectionManager.connectionMode.runMode

			DispatchQueue.global(qos: .utility).async {
				do {
					let reply = try ComposeHandler.down(client: client, name: project.name, runMode: runMode)

					DispatchQueue.main.async {
						if reply.success {
							onDone()
						} else {
							onCancel?()
							alertError(String(localized: "Failed to stop compose project"), reply.reason)
						}
					}
				} catch {
					DispatchQueue.main.async {
						onCancel?()
						alertError(error)
					}
				}
			}
		}
	}

	/// Asks for confirmation (naming how many services will be stopped first, if any), then removes
	/// `project` — used by both this view's inline row action and `HomeView`'s toolbar Delete button
	/// for the `.compose` category, matching `ImageCacheView.confirmAndDelete`'s shape.
	static func confirmAndDelete(_ project: ComposeReplyList.ComposeInfo, onDeleted: @escaping () -> Void, onCancel: (() -> Void)? = nil) {
		DispatchQueue.main.async {
			let alert = NSGlassEffectAlert()
			let runningNote =
				project.runningServiceCount > 0
				? String(format: String(localized: " %d of its services are still running and will be stopped first."), project.runningServiceCount)
				: ""

			alert.messageText = String(localized: "Delete compose project")
			alert.informativeText = String(format: String(localized: "Are you sure you want to delete \"%@\"? This action cannot be undone.%@"), project.name, runningNote)
			alert.alertStyle = .critical
			alert.addButton(withTitle: String(localized: "Delete"))
			alert.addButton(withTitle: String(localized: "Cancel"))

			guard alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn else {
				onCancel?()
				return
			}

			let client = AppState.shared.connectionManager.serviceClient
			let runMode = AppState.shared.connectionManager.connectionMode.runMode
			let stopFirst = project.runningServiceCount > 0

			DispatchQueue.global(qos: .utility).async {
				do {
					let reply = try ComposeHandler.rm(client: client, name: project.name, stop: stopFirst, runMode: runMode)

					DispatchQueue.main.async {
						if reply.success {
							onDeleted()
						} else {
							onCancel?()
							alertError(String(localized: "Delete failed"), reply.reason)
						}
					}
				} catch {
					DispatchQueue.main.async {
						onCancel?()
						alertError(error)
					}
				}
			}
		}
	}

	private func pollLoop() async {
		while !Task.isCancelled {
			self.refresh()

			try? await Task.sleep(for: Self.pollInterval)
		}
	}

	/// Reloads the projects; `completion` runs on the main thread once the list has been updated (or the reload failed).
	private func refresh(completion: (() -> Void)? = nil) {
		let client = AppState.shared.connectionManager.serviceClient
		let runMode = AppState.shared.connectionManager.connectionMode.runMode

		DispatchQueue.global(qos: .utility).async {
			do {
				let reply = try ComposeHandler.list(client: client, runMode: runMode)

				DispatchQueue.main.async {
					guard reply.success else {
						self.loadError = reply.reason
						completion?()
						return
					}

					self.projects = reply.composeFiles.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
					self.loadError = nil

					if let pendingName = self.navigationModel.pendingComposeProjectName {
						// A menu-bar "Open" action requested this project — apply it now that the
						// freshly (re)loaded list actually contains it, then clear the request.
						if let match = self.projects.first(where: { $0.name == pendingName }) {
							self.navigationModel.selectedComposeProject = match
							self.navigationModel.pendingComposeProjectName = nil
						}
					} else if let selected = self.navigationModel.selectedComposeProject {
						self.navigationModel.selectedComposeProject = self.projects.first { $0.name == selected.name }
					}

					completion?()
				}
			} catch {
				DispatchQueue.main.async {
					self.loadError = error.localizedDescription
					completion?()
				}
			}
		}
	}
}

#Preview {
	ComposeView(navigationModel: .init(selectedCategory: .compose))
}
