//
//  ForwardedPortDetailView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import CakeAgentLib
import GRPCLib
import NIOPortForwarding
import SwiftUI

struct ForwardedPortDetailView: View {
	enum ForwardMode: Int, CaseIterable, Hashable {
		case portForwarding
		case unixDomainSocket

		var description: String {
			switch self {
			case .portForwarding:
				return "Port forwarding"
			case .unixDomainSocket:
				return "Unix domain socket"
			}
		}
	}

	enum Proto: String, Sendable, Codable, CaseIterable, Hashable {
		case tcp
		case udp
		case both

		init(_ from: MappedPort.Proto) {
			switch from {
			case .tcp: self = .tcp
			case .udp: self = .udp
			case .both: self = .both
			case .none: self = .tcp
			}
		}

		var proto: MappedPort.Proto {
			switch self {
			case .tcp: return .tcp
			case .udp: return .udp
			case .both: return .both
			}
		}
	}

	class TunnelAttachementModel: ObservableObject, Observable, Equatable {
		static func == (lhs: ForwardedPortDetailView.TunnelAttachementModel, rhs: ForwardedPortDetailView.TunnelAttachementModel) -> Bool {
			lhs.tunnelAttachement == rhs.tunnelAttachement
		}

		@Published var mode: ForwardMode
		@Published var selectedProtocol: Proto
		@Published var hostPath: String?
		@Published var guestPath: String?
		@Published var hostPort: TextFieldStore<Int, RangeIntegerStyle>
		@Published var guestPort: TextFieldStore<Int, RangeIntegerStyle>

		var tunnelAttachement: TunnelAttachement {
			switch mode {
			case .portForwarding:
				return .init(host: hostPort.value, guest: guestPort.value, proto: selectedProtocol.proto)
			case .unixDomainSocket:
				return .init(host: hostPath ?? "", guest: guestPath ?? "", proto: selectedProtocol.proto)
			}
		}

		init(item: Binding<TunnelAttachement>) {
			let hostStyle = RangeIntegerStyle.guestPortRange
			let guestStyle = RangeIntegerStyle.guestPortRange

			if case let .forward(forward) = item.wrappedValue.oneOf {
				self.mode = ForwardMode.portForwarding
				self.selectedProtocol = .init(forward.proto)
				self.hostPort = TextFieldStore(value: forward.host, type: .int, maxLength: 5, allowNegative: false, formatter: hostStyle)
				self.guestPort = TextFieldStore(value: forward.guest, type: .int, maxLength: 5, allowNegative: false, formatter: guestStyle)
			} else if case let .unixDomain(unixDomain) = item.wrappedValue.oneOf {
				self.mode = ForwardMode.unixDomainSocket
				self.selectedProtocol = .init(unixDomain.proto)
				self.hostPath = unixDomain.host
				self.guestPath = unixDomain.guest
				self.hostPort = TextFieldStore(value: 0, text: "", type: .int, maxLength: 5, allowNegative: false, formatter: hostStyle)
				self.guestPort = TextFieldStore(value: 0, text: "", type: .int, maxLength: 5, allowNegative: false, formatter: guestStyle)
			} else {
				self.mode = .portForwarding
				self.selectedProtocol = .both
				self.hostPort = TextFieldStore(value: 0, text: "", type: .int, maxLength: 5, allowNegative: false, formatter: hostStyle)
				self.guestPort = TextFieldStore(value: 0, text: "", type: .int, maxLength: 5, allowNegative: false, formatter: guestStyle)
			}
		}
	}

	@Binding private var currentItem: TunnelAttachement
	@StateObject private var model: TunnelAttachementModel
	private var readOnly: Bool

	init(currentItem: Binding<TunnelAttachement>, readOnly: Bool = true) {
		_currentItem = currentItem
		self._model = StateObject(wrappedValue: TunnelAttachementModel(item: currentItem))
		self.readOnly = readOnly
	}

	var unixDomain: TunnelAttachement.ForwardUnixDomainSocket? {
		guard let hostPath = model.hostPath, let guestPath = model.guestPath else {
			return nil
		}

		return TunnelAttachement.ForwardUnixDomainSocket(proto: model.selectedProtocol.proto, host: hostPath, guest: guestPath)
	}

