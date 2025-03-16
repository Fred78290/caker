import Foundation
import NIOCore
import NIOPosix
import Virtualization
import GRPCLib

class EstablishedConnection {
	let connection: VZVirtioSocketConnection
	let channel: Channel

	init(connection: VZVirtioSocketConnection, channel: Channel) {
		self.connection = connection
		self.channel = channel
	}

	func isFileDescriptorOpen(_ fd: Int32) -> Bool {
		return fcntl(fd, F_GETFD) != -1 || errno != EBADF
	}

	func haveBeenDisconnected() -> Bool {
		self.isFileDescriptorOpen(connection.fileDescriptor) == false
	}
}

class SocketState {
	let socket: SocketDevice
	var connections: [EstablishedConnection]

	var mode: SocketMode {
		self.socket.mode
	}

	var bind: String {
		self.socket.bind
	}

	var port: Int {
		self.socket.port
	}

	var description: String {
		self.socket.description
	}

	var fileDescriptors: (Int32, Int32) {
		socket.fileDescriptors
	}

	init(vsock: SocketDevice) {
		self.socket = vsock
		self.connections = []
	}

	// Called when the guest vsock is closed by remote or host socket is closed
	func closedByRemote(_ fd: Int32) -> Channel? {
		self.connections.first { $0.connection.fileDescriptor == fd }.map { connection in
			self.connections.removeAll { $0 === connection }

			Logger(self).debug("Socket connection on \(self.description) via fd:\(fd) is closed by remote")

			return connection.channel
		}
	}

	// Check broken connections
	func haveBeenDisconnected() -> [Channel] {
		self.connections.compactMap { connection in
			if connection.haveBeenDisconnected() {
				Logger(self).info("Socket connection on \(self.description) was closed by remote")

				return connection.channel
			}

			return nil
		}
	}
}

class VirtioSocketDevices: NSObject, VZVirtioSocketListenerDelegate, CatchRemoteCloseDelegate {
	private let queue = DispatchQueue(label: "com.cirruslabs.VirtualSocketQueue")
	private let mainGroup: EventLoopGroup
	private var sockets: [Int: SocketState]
	private var channels: [Channel]
	private var socketDevice: VZVirtioSocketDevice?
	private var idle: RepeatedTask?

	private init(on: EventLoopGroup, sockets: [SocketDevice]) {
		var socketStates: [Int: SocketState] = [:]

		sockets.map({ SocketState(vsock: $0) }).forEach {
			socketStates[$0.socket.port] = $0
		}

		self.channels = []
		self.sockets = socketStates
		self.mainGroup = on
	}

	// Close all channels
	func close() {
		if self.channels.isEmpty {
			return
		}

		let futures = self.sockets.reduce(into: [EventLoopFuture<Void>](), { futures, socket in
			socket.value.connections.forEach { connection in
				self.channels.removeAll { $0 === connection.channel }
				let futureResult: EventLoopFuture<Void> = connection.channel.close()

				futureResult.whenComplete { _ in
					self.queue.sync {
						// When the channel is closed, close the connection
						connection.connection.close()
					}
				}

				futures.append(connection.channel.close())
			}
		})

		_ = try? EventLoopFuture.whenAllComplete(futures, on: mainGroup.next()).wait()
	}

	func closedByRemote(port: Int, fd: Int32) {
		if let socket = sockets[port] {
			if let channel = socket.closedByRemote(fd) {
				self.queue.sync {
					self.channels.removeAll { $0 === channel }
				}

				return
			}
		}

		Logger(self).warn("Closed socket connection on port:\(port) via fd:\(fd) is not found, already closed?")
	}

	// The guest initiates the connection to the host, the host must listen for the connection on the port
	private func connectionInitiatedByGuest(inboundChannel: Channel, socket: SocketState, connection: VZVirtioSocketConnection)
		-> EventLoopFuture<Void>
	{
		Logger(self).debug("Guest connected on \(socket.description) via fd:\(connection.fileDescriptor)")

		return NIOPipeBootstrap(group: inboundChannel.eventLoop)
			.takingOwnershipOfDescriptor(inputOutput: dup(connection.fileDescriptor))
			.flatMap { childChannel in
				let (ours, theirs) = GlueHandler.matchedPair()
				let handler = CatchRemoteClose(port: Int(connection.destinationPort), fd: connection.fileDescriptor, delegate: self)

				return childChannel.pipeline.addHandlers([handler, ours]).flatMap {
					inboundChannel.pipeline.addHandlers([
						handler, theirs
					])
				}
			}
	}

