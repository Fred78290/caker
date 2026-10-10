import AppKit
import SwiftUI

// MARK: - Public API

/// Dismisses the glassed sheet that hosts the current view.
/// Read it with `@Environment(\.dismissGlassedSheet)`, then call it like a function.
public struct GlassedSheetDismissAction {
	fileprivate let action: @MainActor () -> Void

	@MainActor
	public func callAsFunction() { action() }
}

extension EnvironmentValues {
	/// Dismiss action for the enclosing `glassedSheet`. Does nothing outside one.
	@Entry public var dismissGlassedSheet = GlassedSheetDismissAction(action: {
			EnvironmentValues().dismiss()
		}
	)
}

extension View {
	/// Presents `content` as a native AppKit sheet on the window hosting this view.
	/// It is a drop-in replacement for `.sheet(isPresented:onDismiss:content:)`.
	@ViewBuilder
	public func glassedSheet<Content: View>(
		isPresented: Binding<Bool>,
		onDismiss: (() -> Void)? = nil,
		@ViewBuilder content: @escaping () -> Content
	) -> some View {
		if #available(macOS 26.0, *) {
			background(
				GlassedSheetPresenter(
					isPresented: isPresented,
					onDismiss: onDismiss,
					content: content
				).onChange(of: isPresented.wrappedValue) { _, newValue in
					// Nothing, just watch isPresented to keep the sheet in sync with SwiftUI state.
				}
			)
		} else {
			sheet(isPresented: isPresented, onDismiss: onDismiss) {
				content().environment(
					\.dismissGlassedSheet,
					GlassedSheetDismissAction { EnvironmentValues().dismiss() }
				)
			}
		}
	}

	/// Item-driven variant, like `.sheet(item:onDismiss:content:)`.
	public func glassedSheet<Item: Identifiable, Content: View>(
		item: Binding<Item?>,
		onDismiss: (() -> Void)? = nil,
		@ViewBuilder content: @escaping (Item) -> Content
	) -> some View {
		glassedSheet(
			isPresented: Binding(
				get: { item.wrappedValue != nil },
				set: { if !$0 { item.wrappedValue = nil } }
			),
			onDismiss: onDismiss
		) {
			if let value = item.wrappedValue {
				content(value)
			}
		}
	}
}

// MARK: - Root view placed inside the sheet window

private struct GlassedSheetRoot<Content: View>: View {
	let dismiss: GlassedSheetDismissAction
	let content: Content

	var body: some View {
		content
			.environment(\.dismissGlassedSheet, dismiss)
	}
}

// MARK: - Bridge to AppKit

/// Invisible view that finds the host NSWindow and presents/dismisses the sheet on it.
private struct GlassedSheetPresenter<Content: View>: NSViewRepresentable {
	@Binding var isPresented: Bool
	var onDismiss: (() -> Void)?
	var content: () -> Content

	func makeCoordinator() -> GlassedSheetCoordinator<Content> {
		GlassedSheetCoordinator(parent: self)
	}

	func makeNSView(context: Context) -> GlassedSheetAnchorView {
		let view = GlassedSheetAnchorView()
		let coordinator = context.coordinator

		coordinator.anchor = view

		view.onWindowChange = { [weak coordinator] window in
			if window == nil {
				coordinator?.teardown()
			} else {
				coordinator?.scheduleSync()
			}
		}

		return view
	}

	func updateNSView(_ nsView: GlassedSheetAnchorView, context: Context) {
		context.coordinator.parent = self
		context.coordinator.scheduleSync()
	}

	static func dismantleNSView(
		_ nsView: GlassedSheetAnchorView,
		coordinator: GlassedSheetCoordinator<Content>
	) {
		coordinator.teardown()
	}
}

/// Reports when the sheet leaves the screen, whoever dismissed it (code, Escape, ...).
private final class GlassedSheetHostingController<Content: View>:
	NSHostingController<Content>
{
	var onDisappear: (() -> Void)?

	override func viewDidDisappear() {
		super.viewDidDisappear()
		onDisappear?()
	}
}

private final class GlassedSheetAnchorView: NSView {
	var onWindowChange: ((NSWindow?) -> Void)?

	override func viewDidMoveToWindow() {
		super.viewDidMoveToWindow()

		onWindowChange?(window)
	}

	// Never intercept clicks meant for the real content.
	override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

@MainActor
private final class GlassedSheetCoordinator<Content: View> {
	var parent: GlassedSheetPresenter<Content>
	weak var anchor: NSView?

	private var hostingController: NSHostingController<GlassedSheetRoot<Content>>?
	private var presenter: NSViewController?
	private var isDismissing = false
	private var syncScheduled = false

	init(parent: GlassedSheetPresenter<Content>) {
		self.parent = parent
	}

	/// Defers AppKit work out of SwiftUI's update pass so presenting
	/// or dismissing never mutates state during a view update.
	func scheduleSync() {
		guard !syncScheduled else { return }
		syncScheduled = true
		Task { @MainActor [weak self] in
			guard let self else { return }
			self.syncScheduled = false
			self.sync()
		}
	}

	private func sync() {
		if parent.isPresented {
			if let hostingController {
				// Keep the sheet's content up to date with the parent's state.
				hostingController.rootView = makeRoot()
			} else {
				present()
			}
		} else if hostingController != nil {
			dismissSheet()
		}
	}

	private func makeRoot() -> GlassedSheetRoot<Content> {
		GlassedSheetRoot(
			dismiss: GlassedSheetDismissAction { [weak self] in
				self?.requestDismiss()
			},
			content: parent.content()
		)
	}

	/// Presents a SwiftUI view as a native AppKit sheet on the main window.
	private func present() {
		// No window yet: viewDidMoveToWindow will trigger another sync.
		guard let hostWindow = anchor?.window,
			let presenter = hostWindow.contentViewController,
			presenter.presentedViewControllers?.isEmpty ?? true
		else { return }

		let sheetController = GlassedSheetHostingController(
			rootView: makeRoot()
		)
		sheetController.sizingOptions = [.preferredContentSize]
		sheetController.onDisappear = { [weak self, weak sheetController] in
			MainActor.assumeIsolated {
				guard let self, self.hostingController === sheetController
				else { return }
				self.didDisappear()
			}
		}

		presenter.presentAsSheet(sheetController)

		self.hostingController = sheetController
		self.presenter = presenter
	}

	private func requestDismiss() {
		if parent.isPresented {
			parent.isPresented = false
		}
		dismissSheet()
	}

	private func dismissSheet() {
		guard let hostingController, let presenter, !isDismissing else {
			return
		}

		isDismissing = true
		presenter.dismiss(hostingController)
	}

	/// The sheet is gone: reset state, sync the binding and notify.
	private func didDisappear() {
		hostingController = nil
		presenter = nil
		isDismissing = false

		if parent.isPresented {
			parent.isPresented = false
		}
		parent.onDismiss?()
	}

	/// Called when the presenting view leaves the hierarchy.
	func teardown() {
		dismissSheet()
	}
}
