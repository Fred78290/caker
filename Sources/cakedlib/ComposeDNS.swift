import CakeAgentLib
import Foundation
import GRPCLib

/// Pure, network-independent logic for the small "compose DNS" resolver: name resolution for
/// compose services from other VMs, over the NAT network every VM already carries (see
/// `CakeConfig.qualifiedNetworks` — a NAT attachment is unconditional, not opt-in). This file
/// holds only what a unit test can exercise without a live socket: the synthetic-domain naming
/// scheme and a minimal DNS message codec (A records only). The actual UDP server/registry that
/// use this live in `Sources/caked/ComposeDNS/` — `caked`'s own executable target, since they
/// need `NIO`'s networking and daemon-only state (`VMLifecycleHooks`, the host DHCP lease table)
/// that `CakedLib` itself has no business depending on.
///
/// ## Why the NAT network, not the IMDS one
///
/// `IMDSNetworkInterface` (`NetworkAttachement.swift`) already gives every *Linux* VM a private,
/// host-only side channel to `caked` — but it runs with `vmnet_enable_isolation_key = true`
/// (`VZVMNet.swift`), so it only ever supports VM↔host traffic, never VM↔VM. The NAT interface
/// every VM gets from `CakeConfig.qualifiedNetworks` is different: it's Apple's own
/// `VZNATNetworkDeviceAttachment` (`NATNetworkInterface.attachment(...)`), which never goes
/// through caked's isolation-flag code at all, and — per `NetworksHandler.natNetworkInfos()`/
/// `defaultNatNetwork(runMode:)` — is one shared, host-wide subnet (`com.apple.vmnet.plist`'s
/// `Shared_Net_Address`, or `192.168.64.1/24` on macOS 26+), not a per-VM private instance. Every
/// VM caker creates already has this attachment, macOS or Linux, `driver: bridge` or not, so it's
/// the one place a resolver can sit without depending on whatever the compose network's own
/// primary attachment happens to be. See `ComposeDNSCoordinator`'s own doc comment for the parts
/// of this that are read from code rather than empirically verified (chiefly: that
/// `VZNATNetworkDeviceAttachment` genuinely allows VM-to-VM packets, not just VM-to-host/internet
/// — everything here is consistent with that, but nobody in this codebase relied on it before).
public enum ComposeDNS {
	/// The built-in domain suffix, used whenever `CakedKeyConfig.composeDnsDomain` has no valid
	/// value configured — the fallback `domainSuffix` itself resolves to, and what every bundled
	/// compose template/doc reference assumes unless the operator has changed it in Advanced
	/// Settings.
	public static let defaultDomainSuffix = "compose.internal"

	/// The domain suffix the resolver currently answers for — anything else is `REFUSED`, this
	/// is not, and must never become, an open resolver for the shared NAT subnet. Configurable
	/// via `CakedKeyConfig.composeDnsDomain` (`UserDefaults.shared`, the same app-group-backed
	/// store `caker`'s Advanced Settings already uses for `bridgedNetwork`/`primaryName`/etc —
	/// see `AdvancedSettingsView.swift`'s "Compose" section), read fresh on every call rather than
	/// cached, so a change made in Settings takes effect on the next query without restarting
	/// `caked`/`caked dns`. An unset or invalid stored value (never possible via the Settings UI,
	/// which validates before saving, but always possible via a hand-edited defaults plist)
	/// silently falls back to `defaultDomainSuffix` rather than ever breaking the resolver —
	/// see `normalizeDomainSuffix(_:)`.
	///
	/// Changing this only affects virtual machines *built* afterward: the guest-side split-DNS
	/// `resolvectl domain '~...'` setup (`ComposeFile.toBuildOptions`) bakes in whatever this
	/// resolved to at build time, into the VM's own cloud-init — an already-provisioned VM keeps
	/// pointing at its old domain until rebuilt.
	public static var domainSuffix: String {
		guard let stored = CakedKeyConfig.composeDnsDomain.string(), let normalized = Self.normalizeDomainSuffix(stored) else {
			return Self.defaultDomainSuffix
		}

		return normalized
	}

