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

	class TunnelAttachementModel: ObservableObject {
		@Published var mode: ForwardMode
		@Published var selectedProtocol: Proto
		@Published var hostPath: String?
		@Published var guestPath: String?
		@Published var hostPort: NumberStore<Int, RangeIntegerStyle>
		@Published var guestPort: NumberStore<Int, RangeIntegerStyle>

		init(item: Binding<TunnelAttachement>) {

			if case let .forward(forward) = item.wrappedValue.oneOf {
				self.mode = ForwardMode.portForwarding
				self.selectedProtocol = .init(forward.proto)
				self.hostPort = NumberStore(text: "\(forward.host)", type: .int, maxLength: 5, allowNegative: false, formatter: .ranged(((geteuid() == 0 ? 1 : 1024)...65535)))
				self.guestPort =  NumberStore(text: "\(forward.guest)", type: .int, maxLength: 5, allowNegative: false, formatter: .ranged(1...65535))
			} else if case let .unixDomain(unixDomain) = item.wrappedValue.oneOf {
				self.mode = ForwardMode.unixDomainSocket
				self.selectedProtocol = .init(unixDomain.proto)
				self.hostPath = unixDomain.host
				self.guestPath = unixDomain.guest
				self.hostPort = NumberStore(text: "", type: .int, maxLength: 5, allowNegative: false, formatter: .ranged(((geteuid() == 0 ? 1 : 1024)...65535)))
				self.guestPort =  NumberStore(text: "", type: .int, maxLength: 5, allowNegative: false, formatter: .ranged(1...65535))
			} else {
				self.mode = .portForwarding
				self.selectedProtocol = .both
				self.hostPort = NumberStore(text: "", type: .int, maxLength: 5, allowNegative: false, formatter: .ranged(((geteuid() == 0 ? 1 : 1024)...65535)))
				self.guestPort =  NumberStore(text: "", type: .int, maxLength: 5, allowNegative: false, formatter: .ranged(1...65535))
			}
		}
	}

	@Binding private var currentItem: TunnelAttachement
	@State private var model: TunnelAttachementModel

	init(currentItem: Binding<TunnelAttachement>) {
		_currentItem = currentItem
		self.model = .init(item: currentItem)
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
					}.labelsHidden()
				}.frame(width: 150)
			}

			LabeledContent("Protocol") {
				HStack {
					Picker("Protocol", selection: $model.selectedProtocol) {
						ForEach(Proto.allCases, id: \.self) { proto in
							Text(proto.rawValue).tag(proto).frame(width: 100)
						}
					}.labelsHidden()
				}.frame(width: 150)
			}.onChange(of: model.selectedProtocol) { newValue in
				if model.mode == .portForwarding {
					if let forwardedPort = self.forwardedPort {
						currentItem.oneOf = .forward(ForwardedPort(proto: newValue.proto, host: forwardedPort.host, guest: forwardedPort.guest))
					}
				} else {
					if let unixDomain = self.unixDomain {
						currentItem.oneOf = .unixDomain(TunnelAttachement.ForwardUnixDomainSocket(proto: newValue.proto, host: unixDomain.host, guest: unixDomain.guest))
					}
				}
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
						.formatAndValidate(model.hostPort) {
							((geteuid() == 0 ? 1 : 1024)...65535).contains($0)
						}
						.onChange(of: model.hostPort.text) { _ in
							if let forwardedPort = self.forwardedPort, let newValue = model.hostPort.getValue() {
								currentItem.oneOf = .forward(ForwardedPort(proto: forwardedPort.proto, host: newValue, guest: forwardedPort.guest))
							}
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
						.formatAndValidate(model.hostPort) {
							(1...65535).contains($0)
						}
						.onChange(of: model.guestPort.text) { _ in
							if let forwardedPort = self.forwardedPort, let newValue = model.guestPort.getValue()  {
								currentItem.oneOf = .forward(ForwardedPort(proto: forwardedPort.proto, host: forwardedPort.host, guest: newValue))
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
							.onChange(of: model.hostPath) { newValue in
								if let unixDomain = self.unixDomain {
									currentItem.oneOf = .unixDomain(TunnelAttachement.ForwardUnixDomainSocket(proto: unixDomain.proto, host: newValue ?? "", guest: unixDomain.guest))
								}
							}
						Button(action: {
							chooseSocketFile()
						}) {
							Image(systemName: "powerplug")
						}.buttonStyle(.borderless)
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
							.onChange(of: model.guestPath) { newValue in
								if let unixDomain = self.unixDomain {
									currentItem.oneOf = .unixDomain(TunnelAttachement.ForwardUnixDomainSocket(proto: unixDomain.proto, host: unixDomain.host, guest: newValue ?? ""))
								}
							}
					}.frame(maxWidth: 600)
				}
			}
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
