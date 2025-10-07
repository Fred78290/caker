//
//  WindowAccessor.swift
//  Caker
//
//  Created by Frederic BOLTZ on 10/09/2025.
//
import SwiftUI

struct WindowAccessor: NSViewRepresentable {
	typealias CallbackWindow = (NSWindow?) -> Void

	@Binding private var window: NSWindow?
	private let callback: CallbackWindow?

	init(_ window: Binding<NSWindow?>, callback: CallbackWindow? = nil) {
		self._window = window
		self.callback = callback
	}

	class MoveToWindowDetector: NSView {
		var onMoveToWindow: (NSWindow?) -> Void = { _ in }

		override func viewDidMoveToWindow() {
			onMoveToWindow(window)
		}
	}

	func makeNSView(context: Context) -> MoveToWindowDetector {
		MoveToWindowDetector()
	}

	func updateNSView(_ nsView: MoveToWindowDetector, context: Context) {
		nsView.onMoveToWindow = {
			if $0 != nil {
				window = $0
				if let callback {
					callback($0)
				}
			}
		}
	}
}

extension View {
	func windowAccessor(_ window: Binding<NSWindow?>, callback: WindowAccessor.CallbackWindow? = nil) -> some View {
		background {
			WindowAccessor(window, callback: callback)
		}
	}
}
