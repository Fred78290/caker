import CakeAgentLib
import Foundation
import NIOCore
import NIOPosix

/// Forwards a raw DNS query to the next resolver and hands back its raw answer, for the names the compose
/// resolver of a network is not authoritative for. Plain UDP, one short-lived socket per query, first answer wins;
/// the upstreams are tried in order.
public final class DNSForwarder: Sendable {
	private final class ResponseHandler: ChannelInboundHandler, @unchecked Sendable {
		typealias InboundIn = AddressedEnvelope<ByteBuffer>

		let promise: EventLoopPromise<[UInt8]>
		let queryID: [UInt8]

		init(promise: EventLoopPromise<[UInt8]>, queryID: [UInt8]) {
			self.promise = promise
			self.queryID = queryID
		}

		func channelRead(context: ChannelHandlerContext, data: NIOAny) {
			var buffer = self.unwrapInboundIn(data).data

			// Ignore anything that isn't the answer to our query.
			if let bytes = buffer.readBytes(length: buffer.readableBytes), bytes.count >= 12, Array(bytes[0..<2]) == queryID {
				self.promise.succeed(bytes)
			}
		}

		func errorCaught(context: ChannelHandlerContext, error: Error) {
			self.promise.fail(error)
		}
	}

	private let group: EventLoopGroup
	private let provider: @Sendable () -> [String]
	public let timeout: TimeAmount
	private let port: Int

	/// - Parameter upstreams: IPv4 addresses of the resolvers to ask, in order. Evaluated for each query, so a
	///   change of the host's resolvers (VPN, network switch) is followed without restarting the network.
	public init(group: EventLoopGroup, timeout: TimeAmount = .seconds(2), port: Int = 53, upstreams: @escaping @Sendable () -> [String]) {
		self.group = group
		self.port = port
		self.provider = upstreams
		self.timeout = timeout
	}

	public convenience init(group: EventLoopGroup, upstreams: [String], timeout: TimeAmount = .seconds(2), port: Int = 53) {
		self.init(group: group, timeout: timeout, port: port) { upstreams }
	}

	public var upstreams: [String] {
		self.provider()
	}

	/// The host's resolvers, from `/etc/resolv.conf`, minus `excluding` (the network's own gateway: forwarding to
	/// ourselves would loop) and loopback.
	public static func systemResolvers(excluding: Set<String> = [], contents: String? = nil) -> [String] {
		let text = contents ?? (try? String(contentsOfFile: "/etc/resolv.conf", encoding: .utf8)) ?? ""
		var result: [String] = []

		for line in text.split(separator: "\n") {
			let fields = line.split(whereSeparator: { $0 == " " || $0 == "\t" })

			guard fields.count >= 2, fields[0] == "nameserver" else { continue }

			let address = String(fields[1])

			guard DHCPAddress.parse(address) != nil, address.hasPrefix("127.") == false, excluding.contains(address) == false, result.contains(address) == false else { continue }

			result.append(address)
		}

		return result
	}

	/// The upstream's answer to `query`, `nil` when none of the upstreams answered in time.
	public func forward(_ query: [UInt8]) async -> [UInt8]? {
		guard query.count >= 12 else { return nil }

		for upstream in self.upstreams {
			if let answer = try? await self.ask(upstream, query) {
				return answer
			}
		}

		return nil
	}

	private func ask(_ upstream: String, _ query: [UInt8]) async throws -> [UInt8] {
		let eventLoop = self.group.next()
		let promise = eventLoop.makePromise(of: [UInt8].self)
		let queryID = Array(query[0..<2])
		let channel = try await DatagramBootstrap(group: eventLoop)
			.channelInitializer { channel in
				channel.pipeline.addHandler(ResponseHandler(promise: promise, queryID: queryID))
			}
			.bind(host: "0.0.0.0", port: 0).get()

		let timer = eventLoop.scheduleTask(in: self.timeout) {
			promise.fail(ChannelError.connectTimeout(self.timeout))
		}

		defer {
			timer.cancel()
			channel.close(promise: nil)
		}

		var buffer = channel.allocator.buffer(capacity: query.count)

		buffer.writeBytes(query)

		try await channel.writeAndFlush(AddressedEnvelope(remoteAddress: SocketAddress(ipAddress: upstream, port: self.port), data: buffer))

		return try await promise.futureResult.get()
	}
}