	/// Validates and normalizes a candidate domain suffix: trims surrounding whitespace, strips
	/// a single leading/trailing dot, lowercases, and requires every dot-separated label to be a
	/// plausible DNS label (1–63 ASCII letters/digits/hyphens, never starting or ending with a
	/// hyphen). `nil` for anything that doesn't meet that bar — used both by the Settings UI (to
	/// reject an invalid value before it's ever saved) and internally by `domainSuffix` itself
	/// (so a value that somehow got saved invalid can never take the resolver down, it just
	/// falls back). Deliberately hand-rolled rather than `NSRegularExpression`, since
	/// `domainSuffix` calls this on every DNS query the server receives.
	public static func normalizeDomainSuffix(_ candidate: String) -> String? {
		var value = candidate.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

		if value.hasPrefix(".") {
			value.removeFirst()
		}

		if value.hasSuffix(".") {
			value.removeLast()
		}

		guard value.isEmpty == false else { return nil }

		let labels = value.split(separator: ".", omittingEmptySubsequences: false)

		for label in labels {
			guard label.isEmpty == false, label.count <= 63 else { return nil }
			guard label.allSatisfy({ ("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "-" }) else { return nil }
			guard label.first != "-", label.last != "-" else { return nil }
		}

		return value
	}

	/// A query name this resolver will answer for, already split back into what it names —
	/// either a compose service (two labels, `<service>.<project>`) or a plain virtual machine
	/// (one label, `<vmname>`), both under `domainSuffix`.
	public enum QueryName: Equatable, Sendable {
		case service(ServiceName)
		case vm(String)
	}

	/// A query name this resolver will answer, already split back into its compose identity.
	public struct ServiceName: Equatable, Sendable {
		public let service: String
		public let project: String

		public init(service: String, project: String) {
			self.service = service
			self.project = project
		}
	}

	/// Parses a query name (case-insensitive, trailing dot optional, matching how a resolver
	/// hands a query name to a stub) back into what it names under `domainSuffix` — a compose
	/// service (`<service>.<project>.<domain>`) or a plain virtual machine (`<vmname>.<domain>`).
	/// `nil` for anything outside the synthetic domain, or with more than the two labels a
	/// compose service name allows in front of it — deliberately strict, since a permissive
	/// parse here is how a resolver becomes something other than "answers for known names only."
	public static func parseQueryName(_ queryName: String) -> QueryName? {
		var name = queryName.lowercased()

		if name.hasSuffix(".") {
			name.removeLast()
		}

		let suffix = ".\(self.domainSuffix)"

		guard name.hasSuffix(suffix) else {
			return nil
		}

		let prefix = String(name.dropLast(suffix.count))
		let labels = prefix.split(separator: ".", omittingEmptySubsequences: false)

		guard labels.allSatisfy({ $0.isEmpty == false }) else {
			return nil
		}

		switch labels.count {
		case 1:
			return .vm(String(labels[0]))
		case 2:
			return .service(ServiceName(service: String(labels[0]), project: String(labels[1])))
		default:
			return nil
		}
	}

	/// Parses `<service>.<project>.<domain>` specifically, discarding a plain-VM match — the
	/// original, narrower entry point kept for callers (and tests) that only ever care about
	/// compose service names, implemented in terms of `parseQueryName(_:)` so the two never
	/// drift out of sync on what counts as "in the synthetic domain" in the first place.
	public static func parseServiceName(_ queryName: String) -> ServiceName? {
		guard case .service(let name) = Self.parseQueryName(queryName) else { return nil }

		return name
	}

	/// The query name a client should ask for `service` in `project` — the inverse of
	/// `parseServiceName(_:)`, used by tests and by anything that wants to print/log the FQDN a
	/// service resolves at.
	public static func fullyQualifiedName(service: String, project: String) -> String {
		"\(service.lowercased()).\(project.lowercased()).\(self.domainSuffix)"
	}

	/// The query name a client should ask for a plain virtual machine named `vmName` — the
	/// inverse of the `.vm(_:)` case of `parseQueryName(_:)`.
	public static func fullyQualifiedName(vmName: String) -> String {
		"\(vmName.lowercased()).\(self.domainSuffix)"
	}

	/// The NAT network's gateway address, stripped of its `/24`-style CIDR suffix — where the
	/// compose DNS resolver binds, and the one address every compose-created VM's `post_commands`
	/// is told to route `*.compose.internal` queries to (see `ComposeFile.toBuildOptions`'s
	/// `composeDNSGateway` parameter). `nil` only if `NetworksHandler` itself couldn't determine
	/// one — the resolver has nothing to bind to in that case, and no compose-created VM gets the
	/// split-DNS `post_commands` entry either.
	public static func natGatewayAddress(runMode: Utils.RunMode) -> String? {
		let gateway = NetworksHandler.defaultNatNetwork(runMode: runMode).gateway

		guard gateway.isEmpty == false else { return nil }

		return String(gateway.split(separator: "/", maxSplits: 1).first ?? Substring(gateway))
	}

	/// `config`'s current address on the NAT network, from the host's own DHCP lease table — the
	/// exact same mechanism `VMLocation.waitIPWithLease(...)`'s NAT branch already uses for a
	/// NAT-*primary* VM, applied here unconditionally instead: `CakeConfig.qualifiedNetworks`
	/// guarantees a NAT attachment on every VM regardless of what its primary attachment is (see
	/// `ComposeDNS`'s own doc comment), and `collectNetworks` always gives that attachment
	/// `config.macAddress` specifically — so this same lookup works for a `driver: bridge`
	/// compose service too, not only a NAT-primary one. `nil` if the lease table has nothing for
	/// this VM yet (not yet DHCP-assigned) or the parser itself couldn't be read.
	public static func natAddress(for config: CakeConfig) -> String? {
		guard let parser = try? DHCPLeaseParser() else { return nil }

		let clientID = config.dhcpClientID ?? config.macAddress ?? ""

		guard clientID.isEmpty == false else { return nil }

		return parser[clientID]
	}

	/// `true` if a compose DNS resolver already appears to be running for `runMode` — read from
	/// `Home.composeDnsPID`, the PID file `Sources/caked/ComposeDNS/ComposeDNSCoordinator.swift`
	/// writes as soon as its poll loop starts, not only once its UDP server actually manages to
	/// bind (whether that coordinator lives inside `caked service listen` or the standalone
	/// `caked dns` command — either one writes the same file, so this can't tell which, and
	/// doesn't need to). Best-effort: a stale/missing file reads as "not running," never throws.
	///
	/// Cheap and side-effect free (`createItIfNotExists: false`, so it never creates the home or
	/// its certificates/stores just to answer), because `caker` polls it every second to drive the
	/// Service menu's "Start/Stop caked DNS" item. The PID must also belong to a `caked` process,
	/// so a stale `composedns.pid` whose PID was since reused by an unrelated process neither
	/// reads as "running" nor, worse, gets signalled by `stopResolver(runMode:)`.
	public static func isResolverRunning(runMode: Utils.RunMode) -> Bool {
		guard let home = try? Home(runMode: runMode, createItIfNotExists: false) else { return false }

		return Self.isResolverRunning(pidFile: home.composeDnsPID)
	}

	static func isResolverRunning(pidFile: URL) -> Bool {
		pidFile.isPIDRunning([Home.cakedCommandName]).running
	}

	/// Ensures a compose DNS resolver is reachable for `runMode` — called from
	/// `CakedLib.ComposeHandler.up(...)`, the one function every "bring compose services up"
	/// entry point (`caked compose up`'s own one-shot process, `cakectl compose up` via a running
	/// `caked service listen`, and `caker`'s `.app` mode) funnels through, so this is what makes
	/// "ensure the resolver is launched" true regardless of *how* compose was invoked rather than
	/// requiring the operator to know to run `caked dns` themselves.
	///
	/// If `isResolverRunning(runMode:)` is already `true` — including because this same call
	/// already spawned one moments ago for an earlier service in the same `up` — this is a no-op.
	/// Otherwise it spawns `caked dns` as a detached background process (`Bundle.runCaked`,
	/// the same "launch another `caked` subcommand as an independent child" mechanism
	/// `StartHandler` already uses for `caked vmrun`; a child spawned this way outlives the
	/// spawning process — e.g. `caked compose up`'s own short-lived invocation — since nothing
	/// here waits on or explicitly kills it) with its stdout/stderr redirected to
	/// `Home.composeDnsLog` rather than inherited, so it doesn't interleave with whatever invoked
	/// `compose up`. Best-effort in every sense: a failure to spawn is logged and otherwise
	/// ignored — compose itself must keep working even if the resolver can't be started (e.g. no
	/// writable `<CAKE_HOME>`, or `caked` isn't on the expected path), just without name
	/// resolution between services.
	public static func ensureResolverRunning(runMode: Utils.RunMode) {
		guard Self.isResolverRunning(runMode: runMode) == false else { return }

		do {
			try Self.startResolver(runMode: runMode)
		} catch {
			Logger("ComposeDNS").warn("Could not start the compose DNS resolver automatically: \(error). Name resolution between compose services won't work until `caked dns` is run manually.")
		}
	}

	/// Spawns `caked dns` as a detached background process for `runMode`, with its stdout/stderr
	/// redirected to `Home.composeDnsLog`. Unlike `ensureResolverRunning(runMode:)` — which is
	/// best-effort and never reports a failure to its caller — this throws, so an explicit
	/// request from `caker`'s Service menu can tell the operator why nothing started. Does *not*
	/// check `isResolverRunning(runMode:)` first: that's the caller's decision, since the
	/// automatic path wants a silent no-op and the menu path has already gated on it.
	public static func startResolver(runMode: Utils.RunMode) throws {
		let home = try Home(runMode: runMode)

		FileManager.default.createFile(atPath: home.composeDnsLog.path(percentEncoded: false), contents: nil)

		let log = try FileHandle(forWritingTo: home.composeDnsLog)

		log.seekToEndOfFile()

		try Bundle.runCaked(
			with: ["dns", "--log-level=\(Logger.LoggingLevel().rawValue)"],
			standardInput: nil,
			standardOutput: log,
			standardError: log,
			runMode: runMode
		)

		Logger("ComposeDNS").info("Started compose DNS resolver in the background (log: \(home.composeDnsLog.path(percentEncoded: false)))")
	}

	/// Stops the resolver `isResolverRunning(runMode:)` sees, with `SIGINT` — the signal `caked
	/// dns` (and `caked service listen`'s embedded coordinator) treats as "tear the UDP server and
	/// `pf` redirect down cleanly, remove `composedns.pid`, then exit" (see `Dns.run()`), the same
	/// way `ServiceHandler.stopAgentRunning(runMode:)` stops the daemon. Throws if no `caked`
	/// process owns the PID file, rather than signalling whatever process happens to have that PID.
	public static func stopResolver(runMode: Utils.RunMode) throws {
		try Self.stopResolver(pidFile: try Home(runMode: runMode, createItIfNotExists: false).composeDnsPID)
	}

	static func stopResolver(pidFile: URL) throws {
		guard Self.isResolverRunning(pidFile: pidFile) else {
			throw ServiceError(String(localized: "Compose DNS resolver is not running"))
		}

		let status = pidFile.killPID(SIGINT)

		// `killPID` returns kill(2)'s own -1 (the real error is in `errno`) or, for a PID file it
		// couldn't read, a positive errno-style code. Capture it right here, before any other call:
		// resolving the localized message below can itself set `errno` (Foundation probes missing
		// bundle paths) and would otherwise replace the actual kill(2) error, e.g. EPERM, with ENOENT.
		let code = status == -1 ? errno : status

		guard status == 0 else {
			throw ServiceError(String(format: String(localized: "Failed to stop the compose DNS resolver (errno %d)"), code))
		}
	}
}

// MARK: - Minimal DNS message codec (RFC 1035, A records only)

/// Deliberately not a general-purpose DNS library: this resolver only ever needs to decode one
/// A-record question and encode either an A-record answer or an error response back. No message
/// compression on decode (a query's question section is the first thing after the header, so
/// there is nothing earlier for a compression pointer to reference — a compliant client's query
/// never uses one there), and encoding only ever points its answer's NAME back at the question
/// via the standard `0xC00C` pointer rather than re-spelling it.
public enum DNSMessage {
	public enum DNSError: Error, Equatable {
		case truncated
		case unsupportedQuestionCount(UInt16)
		case malformedName
		case nameTooLong
	}

	public enum ResponseCode: UInt8 {
		case noError = 0
		case formatError = 1
		case nxDomain = 3
		case refused = 5
	}

	/// A parsed query — enough to answer it and nothing else (no support for multi-question
	/// messages, EDNS0, or any record type other than A/AAAA-shaped `type`/`class` echoing).
	public struct Query: Equatable, Sendable {
		public let id: UInt16
		public let recursionDesired: Bool
		public let name: String
		public let type: UInt16
		public let qclass: UInt16

		public init(id: UInt16, recursionDesired: Bool, name: String, type: UInt16, qclass: UInt16) {
			self.id = id
			self.recursionDesired = recursionDesired
			self.name = name
			self.type = type
			self.qclass = qclass
		}
	}

	public static let typeA: UInt16 = 1
	public static let classIN: UInt16 = 1

	/// Parses the question out of a raw UDP payload. Throws (never crashes/traps) on anything
	/// malformed — a hostile or simply buggy packet on this port must never bring the daemon
	/// down. A message with zero or more than one question is rejected outright: nothing this
	/// resolver serves ever needs to ask more than one name at once, and answering only the
	/// first of several would silently misrepresent what was actually resolved.
	public static func parseQuery(_ bytes: [UInt8]) throws -> Query {
		guard bytes.count >= 12 else {
			throw DNSError.truncated
		}

		let id = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
		let flags = UInt16(bytes[2]) << 8 | UInt16(bytes[3])
		let recursionDesired = (flags & 0x0100) != 0
		let qdcount = UInt16(bytes[4]) << 8 | UInt16(bytes[5])

		guard qdcount == 1 else {
			throw DNSError.unsupportedQuestionCount(qdcount)
		}

		var offset = 12
		let (name, nameEnd) = try self.readName(bytes, startingAt: offset)

		offset = nameEnd

		guard bytes.count >= offset + 4 else {
			throw DNSError.truncated
		}

		let type = UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1])
		let qclass = UInt16(bytes[offset + 2]) << 8 | UInt16(bytes[offset + 3])

		return Query(id: id, recursionDesired: recursionDesired, name: name, type: type, qclass: qclass)
	}

	/// Reads one DNS name (a sequence of length-prefixed labels terminated by a zero-length
	/// label) starting at `startingAt`. No compression-pointer support — a question's name is
	/// always the first thing after the 12-byte header, so a compliant query never has one
	/// there, and this resolver never needs to parse a name anywhere else in a message.
	private static func readName(_ bytes: [UInt8], startingAt: Int) throws -> (name: String, end: Int) {
		var offset = startingAt
		var labels: [String] = []

		while true {
			guard offset < bytes.count else {
				throw DNSError.truncated
			}

			let length = Int(bytes[offset])

			if length & 0xC0 != 0 {
				// A compression pointer — not expected in a question section this resolver
				// receives (see the doc comment above), and not worth the extra decode-path
				// complexity to support for a message shape that never legitimately needs it.
				throw DNSError.malformedName
			}

			offset += 1

			if length == 0 {
				break
			}

			guard offset + length <= bytes.count else {
				throw DNSError.truncated
			}

			guard let label = String(bytes: bytes[offset..<(offset + length)], encoding: .utf8) else {
				throw DNSError.malformedName
			}

			labels.append(label)
			offset += length

			guard labels.count <= 32 else {
				// A real name can't have this many labels; treat it as malformed rather than
				// looping arbitrarily long on a hostile payload.
				throw DNSError.malformedName
			}
		}

		return (labels.joined(separator: "."), offset)
	}

	/// Encodes a successful response carrying zero or more A records for `query`. `ttlSeconds`
	/// is deliberately short by default — a compose service's NAT-subnet IP can change on
	/// rebuild/restart, and this resolver has no way to push an update to a client that already
	/// cached a stale answer, so a short TTL is the only guard against that.
	public static func encodeResponse(to query: Query, addresses: [String], ttlSeconds: UInt32 = 5) -> Data {
		// Resolved first, separately from the header: ANCOUNT must equal exactly how many
		// records end up in the body, and an address that fails to parse (which the registry
		// itself never produces, but nothing here should assume that) must not overstate it.
		let octetsList = addresses.compactMap { self.ipv4Octets($0) }
		var body = Data()

		self.appendHeader(to: &body, query: query, answerCount: UInt16(octetsList.count), rcode: .noError)
		self.appendQuestion(to: &body, query: query)

		for octets in octetsList {
			// NAME: a compression pointer back at the question name (offset 12, right after
			// the fixed 12-byte header) rather than re-encoding the labels a second time.
			body.append(contentsOf: [0xC0, 0x0C])
			self.appendUInt16(self.typeA, to: &body)
			self.appendUInt16(self.classIN, to: &body)
			self.appendUInt32(ttlSeconds, to: &body)
			self.appendUInt16(4, to: &body)
			body.append(contentsOf: octets)
		}

		return body
	}

	/// Encodes an error response (`NXDOMAIN`/`REFUSED`/etc.) with the question echoed back and
	/// no answers — standard DNS practice, and lets a resolver-level `dig`/`resolvectl query`
	/// used to debug this show the query it actually reached rather than a bare error.
	public static func encodeError(to query: Query, rcode: ResponseCode) -> Data {
		var body = Data()

		self.appendHeader(to: &body, query: query, answerCount: 0, rcode: rcode)
		self.appendQuestion(to: &body, query: query)

		return body
	}

	private static func appendHeader(to body: inout Data, query: Query, answerCount: UInt16, rcode: ResponseCode) {
		self.appendUInt16(query.id, to: &body)

		// QR=1 (response), Opcode=0 (query, echoed), AA=0, TC=0, RD=echoed, RA=0, Z=0, RCODE=rcode.
		let flagsHigh: UInt8 = 0x80 | (query.recursionDesired ? 0x01 : 0x00)
		let flagsLow: UInt8 = rcode.rawValue

		body.append(flagsHigh)
		body.append(flagsLow)

		self.appendUInt16(1, to: &body)  // QDCOUNT — the question is always echoed back.
		self.appendUInt16(answerCount, to: &body)
		self.appendUInt16(0, to: &body)  // NSCOUNT
		self.appendUInt16(0, to: &body)  // ARCOUNT
	}

	private static func appendQuestion(to body: inout Data, query: Query) {
		for label in query.name.split(separator: ".") {
			let bytes = Array(label.utf8)

			body.append(UInt8(min(bytes.count, 63)))
			body.append(contentsOf: bytes.prefix(63))
		}

		body.append(0)
		self.appendUInt16(query.type, to: &body)
		self.appendUInt16(query.qclass, to: &body)
	}

	private static func appendUInt16(_ value: UInt16, to body: inout Data) {
		body.append(UInt8(value >> 8))
		body.append(UInt8(value & 0xFF))
	}

	private static func appendUInt32(_ value: UInt32, to body: inout Data) {
		body.append(UInt8((value >> 24) & 0xFF))
		body.append(UInt8((value >> 16) & 0xFF))
		body.append(UInt8((value >> 8) & 0xFF))
		body.append(UInt8(value & 0xFF))
	}

	private static func ipv4Octets(_ address: String) -> [UInt8]? {
		let parts = address.split(separator: ".")

		guard parts.count == 4 else { return nil }

		var octets: [UInt8] = []

		for part in parts {
			guard let value = UInt8(part) else { return nil }
			octets.append(value)
		}

		return octets
	}
}
