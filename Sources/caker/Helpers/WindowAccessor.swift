//
//  WindowAccessor.swift
//  Caker
//
//  Created by Frederic BOLTZ on 10/09/2025.
//
import SwiftUI

struct WindowAccessor: NSViewRepresentable {
	@Binding var window: NSWindow?
	let delegate: NSWindowDelegate?

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
			window = $0
			if delegate != nil {
				$0?.delegate = delegate
			}
		}
	}
}

extension View {
	func windowAccessor(_ window: Binding<NSWindow?>, delegate: NSWindowDelegate? = nil) -> some View {
		background {
			WindowAccessor(window: window, delegate: delegate)
		}
	}
}
