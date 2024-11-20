import Foundation
import ShellOut

struct Shell {
  static func runTart(command: String, arguments: [String]) throws {
    do {
      let convertOuput = try shellOut(to: "tart", arguments: [name, arguments...])
      defaultLogger.appendNewLine(convertOuput)
    } catch {
      let error = error as! ShellOutError

      defaultLogger.appendNewLine(error.message)
      defaultLogger.appendNewLine(error.output)

      throw error
    }
  }

}