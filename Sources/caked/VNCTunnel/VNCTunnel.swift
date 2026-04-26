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
	typealias TunnelID = UUID

	private class Tunneling: Identifiable {
		var id: TunnelID = UUID()

		private let requestStream: GRPCAsyncRequestStream<Caked_VncStream>
		private let responseStream: GRPCAsyncResponseStreamWriter<Caked_VncStream>
		private let group: EventLoopGroup
		private let vmName: String
		private let runMode: Utils.RunMode
		private let logger = Logger("Tunneling")
		private var channel: Channel! = nil
		private var taskGroup: TaskGroup<Void>? = nil

		init(requestStream: GRPCAsyncRequestStream<Caked_VncStream>, responseStream: GRPCAsyncResponseStreamWriter<Caked_VncStream>, group: EventLoopGroup, vmName: String, runMode: Utils.RunMode) {
			self.requestStream = requestStream
			self.responseStream = responseStream
			self.group = group
			self.vmName = vmName
			self.runMode = runMode
		}

		func stopTunnel() {
			self.logger.debug("Stopping VNC tunnel, for VM \(vmName) id: \(id)")
			
			// Annuler la tâche du tunnel
			self.taskGroup?.cancelAll()
			self.taskGroup = nil
		}

		func startTunnel() async throws {
			logger.debug("Starting VNC tunnel for VM: \(vmName), id: \(id)")

			// Récupérer les informations VNC pour cette machine virtuelle
			let vncInfos = try CakedLib.VNCInfosHandler.vncInfos(name: vmName, runMode: runMode)

			guard vncInfos.urls.isEmpty == false else {
				logger.error("No VNC URL found for VM: \(vmName), id: \(id)")
				throw ServiceError(String(localized: "No VNC URL found for VM: \(vmName)"))
			}
			
			// Extraire l'host et le port de la première URL VNC
			guard let vncURL = URL(string: vncInfos.urls[0]) else {
				logger.error("Invalid VNC URL: \(vncInfos.urls[0]) for VM: \(vmName), id: \(id)")
				throw ServiceError(String(localized: "Invalid VNC URL: \(vncInfos.urls[0])"))
			}

			let vncPort = vncURL.port ?? 5900

			await handleVNCTunnel(vncPort: vncPort)
		}
		
		func handleVNCTunnel(_ vncHost: String = "127.0.0.1", vncPort: Int) async {
			do {
				logger.debug("Connecting to VNC server for VM \(vmName), id: \(id) at \(vncHost):\(vncPort)")
				
				let client = ClientBootstrap(group: group)
					.channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
					.channelInitializer { channel in
						return channel.eventLoop.makeSucceededVoidFuture()
					}
					
				let asyncChannel = try await client.connect(host: vncHost, port: vncPort) { channel in
						self.channel = channel

						return channel.eventLoop.makeCompletedFuture {
							try NIOAsyncChannel<ByteBuffer, ByteBuffer>(wrappingChannelSynchronously: channel)
						}
					}

				logger.debug("Connected to VNC server for VM \(vmName), id: \(id) at \(vncHost):\(vncPort)")
				
				try await asyncChannel.executeThenClose { input, output in
					await withTaskGroup { group in

						self.taskGroup = group

						// Tâche pour lire du requestStream et écrire au serveur VNC
						group.addTask {
							do {
								var iterator = self.requestStream.makeAsyncIterator()
								
								while let vncMessage = try await iterator.next() {
									// Vérifier l'annulation
									try Task.checkCancellation()
									
									let buffer = self.channel.allocator.buffer(data: vncMessage.stream)
									try await output.write(buffer)
								}
								
								self.logger.debug("Request stream ended, closing VNC write channel for VM \(self.vmName), id: \(self.id)")
							} catch is CancellationError {
								self.logger.debug("VNC request stream task cancelled for VM \(self.vmName), id: \(self.id)")
							} catch {
								self.logger.error("Error handling request stream for VM \(self.vmName), id: \(self.id): \(error)")
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
								
								self.logger.debug("VNC server connection ended for VM \(self.vmName), id: \(self.id)")
							} catch is CancellationError {
								self.logger.debug("VNC response stream task cancelled for VM \(self.vmName), id: \(self.id)")
							} catch {
								self.logger.error("Error handling VNC server response for VM \(self.vmName), id: \(self.id): \(error)")
							}
						}

						await group.waitForAll()

						try? await self.channel.close().get()
					}
				}

				self.logger.debug("VNC tunnel ended for VM \(vmName), id: \(id)")
			} catch is CancellationError {
				self.logger.debug("VNC tunnel cancelled for VM \(vmName), id: \(id)")
			} catch {
				self.logger.error("Failed to start VNC tunnel for VM \(vmName), id: \(id), error: \(error)")
			}
		}
	}

	private let runMode: Utils.RunMode
	private let group: EventLoopGroup
	private let tunnels: Mutex<[TunnelID: Tunneling]>
	private let logger = Logger("VNCTunnel")

	public init(group: EventLoopGroup, runMode: Utils.RunMode) {
		self.group = group
		self.runMode = runMode
		self.tunnels = .init([:])
	}

	public func stopVNCTunnel() {
		self.tunnels.withLock { listeners in
			listeners.values.forEach {
				$0.stopTunnel()
			}
		}
	}

	public func tunnel(requestStream: GRPCAsyncRequestStream<Caked_VncStream>, responseStream: GRPCAsyncResponseStreamWriter<Caked_VncStream>, context: GRPCAsyncServerCallContext) async throws {
		guard let vmName = context.request.headers.first(name: "CAKEAGENT_VMNAME") else {
			self.logger.error("no CAKEAGENT_VMNAME header")

			throw ServiceError(String(localized: "no CAKEAGENT_VMNAME header"))
		}

		let tunnel = Tunneling(requestStream: requestStream, responseStream: responseStream, group: group, vmName: vmName, runMode: runMode)

		self.tunnels.withLock {
			$0[tunnel.id] = tunnel
			self.logger.debug("Start VNC tunnel for VM \(vmName), id: \(tunnel.id)")
			self.logger.debug("Number of active VNC tunnels: \($0.count)")
		}

		defer {
			tunnel.stopTunnel()

			self.tunnels.withLock {
				$0.removeValue(forKey: tunnel.id)
				self.logger.debug("Stop VNC tunnel for VM \(vmName), id: \(tunnel.id)")
			}
		}

		try await tunnel.startTunnel()
	}
}
