//
//  TaskQueue.swift
//  Caker
//
//  Created by Frederic BOLTZ on 10/01/2026.
//  From: https://github.com/rickymohk/SwiftTaskQueue
//

import Foundation

public enum TaskQueueError: Error {
	case invalidResultType(expected: String, actual: String)
}

public class TaskQueue {
	private class PendingTask {
		let label: String?
		var isCancelled = false
		init(label: String? = nil) {
			self.label = label
		}
	}

	private class AsyncTask: PendingTask {
		let continuation: CheckedContinuation<Any, Error>?
		let block: () async throws -> Any

		init(label: String?, continuation: CheckedContinuation<Any, Error>?, block: @escaping () async throws -> Any) {
			self.continuation = continuation
			self.block = block
			super.init(label: label)
		}
	}

	private class StreamTask: PendingTask {
		let cancel: () -> Void
		let block: () async throws -> Void

		init(label: String?, cancel: @escaping () -> Void, block: @escaping () async throws -> Void) {
			self.cancel = cancel
			self.block = block
			super.init(label: label)
		}
	}

	public let label: String?

	private var pendingTasksContinuation: AsyncStream<PendingTask>.Continuation
	private var pendingTasks: AsyncStream<PendingTask>
	private var scope: Task<Void, Never>?
	private var isScopeCancelled = false

	private func initScope() {
		self.scope = Task {
			for await pendingTask in self.pendingTasks {
				//                print("PendingTask \(pendingTask.label ?? String.empty) received", label ?? String.empty)
				//                print("\(label ?? "TaskQueue"): scope isCancelled \(Task.isCancelled)")
				if Task.isCancelled { break }
				if self.isScopeCancelled { break }
				if pendingTask.isCancelled { continue }

				if let task = pendingTask as? AsyncTask {
					do {
						//                        print("AsyncTask \(pendingTask.tag ?? String.empty) start",source: tag)
						let result = try await task.block()
						//                        print("AsyncTask \(pendingTask.tag ?? String.empty) resume",source: tag)
						task.continuation?.resume(returning: result)
					} catch {
						//                        log.error("AsyncTask \(pendingTask.tag ?? String.empty) error \(error)",source: tag)
						task.continuation?.resume(throwing: error)
					}
				} else if let task = pendingTask as? StreamTask {
					do {
						try await task.block()
					} catch {
						//                        print("StreamTask error \(error)")
						//                        log.error("StreamTask \(pendingTask.tag ?? String.empty) error \(error)",source: tag)
						// Stream completion is handled in block.
					}
				} else {
					//                    print("PendingTask discard \(pendingTask)", label ?? String.empty)
				}

				if Task.isCancelled { break }
				if isScopeCancelled { break }
			}

			for await pendingTask in self.pendingTasks {
				if let task = pendingTask as? AsyncTask {
					task.continuation?.resume(throwing: CancellationError())
				} else if let task = pendingTask as? StreamTask {
					task.cancel()
				}
			}
		}
	}

	public init(label: String? = nil) {
		self.label = label
		(pendingTasks, pendingTasksContinuation) = AsyncStream.makeStream()
		initScope()
	}

	public func close() {
		if !isScopeCancelled {
			isScopeCancelled = true
		}
	}

	@discardableResult
	public static func dispatch(label: String? = nil, handler: @escaping () async throws -> Void) -> TaskQueue {
		let taskQueue = TaskQueue(label: label)
		
		taskQueue.dispatchSync {
			try await handler()
			taskQueue.close()
		}

		return taskQueue
	}

	public func dispatchSync(label: String? = nil, block: @escaping () async throws -> Void) {
		//            print("yield directly \(label)")
		pendingTasksContinuation.yield(AsyncTask(label: label, continuation: nil, block: block))
	}

	public func dispatch<T>(label: String? = nil, block: @escaping () async throws -> T) async throws -> T {
		var pendingTask: AsyncTask?

		let cancel = {
			pendingTask?.isCancelled = true
		}

		return try await withTaskCancellationHandler {
			let result = try await withCheckedThrowingContinuation({ continuation in
				let task = AsyncTask(label: label, continuation: continuation, block: block)
				pendingTask = task
				pendingTasksContinuation.yield(task)
			})

			guard let typedResult = result as? T else {
				throw TaskQueueError.invalidResultType(expected: "\(T.self)", actual: "\(type(of: result))")
			}

			return typedResult
		} onCancel: {
			cancel()
		}
	}

	public func dispatchStream<T>(label: String? = nil, block: @escaping (AsyncThrowingStream<T, Error>.Continuation) -> Void) -> (stream: AsyncThrowingStream<T, Error>, continuation: AsyncThrowingStream<T, Error>.Continuation) {
		let asyncStream = AsyncThrowingStream.makeStream(of: T.self)
		let typedContinuation = asyncStream.continuation

		pendingTasksContinuation.yield(
			StreamTask(
				label: label,
				cancel: {
					typedContinuation.finish(throwing: CancellationError())
				},
				block: { [weak self] in
					do {
						for try await element in AsyncThrowingStream(T.self, block) {
							guard self?.isScopeCancelled == false else {
								throw CancellationError()
							}
							typedContinuation.yield(element)
						}
						typedContinuation.finish()
					} catch {
						typedContinuation.finish(throwing: error)
					}
				}
			)
		)

		return asyncStream
	}
}
