//
//  SocketsDetailView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import GRPCLib
import SwiftUI

struct SocketsDetailView: View {
	@Binding private var currentItem: SocketDevice
	@State var port: TextFieldStore<Int, RangeIntegerStyle>

	private var readOnly: Bool

	init(currentItem: Binding<SocketDevice>, readOnly: Bool = true) {
		self._currentItem = currentItem
		self.readOnly = readOnly
		self.port = TextFieldStore(value: currentItem.wrappedValue.port, type: .int, maxLength: 5, allowNegative: false, formatter: RangeIntegerStyle.guestPortRange)
	}

	var body: some View {
		VStack {
			LabeledContent("Socket mode") {
				HStack {
					Spacer()
					Picker("Socket mode", selection: $currentItem.mode) {
						ForEach(SocketMode.allCases, id: \.self) { mode in
							Text(mode.description).tag(mode)
						}
					}
					.allowsHitTesting(readOnly == false)
					.labelsHidden()
				}.frame(width: 100)
			}

			LabeledContent("Host path") {
				HStack {
					if readOnly == false {
						Button(action: {
							chooseSocketFile()
						}) {
							Image(systemName: "powerplug")
						}.buttonStyle(.borderless)
					}
					TextField("Host path", text: $currentItem.bind)
						.rounded(.leading)
						.allowsHitTesting(readOnly == false)
				}.frame(width: readOnly ? 450 : 350)
			}

			LabeledContent("Guest port") {
				TextField("Guest port", text: $port.text)
					.rounded(.center)
					.frame(width: 50)
					.allowsHitTesting(readOnly == false)
					.formatAndValidate($port) {
						RangeIntegerStyle.guestPortRange.outside($0)
					}
					.onChange(of: port.value) { _, newValue in
						self.currentItem.port = newValue
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
