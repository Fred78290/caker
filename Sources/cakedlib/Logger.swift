import ArgumentParser
import Foundation
import Logging

public enum LogLevel: Int, Equatable, Comparable {
	case trace = 6
	case debug = 5
	case info = 4
	case notice = 3
	case warning = 2
	case error = 1
	case critical = 0

	public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
		return lhs.rawValue < rhs.rawValue
	}
}

extension Logging.Logger.Level: @retroactive ExpressibleByArgument {
	public init?(argument: String) {
		switch argument {
		case "trace":
			self = .trace
		case "debug":
			self = .debug
		case "info":
			self = .info
		case "notice":
			self = .notice
		case "warning":
			self = .warning
		case "error":
			self = .error
		case "critical":
			self = .critical
		default:
			return nil
		}
	}

	public var level: LogLevel {
		switch self {
		case .trace:
			return LogLevel.trace
		case .debug:
			return LogLevel.debug
		case .info:
			return LogLevel.info
		case .notice:
			return LogLevel.notice
		case .warning:
			return LogLevel.warning
		case .error:
			return LogLevel.error
		case .critical:
			return LogLevel.critical
		}
	}
}

public final class Logger {
	private static let eraseCursorDown: String = "\u{001B}[J"
	private static let moveUp = "\u{001B}[1A"
	private static let moveBeginningOfLine = "\r"
	nonisolated(unsafe) private static var logLevel: Logging.Logger.Level = .info
	nonisolated(unsafe) private static var intLogLevel = LogLevel.info

	private let label = "com.aldunelabs.caker"
	private var logger: Logging.Logger
	private let isTTY: Bool

	public init(_ target: Any) {
		let thisType = type(of: target)
		self.logger = Logging.Logger(label: "com.aldunelabs.caker.\(String(describing: thisType))")
		self.logger.logLevel = Self.logLevel
		self.isTTY = FileHandle.standardOutput.isTTY()
	}

	public init(_ label: String) {
		self.logger = Logging.Logger(label: "com.aldunelabs.caker.\(label)")
		self.logger.logLevel = Self.logLevel
		self.isTTY = FileHandle.standardOutput.isTTY()
	}

	static public func Level() -> LogLevel {
		Self.intLogLevel
	}

	static public func LoggingLevel() -> Logging.Logger.Level {
		Self.logLevel
	}

	static public func setLevel(_ level: Logging.Logger.Level) {
		Self.logLevel = level
		Self.intLogLevel = level.level
	}

	public func error(_ err: Error) {
		if Self.intLogLevel >= LogLevel.error {
			if self.isTTY {
				logger.error("\u{001B}[0;31m\u{001B}[1m\(String(stringLiteral: err.localizedDescription))\u{001B}[0m")
			} else {
				logger.error(.init(stringLiteral: err.localizedDescription))
			}
		}
	}

	public func error(_ err: String) {
		if Self.intLogLevel >= LogLevel.error {
			if self.isTTY {
				logger.error("\u{001B}[0;31m\u{001B}[1m\(String(stringLiteral: err))\u{001B}[0m")
			} else {
				logger.error(.init(stringLiteral: err))
			}
		}
	}

	public func warn(_ line: String) {
		if Self.intLogLevel >= LogLevel.warning {
			if self.isTTY {
				logger.warning("\u{001B}[0;33m\u{001B}[1m\(String(stringLiteral: line))\u{001B}[0m")
			} else {
				logger.warning(.init(stringLiteral: line))
			}
		}
	}

	public func info(_ line: String) {
		if Self.intLogLevel >= LogLevel.info {
			logger.info(.init(stringLiteral: line))
		}
	}

	public func debug(_ line: String) {
		if Self.intLogLevel >= LogLevel.debug {
			if self.isTTY {
				logger.debug("\u{001B}[0;32m\u{001B}[1m\(String(stringLiteral: line))\u{001B}[0m")
			} else {
				logger.debug(.init(stringLiteral: line))
			}
		}
	}

	public func trace(_ line: String) {
		if Self.intLogLevel >= LogLevel.trace {
			if self.isTTY {
				logger.trace("\u{001B}[0;34m\u{001B}[1m\(String(stringLiteral: line))\u{001B}[0m")
			} else {
				logger.trace(.init(stringLiteral: line))
			}
		}
	}

	static public func appendNewLine(_ line: String) {
		if line.isEmpty {
			return
		}

		print(line, terminator: "\n")
	}

	static public func updateLastLine(_ line: String) {
		if line.isEmpty {
			return
		}

		print(moveUp, moveBeginningOfLine, eraseCursorDown, line, separator: "", terminator: "\n")
	}
}
