import Foundation
import ShellOut

struct Shell {
	@discardableResult static func runTart(command: String, arguments: [String]) throws -> String{
		do {
			var args = [command]
			var outputData: Data = Data()
			let outputPipe = Pipe()

			args += arguments

			outputPipe.fileHandleForReading.readabilityHandler = { handler in
				outputData.append(handler.availableData)
			}

			let convertOuput = try shellOut(to: "tart", arguments: args,
											outputHandle: outputPipe.fileHandleForWriting,
											errorHandle: outputPipe.fileHandleForWriting)

			defaultLogger.appendNewLine(convertOuput)

			return String(data: outputData,  encoding: .utf8)!
		} catch {
			let error = error as! ShellOutError

			defaultLogger.appendNewLine(error.message)
			defaultLogger.appendNewLine(error.output)

			throw error
		}
	}

}
