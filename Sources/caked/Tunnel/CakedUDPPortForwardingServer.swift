import Foundation
import NIOPortForwarding

class CakedUDPPortForwardingServer: PortForwarding {
	public let bootstrap: Bindable
	public let eventLoop: EventLoop
	public let bindAddress: SocketAddress
	public let remoteAddress: SocketAddress
	public var channel: Channel?
	public var proto: MappedPort.Proto { return .udp }
	internal let cakeAgentClient: CakeAgentClient

	public init(on: EventLoop,
	            bindAddress: SocketAddress,
	            remoteAddress: SocketAddress,
	            ttl: Int,
				cakeAgentClient: CakeAgentClient) {

		self.eventLoop = on
		self.bindAddress = bindAddress
		self.remoteAddress = remoteAddress
		self.bootstrap = DatagramBootstrap(group: on)
			.channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
			.channelInitializer { inboundChannel in
				inboundChannel.pipeline.addHandler(InboundUDPWrapperHandler(remoteAddress: remoteAddress, bindAddress: bindAddress, ttl: ttl))
			}
	}

	public func setChannel(_ channel: any NIOCore.Channel) {
		self.channel = channel
	}
}