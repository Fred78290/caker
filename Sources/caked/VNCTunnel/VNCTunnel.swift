//
//  VNCTunnel.swift
//  Caker
//
//  Created by Frederic BOLTZ on 25/04/2026.
//
import Foundation
import GRPC
import GRPCLib
import Synchronization
import NIO
import CakeAgentLib
import CakedLib

typealias AsyncThrowingStreamCakedVNCStream = (
	stream: AsyncThrowingStream<Caked_VncStream, Error>,
	continuation: AsyncThrowingStream<Caked_VncStream, Error>.Continuation
)

final class VNCTunnel {
	typealias ListenerID = UUID

	class Tunneling: Identifiable {
		var id: ListenerID = UUID()

		let requestStream: GRPCAsyncRequestStream<Caked_VncStream>
		let responseStream: GRPCAsyncResponseStreamWriter<Caked_VncStream>
		let group: EventLoopGroup
		let vmName: String
		let runMode: Utils.RunMode
		private var tunnelTask: Task<Void, Never>? = nil

		init(requestStream: GRPCAsyncRequestStream<Caked_VncStream>, responseStream: GRPCAsyncResponseStreamWriter<Caked_VncStream>, group: EventLoopGroup, vmName: String, runMode: Utils.RunMode) {
			self.requestStream = requestStream
			self.responseStream = responseStream
			self.group = group
			self.vmName = vmName
			self.runMode = runMode
		}

		func stopTunnel() {
			let logger = Logger("VNCTunneling")
			logger.debug("Stopping VNC tunnel, id: \(id)")
			
			// Annuler la tâche du tunnel
			tunnelTask?.cancel()
			tunnelTask = nil
		}

		func startTunnel() {
			tunnelTask = Task {
				await handleVNCTunnel()
			}
		}
		
		func handleVNCTunnel() async {
			do {
				let logger = Logger("VNCTunneling")
				logger.debug("Starting VNC tunnel for VM: \(vmName), id: \(id)")
				
				// Récupérer les informations VNC pour cette machine virtuelle
				let vncInfos = try VNCInfosHandler.vncInfos(name: vmName, runMode: runMode)
				
				guard !vncInfos.urls.isEmpty else {
					logger.error("No VNC URL found for VM: \(vmName)")
					return
				}
				
				// Extraire l'host et le port de la première URL VNC
				guard let vncURL = URL(string: vncInfos.urls[0]) else {
					logger.error("Invalid VNC URL: \(vncInfos.urls[0])")
					return
				}
				
				let vncHost = vncURL.host ?? "127.0.0.1"
				let vncPort = vncURL.port ?? 5900
				
				logger.debug("Connecting to VNC server for VM \(vmName) at \(vncHost):\(vncPort)")
				
				let bootstrap = ClientBootstrap(group: group)
					.channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
					.channelInitializer { channel in
						return channel.eventLoop.makeSucceededVoidFuture()
					}
				
				let vncAddress = try SocketAddress.makeAddressResolvingHost(vncHost, port: vncPort)
				let channel = try await bootstrap.connect(to: vncAddress)
				
				logger.debug("Connected to VNC server for VM \(vmName) at \(vncHost):\(vncPort)")
				
				let asyncChannel = try NIOAsyncChannel<ByteBuffer, ByteBuffer>(wrappingChannelSynchronously: channel)
				
				try await asyncChannel.executeThenClose { input, output in
					await withTaskGroup { group in
						// Tâche pour lire du requestStream et écrire au serveur VNC
						group.addTask {
							do {
								var iterator = self.requestStream.makeAsyncIterator()
								
								while let vncMessage = try await iterator.next() {
									// Vérifier l'annulation
									try Task.checkCancellation()
									
									let buffer = channel.allocator.buffer(data: vncMessage.stream)
									try await output.write(buffer)
								}
								
								logger.debug("Request stream ended, closing VNC write channel")
							} catch is CancellationError {
								logger.debug("VNC request stream task cancelled")
							} catch {
								logger.error("Error handling request stream: \(error)")
							}
						}
						
						// Tâche pour lire du serveur VNC et écrire au responseStream
						group.addTask {
							do {
								for try await buffer in input {
									// Vérifier l'annulation
									try Task.checkCancellation()
									
									let data = Data(buffer: buffer)
									let vncStream = Caked_VncStream.with {
										$0.stream = data
									}
									try await self.responseStream.send(vncStream)
								}
								
								logger.debug("VNC server connection ended")
							} catch is CancellationError {
								logger.debug("VNC response stream task cancelled")
							} catch {
								logger.error("Error handling VNC server response: \(error)")
							}
						}
					}
				}
				
				logger.debug("VNC tunnel ended for VM \(vmName), id: \(id)")
				
			} catch is CancellationError {
				let logger = Logger("VNCTunneling")
				logger.debug("VNC tunnel cancelled for VM \(vmName), id: \(id)")
			} catch {
				let logger = Logger("VNCTunneling")
				logger.error("Failed to start VNC tunnel for VM \(vmName), id: \(id), error: \(error)")
			}
		}
	}

	let runMode: Utils.RunMode
	let group: EventLoopGroup
	let listeners: Mutex<[ListenerID: Tunneling]>
	let logger = Logger("VNCTunnel")

	public init(group: EventLoopGroup, runMode: Utils.RunMode) {
		self.group = group
		self.runMode = runMode
		self.listeners = .init([:])
	}

	public func stopVNCTunnel() {
		self.listeners.withLock { listeners in
			listeners.values.forEach {
				$0.stopTunnel()
			}
		}
	}

	public func tunnel(requestStream: GRPCAsyncRequestStream<Caked_VncStream>, responseStream: GRPCAsyncResponseStreamWriter<Caked_VncStream>, vmName: String) {
		let tunnel = Tunneling(requestStream: requestStream, responseStream: responseStream, group: group, vmName: vmName, runMode: runMode)

		self.listeners.withLock {
			$0[tunnel.id] = tunnel
			self.logger.debug("Start VNC tunnel for VM \(vmName), id: \(tunnel.id)")
			self.logger.debug("Number of active VNC tunnels: \($0.count)")
		}

		defer {
			self.listeners.withLock {
				$0.removeValue(forKey: tunnel.id)
				self.logger.debug("Stop VNC tunnel for VM \(vmName), id: \(tunnel.id)")
			}
		}

		tunnel.startTunnel()
	}
}