	// The host initiates the connection to the guest, the guest must listen for the connection on the port
	private func connectionInitiatedByHost(inboundChannel: Channel, socketDevice: VZVirtioSocketDevice, port: Int)
		-> EventLoopFuture<Void>
	{
		// Create a promise to notify the connection status
		let promise: EventLoopPromise<Void> = inboundChannel.eventLoop.makePromise(of: Void.self)

		// Try to connect to the socket device, if the connection is successful, start nio pipe
		socketDevice.connect(toPort: UInt32(port)) { result in
			switch result {
			case let .success(connection):

				guard let socket = self.sockets[port] else {
					promise.fail(ServiceError("Socket device not found on port:\(port)"))
					return
				}

				// Keep the connection for the socket
				socket.connections.append(EstablishedConnection(connection: connection, channel: inboundChannel))

				Logger(self).debug("Host connected on \(socket.description) via fd:\(connection.fileDescriptor)")

				do {

					// Pipe the connection to the channel
					try NIOPipeBootstrap(group: inboundChannel.eventLoop)
						.takingOwnershipOfDescriptor(inputOutput: dup(connection.fileDescriptor))
						.flatMap { childChannel in
							let (ours, theirs) = GlueHandler.matchedPair()
							let handler = CatchRemoteClose(port: port, fd: connection.fileDescriptor, delegate: self)

							return childChannel.pipeline.addHandlers([handler, ours])
								.flatMap {
									inboundChannel.pipeline.addHandlers([handler, theirs])
								}
						}.wait()

					// Notify the promise that the connection is successful
					promise.succeed(())
				} catch {
					if error.localizedDescription.contains("Connection reset by peer") == false {
						Logger(self).error("Failed to connect to socket device on port:\(port) via fd:\(connection.fileDescriptor), \(error)")
					}
					promise.fail(error)
				}
			case let .failure(error):
				if error.localizedDescription.contains("Connection reset by peer") == false {
					Logger(self).error("Failed to connect to socket device on port:\(port), \(error)")
				}
				// Notify the promise that the connection is failed
				promise.fail(error)
			}
		}

		return promise.futureResult
	}

	func connect(virtualMachine: VZVirtualMachine) {
		if let socketDevice: VZVirtioSocketDevice = virtualMachine.socketDevices.first as? VZVirtioSocketDevice {
			// Keep the socket device
			self.socketDevice = socketDevice
			let eventLoop = mainGroup.next()

			// Start the idle task to check broken connections
			// If the connection is broken, close the channel
			// Needed because we don't have a way to listen for the channel close event
			self.idle = eventLoop.scheduleRepeatedAsyncTask(
				initialDelay: TimeAmount.seconds(10), delay: TimeAmount.milliseconds(500)
			) {
				RepeatedTask in

				return self.queue.sync {
					self.sockets.forEach { port, socket in
						socket.haveBeenDisconnected().forEach { disconnected in
							self.channels.removeAll { $0 === disconnected }
						}
					}

					return eventLoop.makeSucceededVoidFuture()
				}
			}

			let listener: VZVirtioSocketListener = VZVirtioSocketListener()

			listener.delegate = self

			// Set the listener delegate for each socket
			self.sockets.forEach { port, socket in
				let channel: EventLoopFuture<Channel>

				// Add the listener to the socket device for the port
				socketDevice.setSocketListener(listener, forPort: UInt32(port))

				if socket.mode == .bind || socket.mode == .tcp || socket.mode == .udp {
					let channelInitializer: @Sendable (Channel) -> EventLoopFuture<Void> = { channel in
						// Here we connect to the guest socket device
						// !!! This is a blocking call, we need to run it on the main thread !!!
						return DispatchQueue.main.sync {
							return self.connectionInitiatedByHost(inboundChannel: channel, socketDevice: socketDevice, port: port)
						}
					}

					if socket.mode == .udp {
						// Start listening on the udp socket
						let bootstrap = DatagramBootstrap(group: mainGroup)
							.channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
							.channelInitializer(channelInitializer)

						// Bind udp socket to the port
						channel = bootstrap.bind(host: socket.bind, port: port)
					} else if socket.mode == .tcp {
						// Start listening on tcp socket
						let bootstrap = ServerBootstrap(group: mainGroup)
							.serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
							.childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
							.childChannelInitializer(channelInitializer)

						// Bind tcp socket to the port
						channel = bootstrap.bind(host: socket.bind, port: port)
					} else {
						// Start listening on unix socket
						let bootstrap = ServerBootstrap(group: mainGroup)
							.serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
							.childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
							.childChannelInitializer(channelInitializer)

						// Bind the unix socket device to the port
						// ??? We need to unlink the unix socket before binding the socket ???
						channel = bootstrap.bind(unixDomainSocketPath: socket.bind, cleanupExistingSocketFile: true)
					}

					// Get the channel to be ready
					channel.whenComplete { result in
						self.queue.sync {
							switch result {
							case let .success(channel):
								self.channels.append(channel)
								Logger(self).debug("Socket device connected on \(socket.description)")
							case let .failure(error):
								Logger(self).error("Failed to connect socket device on \(socket.description), \(error)")
							}
						}
					}
				}
			}
		}
	}

