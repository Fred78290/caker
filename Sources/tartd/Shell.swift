import Foundation
import ShellOut

struct Shell {
  static func runTart(command: String, arguments: [String]) throws {
    do {
		var args = [command]
		
		args += arguments
      let convertOuput = try shellOut(to: "tart", arguments: args)
      defaultLogger.appendNewLine(convertOuput)
    } catch {
      let error = error as! ShellOutError

      defaultLogger.appendNewLine(error.message)
      defaultLogger.appendNewLine(error.output)

      throw error
    }
  }

}
