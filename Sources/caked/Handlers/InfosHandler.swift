import Dispatch
import Foundation
import SwiftUI
import Virtualization
import GRPCLib
import NIOCore
import CakeAgentLib

struct InfosHandler: CakedCommand {
	var request: Caked_InfoRequest

	func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<String> {
		let client = try createCakeAgentClient(on: on, asSystem: asSystem, name: request.name)

		return on.makeFutureWithTask {
			let format = request.format == .text ? Format.text : Format.json
			let result = try await CakeAgentHelper(on: on, client: client).info(callOptions: nil)

			return format.renderSingle(result)
		}
	}
}