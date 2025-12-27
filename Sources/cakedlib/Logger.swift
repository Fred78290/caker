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
		#if DEBUG
			if Self.intLogLevel >= LogLevel.debug {
				logger.debug(.init(stringLiteral: line))
			}
		#endif
	}

	public func trace(_ line: String) {
		if Self.intLogLevel >= LogLevel.trace {
			logger.trace(.init(stringLiteral: line))
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

public final class ProgressObserver: NSObject, @unchecked Sendable {
	public enum ProgressValue: Sendable {
		case progress(ProgressHandlerContext, Double)
		case step(String)
		case terminated(Result<VMLocation, any Error>, String?)
	}

	public final class ProgressHandlerContext: @unchecked Sendable {
		public var oldFractionCompleted: Double = -1
		public var lastCompleted10: Int
		public var lastCompleted2: Int

		public init() {
			self.lastCompleted10 = 0
			self.lastCompleted2 = 0
		}
	}

	public typealias BuildProgressHandler = (ProgressValue) -> Void

	@objc var progress: Progress
	var observation: NSKeyValueObservation?
	let progressHandler: BuildProgressHandler?

	public static func progressHandler(_ result: ProgressValue) {
		if case .progress(let context, let fractionCompleted) = result {
			let completed = Int(100 * fractionCompleted)

			if completed % 10 == 0 {
				if completed - context.lastCompleted10 >= 10 || completed == 0 || completed == 100 {
					if context.lastCompleted10 == 0 && completed == 100 {
						print(String(format: "...%0.3d%%", completed), terminator: " complete\n")
					} else if completed < 100 {
						print(String(format: "%0.2d%%", completed), terminator: "")
					} else {
						print(String(format: "%0.3d%%", completed), terminator: " complete\n")
					}

					fflush(stdout)

					context.lastCompleted10 = completed
				}
			} else if completed % 2 == 0 {
				if completed - context.lastCompleted2 >= 2 {
					context.lastCompleted2 = completed
					print(".", terminator: "")
					fflush(stdout)
				}
			}
		} else if case .terminated(let result, let message) = result {
			let logger = Logger("BuildHandler")

			if case .failure(let error) = result {
				if let message {
					logger.error("\(message): \(error)")
				} else {
					logger.error("Installation failed: \(error)")
				}
			} else {
				logger.info(message ?? "Installation succeeded")
			}
		} else if case .step(let message) = result {
			Logger(self).info(message)
		}
	}

	public init(progressHandler: ProgressObserver.BuildProgressHandler?) {
		self.progress = Progress(totalUnitCount: 100)
		self.progressHandler = progressHandler
	}

	public init(totalUnitCount unitCount: Int64) {
		self.progress = Progress(totalUnitCount: unitCount)
		self.progressHandler = nil
	}

	public func log(_ message: String) -> ProgressObserver {
		if self.progressHandler == nil {
			print(message + ":", terminator: "")
		}

		let context: ProgressHandlerContext = .init()

		observation = progress.observe(\.fractionCompleted, options: [.initial, .new, .old]) { (progress, changed) in
			if context.oldFractionCompleted != progress.fractionCompleted {

				if let progressHandler = self.progressHandler {
					progressHandler(.progress(context, progress.fractionCompleted))
				} else {
					Self.progressHandler(.progress(context, progress.fractionCompleted))
				}

				context.oldFractionCompleted = progress.fractionCompleted
			}
		}

		return self
	}
}
