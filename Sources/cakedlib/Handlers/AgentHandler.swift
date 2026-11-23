//
//  AgentHandler.swift
//  Caker
//
//  `caked agent` / `cakectl agent`: query, install and update the cakeagent that runs inside a VM,
//  without needing Caker.app (whose toolbar button does the same).
//
import CakeAgentLib
import Foundation
import GRPC
import GRPCLib

/// What `agent version` reports for one VM.
public struct AgentVersionReply: Codable, Sendable {
	/// The VM's name.
	public let name: String
	/// Whether the VM is running: a stopped VM has no agent to ask.
	public let running: Bool
	/// The version of the agent running in the guest, `nil` when it is not installed, not started yet or not answering.
	public let version: String?
	/// The version this build installs (`CAKEAGENT_VERSION`).
	public let expected: String
	/// The guest runs exactly the agent this build installs. Stored, not computed, so `--json` carries it.
	public let upToDate: Bool

	public init(name: String, running: Bool, version: String?, expected: String = CAKEAGENT_VERSION) {
		let version = version?.isEmpty == true ? nil : version

		self.name = name
		self.running = running
		self.version = version
		self.expected = expected
		self.upToDate = version != nil && version == expected
	}

	/// One line for people; `--format json` renders the struct itself.
	public var summary: String {
		guard self.running else {
			return String(format: String(localized: "VM %@ is not running, its agent cannot be queried (this build installs %@)"), self.name, self.expected)
		}

		guard let version = self.version else {
			return String(format: String(localized: "VM %@: the agent is not installed or not answering (this build installs %@)"), self.name, self.expected)
		}

		if self.upToDate {
			return String(format: String(localized: "VM %@: agent %@ is up to date"), self.name, version)
		}

		return String(format: String(localized: "VM %@: agent %@ is installed, this build installs %@: run 'agent update'"), self.name, version, self.expected)
	}
}

/// What an `agent install`/`agent update` did.
public struct AgentInstallReply: Codable, Sendable {
	public let name: String
	/// The agent was (re)installed by this call.
	public let installed: Bool
	/// `agent update` found nothing to do.
	public let skipped: Bool
	public let reason: String

	public init(name: String, installed: Bool, skipped: Bool = false, reason: String) {
		self.name = name
		self.installed = installed
		self.skipped = skipped
		self.reason = reason
	}

	public var success: Bool {
		self.installed || self.skipped
	}

	public init(_ from: InstalledAgentReply) {
		self.init(name: from.name, installed: from.installed, reason: from.reason.isEmpty && from.installed ? String(format: String(localized: "Agent %@ installed on %@"), CAKEAGENT_VERSION, from.name) : from.reason)
	}
}

public struct AgentHandler {
	/// Seconds the host retries to reach the guest's SSH server while installing (Caker.app uses 2).
	public static let defaultInstallTimeout: UInt = 30

	/// What `agent update` has to do given what the guest runs: install unless it already has this build's version.
	public static func updateIsNeeded(_ reply: AgentVersionReply, force: Bool) -> Bool {
		force || reply.upToDate == false
	}

	/// The result of an `agent update` that found the agent current.
	public static func upToDate(_ reply: AgentVersionReply) -> AgentInstallReply {
		AgentInstallReply(name: reply.name, installed: false, skipped: true, reason: String(format: String(localized: "Agent %@ is already up to date on %@"), reply.version ?? reply.expected, reply.name))
	}

	/// Asks the agent of a VM of this host (through its own vsock socket, no service needed) which version it runs.
	public static func version(name: String, runMode: Utils.RunMode, timeout: Int64 = 3) -> AgentVersionReply {
		let location: VMLocation

		do {
			location = try StorageLocation(runMode: runMode).find(name)
		} catch {
			Logger("AgentHandler").debug("Unable to query the agent of \(name): \(error.reason)")

			return AgentVersionReply(name: name, running: false, version: nil)
		}

		guard case .running = location.status else {
			return AgentVersionReply(name: location.name, running: false, version: nil)
		}

		// The VM is running: whatever fails from here on means the agent can't be reached, not that the VM is stopped.
		do {
			let helper = try CakeAgentHelper.createCakeAgentHelper(location: location, connectionTimeout: timeout, retries: .upTo(1), runMode: runMode)
			let version = try? helper.info(callOptions: CallOptions(timeLimit: .timeout(.seconds(timeout)))).agentVersion

			return AgentVersionReply(name: location.name, running: true, version: version)
		} catch {
			Logger("AgentHandler").debug("Unable to query the agent of \(name): \(error.reason)")

			return AgentVersionReply(name: location.name, running: true, version: nil)
		}
	}

	/// Installs the agent in a VM of this host, unconditionally.
	public static func install(name: String, timeout: UInt = AgentHandler.defaultInstallTimeout, runMode: Utils.RunMode) -> AgentInstallReply {
		AgentInstallReply(InstallAgentHandler.installAgent(name: name, timeout: timeout, runMode: runMode))
	}

	/// Installs the agent in a VM of this host unless it already runs this build's version.
	public static func update(name: String, force: Bool, timeout: UInt = AgentHandler.defaultInstallTimeout, runMode: Utils.RunMode) -> AgentInstallReply {
		let current = self.version(name: name, runMode: runMode)

		guard self.updateIsNeeded(current, force: force) else {
			return self.upToDate(current)
		}

		return self.install(name: name, timeout: timeout, runMode: runMode)
	}
}

extension CakeAgentLib.Format {
	public func render(_ data: AgentVersionReply) -> String {
		if self == .json {
			return self.renderSingle(data)
		}

		return data.summary
	}

	public func render(_ data: AgentInstallReply) -> String {
		if self == .json {
			return self.renderSingle(data)
		}

		return data.reason
	}
}
