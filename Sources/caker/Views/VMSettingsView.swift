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
	@AppStorage("NoShutdownVMOnClose") var isNoShutdownVMOnClose = false
	@AppStorage("ClipboardRedirectionEnabled") var isClipboardRedirectionEnabled = false
	@AppStorage("DebugVNCMessageEnabled") var debugVNCMessageEnabled: Bool = false

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

			Toggle(
				isOn: $isNoShutdownVMOnClose.inverted,
				label: {
					Text("Shutdown VM on window close")
				}
			).onChange(of: isNoShutdownVMOnClose) { _, newValue in
				if newValue {
					isNoShutdownVMOnClose = newValue
				}
			}

			Toggle(
				isOn: $isClipboardRedirectionEnabled,
				label: {
					Text("Send clipboard data to VM on VNC view")
				}
			).onChange(of: isClipboardRedirectionEnabled) { _, newValue in
				if newValue {
					isClipboardRedirectionEnabled = newValue
				}
			}

			#if DEBUG
			Toggle(
				isOn: $debugVNCMessageEnabled,
				label: {
					Text("Debug VNC messages")
				}
			).onChange(of: debugVNCMessageEnabled) { _, newValue in
				if newValue {
					debugVNCMessageEnabled = newValue
				}
			}
			#endif

		}.formStyle(.grouped)
	}
}

#Preview {
	VMSettingsView()
}
