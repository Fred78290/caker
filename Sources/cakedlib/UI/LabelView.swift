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
		if progress {
			VStack(alignment: .center) {
				ProgressView().overlay {
					Color.white.mask {
						ProgressView()
					}
				}
				Text(text)
					.foregroundStyle(.white)
					.font(.largeTitle)
			}
			.frame(width: size.width, height: size.height)
			.background(.black, ignoresSafeAreaEdges: .bottom)
		} else {
			HStack {
				Text(text).foregroundStyle(.white).font(.largeTitle)
			}
			.frame(width: size.width, height: size.height)
			.background(.black, ignoresSafeAreaEdges: .bottom)
		}
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
