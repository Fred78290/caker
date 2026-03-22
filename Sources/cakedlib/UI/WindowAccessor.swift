//
//  WindowAccessor.swift
//  Caker
//
//  Created by Frederic BOLTZ on 10/09/2025.
//
import SwiftUI

public struct WindowAccessor: NSViewRepresentable {
	public typealias CallbackWindow = (NSWindow?) -> Void

	@Binding private var window: NSWindow?
	private let callback: CallbackWindow?

	public init(_ window: Binding<NSWindow?>, callback: CallbackWindow? = nil) {
		self._window = window
		self.callback = callback
	}

	public class MoveToWindowDetector: NSView {
		var onMoveToWindow: (NSWindow?) -> Void = { _ in }

		public override func viewDidMoveToWindow() {
			onMoveToWindow(window)
		}
	}

	public func makeNSView(context: Context) -> MoveToWindowDetector {
		MoveToWindowDetector()
	}

	public func updateNSView(_ nsView: MoveToWindowDetector, context: Context) {
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
	public func windowAccessor(_ window: Binding<NSWindow?>, callback: WindowAccessor.CallbackWindow? = nil) -> some View {
		background {
			WindowAccessor(window, callback: callback)
		}
	}
}
