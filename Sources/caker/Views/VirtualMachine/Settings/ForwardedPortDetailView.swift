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
				return String(localized: "Port forwarding")
			case .unixDomainSocket:
				return String(localized: "Unix domain socket")
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

	enum WellKnownService: Int, CaseIterable, Hashable {
		case custom = 0
		case ftp = 21
		case ssh = 22
		case telnet = 23
		case smtp = 25
		case dns = 53
		case http = 80
		case pop3 = 110
		case ntp = 123
		case imap = 143
		case snmp = 161
		case ldap = 389
		case https = 443
		case smtps = 465
		case syslog = 514
		case ldaps = 636
		case imaps = 993
		case pop3s = 995
		case mysql = 3306
		case rdp = 3389
		case postgresql = 5432
		case vnc = 5900
		case httpAlt = 8080

		init(port: Int) {
			self = WellKnownService(rawValue: port) ?? .custom
		}

		var description: String {
			switch self {
			case .custom: return String(localized: "Custom")
			case .ftp: return "FTP (21)"
			case .ssh: return "SSH (22)"
			case .telnet: return "Telnet (23)"
			case .smtp: return "SMTP (25)"
			case .dns: return "DNS (53)"
			case .http: return "HTTP (80)"
			case .pop3: return "POP3 (110)"
			case .ntp: return "NTP (123)"
			case .imap: return "IMAP (143)"
			case .snmp: return "SNMP (161)"
			case .ldap: return "LDAP (389)"
			case .https: return "HTTPS (443)"
			case .smtps: return "SMTPS (465)"
			case .syslog: return "Syslog (514)"
			case .ldaps: return "LDAPS (636)"
			case .imaps: return "IMAPS (993)"
			case .pop3s: return "POP3S (995)"
			case .mysql: return "MySQL (3306)"
			case .rdp: return "RDP (3389)"
			case .postgresql: return "PostgreSQL (5432)"
			case .vnc: return "VNC (5900)"
			case .httpAlt: return "HTTP alt (8080)"
			}
		}
	}

	@Observable class TunnelAttachementModel: Equatable {
		static func == (lhs: ForwardedPortDetailView.TunnelAttachementModel, rhs: ForwardedPortDetailView.TunnelAttachementModel) -> Bool {
			lhs.tunnelAttachement == rhs.tunnelAttachement
		}

		var mode: ForwardMode
		var selectedProtocol: Proto
		var hostPath: String?
		var guestPath: String?
		var hostPort: TextFieldStore<Int, RangeIntegerStyle>
		var guestPort: TextFieldStore<Int, RangeIntegerStyle>
		var wellKnownService: WellKnownService = .custom

		var tunnelAttachement: TunnelAttachement {
			switch mode {
			case .portForwarding:
				return .init(host: hostPort.value, guest: guestPort.value, proto: selectedProtocol.proto)
			case .unixDomainSocket:
				return .init(host: hostPath ?? String.empty, guest: guestPath ?? String.empty, proto: selectedProtocol.proto)
			}
		}

		init(item: Binding<TunnelAttachement>) {
			let hostStyle = RangeIntegerStyle.guestPortRange
			let guestStyle = RangeIntegerStyle.guestPortRange

			if case .forward(let forward) = item.wrappedValue.oneOf {
				self.mode = ForwardMode.portForwarding
				self.selectedProtocol = .init(forward.proto)
				self.hostPort = TextFieldStore(value: forward.host, type: .int, maxLength: 5, allowNegative: false, formatter: hostStyle)
				self.guestPort = TextFieldStore(value: forward.guest, type: .int, maxLength: 5, allowNegative: false, formatter: guestStyle)
			} else if case .unixDomain(let unixDomain) = item.wrappedValue.oneOf {
				self.mode = ForwardMode.unixDomainSocket
				self.selectedProtocol = .init(unixDomain.proto)
				self.hostPath = unixDomain.host
				self.guestPath = unixDomain.guest
				self.hostPort = TextFieldStore(value: 0, text: String.empty, type: .int, maxLength: 5, allowNegative: false, formatter: hostStyle)
				self.guestPort = TextFieldStore(value: 0, text: String.empty, type: .int, maxLength: 5, allowNegative: false, formatter: guestStyle)
			} else {
				self.mode = .portForwarding
				self.selectedProtocol = .both
				self.hostPort = TextFieldStore(value: 0, text: String.empty, type: .int, maxLength: 5, allowNegative: false, formatter: hostStyle)
				self.guestPort = TextFieldStore(value: 0, text: String.empty, type: .int, maxLength: 5, allowNegative: false, formatter: guestStyle)
			}

			self.wellKnownService = WellKnownService(port: self.guestPort.value)
		}
	}

	@Binding private var currentItem: TunnelAttachement
	@State private var model: TunnelAttachementModel
	private var readOnly: Bool

	init(currentItem: Binding<TunnelAttachement>, readOnly: Bool = true) {
		_currentItem = currentItem
		self._model = State(initialValue: TunnelAttachementModel(item: currentItem))
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
		Group {
			if readOnly {
				compactRow
			} else {
				fullForm
			}
		}
		.onChange(of: model) { _, newValue in
			self.currentItem.oneOf = newValue.tunnelAttachement.oneOf
		}
	}

	@ViewBuilder
	var compactRow: some View {
		HStack(spacing: 10) {
			ZStack {
				RoundedRectangle(cornerRadius: 7)
					.fill((model.mode == .portForwarding ? Color.blue : Color.purple).gradient)
					.frame(width: 28, height: 28)
				Image(systemName: model.mode == .portForwarding ? "arrow.left.and.right" : "powerplug")
					.font(.system(size: 12, weight: .semibold))
					.foregroundStyle(.white)
			}

			if model.mode == .portForwarding {
				Text(":\(model.hostPort.text)")
					.font(.system(size: 13, weight: .medium, design: .monospaced))
				Image(systemName: "arrow.right")
					.font(.system(size: 11))
					.foregroundStyle(.tertiary)
				Text(":\(model.guestPort.text)")
					.font(.system(size: 13, weight: .medium, design: .monospaced))
			} else {
				VStack(alignment: .leading, spacing: 2) {
					Text(model.hostPath ?? "–")
						.font(.system(size: 12, design: .monospaced))
						.lineLimit(1)
					Text(model.guestPath ?? "–")
						.font(.system(size: 11, design: .monospaced))
						.foregroundStyle(.secondary)
						.lineLimit(1)
				}
			}

			Spacer()

			Text(model.selectedProtocol.rawValue.uppercased())
				.font(.system(size: 11, weight: .medium))
				.foregroundStyle(.secondary)
				.padding(.horizontal, 6)
				.padding(.vertical, 2)
				.background(Capsule().fill(.secondary.opacity(0.10)))
		}
		.padding(.vertical, 4)
	}

	@ViewBuilder
	var fullForm: some View {
		VStack {
			LabeledContent("Mode") {
				HStack {
					Spacer()
					Picker("Mode", selection: $model.mode) {
						ForEach(ForwardMode.allCases, id: \.self) { selected in
							Text(selected.description).tag(selected)
						}
					}
					.labelsHidden()
					.onChange(of: model.mode) { _, newValue in
						self.currentItem.oneOf = model.tunnelAttachement.oneOf
					}
				}.frame(width: 200)
			}

			LabeledContent("Protocol") {
				HStack {
					Spacer()
					Picker("Protocol", selection: $model.selectedProtocol) {
						ForEach(Proto.allCases, id: \.self) { proto in
							Text(LocalizedStringKey(stringLiteral: proto.rawValue)).tag(proto)
						}
					}
					.labelsHidden()
					.onChange(of: model.selectedProtocol) { _, newValue in
						self.currentItem.oneOf = model.tunnelAttachement.oneOf
					}
				}.frame(width: 200)
			}

			if model.mode == .portForwarding {
				LabeledContent("Guest port") {
					HStack {
						Spacer()
						Picker("Service", selection: $model.wellKnownService) {
							ForEach(WellKnownService.allCases, id: \.self) { service in
								Text(service.description).tag(service)
							}
						}
						.labelsHidden()
						.frame(width: 150)
						.onChange(of: model.wellKnownService) { _, newValue in
							if newValue != .custom {
								model.guestPort.text = String(newValue.rawValue)
							}
						}
						TextField("Guest port", text: $model.guestPort.text)
							.rounded(.center)
							.frame(width: 80)
							.formatAndValidate($model.guestPort) {
								RangeIntegerStyle.guestPortRange.outside($0)
							}
							.onChange(of: model.guestPort.value) { _, newValue in
								model.wellKnownService = WellKnownService(port: newValue)
								self.currentItem.oneOf = model.tunnelAttachement.oneOf
							}
					}
				}

				LabeledContent("Host port") {
					HStack {
						Spacer()
						TextField("Host port", text: $model.hostPort.text)
							.rounded(.center)
							.frame(width: 80)
							.formatAndValidate($model.hostPort) {
								RangeIntegerStyle.hostPortRange.outside($0)
							}
							.onChange(of: model.hostPort.value) { _, newValue in
								self.currentItem.oneOf = model.tunnelAttachement.oneOf
							}
					}
				}
			} else {
				LabeledContent("Guest path") {
					TextField("Guest path", value: $model.guestPath, format: .optional)
						.rounded(.leading)
						.onChange(of: model.guestPath) { _, newValue in
							self.currentItem.oneOf = model.tunnelAttachement.oneOf
						}
						.frame(width: 350)
				}

				LabeledContent("Host path") {
					HStack {
						TextField("Host path", value: $model.hostPath, format: .optional)
							.rounded(.leading)
							.onChange(of: model.hostPath) { _, newValue in
								self.currentItem.oneOf = model.tunnelAttachement.oneOf
							}
						Button(action: chooseSocketFile) {
							Image(systemName: "powerplug")
						}.buttonStyle(.borderless)
					}.frame(width: 350)
				}
			}
		}
	}

	func chooseSocketFile() {
		if let hostPath = FileHelpers.selectSingleInputFile(ofType: [.unixSocketAddress], withTitle: String(localized: "Choose a socket file"), allowsOtherFileTypes: true) {
			self.model.hostPath = hostPath.absoluteURL.path
		}
	}
}

#Preview {
	ForwardedPortDetailView(currentItem: .constant(.init()))
}
