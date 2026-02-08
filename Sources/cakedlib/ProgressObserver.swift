//
//  ProgressObserver.swift
//  Caker
//
//  Created by Frederic BOLTZ on 07/01/2026.
//
import Foundation
import CakeAgentLib

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
						fputs(String(format: "...%0.3d%% complete\n", completed), stderr)
						fflush(stderr)
					} else if completed < 100 {
						fputs(String(format: "%0.2d%%", completed), stderr)
						fflush(stderr)
					} else {
						fputs(String(format: "%0.3d%% complete\n", completed), stderr)
						fflush(stderr)
					}

					context.lastCompleted10 = completed
				}
			} else if completed % 2 == 0 {
				if completed - context.lastCompleted2 >= 2 {
					context.lastCompleted2 = completed
					fputs(".", stderr)
					fflush(stderr)
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

