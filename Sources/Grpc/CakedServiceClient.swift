//
//  CakedServiceClient.swift
//  Caker
//
//  Created by Frederic BOLTZ on 11/03/2026.
//
import Foundation
import GRPC
import NIOCore
import NIOPosix
import Logging

extension CakedServiceClient {
	public func info(name: String, includeConfig: Bool = false, timeout: Int64 = 10) throws -> Caked_Reply {
		return try self.info(.with {
			$0.name = name
			$0.includeConfig = includeConfig
		}, callOptions: CallOptions(timeLimit: .timeout(.seconds(timeout)))).response.wait()
	}

	public func shell(name: String, rows: Int32, cols: Int32, handler: @escaping (Caked_ExecuteResponse) -> Void) throws -> BidirectionalStreamingCall<Caked_ExecuteRequest, Caked_ExecuteResponse> {
		let stream = self.execute(callOptions: CallOptions(customMetadata: .init([("CAKEAGENT_VMNAME", name)]), timeLimit: .none), handler: handler)

		try stream.sendTerminalSize(rows: rows, cols: cols).wait()
		try stream.sendShell().wait()

		return stream
	}

	internal func exec(
		name: String,
		command: CakedChannelStreamer.ExecuteCommand,
		inputHandle: FileHandle = FileHandle.standardInput,
		outputHandle: FileHandle = FileHandle.standardOutput,
		errorHandle: FileHandle = FileHandle.standardError,
		callOptions: CallOptions? = nil
	) async throws -> Int32 {
		let handler = CakedChannelStreamer(inputHandle: inputHandle, outputHandle: outputHandle, errorHandle: errorHandle)
		var callOptions = callOptions ?? CallOptions()

		callOptions.timeLimit = .none
		callOptions.customMetadata.add(name: "CAKEAGENT_VMNAME", value: name)

		return try await handler.stream(command: command) {
			return self.execute(callOptions: callOptions, handler: handler.handleResponse)
		}
	}

	public func exec(
		name: String,
		command: String,
		arguments: [String],
		inputHandle: FileHandle = FileHandle.standardInput,
		outputHandle: FileHandle = FileHandle.standardOutput,
		errorHandle: FileHandle = FileHandle.standardError,
		callOptions: CallOptions? = nil
	) async throws -> Int32 {
		return try await self.exec(name: name, command: .execute(command, arguments), inputHandle: inputHandle, outputHandle: outputHandle, errorHandle: errorHandle, callOptions: callOptions)
	}

	public func shell(
		name: String,
		inputHandle: FileHandle = FileHandle.standardInput,
		outputHandle: FileHandle = FileHandle.standardOutput,
		errorHandle: FileHandle = FileHandle.standardError,
		callOptions: CallOptions? = nil
	) async throws -> Int32 {
		return try await self.exec(name: name, command: .shell(), inputHandle: inputHandle, outputHandle: outputHandle, errorHandle: errorHandle, callOptions: callOptions)
	}
	
