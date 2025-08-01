import Foundation

public protocol HasExitCode {
	var exitCode: Int32 { get }
}

public struct ExitCode: Error, HasExitCode {
	public let exitCode: Int32

	public init(_ code: Int32) {
		self.exitCode = code
	}
}

public class ServiceError: Error, CustomStringConvertible, Equatable {
	public let description: String
	public let exitCode: Int32

	public init(_ errno: Int32) {
		self.description = String(cString: strerror(errno))
		self.exitCode = errno
	}

	public init(_ what: String, _ code: Int32 = 1) {
		self.description = what
		self.exitCode = code
	}

	public static func != (lhs: ServiceError, rhs: ServiceError) -> Bool {
		return lhs.description != rhs.description && lhs.exitCode != rhs.exitCode
	}

	public static func == (lhs: ServiceError, rhs: ServiceError) -> Bool {
		return lhs.description == rhs.description && lhs.exitCode == rhs.exitCode
	}
}
