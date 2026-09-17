//
//  TasksView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 17/09/2026.
//

import CakedLib
import GRPCLib
import SwiftUI

/// Lists `caked`'s currently-registered long-running tasks (the merged gRPC+REST view behind the
/// `ListTasks` RPC — see `CakedProvider.listTasks()`/`CLAUDE.md`'s "`ListTasks`/`CancelTask` RPCs"
/// section), with a context-menu action to cancel one via the `CancelTask` RPC. Modeled directly on
/// `RemotesView.swift`'s structure (a plain `List` + context menu, no detail view).
///
/// Unlike `AppState.remotes`/`.networks`/etc., there is no push-notification mechanism for task
/// state changes, so this view polls on its own while visible instead of relying on a GCD-pushed
/// update — `.task` both fetches immediately on appear and is automatically cancelled on disappear.
struct TasksView: View {
	private static let pollInterval: Duration = .seconds(3)

	@State private var tasks: [Caked_Reply.TaskReply.TaskEntry] = []
	@State private var loadError: String? = nil

	var body: some View {
		GeometryReader { geom in
			if self.tasks.isEmpty {
				VStack(alignment: .center) {
					if let loadError {
						ContentUnavailableView("Unable to load tasks", systemImage: "exclamationmark.triangle", description: Text(loadError))
					} else {
						ContentUnavailableView("List empty", systemImage: "tray")
					}
				}.frame(width: geom.size.width)
			} else {
				List(self.tasks, id: \.id) { task in
					HStack(spacing: 12) {
						ZStack {
							RoundedRectangle(cornerRadius: 9)
								.fill(Color.indigo.gradient)
								.frame(width: 38, height: 38)
							Image(systemName: "hourglass")
								.resizable()
								.aspectRatio(contentMode: .fit)
								.foregroundStyle(.white)
								.frame(width: 20, height: 20)
						}

						VStack(alignment: .leading, spacing: 2) {
							Text(task.title)
								.font(.system(size: 13, weight: .semibold))
							Text(task.id)
								.font(.system(size: 11, design: .monospaced))
								.foregroundStyle(.secondary)
								.lineLimit(1)
								.truncationMode(.middle)
						}

						Spacer()
					}
					.padding(.vertical, 4)
					.contentShape(Rectangle())
					.contextMenu {
						Button("Cancel", role: .destructive) {
							self.cancelTask(task)
						}
					}
				}
				.listStyle(.inset(alternatesRowBackgrounds: true))
				.frame(size: geom.size)
			}
		}
		.task {
			await self.pollLoop()
		}
	}

	private func pollLoop() async {
		while !Task.isCancelled {
			self.refresh()

			try? await Task.sleep(for: Self.pollInterval)
		}
	}

	private func refresh() {
		do {
			self.tasks = try TasksHandler.listTasks(client: AppState.shared.connectionManager.serviceClient)
			self.loadError = nil
		} catch {
			self.loadError = error.localizedDescription
		}
	}

	private func cancelTask(_ task: Caked_Reply.TaskReply.TaskEntry) {
		let alert = NSGlassEffectAlert()

		alert.messageText = String(localized: "Cancel task")
		alert.informativeText = String(format: String(localized: "Are you sure you want to cancel \"%@\"? This action cannot be undone."), task.title)
		alert.alertStyle = .critical
		alert.addButton(withTitle: String(localized: "Cancel Task"))
		alert.addButton(withTitle: String(localized: "Keep Running"))

		guard alert.runModal() == NSApplication.ModalResponse.alertFirstButtonReturn else {
			return
		}

		do {
			let result = try TasksHandler.cancelTask(client: AppState.shared.connectionManager.serviceClient, id: task.id)

			if result.success {
				self.refresh()
			} else {
				DispatchQueue.main.async {
					alertError(String(localized: "Cancel failed"), result.reason)
				}
			}
		} catch {
			DispatchQueue.main.async {
				alertError(error)
			}
		}
	}
}

#Preview {
	TasksView()
}
