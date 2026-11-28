//
//  WaitWindow.swift
//  Caker
//
//  A small "please wait" window shown while a long operation runs in the background.
//

import AppKit
import SwiftUI

@MainActor
final class WaitWindow {
	/// Below this delay the operation finishes before the window shows, so a fast operation doesn't flash a window.
	static let showDelay: Duration = .milliseconds(250)

	private let panel: NSPanel
	private let model: WaitWindowModel
	private var parent: NSWindow?
	private var showTask: Task<Void, Never>?
	private var closed = false

	/// True once the user pressed Cancel.
	var cancelled: Bool {
		self.model.cancelling
	}

	/// `onCancel`, when given, adds a Cancel button (also Escape) that calls it once.
	init(title: String, message: String, onCancel: (() -> Void)? = nil) {
		let model = WaitWindowModel(title: title, message: message, onCancel: onCancel)
		let hostingView = NSHostingView(rootView: WaitWindowView(model: model))

		hostingView.frame.size = hostingView.fittingSize

		self.model = model
		self.panel = NSPanel(contentRect: NSRect(origin: .zero, size: hostingView.fittingSize), styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: true)
		self.panel.title = title
		self.panel.titleVisibility = .hidden
		self.panel.titlebarAppearsTransparent = true
		self.panel.isMovableByWindowBackground = true
		self.panel.isReleasedWhenClosed = false
		self.panel.hidesOnDeactivate = false
		self.panel.contentView = hostingView
	}

	/// Shows the window after `showDelay`, as a sheet on the key window when there is one, else as a floating panel.
	func show() {
		self.showTask = Task { @MainActor [weak self] in
			try? await Task.sleep(for: Self.showDelay)

			guard let self, Task.isCancelled == false, self.closed == false else {
				return
			}

			if let parent = NSApp.keyWindow ?? NSApp.mainWindow, parent.isVisible, parent.attachedSheet == nil {
				self.parent = parent
				parent.beginSheet(self.panel, completionHandler: nil)
			} else {
				self.panel.level = .floating
				self.panel.center()
				self.panel.makeKeyAndOrderFront(nil)
			}
		}
	}

	func close() {
		self.closed = true
		self.showTask?.cancel()
		self.showTask = nil

		if let parent = self.parent {
			parent.endSheet(self.panel)
			self.parent = nil
		} else {
			self.panel.orderOut(nil)
		}
	}

	/// Runs `work` in a detached task while the wait window is shown, and closes the window once it returns or throws.
	/// With `cancellable`, the window has a Cancel button that cancels that task; `work` decides what a
	/// cancellation returns, and `cancelled` tells the caller the user asked for it.
	static func run<T: Sendable>(title: String, message: String, cancellable: Bool = false, _ work: @escaping @Sendable () async throws -> T) async throws -> (value: T, cancelled: Bool) {
		let task = Task.detached(priority: .userInitiated) {
			try await work()
		}
		let window = WaitWindow(title: title, message: message, onCancel: cancellable ? { task.cancel() } : nil)

		window.show()

		defer {
			window.close()
		}

		let value = try await withTaskCancellationHandler {
			try await task.value
		} onCancel: {
			task.cancel()
		}

		return (value, window.cancelled)
	}
}

@MainActor
private final class WaitWindowModel: ObservableObject {
	let title: String
	let message: String
	let onCancel: (() -> Void)?

	@Published var cancelling = false

	init(title: String, message: String, onCancel: (() -> Void)?) {
		self.title = title
		self.message = message
		self.onCancel = onCancel
	}

	func cancel() {
		guard self.cancelling == false else {
			return
		}

		self.cancelling = true
		self.onCancel?()
	}
}

private struct WaitWindowView: View {
	@ObservedObject var model: WaitWindowModel

	var body: some View {
		VStack(alignment: .trailing, spacing: 16) {
			HStack(alignment: .center, spacing: 16) {
				ProgressView()
					.controlSize(.large)

				VStack(alignment: .leading, spacing: 4) {
					Text(self.model.title)
						.font(.headline)

					Text(self.model.cancelling ? String(localized: "Cancelling…") : self.model.message)
						.font(.callout)
						.foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)
				}

				Spacer(minLength: 0)
			}

			if self.model.onCancel != nil {
				Button(String(localized: "Cancel")) {
					self.model.cancel()
				}
				.keyboardShortcut(.cancelAction)
				.disabled(self.model.cancelling)
			}
		}
		.padding(24)
		.frame(minWidth: 320, maxWidth: 420, alignment: .leading)
	}
}
