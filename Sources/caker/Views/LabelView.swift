//
//  LabelView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 06/09/2025.
//

import SwiftUI

struct LabelView: View {
	let text: String

	init(_ text: String = "Hello, World!") {
		self.text = text
	}

	var body: some View {
		GeometryReader { geom in
			HStack {
				Text(text).foregroundStyle(.white).font(.largeTitle)
			}
			.frame(size: geom.size)
			.background(.black, ignoresSafeAreaEdges: .bottom)
		}
    }
}

#Preview {
	LabelView()
}
