import Foundation

/// IPv4 addresses as host-order integers, the form the DHCP code does its arithmetic on.
public enum DHCPAddress {
	public static func parse(_ string: String) -> UInt32? {
		let octets = string.split(separator: ".", omittingEmptySubsequences: false).map { UInt8($0) }

		guard octets.count == 4, octets.allSatisfy({ $0 != nil }) else {
			return nil
		}

		return octets.reduce(UInt32(0)) { ($0 << 8) | UInt32($1!) }
	}

	public static func string(_ address: UInt32) -> String {
		"\(address >> 24).\((address >> 16) & 0xff).\((address >> 8) & 0xff).\(address & 0xff)"
	}
}

/// A minimal RFC 2131/2132 codec: the BOOTP header plus the options a server needs to read and write.
/// Like `DNSMessage`, parsing never traps — the port is reachable by every guest on the network.
public struct DHCPMessage: Equatable, Sendable {
	public enum MessageType: UInt8, Sendable {
		case discover = 1
		case offer = 2
		case request = 3
		case decline = 4
		case ack = 5
		case nak = 6
		case release = 7
		case inform = 8
	}

	public enum DHCPError: Error, Equatable {
		case truncated
		case badCookie
		case malformedOptions
	}

	public static let serverPort = 67
	public static let clientPort = 68
	static let magicCookie: [UInt8] = [99, 130, 83, 99]
	static let headerSize = 236
	static let broadcastFlag: UInt16 = 0x8000

	// Option codes (RFC 2132).
	enum Option {
		static let pad: UInt8 = 0
		static let subnetMask: UInt8 = 1
		static let router: UInt8 = 3
		static let dnsServers: UInt8 = 6
		static let hostname: UInt8 = 12
		static let domainName: UInt8 = 15
		static let broadcast: UInt8 = 28
		static let requestedIP: UInt8 = 50
		static let leaseTime: UInt8 = 51
		static let messageType: UInt8 = 53
		static let serverIdentifier: UInt8 = 54
		static let message: UInt8 = 56
		static let renewalTime: UInt8 = 58
		static let rebindingTime: UInt8 = 59
		static let clientIdentifier: UInt8 = 61
		static let end: UInt8 = 255
	}

	public var op: UInt8
	public var hardwareType: UInt8
	public var xid: UInt32
	public var secs: UInt16
	public var flags: UInt16
	public var ciaddr: UInt32
	public var yiaddr: UInt32
	public var siaddr: UInt32
	public var giaddr: UInt32
	public var clientHardwareAddress: [UInt8]

	public var messageType: MessageType?
	public var requestedAddress: UInt32?
	public var serverIdentifier: UInt32?
	public var clientIdentifier: [UInt8]?
	public var hostname: String?
	public var leaseTime: UInt32?
	public var subnetMask: UInt32?
	public var routers: [UInt32] = []
	public var dnsServers: [UInt32] = []
	public var domainName: String?
	public var broadcastAddress: UInt32?
	public var renewalTime: UInt32?
	public var rebindingTime: UInt32?
	public var message: String?

	public init(
		op: UInt8 = 1, hardwareType: UInt8 = 1, xid: UInt32 = 0, secs: UInt16 = 0, flags: UInt16 = 0, ciaddr: UInt32 = 0, yiaddr: UInt32 = 0, siaddr: UInt32 = 0, giaddr: UInt32 = 0,
		clientHardwareAddress: [UInt8] = [], messageType: MessageType? = nil
	) {
		self.op = op
		self.hardwareType = hardwareType
		self.xid = xid
		self.secs = secs
		self.flags = flags
		self.ciaddr = ciaddr
		self.yiaddr = yiaddr
		self.siaddr = siaddr
		self.giaddr = giaddr
		self.clientHardwareAddress = clientHardwareAddress
		self.messageType = messageType
	}

	public var wantsBroadcast: Bool {
		(flags & Self.broadcastFlag) != 0
	}

	/// The key a lease is stored under, in the form `dhcpd_leases` uses for `hw_address`: `1,<mac>` for an Ethernet
	/// client, `ff,<duid>` when the client identifies itself with a DUID (option 61, type 255 — dhcpcd does).
	public var hwAddressKey: String {
		if let id = clientIdentifier, id.count > 1, id[0] == 255 {
			return "ff," + Self.hex(id.dropFirst())
		}

		return "1," + Self.hex(clientHardwareAddress)
	}

	static func hex<S: Sequence>(_ bytes: S) -> String where S.Element == UInt8 {
		bytes.map { String(format: "%02x", $0) }.joined(separator: ":")
	}

	// MARK: - Decode

