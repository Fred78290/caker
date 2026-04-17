//
//  AboutApplication.swift
//  Caker
//
//  Created by Frederic BOLTZ on 22/03/2026.
//

import SwiftUI
import GRPCLib

public struct AboutApplication: View {
	var infos: NSAttributedString
	
	public init(config: VirtualMachineConfiguration) {
		let infos = NSMutableAttributedString()
		let style: NSMutableParagraphStyle = NSMutableParagraphStyle()
		
		style.alignment = NSTextAlignment.center
		
		let center: [NSAttributedString.Key: Any] = [.paragraphStyle: style]
		
		infos.append(NSAttributedString(string: String(localized: "CPU: \(config.cpuCount) cores") + "\n", attributes: center))
		infos.append(NSAttributedString(string: String(localized: "Memory: \(ByteCountFormatter.string(fromByteCount: Int64(config.memorySize), countStyle: .memory))") + "\n", attributes: center))
		infos.append(NSAttributedString(string: String(localized: "User: \(config.configuredUser)") + "\n", attributes: center))
		
		if let runningIP = config.runningIP {
			infos.append(NSAttributedString(string: String(localized: "IP: \(runningIP)\n"), attributes: center))
		}
		
		self.infos = infos
	}
	
	public var body: some View {
		Button("About Caked") {
			NSApplication.shared.orderFrontStandardAboutPanel(options: [
				NSApplication.AboutPanelOptionKey.applicationIcon: NSApplication.shared.applicationIconImage as Any,
				NSApplication.AboutPanelOptionKey.applicationName: "Caked",
				NSApplication.AboutPanelOptionKey.applicationVersion: CI.version,
				NSApplication.AboutPanelOptionKey.credits: self.infos,
			])
		}
	}
}

