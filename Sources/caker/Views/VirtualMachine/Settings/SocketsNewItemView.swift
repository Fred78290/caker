//
//  SocketsNewItemView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import SwiftUI
import GRPCLib

struct SocketsNewItemView: View {
	@Binding var sockets: [SocketDevice]
	@State var newItem: SocketDevice = .init(mode: .bind, port: 0, bind: "")
	@State var vsockPort: Int? = nil

	var body: some View {
		EditableListNewItem(newItem: $newItem, $sockets) {
			Section("New socket endpoint") {
				Picker("Socket mode", selection: $newItem.mode) {
					ForEach(SocketMode.allCases, id: \.self) { mode in
						Text(mode.description).tag(mode)
					}
				}

				HStack {
					Text("Socket port")
					Spacer()
					TextField("", value: $vsockPort, format: .number)
						.multilineTextAlignment(.center)
						.textFieldStyle(SquareBorderTextFieldStyle())
						.labelsHidden()
						.frame(width: 50)
						.onChange(of: vsockPort) {
							if let vsockPort = vsockPort {
								newItem.port = vsockPort
							} else {
								newItem.port = -1
							}
						}
				}

				HStack {
					Text("Host bind to socket")
					Spacer()
					HStack {
						TextField("", text: $newItem.bind)
							.multilineTextAlignment(.leading)
							.textFieldStyle(SquareBorderTextFieldStyle())
							.labelsHidden()
					}.frame(width: 300)
				}
			}
		}
    }
}

#Preview {
    SocketsNewItemView(sockets: .constant([]))
}
