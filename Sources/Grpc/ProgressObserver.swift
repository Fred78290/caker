//
//  ProgressObserver.swift
//  Caker
//
//  Created by Frederic BOLTZ on 07/01/2026.
//
import Foundation
import CakeAgentLib

public final class ProgressObserver: NSObject, @unchecked Sendable {
	public struct ProvisionInfo: Sendable {
		public let vncURL: URL
		public let screenSize: ViewSize
		public let config: CakedConfiguration

		public init(vncURL: URL, screenSize: ViewSize, config: CakedConfiguration) {
			self.vncURL = vncURL
			self.screenSize = screenSize
			self.config = config
		}

		public init(_ from: Caked_ProvisionStreamReply.ProvisionInfo) {
			self.vncURL = URL(string: from.vncURL)!
			self.screenSize = ViewSize(from.screenSize)
			self.config = CakedConfiguration(from.config)
		}

		public var caked: Caked_ProvisionStreamReply.ProvisionInfo {
			.with {
				$0.vncURL = vncURL.absoluteString
				$0.config = config.caked
				$0.screenSize = .with {
					$0.width = Int32(screenSize.width)
					$0.height = Int32(screenSize.height)
				}
			}
		}
	}

	public enum ProgressValue: Sendable {
		case progress(ProgressHandlerContext, Double)
		case step(String)
		case substep(String)
		case terminated(Result<Sendable?, any Error>, String?)
		case provision(ProvisionInfo)
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

	@objc public var progress: Progress
	public var observation: NSKeyValueObservation?
	public let progressHandler: BuildProgressHandler?

	public static func progressHandler(_ result: ProgressValue) {
		if case .progress(let context, let fractionCompleted) = result {
			let completed = Int(100 * fractionCompleted)

			if completed == 0 {
				if context.oldFractionCompleted < 0 {
					fputs(String(format: "%0.2d%%", completed), stderr)
					fflush(stderr)
				}
			} else if completed % 10 == 0 {
				if completed - context.lastCompleted10 >= 10 || completed == 0 || completed == 100 {
					if context.lastCompleted10 == 0 && completed == 100 {
						fputs(String(format: String(localized: "...%0.3d%% complete") + "\n", completed), stderr)
						fflush(stderr)
					} else if completed < 100 {
						fputs(String(format: "%0.2d%%", completed), stderr)
						fflush(stderr)
					} else {
						fputs(String(format: String(localized: "...%0.3d%% complete") + "\n", completed), stderr)
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

			context.oldFractionCompleted = fractionCompleted
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
		} else if case .substep(let message) = result {
			Logger(self).info(message)
		} else if case .provision(let info) = result {
			Logger(self).info("Provisioning visible at: \(info.vncURL)")
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
			print(message + ":", terminator: String.empty)
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

