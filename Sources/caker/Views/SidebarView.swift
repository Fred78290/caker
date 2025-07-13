//
//  SidebarView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 12/07/2025.
//

import SwiftUI

struct SidebarView: View {
    var body: some View {
		NavigationView {
			List {
				NavigationLink(destination: MainView(title: "Virtual machine")) {
					Label("Virtual machine", systemImage: "house")
				}
				NavigationLink(destination: MainView(title: "Remotes")) {
					Label("Remotes", systemImage: "cloud")
				}
				NavigationLink(destination: MainView(title: "Network")) {
					Label("Network", systemImage: "network")
				}
			}
			.listStyle(SidebarListStyle())
			.navigationTitle("Explore")
			.frame(width: 180)
			.toolbar {
				ToolbarItem(placement: .navigation) {
						Button(action: toggleSidebar, label: {
						Image(systemName: "sidebar.left")
					})
				}
			}
		}
    }

	// Toggle Sidebar Function
	func toggleSidebar() {
		NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
	}
}

#Preview {
    SidebarView()
}
