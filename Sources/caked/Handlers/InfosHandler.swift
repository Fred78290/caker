import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import NIO

struct InfosHandler: CakedCommand {
    mutating func run(on: any EventLoop, asSystem: Bool) throws -> EventLoopFuture<String> {
        on.submit {
			""
		}
    }

	
}