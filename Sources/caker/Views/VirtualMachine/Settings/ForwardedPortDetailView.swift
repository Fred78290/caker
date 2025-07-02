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
		@Published var hostPort: Int?
		@Published var guestPort: Int?

		init(mode: ForwardMode, selectedProtocol: Proto, hostPath: String? = nil, guestPath: String? = nil, hostPort: Int? = nil, guestPort: Int? = nil) {
			self.mode = mode
			self.selectedProtocol = selectedProtocol
			self.hostPath = hostPath
			self.guestPath = guestPath
			self.hostPort = hostPort
			self.guestPort = guestPort
		}
	}

	@Binding var currentItem: TunnelAttachement
	@State var model: TunnelAttachementModel
	/*
	@State private var mode: ForwardMode
	@State private var selectedProtocol: Proto
	@State private var hostPath: String?
	@State private var guestPath: String?
	@State private var hostPort: Int?
	@State private var guestPort: Int?*/

	init(currentItem: Binding<TunnelAttachement>) {
		_currentItem = currentItem
		
		var mode: ForwardMode = ForwardMode.portForwarding
		var selectedProtocol: Proto = .both
		var hostPath: String? = nil
		var guestPath: String? = nil
		var hostPort: Int? = nil
		var guestPort: Int? = nil

		if case let .forward(forward) = currentItem.wrappedValue.oneOf {
			mode = ForwardMode.portForwarding
			selectedProtocol = .init(forward.proto)
			hostPort = forward.host
			guestPort = forward.guest
		} else if case let .unixDomain(unixDomain) = currentItem.wrappedValue.oneOf {
			mode = ForwardMode.unixDomainSocket
			selectedProtocol = .init(unixDomain.proto)
			hostPath = unixDomain.host
			guestPath = unixDomain.guest
		}
		
		self.model = .init(mode: mode, selectedProtocol: selectedProtocol, hostPath: hostPath, guestPath: guestPath, hostPort: hostPort, guestPort: guestPort)
/*		self.mode = mode
		self.selectedProtocol = selectedProtocol
		self.hostPath = hostPath
		self.guestPath = guestPath
		self.hostPort = hostPort
		self.guestPort = guestPort*/
		
		print(self.model)
	}

	var unixDomain: TunnelAttachement.ForwardUnixDomainSocket? {
		guard let hostPath = model.hostPath, let guestPath = model.guestPath else {
			return nil
		}

		return TunnelAttachement.ForwardUnixDomainSocket(proto: model.selectedProtocol.proto, host: hostPath, guest: guestPath)
	}

	var forwardedPort: ForwardedPort? {
		guard let hostPort = model.hostPort, let guestPort = model.guestPort else {
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
					TextField("Host port", value: $model.hostPort, format: .ranged((geteuid() == 0 ? 0 : 1024)...65535))
						.multilineTextAlignment(.center)
						.textFieldStyle(.roundedBorder)
						.background(.white)
						.labelsHidden()
						.frame(width: 80)
						.clipShape(RoundedRectangle(cornerRadius: 6))
						.onChange(of: model.hostPort) { newValue in
							if let forwardedPort = self.forwardedPort {
								currentItem.oneOf = .forward(ForwardedPort(proto: forwardedPort.proto, host: newValue ?? -1, guest: forwardedPort.guest))
							}
						}
				}

				LabeledContent("Guest port") {
					TextField("Guest port", value: $model.guestPort, format: .ranged(1...65535))
						.multilineTextAlignment(.center)
						.textFieldStyle(.roundedBorder)
						.background(.white)
						.labelsHidden()
						.frame(width: 80)
						.clipShape(RoundedRectangle(cornerRadius: 6))
						.onChange(of: model.guestPort) { newValue in
							if let forwardedPort = self.forwardedPort {
								currentItem.oneOf = .forward(ForwardedPort(proto: forwardedPort.proto, host: forwardedPort.host, guest: newValue ?? -1))
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
