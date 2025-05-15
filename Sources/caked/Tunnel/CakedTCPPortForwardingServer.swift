
import Foundation
import NIOPortForwarding
import NIO
import CakeAgentLib

class CakedTCPPortForwardingServer: TCPPortForwardingServer {
	let cakeAgentClient: CakeAgentClient

	init(on: EventLoop, bindAddress: SocketAddress, remoteAddress: SocketAddress, cakeAgentClient: CakeAgentClient) {
		super.init(on: on, bindAddress: bindAddress, remoteAddress: remoteAddress)

		self.cakeAgentClient = cakeAgentClient
	}

	override func childChannelInitializer(channel: Channel) -> EventLoopFuture<Void> {
		return super.childChannelInitializer(channel: channel)
	}
}
