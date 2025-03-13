import Foundation
import Logging
import ArgumentParser

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
}


struct Logger {
	private static let eraseCursorDown: String = "\u{001B}[J"
	private static let moveUp = "\u{001B}[1A"
	private static let moveBeginningOfLine = "\r"
	private static var logLevel: Logging.Logger.Level = .info

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

	static public func setLevel(_ level: Logging.Logger.Level) {
		Self.logLevel = level
	}

	public func error(_ err: Error) {
		logger.error(.init(stringLiteral: err.localizedDescription))
	}

	public func error(_ err: String) {
		logger.error(.init(stringLiteral: err))
	}

	public func warn(_ line: String) {
		logger.warning(.init(stringLiteral: line))
	}

	public func info(_ line: String) {
		logger.info(.init(stringLiteral: line))
	}

	public func debug(_ line: String) {
		logger.debug(.init(stringLiteral: line))
	}

	public func trace(_ line: String) {
		logger.trace(.init(stringLiteral: line))
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
