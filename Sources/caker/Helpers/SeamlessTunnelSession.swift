//
//  SeamlessTunnelSession.swift
//  Caker
//
import CakeAgentLib
import CakedLib
import Foundation
import GRPC
import GRPCLib

/// Shows the windows of a Linux VM run by a `caked` service (a local one or a remote one) on this desktop.
///
/// A VM run by the service has no UI process that could listen for its guest, and the service may be on another
/// host: it listens for the guest compositor itself for as long as this session's gRPC stream lasts (`SeamlessTunnel`)
/// and relays the bytes, which `SeamlessTunnelClient` turns into a stream socket for a `SeamlessWindowManager`.
/// In `.app` mode the VM runs in this process and `VirtualMachine.startSeamlessWindows()` does it directly.
///
/// The session is kept for as long as the VM runs: when the stream ends (the service restarted, a network blip) it
/// connects again, and gives up only on an answer that retrying can't change.
@MainActor
final class SeamlessTunnelSession {
	/// Statuses retrying can't change: the VM is gone, seamless is off for it, or another process shows its windows.
	private static let permanentFailures: Set<GRPCStatus.Code> = [.notFound, .failedPrecondition, .alreadyExists, .unimplemented, .unauthenticated, .permissionDenied]
	private static let retryDelay: Duration = .seconds(3)

	private let vmName: String
	private let connectionManager: ConnectionManager
	private let logger = Logger("SeamlessTunnelSession")
	private var wanted = false
	private var manager: SeamlessWindowManager?
	private var tunnel: SeamlessTunnelClient?
	private var client: CakedServiceClient?
	private var retry: Task<Void, Never>?
	/// Tells a stream's end from the end of one that was already replaced or stopped.
	private var generation = 0

	init(vmName: String, connectionManager: ConnectionManager) {
		self.vmName = vmName
		self.connectionManager = connectionManager
	}

	var isConnected: Bool {
		self.tunnel != nil
	}

	/// Starts showing the VM's windows; nothing to do when it already does.
	func start() {
		self.wanted = true

		guard self.tunnel == nil, self.retry == nil else { return }

		self.connect()
	}

	/// Stops showing them: the windows close and the service stops listening for the guest.
	func stop() {
		self.wanted = false
		self.retry?.cancel()
		self.retry = nil
		self.generation += 1
		self.teardown()
	}

	private func connect() {
		guard self.wanted else { return }

		guard let client = self.connectionManager.serviceClient else {
			self.logger.warn("Seamless windows of \(self.vmName): no connection to the service")
			self.scheduleRetry()

			return
		}

		self.generation += 1

		let generation = self.generation
		let manager = SeamlessWindowManager(vmName: self.vmName, displayMode: .ui)
		let tunnel = SeamlessTunnelClient()

		do {
			let descriptor = try tunnel.open(client: client, vmName: self.vmName) { [weak self] error in
				Task { @MainActor in
					self?.ended(generation, error: error)
				}
			}

			manager.attach(fd: descriptor)
		} catch {
			self.logger.error("Seamless windows of \(self.vmName): \(error)")
			_ = client.channel.close()
			self.scheduleRetry()

			return
		}

		self.client = client
		self.manager = manager
		self.tunnel = tunnel
		self.logger.debug("Seamless windows of \(self.vmName): tunnel opened")
	}

	private func ended(_ generation: Int, error: Error?) {
		guard generation == self.generation else { return }

		self.teardown()

		guard self.wanted else { return }

		if let status = error as? GRPCStatus, Self.permanentFailures.contains(status.code) {
			self.logger.warn("Seamless windows of \(self.vmName): \(status.message ?? status.description)")
			return
		}

		if let error {
			self.logger.debug("Seamless windows of \(self.vmName): tunnel ended: \(error)")
		}

		self.scheduleRetry()
	}

	private func scheduleRetry() {
		guard self.wanted, self.retry == nil else { return }

		self.retry = Task { [weak self] in
			try? await Task.sleep(for: Self.retryDelay)

			guard Task.isCancelled == false else { return }

			self?.retry = nil
			self?.connect()
		}
	}

	private func teardown() {
		let tunnel = self.tunnel
		let manager = self.manager
		let client = self.client

		self.tunnel = nil
		self.manager = nil
		self.client = nil

		tunnel?.close()
		manager?.stop()

		if let client {
			_ = client.channel.close()
		}
	}
}
