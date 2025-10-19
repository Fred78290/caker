//
//  VMSettingsView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 04/09/2025.
//

import SwiftUI

struct VMSettingsView: View {
	@AppStorage("VMLaunchMode") var launchVMExternally = false
	@AppStorage("NoScreenshot") var isNoScreenshot = false
	@AppStorage("NoSaveScreenshot") var isNoSaveScreenshot = false

	var body: some View {
		Form {
			Toggle(
				isOn: $launchVMExternally.inverted,
				label: {
					Text("Launch VM inside app")
				}
			).onChange(of: launchVMExternally) { _, newValue in
				if newValue {
					launchVMExternally = true
				}
			}

			Toggle(
				isOn: $isNoScreenshot.inverted,
				label: {
					Text("Enable VM screenshoting")
				}
			).onChange(of: isNoScreenshot) { _, newValue in
				if newValue {
					isNoScreenshot = newValue
				}
			}

			Toggle(
				isOn: $isNoSaveScreenshot.inverted,
				label: {
					Text("Save VM screenshots")
				}
			).onChange(of: isNoSaveScreenshot) { _, newValue in
				if newValue {
					isNoSaveScreenshot = newValue
				}
			}
		}.formStyle(.grouped)
    }
}

#Preview {
    VMSettingsView()
}
