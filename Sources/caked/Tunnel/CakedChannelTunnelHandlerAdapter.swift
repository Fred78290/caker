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

class CakedChannelTunnelHandlerAdapter: ChannelInboundHandler {
	typealias InboundIn = ByteBuffer
	typealias OutboundOut = ByteBuffer

	let cakeAgentClient: CakeAgentClient
	let bindAddress: SocketAddress
	let remoteAddress: SocketAddress
	let proto: CakeAgent.TunnelMessage.TunnelProtocol

	var tunnel: BidirectionalStreamingCall<Cakeagent_CakeAgent.TunnelMessage, Cakeagent_CakeAgent.TunnelMessage>? = nil

	init(proto: CakeAgent.TunnelMessage.TunnelProtocol, bindAddress: SocketAddress, remoteAddress: SocketAddress, cakeAgentClient: CakeAgentClient) {
		self.proto = proto
		self.bindAddress = bindAddress
		self.remoteAddress = remoteAddress
		self.cakeAgentClient = cakeAgentClient
	}

	func channelRegistered(context: ChannelHandlerContext) {
		self.tunnel = cakeAgentClient.tunnel(callOptions: nil) { message in
			// Handle incoming messages from the tunnel
			switch message.message {
			case .datas(let data):
				// Send data to the channel
				let buffer = context.channel.allocator.buffer(data: data)
				context.channel.writeAndFlush(buffer, promise: nil)
			case .eof:
				// Handle tunnel close
				context.channel.close(promise: nil)
			default:
				break
			}
		}

		context.fireChannelRegistered()
	}

	func channelActive(context: ChannelHandlerContext) {
		if let tunnel = self.tunnel {
			let connect = CakeAgent.TunnelMessage.with {
				$0.connect = CakeAgent.TunnelMessage.TunnelMessageConnect.with { message in
					message.id = "\(self.bindAddress.description):\(self.remoteAddress.description)@\(context.channel)"
					message.protocol = self.proto
					message.guestAddress = self.remoteAddress.pathname!
				}
			}

			_ = tunnel.sendMessage(connect)
		}

		context.fireChannelActive()
	}

	func channelInactive(context: ChannelHandlerContext) {
		if let tunnel = self.tunnel {
			tunnel.sendMessage(CakeAgent.TunnelMessage.with { $0.eof = true}).whenComplete { _ in
				_ = tunnel.sendEnd()
			}
		}

		context.fireChannelInactive()
	}

	func channelRead(context: ChannelHandlerContext, data: NIOAny) {
		if let tunnel = self.tunnel {
			let data = self.unwrapInboundIn(data)

			let message = CakeAgent.TunnelMessage.with {
				$0.datas = Data(buffer: data)
			}

			_ = tunnel.sendMessage(message)
		} else {
			context.fireChannelRead(data)
		}
	}

	func errorCaught(context: ChannelHandlerContext, error: Error) {
		context.close(promise: nil)

		context.fireErrorCaught(error)
	}
}
