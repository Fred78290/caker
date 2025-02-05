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
	static var logger = Logging.Logger(label: "com.aldunelabs.caker") 

	static public func setLevel(_ level: Logging.Logger.Level) {
		logger.logLevel = level
	}

	static public func error(_ err: Error) {
		logger.error(.init(stringLiteral: err.localizedDescription))
	}

	static public func warn(_ line: String) {
		logger.warning(.init(stringLiteral: line))
	}

	static public func info(_ line: String) {
		logger.info(.init(stringLiteral: line))
	}

	static public func debug(_ line: String) {
		logger.debug(.init(stringLiteral: line))
	}

	static public func trace(_ line: String) {
		logger.trace(.init(stringLiteral: line))
	}

	static public func appendNewLine(_ line: String) {
		print(line, terminator: "\n")
	}

	static public func updateLastLine(_ line: String) {
		print(line, terminator: "\n")
	}
}

public class ProgressObserver: NSObject {
	@objc var progressToObserve: Progress
	var observation: NSKeyValueObservation?
	var lastUpdate = Date.now

	public init(_ progress: Progress) {
		progressToObserve = progress
	}

	func log() {
		Logger.appendNewLine(ProgressObserver.renderLine(progressToObserve))

		observation = observe(\.progressToObserve.fractionCompleted) { progress, _ in
			let currentTime = Date.now

			if self.progressToObserve.isFinished || currentTime.timeIntervalSince(self.lastUpdate) >= 1.0 {
				self.lastUpdate = currentTime

				Logger.updateLastLine(ProgressObserver.renderLine(self.progressToObserve))
			}
		}
	}

	private static func renderLine(_ progress: Progress) -> String {
		String(Int(100 * progress.fractionCompleted)) + "%"
	}
}
