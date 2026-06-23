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

	#if USE_VIRTUAL_INSTALL_BACKEND
	@AppStorage("CakerForceVirtualInstallBackend") var forceVirtualInstallBackend: Bool = false
	#endif

	var body: some View {
		Form {
			Section {
				Toggle(isOn: $launchVMExternally.inverted) {
					Label("Launch inside app", systemImage: "macwindow")
				}
				.onChange(of: launchVMExternally) { _, newValue in
					if newValue { launchVMExternally = true }
				}

				Toggle(isOn: $isNoShutdownVMOnClose.inverted) {
					Label("Shutdown on window close", systemImage: "power")
				}
				.onChange(of: isNoShutdownVMOnClose) { _, newValue in
					if newValue { isNoShutdownVMOnClose = newValue }
				}
			} header: {
				Label("Window", systemImage: "macwindow")
			}

			Section {
				Toggle(isOn: $isNoScreenshot.inverted) {
					Label("Enable screenshotting", systemImage: "camera.viewfinder")
				}
				.onChange(of: isNoScreenshot) { _, newValue in
					if newValue { isNoScreenshot = newValue }
				}

				Toggle(isOn: $isNoSaveScreenshot.inverted) {
					Label("Save screenshots to disk", systemImage: "photo.on.rectangle")
				}
				.onChange(of: isNoSaveScreenshot) { _, newValue in
					if newValue { isNoSaveScreenshot = newValue }
				}
			} header: {
				Label("Screenshots", systemImage: "camera")
			}

			Section {
				Toggle(isOn: $isClipboardRedirectionEnabled) {
					Label("Send clipboard to VM", systemImage: "clipboard")
				}
				.onChange(of: isClipboardRedirectionEnabled) { _, newValue in
					if newValue { isClipboardRedirectionEnabled = newValue }
				}
			} header: {
				Label("VNC", systemImage: "play.display")
			}

			#if USE_VIRTUAL_INSTALL_BACKEND
			Section {
				Toggle(isOn: $forceVirtualInstallBackend) {
					Label("Use DFU restore mode", systemImage: "arrow.down.circle")
				}
				.onChange(of: forceVirtualInstallBackend) { _, newValue in
					if newValue { forceVirtualInstallBackend = newValue }
				}
			} header: {
				Label("Restore", systemImage: "arrow.down.circle")
			}
			#endif

			#if DEBUG
			Section {
				Toggle(isOn: $debugVNCMessageEnabled) {
					Label("Debug VNC messages", systemImage: "ladybug")
				}
				.onChange(of: debugVNCMessageEnabled) { _, newValue in
					if newValue { debugVNCMessageEnabled = newValue }
				}
			} header: {
				Label("Debug", systemImage: "ant")
			}
			#endif
		}
		.formStyle(.grouped)
		.scrollDisabled(true)
		.fixedSize(horizontal: false, vertical: true)
	}
}

#Preview {
	VMSettingsView()
}
