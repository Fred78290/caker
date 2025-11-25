//
//  ColorSchemeModifier.swift
//  Caker
//
//  Created by Frederic BOLTZ on 02/11/2025.
//

import SwiftUI

struct ColorSchemeModifier: ViewModifier {
	@Environment(\.colorScheme) var colorScheme

	init() {
	}

	func body(content: Content) -> some View {
		content.onChange(of: self.colorScheme) { _, newValue in
			Color.colorScheme = newValue
		}
	}
}

extension View {
	func colorSchemeForColor() -> some View {
		return self.modifier(ColorSchemeModifier())
	}
}
