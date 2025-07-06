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
	@State var port: NumberStore<Int, RangeIntegerStyle>

	private var readOnly: Bool

	init(currentItem: Binding<SocketDevice>, readOnly: Bool = true) {
		self._currentItem = currentItem
		self.readOnly = readOnly
		self.port = NumberStore(value: currentItem.wrappedValue.port, type: .int, maxLength: 5, allowNegative: false, formatter: .ranged(((geteuid() == 0 ? 1 : 1024)...65535)))
	}

	var body: some View {
		VStack {
			LabeledContent("Socket mode") {
				Picker("Socket mode", selection: $currentItem.mode) {
					ForEach(SocketMode.allCases, id: \.self) { mode in
						Text(mode.description).tag(mode).frame(width: 100)
					}
				}
				.allowsHitTesting(readOnly == false)
				.labelsHidden()
			}

			LabeledContent("Guest port") {
				TextField("Guest port", text: $port.text)
					.multilineTextAlignment(.center)
					.textFieldStyle(.roundedBorder)
					.background(.white)
					.labelsHidden()
					.frame(width: 50)
					.clipShape(RoundedRectangle(cornerRadius: 6))
					.allowsHitTesting(readOnly == false)
					.formatAndValidate(port) {
						RangeIntegerStyle.guestPortRange.inRange($0)
					}
					.onChange(of: port.value) { newValue in
						self.currentItem.port = newValue
					}
			}

			LabeledContent("Host path") {
				HStack {
					TextField("Host path", text: $currentItem.bind)
						.multilineTextAlignment(.leading)
						.textFieldStyle(.roundedBorder)
						.background(.white)
						.labelsHidden()
						.allowsHitTesting(readOnly == false)
						.clipShape(RoundedRectangle(cornerRadius: 6))

					if readOnly == false {
						Button(action: {
							chooseSocketFile()
						}) {
							Image(systemName: "powerplug")
						}.buttonStyle(.borderless)
					}
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
