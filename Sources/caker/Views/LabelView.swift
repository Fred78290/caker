//
//  LabelView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 06/09/2025.
//

import SwiftUI

struct LabelView: View {
	private let text: String
	private let size: CGSize?
	private let progress: Bool

	init(_ text: String, size: CGSize? = nil, progress: Bool = false) {
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
			.frame(size: size)
			.background(.black, ignoresSafeAreaEdges: .bottom)
		} else {
			HStack {
				Text(text).foregroundStyle(.white).font(.largeTitle)
			}
			.frame(size: size)
			.background(.black, ignoresSafeAreaEdges: .bottom)
		}
	}

	var body: some View {
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
