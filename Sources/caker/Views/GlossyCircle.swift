//
//  GlossyCircle.swift
//  Caker
//
//  Created by Frederic BOLTZ on 20/11/2025.
//

import SwiftUI

struct GlossyCircle: View {
	let color: Color

	private var base: Color { color }
	private var dark: Color { color.darker(by: 0.45) }
	private var light: Color { color.lighter(by: 0.35) }

	var body: some View {
		ZStack {
			// Base circle
			Circle()
				.fill(
					RadialGradient(
						gradient: Gradient(colors: [
							light,
							dark
						]),
						center: .center,
						startRadius: 2,
						endRadius: 60
					)
				)
			
			// Inner glow / depth
			Circle()
				.inset(by: 1)
				.stroke(
					LinearGradient(
						colors: [
							Color.white.opacity(0.40),
							Color.black.opacity(0.30)
						],
						startPoint: .topLeading,
						endPoint: .bottomTrailing
					),
					lineWidth: 2
				)
			
			// Top highlight for gloss (brighter & larger)
			Circle()
				.fill(
					LinearGradient(
						colors: [
							Color.white.opacity(0.85),
							Color.white.opacity(0.0)
						],
						startPoint: .top,
						endPoint: .center
					)
				)
				.scaleEffect(y: 0.70, anchor: .top)
				.blur(radius: 0.6)
			
			// Secondary specular highlight (small glint)
			/*Circle()
				.fill(
					RadialGradient(
						gradient: Gradient(colors: [
							Color.white.opacity(0.55),
							Color.white.opacity(0.0)
						]),
						center: .topLeading,
						startRadius: 0,
						endRadius: 22
					)
				)
				.scaleEffect(0.9)
				.offset(x: -4, y: -6)*/
			
			// Bottom subtle reflection
			Circle()
				.fill(
					LinearGradient(
						colors: [
							Color.white.opacity(0.0),
							Color.white.opacity(0.18)
						],
						startPoint: .center,
						endPoint: .bottom
					)
				)
				.scaleEffect(y: 0.9, anchor: .bottom)
				.blur(radius: 0.5)
			
			// Faint bloom to increase perceived intensity
			Circle()
				.stroke(Color.white.opacity(0.15), lineWidth: 1)
				.blur(radius: 1.2)
		}
		
		//.shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)
		.aspectRatio(1, contentMode: .fit)
	}
}

extension Color {
	func lighter(by amount: CGFloat) -> Color {
		#if canImport(AppKit)
		let ns = NSColor(self)
		var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
		ns.usingColorSpace(.deviceRGB)?.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
		return Color(hue: Double(h), saturation: Double(max(0, s - amount * 0.5)), brightness: Double(min(1, b + amount)), opacity: Double(a))
		#else
		return self
		#endif
	}

	func darker(by amount: CGFloat) -> Color {
		#if canImport(AppKit)
		let ns = NSColor(self)
		var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
		ns.usingColorSpace(.deviceRGB)?.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
		return Color(hue: Double(h), saturation: Double(min(1, s + amount * 0.5)), brightness: Double(max(0, b - amount)), opacity: Double(a))
		#else
		return self
		#endif
	}
}

#Preview("Glossy Circles") {
	HStack(spacing: 16) {
		GlossyCircle(color: .red).frame(width: 44, height: 44)
		GlossyCircle(color: .green).frame(width: 44, height: 44)
		GlossyCircle(color: .blue).frame(width: 44, height: 44)
		GlossyCircle(color: .orange).frame(width: 44, height: 44)
		GlossyCircle(color: .purple).frame(width: 44, height: 44)
	}
	.padding()
}
