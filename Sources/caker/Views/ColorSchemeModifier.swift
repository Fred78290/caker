//
//  ColorSchemeModifier.swift
//  Caker
//
//  Created by Frederic BOLTZ on 02/11/2025.
//

import SwiftUI

enum AppearancePreference: String, CaseIterable {
	case system
	case light
	case dark

	var title: LocalizedStringKey {
		switch self {
		case .system: return "System"
		case .light: return "Light"
		case .dark: return "Dark"
		}
	}

	var colorScheme: ColorScheme? {
		switch self {
		case .system: return nil
		case .light: return .light
		case .dark: return .dark
		}
	}

	var systemImage: String {
		switch self {
		case .system: return "circle.lefthalf.filled"
		case .light: return "sun.max.fill"
		case .dark: return "moon.fill"
		}
	}
}

struct ColorSchemeModifier: ViewModifier {
	@Environment(\.colorScheme) var colorScheme
	@AppStorage("AppearancePreference") var appearancePreference: AppearancePreference = .system

	private func resolved(_ colorScheme: ColorScheme?) -> ColorScheme {
		guard let colorScheme else {
			return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? .dark : .light
		}

		return colorScheme
	}

	func body(content: Content) -> some View {
		content
			.preferredColorScheme(resolved(appearancePreference.colorScheme))
			.onChange(of: self.colorScheme) { _, newValue in
				Color.colorScheme = newValue
			}
	}
}

extension View {
	func colorSchemeForColor() -> some View {
		return self.modifier(ColorSchemeModifier())
	}
}
