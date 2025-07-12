//
//  RestorationState.swift
//  Caker
//
//  Created by Frederic BOLTZ on 11/07/2025.
//
import SwiftUI

enum RestorationStateBehavior: String {
	case disabled
	case automatic
}

struct RestorationState: ViewModifier {
	let behavior: RestorationStateBehavior

	func body(content: Content) -> some View {
		if #available(macOS 15.0, *) {
			return content
		} else {
			return content
				.onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification), perform: { output in
					let window = output.object as! NSWindow
					
					window.isRestorable = behavior == .automatic
				})
		}
	}
}

extension View {
	func restorationState(_ restoreState: RestorationStateBehavior = .automatic) -> some View {
		modifier(RestorationState(behavior: restoreState))
	}
}

extension Scene {
	func restorationState(_ restoreState: RestorationStateBehavior = .automatic) -> some Scene {
		if #available(macOS 15.0, *) {
			return self.restorationBehavior(restoreState == .automatic ? .automatic : .disabled)
		}
		
		return self
	}
}
