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
			HStack {
				Text("Socket mode")
				Spacer()
				HStack {
					Spacer()
					Picker("Socket mode", selection: $currentItem.mode) {
						ForEach(SocketMode.allCases, id: \.self) { mode in
							Text(mode.description).tag(mode)
						}
					}.labelsHidden().frame(width: 80)
				}.frame(width: 300)
			}

			HStack {
				Text("Socket port")
				Spacer()
				TextField("", value: $currentItem.port, format: .ranged((geteuid() == 0 ? 0 : 1024)...65535))
					.multilineTextAlignment(.center)
					.textFieldStyle(SquareBorderTextFieldStyle())
					.labelsHidden()
					.frame(width: 50)
			}
			
			HStack {
				Text("Socket path")
				Spacer()
				HStack {
					TextField("", text: $currentItem.bind)
						.multilineTextAlignment(.leading)
						.textFieldStyle(SquareBorderTextFieldStyle())
						.labelsHidden()
						.frame(width: 270)
					Button(action: {
						chooseSocketFile()
					}) {
						Image(systemName: "powerplug")
					}.buttonStyle(.borderless)
				}.frame(width: 300)
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
