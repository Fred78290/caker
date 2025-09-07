//
//  LabelView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 06/09/2025.
//

import SwiftUI

struct LabelView: View {
	private let text: String
	private var callback: ((NSWindow?) -> Void)?

	init(_ text: String, _ callback: ((NSWindow?) -> Void)?) {
		self.text = text
		self.callback = callback
	}

	var body: some View {
		GeometryReader { geom in
			if let callback = self.callback {
				HostingWindowFinder(callback)
			}
			HStack {
				Text(text).foregroundStyle(.white).font(.largeTitle)
			}
			.frame(size: geom.size)
			.background(.black, ignoresSafeAreaEdges: .bottom)
		}
    }
}

#Preview {
	LabelView("Hello, World!", nil)
}
