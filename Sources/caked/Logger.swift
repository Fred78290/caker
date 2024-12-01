import Foundation

struct Logger {
	static public func appendError(_ err: Error) {
		"\(err.localizedDescription)\n".data(using: .utf8).map(FileHandle.standardError.write)
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
