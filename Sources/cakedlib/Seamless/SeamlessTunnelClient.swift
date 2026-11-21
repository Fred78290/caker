import CakeAgentLib
import Darwin
import Foundation
import GRPC
import GRPCLib
import NIO

/// The client end of `caked`'s `SeamlessTunnel`: shows the windows of a guest whose VM runs under a `caked` that
/// may be on another host.
///
/// The service listens for the guest compositor and relays its byte stream over a gRPC stream. This end turns
/// that stream into a socket (`socketpair`) whose other end is handed to a `SeamlessWindowManager`
/// (`attach(fd:)`), so the manager works exactly as it does with a local guest and needs no socket of its own.
public final class SeamlessTunnelClient: @unchecked Sendable {
	private let logger = Logger("SeamlessTunnelClient")
	private let writeQueue = DispatchQueue(label: "com.aldunelabs.caker.seamless.tunnel.write")
	private let lock = NSLock()
	private var local: Int32 = -1
	private var stream: BidirectionalStreamingCall<Caked_SeamlessStream, Caked_SeamlessStream>?
	private var ended = false
	/// Writes to `local` in flight: the descriptor is closed once none can use it, a closed number could be reused.
	private var activeWrites = 0
	private var closePending = false
	/// What the service sent and the window manager has not read yet. The gRPC callback API can't pause delivery, so
	/// a manager that stops reading would make this grow without bound: past the budget the tunnel ends instead
	/// (bytes can't be dropped from a framed stream), and the client connects again.
	private var queuedBytes = 0
	/// A clipboard (32 MiB of data at most) is one message for the guest, so the queue holds one and some more.
	private static let maxQueuedBytes = 48 * 1024 * 1024

	public init() {}

	/// Opens the tunnel to `vmName`'s guest and returns the descriptor to give the window manager (`attach(fd:)`).
	/// `onEnd` is called once, with the error if the stream ended on one (the service is gone, the VM has no
	/// seamless windows, another process already shows them).
	public func open(client: CakedServiceClient, vmName: String, onEnd: @escaping @Sendable (Error?) -> Void) throws -> Int32 {
		var pair: [Int32] = [-1, -1]

		guard socketpair(AF_UNIX, SOCK_STREAM, 0, &pair) == 0 else {
			throw ServiceError("seamless: socketpair failed: \(String(cString: strerror(errno)))")
		}

		var one: Int32 = 1

		for descriptor in pair {
			setsockopt(descriptor, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size))
		}

		self.local = pair[0]

		let options = CallOptions(customMetadata: .init([(CakedServiceClient.META_CAKEAGENT_VMNAME, vmName)]), timeLimit: .none)

		let call = client.seamlessTunnel(callOptions: options) { [weak self] response in
			guard let self, response.stream.isEmpty == false else { return }

			self.lock.lock()
			self.queuedBytes += response.stream.count
			let overflow = self.queuedBytes > Self.maxQueuedBytes
			self.lock.unlock()

			if overflow {
				self.logger.warn("Seamless tunnel: the window manager does not read, ending the tunnel")
				self.close()

				return
			}

			self.writeQueue.async { self.write(response.stream) }
		}

		self.lock.lock()
		self.stream = call
		self.lock.unlock()

		call.status.whenComplete { [weak self] result in
			var failure: Error?

			switch result {
			case .success(let status):
				if status.isOk == false {
					failure = status
				}
			case .failure(let error):
				failure = error
			}

			self?.finish()
			onEnd(failure)
		}

		let reader = Thread { [weak self] in
			self?.forwardToService()
		}

		reader.name = "seamless-tunnel-reader"
		reader.start()

		return pair[1]
	}

	/// Ends the tunnel; the service stops listening for the guest.
	public func close() {
		self.lock.lock()
		let call = self.stream
		self.lock.unlock()

		call?.cancel(promise: nil)
		self.finish()
	}

	private func finish() {
		self.lock.lock()
		defer { self.lock.unlock() }

		guard self.ended == false else { return }

		self.ended = true

		if self.local >= 0 {
			// Wakes the reader thread, which owns the descriptor and closes it.
			Darwin.shutdown(self.local, SHUT_RDWR)
		}
	}

	private var isEnded: Bool {
		self.lock.lock()
		defer { self.lock.unlock() }

		return self.ended
	}

	/// The window manager's output (its input events and replies to the guest) goes to the service. One message at
	/// a time, waiting for it to leave: the manager's send queue is the buffer, not memory here.
	private func forwardToService() {
		let descriptor = self.local
		let chunk = UnsafeMutableRawBufferPointer.allocate(byteCount: 64 * 1024, alignment: 16)

		defer {
			chunk.deallocate()

			self.lock.lock()
			let call = self.stream

			if self.activeWrites > 0 {
				// A write is still in flight: the last one to leave closes the descriptor.
				self.closePending = true
			} else {
				self.local = -1
				Darwin.close(descriptor)
			}

			self.lock.unlock()

			call?.sendEnd(promise: nil)
		}

		while self.isEnded == false {
			let n = Darwin.read(descriptor, chunk.baseAddress!, chunk.count)

			if n < 0 && errno == EINTR { continue }
			if n <= 0 { return }

			self.lock.lock()
			let call = self.stream
			self.lock.unlock()

			guard let call else { return }

			do {
				try call.sendMessage(Caked_SeamlessStream.with { $0.stream = Data(bytes: chunk.baseAddress!, count: n) }).wait()
			} catch {
				self.logger.debug("Seamless tunnel send failed: \(error)")

				return
			}
		}
	}

	/// The service's output (the guest's frames) goes to the window manager. Called on a serial queue, so that a
	/// manager that is slow to read blocks this queue and not the gRPC event loop.
	private func write(_ data: Data) {
		self.lock.lock()
		let descriptor = self.ended ? -1 : self.local

		if descriptor >= 0 {
			self.activeWrites += 1
		}

		self.lock.unlock()

		defer {
			self.lock.lock()
			self.queuedBytes = max(0, self.queuedBytes - data.count)

			if descriptor >= 0 {
				self.activeWrites -= 1

				if self.activeWrites == 0 && self.closePending && self.local >= 0 {
					Darwin.close(self.local)
					self.local = -1
				}
			}

			self.lock.unlock()
		}

		guard descriptor >= 0 else { return }

		data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
			var sent = 0

			while sent < raw.count {
				let n = Darwin.write(descriptor, raw.baseAddress! + sent, raw.count - sent)

				if n < 0 {
					if errno == EINTR { continue }

					self.finish()

					return
				}

				sent += n
			}
		}
	}
}
