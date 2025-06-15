import CakeAgentLib
import Foundation
import GRPC
import NIO
import NIOPortForwarding

class CakedTCPPortForwardingServer: TCPPortForwardingServer {
	let cakeAgentClient: CakeAgentClient

	init(on: EventLoop, bindAddress: SocketAddress, remoteAddress: SocketAddress, cakeAgentClient: CakeAgentClient) {
		self.cakeAgentClient = cakeAgentClient

		super.init(on: on, bindAddress: bindAddress, remoteAddress: remoteAddress)
	}

	override func childChannelInitializer(channel: Channel) -> EventLoopFuture<Void> {
		return channel.pipeline.addHandler(CakedChannelTunnelHandlerAdapter(proto: .tcp, bindAddress: self.bindAddress, remoteAddress: self.remoteAddress, cakeAgentClient: self.cakeAgentClient))
	}
}
