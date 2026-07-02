//
//  SettingsView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 11/07/2025.
//

import SwiftUI

struct SettingsView: View {
	@AppStorage("AppearancePreference") var appearancePreference: AppearancePreference = .system

	var body: some View {
		TabView {
			ApplicationSettingsView().padding()
				.tabItem {
					Label("Application", systemImage: "app.badge")
				}
			VMSettingsView().padding()
				.tabItem {
					Label("Virtual machines", systemImage: "display")
				}
			AdvancedSettingsView().padding()
				.tabItem {
					Label("Advanced", systemImage: "gearshape.2")
				}
		}.frame(minWidth: 450, alignment: .topLeading).preferredColorScheme(self.appearancePreference.colorScheme)
	}
}

extension UserDefaults {
	@objc dynamic var ShowMenuIcon: Bool { false }
	@objc dynamic var HideDockIcon: Bool { false }
}

#Preview {
	SettingsView()
}