	public static func parse(_ bytes: [UInt8]) throws -> DHCPMessage {
		guard bytes.count >= headerSize + 4 else {
			throw DHCPError.truncated
		}

		guard Array(bytes[headerSize..<headerSize + 4]) == magicCookie else {
			throw DHCPError.badCookie
		}

		func u16(_ at: Int) -> UInt16 { UInt16(bytes[at]) << 8 | UInt16(bytes[at + 1]) }
		func u32(_ at: Int) -> UInt32 { UInt32(bytes[at]) << 24 | UInt32(bytes[at + 1]) << 16 | UInt32(bytes[at + 2]) << 8 | UInt32(bytes[at + 3]) }

		let hlen = Int(bytes[2])

		guard hlen <= 16 else {
			throw DHCPError.malformedOptions
		}

		var message = DHCPMessage(
			op: bytes[0], hardwareType: bytes[1], xid: u32(4), secs: u16(8), flags: u16(10), ciaddr: u32(12), yiaddr: u32(16), siaddr: u32(20), giaddr: u32(24),
			clientHardwareAddress: Array(bytes[28..<28 + hlen]))

		var index = headerSize + 4

		while index < bytes.count {
			let code = bytes[index]

			index += 1

			if code == Option.pad {
				continue
			}

			if code == Option.end {
				break
			}

			guard index < bytes.count else {
				throw DHCPError.malformedOptions
			}

			let length = Int(bytes[index])

			index += 1

			guard index + length <= bytes.count else {
				throw DHCPError.malformedOptions
			}

			let value = Array(bytes[index..<index + length])

			index += length

			func address() -> UInt32? {
				value.count == 4 ? value.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) } : nil
			}

			func addresses() -> [UInt32] {
				stride(from: 0, to: value.count - value.count % 4, by: 4).map { i in value[i..<i + 4].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) } }
			}

			switch code {
			case Option.messageType where length == 1:
				message.messageType = MessageType(rawValue: value[0])
			case Option.requestedIP:
				message.requestedAddress = address()
			case Option.serverIdentifier:
				message.serverIdentifier = address()
			case Option.clientIdentifier where length >= 2:
				message.clientIdentifier = value
			case Option.hostname:
				message.hostname = String(decoding: value.prefix { $0 != 0 }, as: UTF8.self)
			case Option.leaseTime:
				message.leaseTime = address()
			case Option.subnetMask:
				message.subnetMask = address()
			case Option.router:
				message.routers = addresses()
			case Option.dnsServers:
				message.dnsServers = addresses()
			case Option.domainName:
				message.domainName = String(decoding: value, as: UTF8.self)
			default:
				break
			}
		}

		return message
	}

	// MARK: - Encode

	public func encode() -> [UInt8] {
		var out = [UInt8](repeating: 0, count: Self.headerSize)

		func put32(_ value: UInt32, at: Int) {
			out[at] = UInt8(value >> 24)
			out[at + 1] = UInt8((value >> 16) & 0xff)
			out[at + 2] = UInt8((value >> 8) & 0xff)
			out[at + 3] = UInt8(value & 0xff)
		}

		let hardware = Array(clientHardwareAddress.prefix(16))

		out[0] = op
		out[1] = hardwareType
		out[2] = UInt8(hardware.count)
		put32(xid, at: 4)
		out[8] = UInt8(secs >> 8)
		out[9] = UInt8(secs & 0xff)
		out[10] = UInt8(flags >> 8)
		out[11] = UInt8(flags & 0xff)
		put32(ciaddr, at: 12)
		put32(yiaddr, at: 16)
		put32(siaddr, at: 20)
		put32(giaddr, at: 24)
		out.replaceSubrange(28..<28 + hardware.count, with: hardware)
		out.append(contentsOf: Self.magicCookie)

		func option(_ code: UInt8, _ value: [UInt8]) {
			guard value.count <= 255 else { return }

			out.append(code)
			out.append(UInt8(value.count))
			out.append(contentsOf: value)
		}

		func bytes(_ value: UInt32) -> [UInt8] {
			[UInt8(value >> 24), UInt8((value >> 16) & 0xff), UInt8((value >> 8) & 0xff), UInt8(value & 0xff)]
		}

		if let messageType {
			option(Option.messageType, [messageType.rawValue])
		}

		if let serverIdentifier {
			option(Option.serverIdentifier, bytes(serverIdentifier))
		}

		if let leaseTime {
			option(Option.leaseTime, bytes(leaseTime))
		}

		if let renewalTime {
			option(Option.renewalTime, bytes(renewalTime))
		}

		if let rebindingTime {
			option(Option.rebindingTime, bytes(rebindingTime))
		}

		if let subnetMask {
			option(Option.subnetMask, bytes(subnetMask))
		}

		if let broadcastAddress {
			option(Option.broadcast, bytes(broadcastAddress))
		}

		if routers.isEmpty == false {
			option(Option.router, routers.flatMap(bytes))
		}

		if dnsServers.isEmpty == false {
			option(Option.dnsServers, dnsServers.flatMap(bytes))
		}

		if let domainName {
			option(Option.domainName, Array(domainName.utf8))
		}

		if let requestedAddress {
			option(Option.requestedIP, bytes(requestedAddress))
		}

		if let clientIdentifier {
			option(Option.clientIdentifier, clientIdentifier)
		}

		if let hostname {
			option(Option.hostname, Array(hostname.utf8))
		}

		if let message {
			option(Option.message, Array(message.utf8))
		}

		out.append(Option.end)

		// Some clients (and BOOTP relays) expect at least 300 bytes.
		if out.count < 300 {
			out.append(contentsOf: [UInt8](repeating: 0, count: 300 - out.count))
		}

		return out
	}
}
