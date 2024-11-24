import Foundation
import ShellOut

struct Shell {
	@discardableResult static func runTart(command: String, arguments: [String], direct: Bool = false) throws -> String{
		var args: [String] = []
		var outputData: Data = Data()
		let outputPipe = Pipe()
		let errorPipe : Pipe = direct ? Pipe() : outputPipe

		if command.count > 0 {
			args.append(command)
		}

		args += arguments

		outputPipe.fileHandleForReading.readabilityHandler = { handler in
			if direct {
				try? FileHandle.standardOutput.write(contentsOf: handler.availableData)
			} else {
				outputData.append(handler.availableData)
			}
		}

		if direct {
			errorPipe.fileHandleForReading.readabilityHandler = { handler in
				try? FileHandle.standardError.write(contentsOf: handler.availableData)
			}
		}

		let _ = try shellOut(to: "tart", arguments: args,
										outputHandle: outputPipe.fileHandleForWriting,
										errorHandle: errorPipe.fileHandleForWriting)

		return String(data: outputData,  encoding: .utf8)!
	}

}
