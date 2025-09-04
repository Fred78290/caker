//
//  VMSettingsView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 04/09/2025.
//

import SwiftUI

struct VMSettingsView: View {
	@AppStorage("VMLaunchMode") var launchVMExternally = false

	var body: some View {
		Form {
			Toggle(
				isOn: $launchVMExternally.inverted,
				label: {
					Text("Launch VM inside app")
				}
			).onChange(of: launchVMExternally) { newValue in
				if newValue {
					launchVMExternally = true
				}
			}

		}.formStyle(.grouped)
    }
}

#Preview {
    VMSettingsView()
}
