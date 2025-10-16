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
					Text("Disable VM screenshoting")
				}
			).onChange(of: isNoScreenshot) { _, newValue in
				if newValue {
					isNoScreenshot = true
				}
			}

			Toggle(
				isOn: $isNoSaveScreenshot.inverted,
				label: {
					Text("Don't save VM screenshots")
				}
			).onChange(of: isNoSaveScreenshot) { _, newValue in
				if newValue {
					isNoSaveScreenshot = true
				}
			}
		}.formStyle(.grouped)
    }
}

#Preview {
    VMSettingsView()
}