	/// Creates a local VNC tunnel server and forwards connections to the remote VM
	/// - Parameters:
	///   - vmName: Name of the VM to connect to
	///   - localPort: Local port to bind the VNC server (0 for automatic port selection)
	///   - eventLoopGroup: Event loop group for networking
	/// - Returns: The local port number where the VNC server is listening
	@discardableResult
	public func createVNCTunnel(
		vmName: String,
		localPort: Int = 0,
		eventLoopGroup: EventLoopGroup
	) async throws -> Int {
		let logger = Logger(label: "VNCTunnel")
		
		// Create async client for VNC tunnel
		let asyncClient = Caked_ServiceAsyncClient(channel: self.channel, defaultCallOptions: self.defaultCallOptions, interceptors: nil)
		
		// Create the server bootstrap for local VNC clients
		let bootstrap = ServerBootstrap(group: eventLoopGroup)
			.serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
			.childChannelOption(.maxMessagesPerRead, value: 16)
			.childChannelOption(.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
			.childChannelInitializer { channel in
				// For each new VNC client connection, create a tunnel
				channel.pipeline.addHandler(VNCTunnelHandler(
					client: asyncClient,
					vmName: vmName,
					logger: logger
				))
			}
		
		// Bind to local port
		let serverChannel = try await bootstrap.bind(host: "127.0.0.1", port: localPort).get()
		let actualPort = serverChannel.localAddress?.port ?? localPort
		
		logger.info("VNC tunnel server listening on port \(actualPort) for VM '\(vmName)'")
		
		// Keep the server running - it will close when the task is cancelled
		try await withTaskCancellationHandler {
			try await serverChannel.closeFuture.get()
		} onCancel: {
			serverChannel.close(promise: nil)
		}
		
		return actualPort
	}
}

/// Handles individual VNC client connections and forwards them through gRPC tunnel
private final class VNCTunnelHandler: ChannelInboundHandler {
	typealias InboundIn = ByteBuffer
	typealias OutboundOut = ByteBuffer
	
	private let client: Caked_ServiceAsyncClient
	private let vmName: String
	private let logger: Logger
	private var grpcStream: GRPCAsyncBidirectionalStreamingCall<Caked_VncStream, Caked_VncStream>?
	private var forwardingTask: Task<Void, Never>?
	
	init(client: Caked_ServiceAsyncClient, vmName: String, logger: Logger) {
		self.client = client
		self.vmName = vmName
		self.logger = logger
	}
	
	func channelActive(context: ChannelHandlerContext) {
		logger.debug("VNC client connected for VM '\(vmName)'")
		
		// Start the gRPC tunnel
		Task { [weak self] in
			await self?.startGRPCTunnel(context: context)
		}
	}
	
	func channelRead(context: ChannelHandlerContext, data: NIOAny) {
		let buffer = self.unwrapInboundIn(data)
		
		// Forward data from VNC client to gRPC stream
		guard let stream = grpcStream else {
			logger.warning("Received data but gRPC stream not ready")
			return
		}
		
		Task {
			do {
				let vncMessage = Caked_VncStream.with { message in
					message.stream = Data(buffer.readableBytesView)
				}
				try await stream.requestStream.send(vncMessage)
			} catch {
				self.logger.error("Error forwarding VNC data: \(error)")
				context.close(promise: nil)
			}
		}
	}
	
	func channelInactive(context: ChannelHandlerContext) {
		logger.debug("VNC client disconnected for VM '\(vmName)'")
		forwardingTask?.cancel()
		grpcStream?.cancel()
	}
	
	func errorCaught(context: ChannelHandlerContext, error: Error) {
		logger.error("VNC tunnel error: \(error)")
		context.close(promise: nil)
	}
	
	private func startGRPCTunnel(context: ChannelHandlerContext) async {
		// Create gRPC call options with VM name header
		let callOptions = CallOptions(
			customMetadata: .init([("CAKEAGENT_VMNAME", vmName)]),
			timeLimit: .none
		)
		
		// Start the gRPC bidirectional stream
		grpcStream = client.makeVncTunnelCall(callOptions: callOptions)
		
		guard let stream = grpcStream else {
			logger.error("Failed to create gRPC stream")
			context.close(promise: nil)
			return
		}
		
		// Start forwarding data from gRPC stream to VNC client
		forwardingTask = Task { [weak self] in
			do {
				for try await response in stream.responseStream {
					guard let self = self else { return }
					
					try Task.checkCancellation()
					
					if !response.stream.isEmpty {
						var buffer = context.channel.allocator.buffer(capacity: response.stream.count)
						buffer.writeBytes(response.stream)
						context.writeAndFlush(self.wrapOutboundOut(buffer), promise: nil)
					}
				}
			} catch {
				if !(error is CancellationError) {
					self?.logger.error("Error receiving VNC data from gRPC: \(error)")
				}
				context.close(promise: nil)
			}
		}
	}
}
