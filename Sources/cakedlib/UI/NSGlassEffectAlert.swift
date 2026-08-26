//
//  NSGlassEffectAlert.swift
//  Caker
//
//  Created by Frederic BOLTZ on 30/07/2026.
//

import AppKit

open class NSGlassEffectAlert: NSAlert {
	@discardableResult
	override open func runModal() -> NSApplication.ModalResponse {

		if #available(macOS 27.0, *) {
			self.buttons.forEach { button in
				button.bezelStyle = .glass
/*				// Apply Liquid Glass effect to each button
				let glassView = NSGlassEffectView(frame: button.bounds)
				glassView.autoresizingMask = [.width, .height]
				glassView.cornerRadius = 8.0
				glassView.tintColor = NSColor.systemBlue.withAlphaComponent(0.15)

				// Insert the glass view behind the button's content
				button.addSubview(glassView, positioned: .below, relativeTo: nil)*/
			}
		}

		return super.runModal()
	}
}