	func listener(
		_ listener: VZVirtioSocketListener,
		shouldAcceptNewConnection connection: VZVirtioSocketConnection,
		from socketDevice: VZVirtioSocketDevice
	) -> Bool {
		Logger(self).debug("Socket device connection on port:\(connection.destinationPort) via fd:\(connection.fileDescriptor) should be accepted")

		// The connection is initiated by the guest
		guard let socket = sockets[Int(connection.destinationPort)] else {
			Logger(self).debug("Unbound socket port:\(connection.destinationPort) via fd:\(connection.fileDescriptor)")
			// Unbound socket port
			return false
		}

		if socket.mode == .connect {
			do {
				Logger(self).debug("Connect to the unix socket:\(socket.description) via fd:\(connection.fileDescriptor)")
				// Connect to the unix socket
				return try self.queue.sync {
					let channel = try ClientBootstrap(group: mainGroup)
						.channelInitializer { channel in
							// The connection is initiated by the guest
							return self.connectionInitiatedByGuest(inboundChannel: channel, socket: socket, connection: connection)
						}
						.connect(unixDomainSocketPath: socket.bind).wait()

					// Ok to accept the connection
					self.channels.append(channel)
					socket.connections.append(EstablishedConnection(connection: connection, channel: channel))

					return true
				}
			} catch {
				// Reject vsock connection if the connection to unix socket failed
				Logger(self).error("Failed to connect the socket device on \(socket.description), \(error)")
				return false
			}
		} else if socket.mode == .fd {
			// The connection is initiated by the guest
			Logger(self).debug("Connect to the host file descriptor:\(socket.description) via fd:\(connection.fileDescriptor)")

			do {
				return try self.queue.sync {
					let (input, output) = socket.fileDescriptors

					let channel = try NIOPipeBootstrap(group: mainGroup)
						.channelInitializer { channel in
							// The connection is initiated by the guest
							return self.connectionInitiatedByGuest(inboundChannel: channel, socket: socket, connection: connection)
						}
						.takingOwnershipOfDescriptors(input: dup(input), output: dup(output)).wait()

					// Ok to accept the connection
					self.channels.append(channel)
					socket.connections.append(EstablishedConnection(connection: connection, channel: channel))

					return true
				}
			} catch {
				// Reject vsock connection if the connection to unix socket failed
				Logger(self).error("Failed to connect the socket device on \(socket.description), \(error)")
				return false
			}

		} else {
			Logger(self).debug("Assume the connection is possible in bind mode on \(socket.description), port:\(connection.destinationPort) via fd:\(connection.fileDescriptor)")
		}

		return false
	}

	private func configure(configuration: VZVirtualMachineConfiguration) -> VirtioSocketDevices {
		if self.sockets.isEmpty {
			return self
		}

		configuration.socketDevices.append(VZVirtioSocketDeviceConfiguration())

		return self
	}

	static func setupVirtioSocketDevices(
		on: EventLoopGroup,
		configuration: VZVirtualMachineConfiguration, sockets: [SocketDevice]
	) -> VirtioSocketDevices {
		return VirtioSocketDevices(on: on, sockets: sockets).configure(configuration: configuration)
	}
}
