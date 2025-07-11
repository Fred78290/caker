//
//  SettingsView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 11/07/2025.
//

import SwiftUI

struct SettingsView: View {
	var body: some View {
		TabView {
			ApplicationSettingsView().padding()
				.tabItem {
					Label("Application", systemImage: "app.badge")
				}
		}.frame(minWidth: 450, minHeight: 350, alignment: .topLeading)
    }
}

extension UserDefaults {
	@objc dynamic var ShowMenuIcon: Bool { false }
	@objc dynamic var HideDockIcon: Bool { false }
}

#Preview {
    SettingsView()
}
