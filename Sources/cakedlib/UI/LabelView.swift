//
//  LabelView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 06/09/2025.
//

import SwiftUI

public struct LabelView: View {
	private let text: LocalizedStringKey
	private let size: CGSize?
	private let progress: Bool

	public init(_ text: LocalizedStringKey, size: CGSize? = nil, progress: Bool = false) {
		self.text = text
		self.size = size
		self.progress = progress
	}

	@ViewBuilder
	private func content(size: CGSize) -> some View {
		ZStack {
			LinearGradient(
				colors: [Color(white: 0.10), Color(white: 0.05)],
				startPoint: .top,
				endPoint: .bottom
			)

			VStack(spacing: 14) {
				if progress {
					ProgressView()
						.scaleEffect(1.2)
						.tint(Color.white.opacity(0.7))
				}
				Text(text)
					.foregroundStyle(.white.opacity(0.85))
					.font(.system(size: 15, weight: .medium))
					.multilineTextAlignment(.center)
					.padding(.horizontal, 32)
			}
		}
		.frame(width: size.width, height: size.height)
	}

	public var body: some View {
		if let size = self.size {
			content(size: size)
		} else {
			GeometryReader { geom in
				content(size: geom.size)
			}
		}
	}
}

#Preview {
	LabelView("Hello, World!")
}
