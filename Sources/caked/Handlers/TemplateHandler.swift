import ArgumentParser
import Foundation
import GRPCLib

struct TemplateHandler: CakedCommand {
	static func template() -> String {
		return """
		# Template
		"""
	}

	func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<String> {
		on.submit {
			Self.template()
		}
	}
}