//
//  LabelView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 06/09/2025.
//

import SwiftUI

struct LabelView: View {
	private let text: String
	private let progress: Bool

	init(_ text: String, progress: Bool = false) {
		self.text = text
		self.progress = progress
	}

	var body: some View {
		GeometryReader { geom in
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
				.frame(size: geom.size)
				.background(.black, ignoresSafeAreaEdges: .bottom)
			} else {
				HStack {
					Text(text).foregroundStyle(.white).font(.largeTitle)
				}
				.frame(size: geom.size)
				.background(.black, ignoresSafeAreaEdges: .bottom)
			}
		}
    }
}

#Preview {
	LabelView("Hello, World!")
}
