//
//  CakedChannelTunnelHandlerAdapter.swift
//  Caker
//
//  Created by Frederic BOLTZ on 15/05/2025.
//
import Foundation
import NIO
import GRPC
import CakeAgentLib
import CryptoKit

class CakedChannelTunnelHandlerAdapter: ChannelInboundHandler {
		public typealias InboundIn = ByteBuffer
		public typealias OutboundOut = ByteBuffer

		let cakeAgentClient: CakeAgentClient
		let bindAddress: SocketAddress
		let remoteAddress: SocketAddress
		let proto: CakeAgent.TunnelMessage.TunnelProtocol

		var tunnel: BidirectionalStreamingCall<Cakeagent_CakeAgent.TunnelMessage, Cakeagent_CakeAgent.TunnelMessage>? = nil

		public init(proto: CakeAgent.TunnelMessage.TunnelProtocol, bindAddress: SocketAddress, remoteAddress: SocketAddress, cakeAgentClient: CakeAgentClient) {
			self.proto = proto
			self.bindAddress = bindAddress
			self.remoteAddress = remoteAddress
			self.cakeAgentClient = cakeAgentClient
		}

		public func channelRegistered(context: ChannelHandlerContext) {
			#if TRACE
				redbold("Create tunnel from \(self.bindAddress) to \(self.remoteAddress)")
			#endif
			self.tunnel = cakeAgentClient.tunnel(callOptions: nil) { message in
				// Handle incoming messages from the tunnel
				#if TRACE
					redbold("Receive message \(message)")
				#endif
				switch message.message {
				case .datas(let data):
					// Send data to the channel
					let buffer = context.channel.allocator.buffer(data: data)
					context.channel.writeAndFlush(buffer, promise: nil)
				case .eof:
					// Handle tunnel close
					context.channel.close(promise: nil)
				case .error(let err):
					// Handle error
					#if TRACE
						redbold("Tunnel error: \(err)")
					#endif
					self.errorCaught(context: context, error: IOError(errnoCode: EIO, reason: err))
				default:
					break
				}
			}

			self.tunnel?.status.whenComplete { result in
				switch result {
				case .failure(let err):
#if TRACE
					redbold("Tunnel error: \(err)")
#endif
					self.errorCaught(context: context, error: err)
				case .success(let status):
#if TRACE
					redbold("Tunnel status: \(status)")
#endif
					if status.code != .ok {
						self.errorCaught(context: context, error: status)
					}
				}
			}

			context.fireChannelRegistered()
		}

		public func channelActive(context: ChannelHandlerContext) {
			if let tunnel = self.tunnel {
				let connect = CakeAgent.TunnelMessage.with {
					$0.connect = CakeAgent.TunnelMessage.TunnelMessageConnect.with { message in
						message.id = SHA256.hash(data: Data("\(self.bindAddress.description):\(self.remoteAddress.description)@\(context.channel)".utf8)).description
						message.protocol = self.proto
						message.guestAddress = self.remoteAddress.pathname!
					}
				}

				#if TRACE
					redbold("Connect tunnel \(connect)")
				#endif

				_ = tunnel.sendMessage(connect)
			}

			context.fireChannelActive()
		}

		public func channelInactive(context: ChannelHandlerContext) {
			if let tunnel = self.tunnel {
				#if TRACE
					redbold("Disconnect tunnel from \(self.bindAddress) to \(self.remoteAddress)")
				#endif
				tunnel.sendMessage(CakeAgent.TunnelMessage.with { $0.eof = true}).whenComplete { _ in
					_ = tunnel.sendEnd()
				}
			}

			context.fireChannelInactive()
		}

		public func channelRead(context: ChannelHandlerContext, data: NIOAny) {
			if let tunnel = self.tunnel {
				let data = self.unwrapInboundIn(data)

				let message = CakeAgent.TunnelMessage.with {
					$0.datas = Data(buffer: data)
				}

				#if TRACE
					redbold("Send message \(message)")
				#endif
				_ = tunnel.sendMessage(message)
			} else {
				context.fireChannelRead(data)
			}
		}

		public func errorCaught(context: ChannelHandlerContext, error: Error) {
			#if TRACE
				redbold("errorCaught \(error)")
			#endif
			context.close(promise: nil)

			context.fireErrorCaught(error)
		}
}
