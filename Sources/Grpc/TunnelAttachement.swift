//
//  TunnelAttachement.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/05/2025.
//
import Foundation
import NIOPortForwarding
import ArgumentParser
import CakeAgentLib

public struct TunnelAttachement: Sendable, CustomStringConvertible, ExpressibleByArgument, Codable, Equatable {
	public static func == (lhs: TunnelAttachement, rhs: TunnelAttachement) -> Bool {
		switch (lhs.oneOf, rhs.oneOf) {
		case (.none, .none):
			return true			
		case (.forward(let lhs), .forward(let rhs)):
			return lhs == rhs
		case (.unixDomain(let lhs), .unixDomain(let rhs)):
			return lhs == rhs
		default:
			return false
		}
	}

	public var tunnelInfo: TunnelInfo? {
		switch self.oneOf {
		case .none:
			return nil
		case .forward(let value):
			return .init(from: value)
		case .unixDomain(let value):
			return .init(from: TunnelInfo.UnixDomainSocket(proto: value.proto, host: value.host, guest: value.guest))
		}
	}

	public var description: String {
		switch self.oneOf {
		case .none:
			""
		case .forward(let value):
			value.description
		case .unixDomain(let value):
			value.description
		}
	}

	public let oneOf: OneOf

	public var mappedPort: MappedPort? {
		guard case .forward(let value) = self.oneOf else {
			return nil
		}

		return .init(host: value.host, guest: value.guest, proto: value.proto)
	}

	public var unixDomain: ForwardUnixDomainSocket? {
		guard case .unixDomain(let value) = self.oneOf else {
			return nil
		}

		return value
	}

	public enum OneOf: Sendable, Equatable {
		case none
		case forward(ForwardedPort)
		case unixDomain(ForwardUnixDomainSocket)

		public static func == (lhs: OneOf, rhs: OneOf) -> Bool {
			switch (lhs, rhs) {
			case (.none, .none):
				return true
			case (.forward(let lhs), .forward(let rhs)):
				return lhs == rhs
			case (.unixDomain(let lhs), .unixDomain(let rhs)):
				return lhs == rhs
			default:
				return false
			}
		}
	}

	public struct ForwardUnixDomainSocket: Sendable, CustomStringConvertible, Codable, Equatable {
		public var description: String {
			"\(proto):\(host):\(guest)"
		}

		public let proto: MappedPort.Proto
		public let host: String
		public let guest: String

		public static func == (lhs: ForwardUnixDomainSocket, rhs: ForwardUnixDomainSocket) -> Bool {
			return lhs.proto == rhs.proto && lhs.host == rhs.host && lhs.guest == rhs.guest
		}
	}

	public init?(argument: String) {
		let expr = try! NSRegularExpression(pattern: #"(?<domain>tcp|udp):(?<hostPath>[\/~].+):(?<guestPath>\/.+)|(?<host>\d+)(:(?<guest>\d+)(\/(?<proto>tcp|udp|both))?)?"#, options: [])
		let range = NSRange(argument.startIndex..<argument.endIndex, in: argument)

		guard let match = expr.firstMatch(in: argument, options: [], range: range) else {
			return nil
		}

		if let domainRange = Range(match.range(withName: "domain"), in: argument) {
			guard let hostPathRange = Range(match.range(withName: "hostPath"), in: argument), let guestPathRange = Range(match.range(withName: "guestPath"), in: argument) else {
				return nil
			}

			guard let proto = MappedPort.Proto(rawValue: String(argument[domainRange])) else {
				return nil
			}

			self.oneOf = .unixDomain(.init(proto: proto, host: String(argument[hostPathRange]), guest: String(argument[guestPathRange])))
		} else {
			var host: Int = 0
			var guest: Int = 0
			var proto: MappedPort.Proto = .tcp

			if let hostRange = Range(match.range(withName: "host"), in: argument) {
				guard let value = Int(argument[hostRange]) else {
					return nil
				}

				host = value
			}

			if let guestRange = Range(match.range(withName: "guest"), in: argument) {
				guard let value = Int(argument[guestRange]) else {
					return nil
				}

				guest = value
			} else {
				guest = host
			}

			if let protoRange = Range(match.range(withName: "proto"), in: argument) {
				if let value = MappedPort.Proto(rawValue: String(argument[protoRange])) {
					proto = value
				}
			}

			self.oneOf = .forward(.init(proto: proto, host: host, guest: guest))
		}
	}

	public init(from decoder: Decoder) throws {
		let container: KeyedDecodingContainer<Self.CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)

		if let foward = try container.decodeIfPresent(ForwardedPort.self, forKey: .forward) {
			self.oneOf = .forward(foward)
		} else if let unixDomainSocket = try container.decodeIfPresent(ForwardUnixDomainSocket.self, forKey: .unixDomain) {
			self.oneOf = .unixDomain(unixDomainSocket)
		} else {
			self.oneOf = .none
		}

	}

	public init(host: Int, guest: Int, proto: MappedPort.Proto) {
		self.oneOf = .forward(.init(proto: proto, host: host, guest: guest))
	}

	public init(host: String, guest: String, proto: MappedPort.Proto) {
		self.oneOf = .unixDomain(.init(proto: proto, host: host, guest: guest))
	}

	public init(host: String, guest: String) {
		self.oneOf = .unixDomain(.init(proto: .tcp, host: host, guest: guest))
	}

	public init(host: Int, guest: Int) {
		self.oneOf = .forward(.init(proto: .tcp, host: host, guest: guest))
	}

	public init(host: Int) {
		self.oneOf = .forward(.init(proto: .tcp, host: host, guest: host))
	}

	public init(host: String) {
		self.oneOf = .unixDomain(.init(proto: .tcp, host: host, guest: host))
	}

	public init() {
		self.oneOf = .none
	}

	public func encode(to encoder: Encoder) throws {
		var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)

		switch oneOf {
		case .forward(let value):
			try container.encode(value, forKey: .forward)
		case .unixDomain(let value):
			try container.encode(value, forKey: .unixDomain)
		case .none:
			break
		}
	}

	enum CodingKeys: String, CodingKey {
		case forward
		case unixDomain
	}
}
