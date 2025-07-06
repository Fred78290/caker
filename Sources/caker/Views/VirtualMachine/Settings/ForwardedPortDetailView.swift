//
//  ForwardedPortDetailView.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/06/2025.
//

import SwiftUI
import GRPCLib
import CakeAgentLib
import NIOPortForwarding

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

	struct TunnelAttachementModel: Equatable {
		static func == (lhs: ForwardedPortDetailView.TunnelAttachementModel, rhs: ForwardedPortDetailView.TunnelAttachementModel) -> Bool {
			lhs.tunnelAttachement == rhs.tunnelAttachement
		}
		
		var mode: ForwardMode
		var selectedProtocol: Proto
		var hostPath: String?
		var guestPath: String?
		var hostPort: NumberStore<Int, IntegerFormatStyle<Int>>
		var guestPort: NumberStore<Int, IntegerFormatStyle<Int>>

		var tunnelAttachement: TunnelAttachement {
			switch mode {
			case .portForwarding:
				return .init(host: hostPort.value, guest: guestPort.value, proto: selectedProtocol.proto)
			case .unixDomainSocket:
				return .init(host: hostPath ?? "", guest: guestPath ?? "", proto: selectedProtocol.proto)
			}
		}

		init(item: Binding<TunnelAttachement>) {
			let hostStyle = IntegerFormatStyle<Int>.number //RangeIntegerStyle.ranged(((geteuid() == 0 ? 1 : 1024)...65535))
			let guestStyle = IntegerFormatStyle<Int>.number //RangeIntegerStyle.ranged(1...65535)

			if case let .forward(forward) = item.wrappedValue.oneOf {
				self.mode = ForwardMode.portForwarding
				self.selectedProtocol = .init(forward.proto)
				self.hostPort = NumberStore(value: forward.host, type: .int, maxLength: 5, allowNegative: false, formatter: hostStyle)
				self.guestPort =  NumberStore(value: forward.guest, type: .int, maxLength: 5, allowNegative: false, formatter: guestStyle)
			} else if case let .unixDomain(unixDomain) = item.wrappedValue.oneOf {
				self.mode = ForwardMode.unixDomainSocket
				self.selectedProtocol = .init(unixDomain.proto)
				self.hostPath = unixDomain.host
				self.guestPath = unixDomain.guest
				self.hostPort = NumberStore(value: 0, text: "", type: .int, maxLength: 5, allowNegative: false, formatter: hostStyle)
				self.guestPort =  NumberStore(value: 0, text: "", type: .int, maxLength: 5, allowNegative: false, formatter: guestStyle)
			} else {
				self.mode = .portForwarding
				self.selectedProtocol = .both
				self.hostPort = NumberStore(value: 0, text: "", type: .int, maxLength: 5, allowNegative: false, formatter: hostStyle)
				self.guestPort =  NumberStore(value: 0, text: "", type: .int, maxLength: 5, allowNegative: false, formatter: guestStyle)
			}
		}
	}

	@Binding private var currentItem: TunnelAttachement
	@State private var model: TunnelAttachementModel
	private var readOnly: Bool

	init(currentItem: Binding<TunnelAttachement>, readOnly: Bool = true) {
		_currentItem = currentItem
		self.model = .init(item: currentItem)
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
		VStack {
			LabeledContent("Mode") {
				HStack {
					Picker("Mode", selection: $model.mode) {
						ForEach(ForwardMode.allCases, id: \.self) { selected in
							Text(selected.description).tag(selected).frame(width: 100)
						}
					}
					.allowsHitTesting(readOnly == false)
					.labelsHidden()
				}.frame(width: 150)
			}

			LabeledContent("Protocol") {
				HStack {
					Picker("Protocol", selection: $model.selectedProtocol) {
						ForEach(Proto.allCases, id: \.self) { proto in
							Text(proto.rawValue).tag(proto).frame(width: 100)
						}
					}
					.allowsHitTesting(readOnly == false)
					.labelsHidden()
				}.frame(width: 150)
			}

			if model.mode == .portForwarding {
				LabeledContent("Host port") {
					TextField("Host port", text: $model.hostPort.text)
						.multilineTextAlignment(.center)
						.textFieldStyle(.roundedBorder)
						.background(.white)
						.labelsHidden()
						.frame(width: 80)
						.clipShape(RoundedRectangle(cornerRadius: 6))
						.allowsHitTesting(readOnly == false)
						.formatAndValidate(model.hostPort) {
							RangeIntegerStyle.hostPortRange.inRange($0)
						}
						.onChange(of: model.hostPort.value) { newValue in
							self.currentItem.oneOf = model.tunnelAttachement.oneOf
						}
				}

				LabeledContent("Guest port") {
					TextField("Guest port", text: $model.guestPort.text)
						.multilineTextAlignment(.center)
						.textFieldStyle(.roundedBorder)
						.background(.white)
						.labelsHidden()
						.frame(width: 80)
						.clipShape(RoundedRectangle(cornerRadius: 6))
						.allowsHitTesting(readOnly == false)
						.formatAndValidate(model.guestPort) {
							RangeIntegerStyle.guestPortRange.inRange($0)
						}
						.onChange(of: model.guestPort.value) { newValue in
							self.currentItem.oneOf = model.tunnelAttachement.oneOf
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
					}.frame(maxWidth: 600)
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
					}.frame(maxWidth: 600)
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
