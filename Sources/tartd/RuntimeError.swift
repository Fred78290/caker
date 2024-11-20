import Foundation

enum RuntimeError : Error, CustomStringConvertible {
  case VMAlreadyRunning(_ message: String)
  case VMNotRunning(_ name: String)
  case MalformedURL(_ hint: String)
  case InternalError(_ hint: String)

  public var description: String {
    switch self {
	  case .VMAlreadyRunning(let message):
	    return message
      case .VMNotRunning(let name):
        return "VM \"\(name)\" is not running"
      case .MalformedURL(let hint):
        return "URL \(hint) is malformed"
      case .InternalError(let hint):
        return "Internal error \(hint)"
    }
  }
}