	var forwardedPort: ForwardedPort? {
		guard model.mode == .portForwarding else {
			return nil
		}

		guard let hostPort = model.hostPort.getValue(), let guestPort = model.guestPort.getValue() else {
			return nil
		}

		return ForwardedPort(proto: model.selectedProtocol.proto, host: hostPort, guest: guestPort)
	}

	var body: some View {
		return VStack {
			LabeledContent("Mode") {
				HStack {
					Spacer()
					Picker("Mode", selection: $model.mode) {
						ForEach(ForwardMode.allCases, id: \.self) { selected in
							Text(selected.description).tag(selected)
						}
					}
					.allowsHitTesting(readOnly == false)
					.labelsHidden()
				}.frame(width: 150)
			}

			LabeledContent("Protocol") {
				HStack {
					Spacer()
					Picker("Protocol", selection: $model.selectedProtocol) {
						ForEach(Proto.allCases, id: \.self) { proto in
							Text(proto.rawValue).tag(proto)
						}
					}
					.allowsHitTesting(readOnly == false)
					.labelsHidden()
				}.frame(width: 150)
			}

			if model.mode == .portForwarding {
				LabeledContent("Host port") {
					HStack {
						Spacer()
						TextField("Host port", text: $model.hostPort.text)
							.multilineTextAlignment(.center)
							.textFieldStyle(.roundedBorder)
							.background(.white)
							.labelsHidden()
							.frame(width: 80)
							.clipShape(RoundedRectangle(cornerRadius: 6))
							.allowsHitTesting(readOnly == false)
							.formatAndValidate($model.hostPort) {
								RangeIntegerStyle.hostPortRange.outside($0)
							}
							.onChange(of: model.hostPort.value) { newValue in
								print("onchange: newValue=\(newValue)")
								self.currentItem.oneOf = model.tunnelAttachement.oneOf
							}
					}
				}

				LabeledContent("Guest port") {
					HStack {
						Spacer()
						TextField("Guest port", text: $model.guestPort.text)
							.multilineTextAlignment(.center)
							.textFieldStyle(.roundedBorder)
							.background(.white)
							.labelsHidden()
							.frame(width: 80)
							.clipShape(RoundedRectangle(cornerRadius: 6))
							.allowsHitTesting(readOnly == false)
							.formatAndValidate($model.guestPort) {
								RangeIntegerStyle.guestPortRange.outside($0)
							}
							.onChange(of: model.guestPort.value) { newValue in
								self.currentItem.oneOf = model.tunnelAttachement.oneOf
							}
					}
				}
			} else {
				LabeledContent("Host path") {
					HStack {
						TextField("Host path", value: $model.hostPath, format: .optional)
							.multilineTextAlignment(.leading)
							.textFieldStyle(.roundedBorder)
							.background(.white)
							.labelsHidden()
							.clipShape(RoundedRectangle(cornerRadius: 6))
							.allowsHitTesting(readOnly == false)

						if readOnly == false {
							Button(action: {
								chooseSocketFile()
							}) {
								Image(systemName: "powerplug")
							}.buttonStyle(.borderless)
						}
					}.frame(width: readOnly ? 450 : 350)
				}

				LabeledContent("Guest path") {
					HStack {
						TextField("Guest path", value: $model.guestPath, format: .optional)
							.multilineTextAlignment(.leading)
							.textFieldStyle(.roundedBorder)
							.background(.white)
							.labelsHidden()
							.clipShape(RoundedRectangle(cornerRadius: 6))
							.allowsHitTesting(readOnly == false)
					}.frame(width: readOnly ? 450 : 350)
				}
			}
		}.onChange(of: model) { newValue in
			self.currentItem.oneOf = newValue.tunnelAttachement.oneOf
		}
	}

	func chooseSocketFile() {
		if let hostPath = FileHelpers.selectSingleInputFile(ofType: [.unixSocketAddress], withTitle: "Select socket file", allowsOtherFileTypes: true) {
			self.model.hostPath = hostPath.absoluteURL.path
		}
	}
}

#Preview {
	ForwardedPortDetailView(currentItem: .constant(.init()))
}
