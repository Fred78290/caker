import Foundation
import Logging
import ArgumentParser

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


struct Logger {
	private static let eraseCursorDown: String = "\u{001B}[J"
	private static let moveUp = "\u{001B}[1A"
	private static let moveBeginningOfLine = "\r"
	private static var logLevel: Logging.Logger.Level = .info
	private static var intLogLevel = LogLevel.info

	let label = "com.aldunelabs.caker"
	var logger: Logging.Logger

	public init(_ target: Any) {
		let thisType = type(of: target)
		self.logger = Logging.Logger(label: "com.aldunelabs.caker.\(String(describing: thisType))")
		self.logger.logLevel = Self.logLevel
	}

	public init(_ label: String) {
		self.logger = Logging.Logger(label: "com.aldunelabs.caker.\(label)")
		self.logger.logLevel = Self.logLevel
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
			logger.error(.init(stringLiteral: err.localizedDescription))
		}
	}

	public func error(_ err: String) {
		if Self.intLogLevel >= LogLevel.error {
			logger.error(.init(stringLiteral: err))
		}
	}

	public func warn(_ line: String) {
		if Self.intLogLevel >= LogLevel.warning {
			logger.warning(.init(stringLiteral: line))
		}
	}

	public func info(_ line: String) {
		if Self.intLogLevel >= LogLevel.info {
			logger.info(.init(stringLiteral: line))
		}
	}

	public func debug(_ line: String) {
		if Self.intLogLevel >= LogLevel.debug {
			logger.debug(.init(stringLiteral: line))
		}
	}

	public func trace(_ line: String) {
		if Self.intLogLevel >= LogLevel.trace {
			logger.trace(.init(stringLiteral: line))
		}
	}

	static public func appendNewLine(_ line: String) {
		print(line, terminator: "\n")
	}

	static public func updateLastLine(_ line: String) {
		print(moveUp, moveBeginningOfLine, eraseCursorDown, line, separator: "", terminator: "\n")
	}
}

public class ProgressObserver: NSObject {
	@objc var progress: Progress
	var observation: NSKeyValueObservation?
	var lastUpdate = Date.now

	public init(totalUnitCount unitCount: Int64) {
		self.progress = Progress(totalUnitCount: unitCount)
	}

	func log(_ message: String) -> ProgressObserver {
		Logger.appendNewLine(ProgressObserver.renderLine(message, self.progress))

		observation = observe(\.progress.fractionCompleted) { progress, _ in
			let currentTime = Date.now

			if self.progress.isFinished || currentTime.timeIntervalSince(self.lastUpdate) >= 1.0 {
				self.lastUpdate = currentTime

				Logger.updateLastLine(ProgressObserver.renderLine(message, self.progress))
			}
		}

		return self
	}

	private static func renderLine(_ message: String, _ progress: Progress) -> String {
		String("\(message): \(Int(100 * progress.fractionCompleted)) %")
	}
}
