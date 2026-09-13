import GRPC
import GRPCLib
import NIOCore
import NIOPosix
import XCTest

@testable import CakedLib
@testable import caked

/// Exercises `CakedProvider.executeCancellable(command:)`/`stop()` directly (no real gRPC
/// transport involved) — regression coverage for the bug where `caked service listen` receiving
/// SIGINT called `provider.stop()`, which never actually cancelled a long-running streaming
/// command's (build/launch/provision) `Task`, since `CakedCommandAsync`'s default
/// `run(on:runMode:)` runs on an unstructured `Task` created by `EventLoop.makeFutureWithTask`
/// that nothing could reach from the outside.
final class CakedProviderCancellationTests: XCTestCase {
	/// A `CakedCommandAsync` that just sleeps and records whether it observed cancellation —
	/// standing in for `BuildHandler`/`ProvisionHandler`'s own long-running work without needing
	/// to actually build or provision a VM.
	private final class CancellationFlag: @unchecked Sendable {
		private let lock = NSLock()
		private var _wasCancelled = false

		var wasCancelled: Bool {
			self.lock.lock()
			defer { self.lock.unlock() }
			return self._wasCancelled
		}

		func markCancelled() {
			self.lock.lock()
			defer { self.lock.unlock() }
			self._wasCancelled = true
		}
	}

	private struct SleepyCommand: CakedCommandAsync {
		let flag: CancellationFlag

		func replyError(error: any Error) -> Caked_Reply {
			Caked_Reply()
		}

		func run(on: EventLoop, runMode: Utils.RunMode) async -> Caked_Reply {
			do {
				// Long enough that the test would fail waiting for it to finish on its own —
				// the assertion is that `stop()` cancels it well before this elapses.
				try await Task.sleep(nanoseconds: 5_000_000_000)
			} catch is CancellationError {
				self.flag.markCancelled()
			} catch {
				// Not expected, but don't let an unrelated error fail this test's own timing.
			}

			return Caked_Reply()
		}
	}

	func testProviderStopCancelsInFlightExecuteCancellableTask() async throws {
		let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

		defer {
			XCTAssertNoThrow(try group.syncShutdownGracefully())
		}

		let provider = try CakedProvider(group: group, password: nil, runMode: .user)
		let flag = CancellationFlag()

		let task = Task {
			_ = try await provider.executeCancellable(command: SleepyCommand(flag: flag))
		}

		// Give `executeCancellable` a moment to register the task and reach the `Task.sleep` call
		// before asking the provider to stop.
		try await Task.sleep(nanoseconds: 200_000_000)

		provider.stop()

		try await task.value

		XCTAssertTrue(flag.wasCancelled, "stop() should have cancelled the in-flight task instead of letting it run to completion")
	}

	func testExecuteCancellableThrowsOnceProviderHasStopped() async throws {
		let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

		defer {
			XCTAssertNoThrow(try group.syncShutdownGracefully())
		}

		let provider = try CakedProvider(group: group, password: nil, runMode: .user)

		provider.stop()

		do {
			_ = try await provider.executeCancellable(command: SleepyCommand(flag: CancellationFlag()))
			XCTFail("executeCancellable should refuse new work once the provider has stopped")
		} catch {
			// Expected — the same "Service is shutting down" guard `execute(command:)` already has.
		}
	}
}
