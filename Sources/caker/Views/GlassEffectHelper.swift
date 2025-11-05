//
//  GlassEffectHelper.swift
//  Caker
//
//  Created by Frederic BOLTZ on 03/11/2025.
//
import SwiftUI

enum GlassEffect {
	case regular(Color?, Bool?)
	case clear(Color?, Bool?)
	case identity(Color?, Bool?)
}

struct GlassEffectHelper<S: Shape>: ViewModifier {
	@Environment(\.appearsActive) var appearsActive

	let effect: GlassEffect
	let shape: S

	init(_ effect: GlassEffect, in shape: S) {
		self.effect = effect
		self.shape = shape
	}

#if compiler(>=6.2)
	@available(macOS 26.0, *)
	private var glassEffect: Glass {
		guard self.appearsActive else { return .identity }
		
		func applyEffect(_ glass: Glass, _ color: Color?, _ interactive: Bool?) -> Glass {
			var glass = glass
			
			if let color = color {
				glass = glass.tint(color)
			}
			
			if let interactive = interactive {
				glass = glass.interactive(interactive)
			}

			return glass
		}

		switch self.effect {
		case let .regular(color, interactive):
			return applyEffect(Glass.regular, color, interactive)
		case let .clear(color, interactive):
			return applyEffect(Glass.clear, color, interactive)
		case let .identity(color, interactive):
			return applyEffect(Glass.identity, color, interactive)
		}
	}
#endif

	func body(content: Content) -> some View {
#if compiler(>=6.2)
		if #available(macOS 26.0, *) {
			GlassEffectContainer {
				content.glassEffect(self.glassEffect, in: shape)
			}
		} else {
			content
		}
#else
		content
#endif
	}
}

private func defaultShape() -> some Shape {
#if compiler(>=6.2)
	if #available(macOS 26.0, *) {
		return DefaultGlassEffectShape()
	} else {
		return Capsule()
	}
#else
	Rectangle()
#endif
}

extension View {
#if compiler(>=6.2)
	func withGlassEffect(_ effect: GlassEffect = .regular(nil, nil), in shape: some Shape = defaultShape()) -> some View {
		if #available(macOS 26.0, *) {
			return modifier(GlassEffectHelper(effect, in: shape))
		} else {
			return self
		}
	}
#else
	func withGlassEffect(_ effect: GlassEffect = .regular(nil, nil), in shape: some Shape = defaultShape()) -> some View {
		modifier(GlassEffectHelper(effect, in: shape))
	}
	#endif
}
