import CakeAgentLib
import CakedLib
import Foundation
import NIOCore
import NIOPosix
import Synchronization

/// A minimal, deliberately narrow UDP:53 DNS responder for compose service names — see
/// `ComposeDNS.swift`'s doc comment for why this sits on the NAT network's gateway address
/// rather than IMDS's own (isolated) side channel.
///
/// Answers only `<service>.<project>.compose.internal` A queries, from `registry` — `REFUSED`
/// for anything outside that domain (never an open resolver on the shared NAT subnet), and
/// `NXDOMAIN` for a name inside it that isn't currently registered (unknown project/service, or
/// registered but not currently running). No recursion, no other record types, no TCP fallback
/// (every answer here is one A record — small enough to never need one).
final class ComposeDNSInboundHandler: ChannelInboundHandler {
	typealias InboundIn = AddressedEnvelope<ByteBuffer>
	typealias OutboundOut = AddressedEnvelope<ByteBuffer>

	private let registry: ComposeDNSRegistry
	private let logger = Logger("ComposeDNSServer")

	init(registry: ComposeDNSRegistry) {
		self.registry = registry
	}

	func channelRead(context: ChannelHandlerContext, data: NIOAny) {
		let envelope = self.unwrapInboundIn(data)
		var buffer = envelope.data
		let bytes = buffer.readBytes(length: buffer.readableBytes) ?? []

		let query: DNSMessage.Query

		do {
			query = try DNSMessage.parseQuery(bytes)
		} catch {
			// A malformed/unparseable payload on this port — never worth a log line at
			// anything above trace, since the port is reachable by every VM on the shared
			// NAT subnet and a stray/hostile packet here is expected background noise, not
			// an operational event.
			#if DEBUG
				self.logger.trace("Dropped unparseable DNS query from \(envelope.remoteAddress): \(error)")
			#endif
			return
		}

		let responseData: Data

		if query.type == DNSMessage.typeA, query.qclass == DNSMessage.classIN, let name = ComposeDNS.parseServiceName(query.name) {
			if let address = self.registry.address(for: name) {
				responseData = DNSMessage.encodeResponse(to: query, addresses: [address])
			} else {
				responseData = DNSMessage.encodeError(to: query, rcode: .nxDomain)
			}
		} else if ComposeDNS.parseServiceName(query.name) != nil {
			// A recognized compose name, but not an A/IN query (e.g. AAAA, which this
			// resolver never has an answer for) — a clean "no data" is more correct than
			// REFUSED, since the name itself is legitimately ours to answer for.
			responseData = DNSMessage.encodeResponse(to: query, addresses: [])
		} else {
			// Outside the synthetic domain entirely — refuse rather than silently ignore, so
			// a client sees a clear, fast failure instead of waiting out its own timeout.
			responseData = DNSMessage.encodeError(to: query, rcode: .refused)
		}

		var responseBuffer = context.channel.allocator.buffer(capacity: responseData.count)

		responseBuffer.writeBytes(responseData)

		let response = AddressedEnvelope(remoteAddress: envelope.remoteAddress, data: responseBuffer)

		context.writeAndFlush(self.wrapOutboundOut(response), promise: nil)
	}

	func errorCaught(context: ChannelHandlerContext, error: Error) {
		self.logger.warn("ComposeDNSServer channel error: \(error)")
	}
}

/// Owns the bound UDP channel. Binding/privilege story mirrors `IMDSServer` exactly (see its
/// own doc comment): always binds the gateway address, on port 53 directly when root, or on
/// `internalPort` unprivileged — `needsPFRedirect` then tells `ComposeDNSCoordinator` whether a
/// `pf` UDP+TCP port redirect (`PFRedirect.enableComposeDNSRedirect`, via the same short-lived
/// root helper IMDS uses) is additionally needed. Unlike IMDS's port-80 redirect (a convenience
/// for guest tooling that hardcodes 80, with IMDS itself already reachable either way), this one
/// is not optional when unprivileged: `resolvectl dns` has no way to target a non-standard port,
/// so the compose DNS split-DNS setup guests get (see `ComposeFile.toBuildOptions`) simply does
/// not work without it — same "needs passwordless sudo configured for caked" caveat as IMDS's own
/// redirect, silently skipped (and the feature inert, not broken) in a sandboxed build.
public final class ComposeDNSServer: Sendable {
	// `DatagramBootstrap` itself isn't `Sendable`, so it's never stored — built fresh in
	// `start()` from these plain, genuinely `Sendable` values instead.
	private let group: EventLoopGroup
	private let registry: ComposeDNSRegistry
	private let channelBox: Mutex<Channel?> = Mutex(nil)

	public static let internalBindPort = 28053

	public let needsPFRedirect: Bool
	public let internalPort: Int
	public let bindAddress: String

	public init(group: EventLoopGroup, registry: ComposeDNSRegistry, bindAddress: String, internalPort: Int = ComposeDNSServer.internalBindPort) {
		let runningAsRoot = geteuid() == 0

		self.group = group
		self.registry = registry
		self.bindAddress = bindAddress
		self.internalPort = runningAsRoot ? 53 : internalPort
		self.needsPFRedirect = runningAsRoot == false
	}

	public func start() throws {
		let registry = self.registry
		let bootstrap = DatagramBootstrap(group: self.group)
			.channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
			.channelInitializer { channel in
				channel.pipeline.addHandler(ComposeDNSInboundHandler(registry: registry))
			}

		let channel = try bootstrap.bind(host: self.bindAddress, port: self.internalPort).wait()

		self.channelBox.withLock { $0 = channel }
	}

	/// Retries `start()` with a fixed delay until it succeeds or `maxAttempts` is reached —
	/// mirrors `IMDSServer.startWithRetry(...)` exactly, for the same reason: a transient bind
	/// failure (e.g. the port briefly held by a just-stopped previous instance) shouldn't be
	/// fatal to the first VM that needed the server started.
	public func startWithRetry(maxAttempts: Int = 20, retryDelayNanoseconds: UInt64 = 500_000_000) async throws {
		var attempts = 0

		while true {
			try Task.checkCancellation()

			do {
				try self.start()
				return
			} catch {
				attempts += 1

				if attempts >= maxAttempts {
					throw error
				}

				try await Task.sleep(nanoseconds: retryDelayNanoseconds)
			}
		}
	}

	public func shutdown() async {
		let channel = self.channelBox.withLock { $0 }

		try? await channel?.close()
	}
}
