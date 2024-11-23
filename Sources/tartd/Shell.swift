import Foundation
import ShellOut

struct Shell {
	@discardableResult static func runTart(command: String, arguments: [String]) throws -> String{
		var args: [String] = []
		var outputData: Data = Data()
		let outputPipe = Pipe()

		if command.count > 0 {
			args.append(command)
		}

		args += arguments

		outputPipe.fileHandleForReading.readabilityHandler = { handler in
			outputData.append(handler.availableData)
		}

		let _ = try shellOut(to: "tart", arguments: args,
										outputHandle: outputPipe.fileHandleForWriting,
										errorHandle: outputPipe.fileHandleForWriting)

		return String(data: outputData,  encoding: .utf8)!
	}

}
