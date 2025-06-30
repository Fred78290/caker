//
//  SocketsDetailView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import SwiftUI
import GRPCLib

struct SocketsDetailView: View {
	@Binding var currentItem: SocketDevice
	
	var body: some View {
		VStack {
			LabeledContent("Socket mode") {
				Picker("Socket mode", selection: $currentItem.mode) {
					ForEach(SocketMode.allCases, id: \.self) { mode in
						Text(mode.description).tag(mode).frame(width: 100)
					}
				}.labelsHidden()
			}

			LabeledContent("Guest port") {
				TextField("", value: $currentItem.port, format: .ranged((geteuid() == 0 ? 0 : 1024)...65535))
					.multilineTextAlignment(.center)
					.textFieldStyle(.roundedBorder)
					.background(.white)
					.labelsHidden()
					.frame(width: 50)
					.clipShape(RoundedRectangle(cornerRadius: 6))
			}

			LabeledContent("Host path") {
				HStack {
					TextField("", text: $currentItem.bind)
						.multilineTextAlignment(.leading)
						.textFieldStyle(.roundedBorder)
						.background(.white)
						.labelsHidden()
						.clipShape(RoundedRectangle(cornerRadius: 6))
					Button(action: {
						chooseSocketFile()
					}) {
						Image(systemName: "powerplug")
					}.buttonStyle(.borderless)
				}
			}
		}
	}
	
	func chooseSocketFile() {
		if let hostPath = FileHelpers.selectSingleInputFile(ofType: [.unixSocketAddress], withTitle: "Select socket file", allowsOtherFileTypes: true) {
			self.currentItem.bind = hostPath.absoluteURL.path
		}
	}
}

#Preview {
	SocketsDetailView(currentItem: .constant(.init(mode: .bind, port: 0, bind: "")))
}
