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
	enum ForwardMode: String, CaseIterable, Hashable {
		case portForwarding = "Port forwarding"
		case unixDomainSocket = "Unix domain socket"
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

	@Binding var currentItem: TunnelAttachement

	@State private var mode = ForwardMode.portForwarding
	@State private var selectedProtocol = Proto.tcp
	@State private var hostPath: String? = nil
	@State private var guestPath: String? = nil
	@State private var hostPort: Int? = nil
	@State private var guestPort: Int? = nil

	init(currentItem: Binding<TunnelAttachement>) {
		_currentItem = currentItem
		
		if case let .forward(forward) = currentItem.wrappedValue.oneOf {
			self.mode = ForwardMode.portForwarding
			self.selectedProtocol = .init(forward.proto)
			self.hostPort = forward.host
			self.guestPort = forward.guest
		} else if case let .unixDomain(unixDomain) = currentItem.wrappedValue.oneOf {
			self.mode = ForwardMode.unixDomainSocket
			self.selectedProtocol = .init(unixDomain.proto)
			self.hostPath = unixDomain.host
			self.guestPath = unixDomain.guest
		}
	}

	var unixDomain: TunnelAttachement.ForwardUnixDomainSocket? {
		guard let hostPath = hostPath, let guestPath = guestPath else {
			return nil
		}

		return TunnelAttachement.ForwardUnixDomainSocket(proto: selectedProtocol.proto, host: hostPath, guest: guestPath)
	}

	var forwardedPort: ForwardedPort? {
		guard let hostPort = hostPort, let guestPort = guestPort else {
			return nil
		}

		return ForwardedPort(proto: selectedProtocol.proto, host: hostPort, guest: guestPort)
	}

	var body: some View {
		VStack {
			HStack {
				Text("Mode")
				Spacer()
				HStack {
					Spacer()
					Picker("Mode", selection: $mode) {
						ForEach(ForwardMode.allCases, id: \.self) { selected in
							Text(selected.rawValue).tag(selected)
						}
					}.labelsHidden().frame(width: 50)
				}.frame(width: 300)
			}

			HStack {
				Text("Protocol")
				Spacer()
				HStack {
					Spacer()
					Picker("Protocol", selection: $selectedProtocol) {
						ForEach(Proto.allCases, id: \.self) { proto in
							Text(proto.rawValue).tag(proto)
						}
					}.labelsHidden().frame(width: 50)
				}.frame(width: 300)
			}

			if mode == .portForwarding {
				HStack {
					Text("Host port")
					Spacer()
					HStack {
						TextField("Host port", value: $hostPort, format: .ranged((geteuid() == 0 ? 0 : 1024)...65535))
							.multilineTextAlignment(.center)
							.textFieldStyle(SquareBorderTextFieldStyle())
							.labelsHidden()
							.frame(width: 50)
							.onChange(of: hostPort) { newValue in
								if let forwardedPort = self.forwardedPort {
									currentItem.oneOf = .forward(forwardedPort)
								}
							}
					}
				}

				HStack {
					Text("Guest port")
					Spacer()
					HStack {
						TextField("", value: $guestPort, format: .ranged(1...65535))
							.multilineTextAlignment(.center)
							.textFieldStyle(SquareBorderTextFieldStyle())
							.labelsHidden()
							.frame(width: 50)
							.onChange(of: guestPort) { newValue in
								if let forwardedPort = self.forwardedPort {
									currentItem.oneOf = .forward(forwardedPort)
								}
							}
					}
				}
			} else {
				HStack {
					Text("Host path")
					Spacer()
					HStack {
						TextField("", value: $hostPath, format: .optional)
							.multilineTextAlignment(.leading)
							.textFieldStyle(SquareBorderTextFieldStyle())
							.labelsHidden()
							.onChange(of: hostPath) { newValue in
								if let unixDomain = self.unixDomain {
									currentItem.oneOf = .unixDomain(unixDomain)
								}
							}
						Button(action: {
							chooseSocketFile()
						}) {
							Image(systemName: "powerplug")
						}.buttonStyle(.borderless)
					}.frame(width: 300)
				}

				HStack {
					Text("Guest path")
					Spacer()
					HStack {
						TextField("Guest path", value: $guestPath, format: .optional)
							.multilineTextAlignment(.leading)
							.textFieldStyle(SquareBorderTextFieldStyle())
							.labelsHidden()
							.onChange(of: guestPath) { newValue in
								if let unixDomain = self.unixDomain {
									currentItem.oneOf = .unixDomain(unixDomain)
								}
							}
					}.frame(width: 300)
				}
			}
		}
    }
	
	func chooseSocketFile() {
		if let hostPath = FileHelpers.selectSingleInputFile(ofType: [.unixSocketAddress], withTitle: "Select socket file", allowsOtherFileTypes: true) {
			self.hostPath = hostPath.absoluteURL.path
		}
	}
}

#Preview {
	ForwardedPortDetailView(currentItem: .constant(.init()))
}
