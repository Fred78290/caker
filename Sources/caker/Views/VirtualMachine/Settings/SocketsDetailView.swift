//
//  SocketsDetailView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import SwiftUI
import GRPCLib

struct SocketsDetailView: View {
	@Binding private var currentItem: SocketDevice
	@State private var model: SocketDeviceModel

	private class SocketDeviceModel: ObservableObject {
		@Published var mode: SocketMode
		@Published var port: NumberStore<Int, RangeIntegerStyle>
		@Published var bind: String
		
		init(item: SocketDevice) {
			self.mode = item.mode
			self.port = NumberStore(text: "\(item.port)", type: .int, maxLength: 5, allowNegative: false, formatter: .ranged((geteuid() == 0 ? 1 : 1024)...65535))
			self.bind = item.bind
		}
	}

	init(currentItem: Binding<SocketDevice>) {
		_currentItem = currentItem
		self.model = .init(item: currentItem.wrappedValue)
	}

	var body: some View {
		VStack {
			LabeledContent("Socket mode") {
				Picker("Socket mode", selection: $model.mode) {
					ForEach(SocketMode.allCases, id: \.self) { mode in
						Text(mode.description).tag(mode).frame(width: 100)
					}
				}
				.labelsHidden()
				.onChange(of: model.mode) { newValue in
					currentItem.mode = newValue
				}
			}

			LabeledContent("Guest port") {
				TextField("Guest port", text: $model.port.text)
					.multilineTextAlignment(.center)
					.textFieldStyle(.roundedBorder)
					.background(.white)
					.labelsHidden()
					.frame(width: 50)
					.clipShape(RoundedRectangle(cornerRadius: 6))
					.formatAndValidate(model.port) {
						((geteuid() == 0 ? 1 : 1024)...65535).contains($0)
					}
					.onChange(of: model.port.text) { newValue in
						if let newValue = model.port.getValue() {
							currentItem.port = newValue
						}
					}
			}

			LabeledContent("Host path") {
				HStack {
					TextField("Host path", text: $model.bind)
						.multilineTextAlignment(.leading)
						.textFieldStyle(.roundedBorder)
						.background(.white)
						.labelsHidden()
						.clipShape(RoundedRectangle(cornerRadius: 6))
						.onChange(of: model.bind) { newValue in
							currentItem.bind = newValue
						}
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
			self.model.bind = hostPath.absoluteURL.path
		}
	}
}

#Preview {
	SocketsDetailView(currentItem: .constant(.init(mode: .bind, port: 0, bind: "")))
}
