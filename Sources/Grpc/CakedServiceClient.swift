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
	public func vncInfos(name: String, includeConfig: Bool = false, timeout: Int64 = 10) throws -> Caked_Reply {
		return try self.vncInfos(.with {
			$0.name = name
			$0.includeConfig = includeConfig
		}, callOptions: CallOptions(timeLimit: .timeout(.seconds(timeout)))).response.wait()
	}

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
		eventLoopGroup: EventLoopGroup,
		vmName: String,
		localPort: Int = 0,
		handler: @escaping (Channel, Int) -> Void
	) throws -> Int {
		let logger = Logger(label: "VNCTunnel")

		// Create the server bootstrap for local VNC clients
		let bootstrap = ServerBootstrap(group: eventLoopGroup)
			.serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
			.childChannelOption(.maxMessagesPerRead, value: 16)
			.childChannelOption(.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
			.childChannelInitializer { channel in
				// For each new VNC client connection, create a tunnel
				channel.pipeline.addHandler(VNCTunnelHandler(
					client: self,
					vmName: vmName
				))
			}
		
		// Bind to local port
		let serverChannel = try bootstrap.bind(host: "127.0.0.1", port: localPort).wait()
		let actualPort = serverChannel.localAddress?.port ?? localPort
		
		logger.info("VNC tunnel server listening on port \(actualPort) for VM '\(vmName)'")
		
		handler(serverChannel, actualPort)
		
		return actualPort
	}
}

/// Handles individual VNC client connections and forwards them through gRPC tunnel
private final class VNCTunnelHandler: ChannelInboundHandler {
	typealias InboundIn = ByteBuffer
	typealias OutboundOut = ByteBuffer
	
	private let client: CakedServiceClient
	private let vmName: String
	private let logger = Logger(label: "VNCTunnelHandler")
	private var grpcStream: BidirectionalStreamingCall<Caked_Caked.VncStream, Caked_Caked.VncStream>! = nil
	
	init(client: CakedServiceClient, vmName: String) {
		self.client = client
		self.vmName = vmName
	}
	
	func channelRegistered(context: ChannelHandlerContext) {
		let channel = context.channel

		logger.debug("VNC client connected for VM '\(vmName)'")

		// Create gRPC call options with VM name header
		let callOptions = CallOptions(
			customMetadata: .init([("CAKEAGENT_VMNAME", vmName)]),
			timeLimit: .none
		)
		
		self.grpcStream = self.client.vncTunnel(callOptions: callOptions) { response in
			if response.stream.isEmpty == false {
				channel.writeAndFlush(ByteBuffer(data: response.stream), promise: nil)
			}
		}
	}
	
	func channelRead(context: ChannelHandlerContext, data: NIOAny) {
		let buffer = self.unwrapInboundIn(data)
		
		// Forward data from VNC client to gRPC stream
		guard let stream = grpcStream else {
			logger.warning("Received data but gRPC stream not ready")
			return
		}

		stream.sendMessage(Caked_VncStream.with { message in
			message.stream = Data(buffer.readableBytesView)
		}).whenComplete {
			switch $0 {
			case .success:
				break // Successfully sent to gRPC stream
			case .failure(let error):
				self.logger.error("Failed to send VNC data to gRPC stream: \(error)")
				self.errorCaught(context: context, error: error)
			}
		}
	}
	
	func channelInactive(context: ChannelHandlerContext) {
		logger.debug("VNC client disconnected for VM '\(vmName)'")

		grpcStream.sendEnd(promise: nil)
	}
	
	func errorCaught(context: ChannelHandlerContext, error: Error) {
		logger.error("VNC tunnel error: \(error)")
		context.close(promise: nil)
	}
}
