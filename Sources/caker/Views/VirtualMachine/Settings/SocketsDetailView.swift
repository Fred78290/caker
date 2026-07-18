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
		if readOnly {
			compactRow
		} else {
			fullForm
		}
	}

	@ViewBuilder
	var compactRow: some View {
		HStack(spacing: 10) {
			ZStack {
				RoundedRectangle(cornerRadius: 7)
					.fill(Color.purple.gradient)
					.frame(width: 28, height: 28)
				Image(systemName: "powerplug")
					.font(.system(size: 12, weight: .semibold))
					.foregroundStyle(.white)
			}

			VStack(alignment: .leading, spacing: 2) {
				Text(currentItem.bind)
					.font(.system(size: 12, design: .monospaced))
					.lineLimit(1)
				HStack(spacing: 6) {
					Text(currentItem.mode.description)
						.font(.system(size: 11))
						.foregroundStyle(.secondary)
					Text("port \(currentItem.port)")
						.font(.system(size: 11, design: .monospaced))
						.foregroundStyle(.secondary)
				}
			}

			Spacer()
		}
		.padding(.vertical, 4)
	}

	@ViewBuilder
	var fullForm: some View {
		VStack {
			LabeledContent("Socket mode") {
				HStack {
					Spacer()
					Picker("Socket mode", selection: $currentItem.mode) {
						ForEach(SocketMode.allCases, id: \.self) { mode in
							Text(mode.description).tag(mode)
						}
					}
					.labelsHidden()
				}.frame(width: 100)
			}

			LabeledContent("Host path") {
				HStack {
					Button(action: chooseSocketFile) {
						Image(systemName: "powerplug")
					}.buttonStyle(.borderless)
					TextField("Host path", text: $currentItem.bind)
						.rounded(.leading)
				}.frame(width: 350)
			}

			LabeledContent("Guest port") {
				TextField("Guest port", text: $port.text)
					.rounded(.center)
					.frame(width: 50)
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
		if let hostPath = FileHelpers.selectSingleInputFile(ofType: [.unixSocketAddress], withTitle: String(localized: "Choose a socket file"), allowsOtherFileTypes: true, directoryURL: try? Utils.getHome(runMode: .current)) {
			self.currentItem.bind = hostPath.absoluteURL.path
		}
	}
}

#Preview {
	SocketsDetailView(currentItem: .constant(.init(mode: .bind, port: 0, bind: String.empty)))
}
