//
//  ApplicationSettingsView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 11/07/2025.
//

import SwiftUI

extension Binding where Value == Bool {
	var inverted: Binding<Bool> {
		Binding {
			!wrappedValue
		} set: { newValue in
			wrappedValue = !newValue
		}
	}
}

struct ApplicationSettingsView: View {
	@AppStorage("HideDockIcon") var isDockIconHidden = false
	@AppStorage("ShowMenuIcon") var isMenuIconShown = false

	var body: some View {
		Form {
			Toggle(
				isOn: $isDockIconHidden.inverted,
				label: {
					Text("Show dock icon")
				}
			).onChange(of: isDockIconHidden) { newValue in
				if newValue {
					isMenuIconShown = true
				}
			}

			Toggle(
				isOn: $isMenuIconShown,
				label: {
					Text("Show menu bar icon")
				}
			).disabled(isDockIconHidden)
		}.formStyle(.grouped)
	}
}

#Preview {
	ApplicationSettingsView()
}
