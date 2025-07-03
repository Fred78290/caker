//
//  SocketsDetailView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import SwiftUI
import GRPCLib

struct SocketsDetailView: View {
	@StateObject private var model: SocketDeviceModel

	private class SocketDeviceModel: ObservableObject {
		@Binding private var currentItem: SocketDevice

		@Published var mode: SocketMode {
			didSet {
				self.currentItem.mode = self.mode
			}
		}

		@Published var port: NumberStore<Int, RangeIntegerStyle> {
			didSet {
				if let value = self.port.getValue() {
					self.currentItem.port = value
				}
			}
		}

		@Published var bind: String {
			didSet {
				self.currentItem.bind = self.bind
			}
		}

		init(item: Binding<SocketDevice>) {
			let wrappedValue = item.wrappedValue
			self._currentItem = item
			self.mode = wrappedValue.mode
			self.port = NumberStore(text: "\(wrappedValue.port)", type: .int, maxLength: 5, allowNegative: false, formatter: .ranged((geteuid() == 0 ? 1 : 1024)...65535))
			self.bind = wrappedValue.bind
		}
		
		func update() {
			self.currentItem.mode = self.mode
			self.currentItem.port = self.port.getValue() ?? 0
			self.currentItem.bind = self.bind
		}
	}

	init(currentItem: Binding<SocketDevice>) {
		self._model = StateObject(wrappedValue: SocketDeviceModel(item: currentItem))
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
			}

			LabeledContent("Host path") {
				HStack {
					TextField("Host path", text: $model.bind)
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
			self.model.bind = hostPath.absoluteURL.path
		}
	}
}

#Preview {
	SocketsDetailView(currentItem: .constant(.init(mode: .bind, port: 0, bind: "")))
}
