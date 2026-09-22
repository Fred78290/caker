import ArgumentParser
import CakeAgentLib
import CakedLib
import Foundation
import GRPC
import GRPCLib
import NIOCore
import NIOPortForwarding
import NIOPosix
import Synchronization

public protocol CakedCommand {
	mutating func run(on: EventLoop, runMode: Utils.RunMode) -> Caked_Reply
	func replyError(error: Error) -> Caked_Reply
}

public protocol CakedCommandAsync: CakedCommand {
	mutating func run(on: EventLoop, runMode: Utils.RunMode) async -> Caked_Reply
}

extension CakedCommand {
	public func createCakeAgentClient(on: EventLoopGroup, runMode: Utils.RunMode, name: String) throws -> CakeAgentClient {
		let certificates = try CertificatesLocation.createAgentCertificats(runMode: runMode)
		let listeningAddress = try StorageLocation(runMode: runMode).find(name).agentURL

		return try CakeAgentHelper.createClient(
			on: on,
			listeningAddress: listeningAddress,
			connectionTimeout: 30,
			caCert: certificates.caCertURL.path(percentEncoded: false),
			tlsCert: certificates.clientCertURL.path(percentEncoded: false),
			tlsKey: certificates.clientKeyURL.path(percentEncoded: false))
	}
}

extension CakedCommandAsync {
	mutating func run(on: EventLoop, runMode: Utils.RunMode) -> Caked_Reply {
		do {
			var handler = self

			return try on.makeFutureWithTask {
				return await handler.run(on: on, runMode: runMode)
			}.wait()
		} catch {
			return self.replyError(error: error)
		}
	}
}

protocol CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand
}

public class Unimplemented: Error {
	let description: String

	init(_ what: String) {
		self.description = what
	}
}

extension Caked_RunCommand: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return RunHandler(request: self, provider: provider)
	}
}

extension Caked_InfoRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return InfosHandler(request: self, provider: provider)
	}
}

extension Caked_MountRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) -> CakedCommand {
		return MountHandler(request: self)
	}

	func directorySharingAttachment() -> DirectorySharingAttachments {
		return self.mounts.map { mount in
			DirectorySharingAttachment(
				source: mount.source,
				destination: mount.hasTarget ? mount.target : nil,
				readOnly: mount.readonly,
				name: mount.hasName ? mount.name : nil,
				uid: mount.hasUid ? Int(mount.uid) : nil,
				gid: mount.hasGid ? Int(mount.gid) : nil)
		}
	}
}

extension Caked_TemplateRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) -> CakedCommand {
		return TemplateHandler(request: self)
	}
}

extension Caked_RenameRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return RenameHandler(request: self)
	}
}

extension Caked_CommonBuildRequest {
	func buildOptions(taskID: UUID) throws -> BuildOptions {
		try BuildOptions(request: self, identifier: taskID)
	}
}

extension Caked_PurgeRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		var options = PurgeOptions()

		options.entries = .caches

		if self.hasEntries {
			if let entries = PurgeOptions.PurgeEntry(rawValue: self.entries) {
				options.entries = entries
			}
		}

		if self.hasOlderThan {
			options.olderThan = UInt(self.olderThan)
		} else {
			options.olderThan = nil
		}

		if self.hasSpaceBudget {
			options.spaceBudget = self.spaceBudget
		} else {
			options.spaceBudget = nil
		}

		return PurgeHandler(options: options)
	}
}

extension Caked_DeleteRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return DeleteHandler(request: self)
	}
}

extension Caked_ConfigureRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return ConfigureHandler(options: ConfigureOptions(request: self))
	}
}

extension Caked_ListRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return ListHandler(vmonly: self.vmonly, includeConfig: self.includeConfig)
	}
}

extension Caked_StartRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return try StartHandler(request: self, startMode: .service, gcd: provider.gcd.haveListeners, runMode: provider.runMode)
	}
}

extension Caked_RestartRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return RestartHandler(request: self, startMode: .service, gcd: provider.gcd.haveListeners)
	}
}

extension Caked_DuplicateRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return DuplicateHandler(request: self)
	}
}

extension Caked_LoginRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return LoginHandler(request: self)
	}
}

extension Caked_LogoutRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return LogoutHandler(request: self)
	}
}

extension Caked_CloneRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return PullHandler(request: self)
	}
}

extension Caked_PushRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return PushHandler(request: self)
	}
}

extension Caked_ImageRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return ImageHandler(request: self)
	}
}

extension Caked_RemoteRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return RemoteHandler(request: self)
	}
}

extension Caked_NetworkRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> CakedCommand {
		return NetworksHandler(request: self)
	}
}

extension Caked_WaitIPRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> any CakedCommand {
		return WaitIPHandler(name: self.name, wait: Int(self.timeout))
	}
}

extension Caked_StopRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> any CakedCommand {
		return StopHandler(request: self)
	}
}

extension Caked_SuspendRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> any CakedCommand {
		return SuspendHandler(request: self)
	}
}

extension Caked_PingRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> any CakedCommand {
		return PingHandler(request: self, provider: provider)
	}
}

extension Caked_GetScreenSizeRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> any CakedCommand {
		return ScreenSizeHandler.GetScreenSizeHandler(request: self)
	}
}

extension Caked_SetScreenSizeRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> any CakedCommand {
		return ScreenSizeHandler.SetScreenSizeHandler(request: self)
	}
}

extension Caked_InstallAgentRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> any CakedCommand {
		return InstallAgentHandler(request: self)
	}
}

extension Caked_CertificateRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> any CakedCommand {
		return CertificateHandler(request: self)
	}
}

extension Caked_ComposeRequest: CreateCakedCommand {
	func createCommand(provider: CakedProvider) throws -> any CakedCommand {
		switch self.compose {
		case .down(let request):
			return ComposeHandler.Down(request: request)
		case .up(let request):
			return ComposeHandler.Up(request: request)
		case .ps(let request):
			return ComposeHandler.Ps(request: request)
		case .ls(let request):
			return ComposeHandler.List(request: request)
		case .delete(let request):
			return ComposeHandler.Delete(request: request)
		case .none:
			throw ServiceError(String(localized: "Unknown compose command"))
		}
	}
}

class CakedProvider: @unchecked Sendable, Caked_ServiceAsyncProvider {
	let runMode: Utils.RunMode
	let group: EventLoopGroup
	let certLocation: CertificatesLocation
	let gcd: GrandCentralDispatch
	let vnc: VNCTunnel
	let shutdown = Mutex<Bool>(false)
	let logger = Logger("CakedProvider")
	var interceptors: Caked_ServiceServerInterceptorFactoryProtocol? = nil

	// One in-flight, explicitly-tracked long-running command — see
	// `executeCancellable(command:title:)`. `title` is purely descriptive (surfaced by `listTasks`/
	// `cakectl tasks list` so an operator can tell which VM/command a given id belongs to before
	// deciding whether to cancel it) and plays no role in cancellation itself.
	private struct RunningTask {
		let title: String
		let task: Task<Caked_Reply, Never>
		let onCancel: () async -> Void
	}

	// Tracks the in-flight `Task` behind each long-running, streaming RPC (build/launch/provision
	// — see `executeCancellable(command:title:)`) so `stop()` can actually cancel them on shutdown,
	// and so `listTasks`/`cancelTask` can expose/cancel them individually on request.
	// `execute(command:)` below never populates this: a `caked list`/`caked info` finishing a beat
	// late during shutdown is harmless, but a `caked build --autoinstall`/`caked provision` left
	// running unbounded — the exact bug this registry fixes — would otherwise block the graceful
	// shutdown future (`servers.map { $0.initiateGracefulShutdown() }` in `Service.Listen`) forever,
	// since nothing ever told that call's `Task` (created via `EventLoop.makeFutureWithTask`, an
	// unstructured, uncancellable-from-outside `Task` under the hood) to stop.
	private let runningTasks = Mutex<[UUID: RunningTask]>([:])

	init(group: EventLoopGroup, password: String?, runMode: Utils.RunMode) throws {
		self.runMode = runMode
		self.group = group
		self.certLocation = try CertificatesLocation.createAgentCertificats(runMode: runMode)
		self.gcd = .init(group: group, runMode: runMode)
		self.vnc = .init(group: group, runMode: runMode)

		if let password {
			self.interceptors = CakedPasswordAuthServerInterceptor(expectedPassword: password)
		}
	}

	func stop() {
		self.shutdown.withLock { $0 = true }
		self.cancelRunningTasks()
		self.gcd.stopGrandCentralDispatch()
		self.vnc.stopVNCTunnel()
	}

	private func cancelRunningTasks() {
		let tasks = self.runningTasks.withLock { $0 }

		guard tasks.isEmpty == false else {
			return
		}

		self.logger.info("Cancelling \(tasks.count) in-flight long-running task(s)")

		for running in tasks.values {
			running.task.cancel()
		}
	}

	func createCakeAgentConnection(vmName: String, retries: ConnectionBackoff.Retries = .unlimited) throws -> CakeAgentConnection {
		let listeningAddress = try StorageLocation(runMode: self.runMode).find(vmName).agentURL

		return CakeAgentConnection(eventLoop: self.group, listeningAddress: listeningAddress, certLocation: self.certLocation, retries: retries)
	}

	func createCakeAgentHelper(vmName: String, connectionTimeout: Int64 = 5, retries: ConnectionBackoff.Retries = .upTo(1)) throws -> CakeAgentHelper {
		return try CakeAgentHelper.createCakeAgentHelper(name: vmName, connectionTimeout: connectionTimeout, retries: retries, runMode: self.runMode)
	}

	func execute(command: CakedCommand) throws -> Caked_Reply {
		guard self.shutdown.withLock({ !$0 }) else {
			throw ServiceError(String(localized: "Service is shutting down"))
		}

		var command = command

		return command.run(on: self.group.next(), runMode: self.runMode)
	}

	func execute(command: CreateCakedCommand) throws -> Caked_Reply {
		try self.execute(command: command.createCommand(provider: self))
	}

	/// Like `execute(command:)`, but for a long-running streaming `CakedCommandAsync` (build,
	/// launch, provision) that must actually stop when the service is asked to shut down, rather
	/// than running to completion regardless. Spawns its own explicitly-tracked `Task` (registered
	/// in `runningTasks` for the duration) instead of going through
	/// `CakedCommandAsync`'s default `run(on:runMode:)` — which relies on
	/// `EventLoop.makeFutureWithTask`'s unstructured `Task`, with no way for `stop()` to reach it.
	/// Cancelling the tracked `Task` here propagates into the handler's own `withThrowingTaskGroup`
	/// child tasks via ordinary structured-concurrency cancellation, and from there into
	/// `CakedLib.BuildHandler.build(...)`/`CakedLib.ProvisionHandler.provision(...)`, which already
	/// handle `CancellationError` gracefully (the same mechanism `caked build`/`caked provision`'s
	/// own SIGINT handling already relies on for a local CLI invocation).
	func executeCancellable(command: CakedCommandAsync, title: String, id: UUID, onCancel: @escaping @Sendable () async -> Void) async throws -> Caked_Reply {
		guard self.shutdown.withLock({ !$0 }) else {
			throw ServiceError(String(localized: "Service is shutting down"))
		}

		let eventLoop = self.group.next()
		let runMode = self.runMode

		let task = Task<Caked_Reply, Never> {
			await withTaskCancellationHandler(
				operation: {
					var command = command
					return await command.run(on: eventLoop, runMode: runMode)
				},
				onCancel: {
					Task.sync {
						await onCancel()
					}
				})
		}

		self.runningTasks.withLock { $0[id] = RunningTask(title: title, task: task, onCancel: onCancel) }

		// Close a race where `stop()` flips `shutdown` and snapshots `runningTasks` before this call
		// registers its task.
		if self.shutdown.withLock({ $0 }) {
			task.cancel()
		}

		defer {
			_ = self.runningTasks.withLock { $0.removeValue(forKey: id) }
		}

		return await task.value
	}

	/// The raw gRPC-native slice of `runningTasks`, as `TaskEntry` values — with no `LXDOperationStore`
	/// merge applied. Split out from `listTasks()`/`nativeRunningTasks()` below so both can share the
	/// same conversion without either one re-deriving it.
	private func nativeTaskEntries() -> [Caked_Reply.TaskReply.TaskEntry] {
		self.runningTasks.withLock { $0 }.map { id, running in
			.with {
				$0.id = id.uuidString
				$0.title = running.title
			}
		}
	}

	/// Lists only the tasks tracked natively in `runningTasks` (gRPC-initiated build/launch/
	/// provision calls) — no `LXDOperationStore` (REST-initiated) entries included. This exists
	/// specifically for `LXDOperationsController`'s own `listOperations`/`getOperation`, which
	/// already lists `LXDOperationStore`'s own entries itself: calling the merged `listTasks()`
	/// there would double-list every REST-initiated Running operation (once from
	/// `LXDOperationStore.shared.list()`, once again from `listTasks()`'s own merge). Everything
	/// else — `cakectl tasks list`, the `caker` GUI's tasks view — should call `listTasks()`
	/// instead, to see REST-initiated work too.
	func nativeRunningTasks() -> Caked_Reply {
		Caked_Reply.with {
			$0.tasks = .with {
				$0.list = .with {
					$0.tasks = self.nativeTaskEntries()
				}
			}
		}
	}

	/// Lists every task currently tracked in `runningTasks`, merged with every currently-`Running`
	/// `LXDOperationStore` operation (REST-API-initiated build/provision work — see
	/// `Sources/caked/REST/LXDOperationStore.swift`) — so a `cakectl tasks list`/the `caker` GUI's
	/// tasks view sees both gRPC- and REST-initiated long-running work in one place, completing the
	/// loop `LXDOperationsController` already closed in the other direction (REST clients seeing
	/// gRPC-initiated tasks via `nativeRunningTasks()` above). `Success`/`Failure`-status
	/// `LXDOperationStore` entries are excluded — they're finished, not "running tasks". Split out
	/// from the `ListTasks` RPC method below (which just forwards here) so tests can call it
	/// directly without needing to construct a real `GRPCAsyncServerCallContext` — this method
	/// never uses `context` in the first place.
	func listTasks() async -> Caked_Reply {
		var entries = self.nativeTaskEntries()

		entries.append(
			contentsOf: await LXDOperationStore.shared.list()
				.filter { $0.status == "Running" }
				.map { op in
					.with {
						$0.id = op.id
						$0.title = op.description
					}
				})

		return Caked_Reply.with {
			$0.tasks = .with {
				$0.list = .with {
					$0.tasks = entries
				}
			}
		}
	}

	func listTasks(request: Caked_Empty, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		await self.listTasks()
	}

	/// Cancels the tracked task with the given id — first checking the gRPC-native `runningTasks`
	/// registry, then falling back to `LXDOperationStore` (a REST-API-initiated operation) if the id
	/// isn't found there. Cancellation of a `runningTasks` entry propagates the same way `stop()`'s
	/// does (see `executeCancellable(command:title:)`'s doc comment); cancellation of an
	/// `LXDOperationStore` entry removes it from the store and calls its `cancellable` closure, if
	/// one was set — most REST-initiated build/provision operations don't have one today, so this
	/// is a known, pre-existing limitation (the operation disappears from the list but isn't
	/// actually stopped), not something newly introduced here. Split out from the `CancelTask` RPC
	/// method below for the same test-without-a-real-context reason as `listTasks()` above.
	func cancelTask(id requestID: String) async -> Caked_Reply {
		guard let id = UUID(uuidString: requestID) else {
			return Caked_Reply.with {
				$0.tasks = .with {
					$0.cancelled = .with {
						$0.success = false
						$0.reason = String(format: String(localized: "'%@' is not a valid task id"), requestID)
					}
				}
			}
		}

		if let running = self.runningTasks.withLock({ $0[id] }) {
			self.logger.info("Cancelling task \(id) (\(running.title))")

			running.task.cancel()

			return Caked_Reply.with {
				$0.tasks = .with {
					$0.cancelled = .with {
						$0.success = true
					}
				}
			}
		}

		if let op = await LXDOperationStore.shared.delete(id: requestID.lowercased()) {
			self.logger.info("Cancelling REST operation \(op.id) (\(op.description))")

			await op.cancel()

			return Caked_Reply.with {
				$0.tasks = .with {
					$0.cancelled = .with {
						$0.success = true
					}
				}
			}
		}

		return Caked_Reply.with {
			$0.tasks = .with {
				$0.cancelled = .with {
					$0.success = false
					$0.reason = String(format: String(localized: "No running task with id '%@'"), requestID)
				}
			}
		}
	}

	func cancelTask(request: Caked_CancelTaskRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		await self.cancelTask(id: request.id)
	}

	func build(request: Caked_BuildRequest, responseStream: GRPCAsyncResponseStreamWriter<Caked_BuildStreamReply>, context: GRPCAsyncServerCallContext) async throws {
		guard let taskID = UUID(uuidString: request.taskID) else {
			throw ServiceError(String(localized: "'\(request.taskID)' is not a valid task id"))
		}

		_ = try await self.executeCancellable(
			command: BuildHandler(provider: self, options: request.options.buildOptions(taskID: taskID), responseStream: responseStream, context: context) {
				try self.gcd.updateStatus(
					.with {
						$0.name = request.options.name
						$0.status = .new
					})
			},
			title: "build \(request.options.name)",
			id: taskID
		) {
			self.logger.info("Build cancelled")
			try? await responseStream.send(
				.with {
					$0.builded = .with {
						$0.name = request.options.name
						$0.builded = false
						$0.reason = String(localized: "Cancelled")
					}
				})
		}
	}

	func launch(request: Caked_LaunchRequest, responseStream: GRPCAsyncResponseStreamWriter<Caked_LaunchStreamReply>, context: GRPCAsyncServerCallContext) async throws {
		guard let taskID = UUID(uuidString: request.taskID) else {
			throw ServiceError(String(localized: "'\(request.taskID)' is not a valid task id"))
		}

		_ = try await self.executeCancellable(
			command: LaunchHandler(request: request, gcd: self.gcd.haveListeners, responseStream: responseStream, context: context, taskID: taskID) {
				try self.gcd.updateStatus(
					.with {
						$0.name = request.options.name
						$0.status = .new
					})
			},
			title: "launch \(request.options.name)",
			id: taskID
		) {
			self.logger.info("Launch cancelled")
			try? await responseStream.send(
				.with {
					$0.launched = .with {
						$0.name = request.options.name
						$0.launched = false
						$0.reason = String(localized: "Cancelled")
					}
				})
		}
	}

	func start(request: Caked_StartRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func restart(request: Caked_RestartRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func duplicate(request: Caked_DuplicateRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		let reply = try self.execute(command: request)

		if reply.vms.duplicated.duplicated {
			try self.gcd.updateStatus(
				.with {
					$0.name = request.to
					$0.status = .new
				})
		}

		return reply
	}

	func delete(request: Caked_DeleteRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		let reply = try self.execute(command: request)

		if reply.vms.delete.success {
			for name in request.names.list {
				try self.gcd.updateStatus(
					.with {
						$0.name = name
						$0.status = .deleted
					})
			}
		}

		return reply
	}

	func configure(request: Caked_ConfigureRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func purge(request: Caked_PurgeRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func login(request: Caked_LoginRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func logout(request: Caked_LogoutRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func clone(request: Caked_CloneRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func push(request: Caked_PushRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func list(request: Caked_ListRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func image(request: Caked_ImageRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func remote(request: Caked_RemoteRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		let reply = try self.execute(command: request)

		if request.command == .add || request.command == .delete {
			self.gcd.updateStatusRemotes()
		}

		return reply
	}

	func template(request: Caked_TemplateRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		let reply = try self.execute(command: request)

		if request.command == .add || request.command == .delete || request.command == .duplicate {
			self.gcd.updateStatusTemplates()
		}

		return reply
	}

	func networks(request: Caked_NetworkRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		let reply = try self.execute(command: request)

		if request.command == .new || request.command == .remove || request.command == .set {
			self.gcd.updateStatusNetworks()
		}

		return reply
	}

	func waitIP(request: Caked_WaitIPRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func stop(request: Caked_StopRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func suspend(request: Caked_Caked.VMRequest.SuspendRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Caked.Reply {
		return try self.execute(command: request)
	}

	func rename(request: Caked_RenameRequest, context: GRPC.GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func info(request: Caked_InfoRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func run(request: Caked_RunCommand, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func execute(requestStream: GRPCAsyncRequestStream<Caked_ExecuteRequest>, responseStream: GRPCAsyncResponseStreamWriter<Caked_ExecuteResponse>, context: GRPCAsyncServerCallContext) async throws {
		_ = try self.execute(command: try ExecuteHandler(provider: self, requestStream: requestStream, responseStream: responseStream, context: context))
	}

	func mount(request: Caked_MountRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func umount(request: Caked_MountRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func ping(request: Caked_PingRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func currentStatus(request: Caked_CurrentStatusRequest, responseStream: GRPCAsyncResponseStreamWriter<Caked_Reply>, context: GRPCAsyncServerCallContext) async throws {
		_ = try self.execute(command: CurrentStatusHandler(provider: self, request: request, responseStream: responseStream))
	}

	func vncInfos(request: Caked_InfoRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: VNCInfosHandler(request: request))
	}

	func getScreenSize(request: Caked_GetScreenSizeRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func setScreenSize(request: Caked_SetScreenSizeRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func installAgent(request: Caked_InstallAgentRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func grandCentralDispatcher(request: Caked_Empty, responseStream: GRPCAsyncResponseStreamWriter<Caked_Reply>, context: GRPCAsyncServerCallContext) async throws {
		guard self.shutdown.withLock({ !$0 }) else {
			throw ServiceError(String(localized: "Service is shutting down"))
		}

		try await gcd.processDispatch(responseStream: responseStream)
	}

	func grandCentralUpdate(requestStream: GRPCAsyncRequestStream<Caked_CurrentStatus>, context: GRPCAsyncServerCallContext) async throws -> Caked_Empty {
		guard self.shutdown.withLock({ !$0 }) else {
			throw ServiceError(String(localized: "Service is shutting down"))
		}

		return try await gcd.processUpdate(requestStream: requestStream)
	}

	func vncTunnel(requestStream: GRPCAsyncRequestStream<Caked_VncStream>, responseStream: GRPCAsyncResponseStreamWriter<Caked_VncStream>, context: GRPCAsyncServerCallContext) async throws {
		guard self.shutdown.withLock({ !$0 }) else {
			throw ServiceError(String(localized: "Service is shutting down"))
		}

		try await self.vnc.tunnel(requestStream: requestStream, responseStream: responseStream, context: context)
	}

	func checkReliability(request: Caked_Empty, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		guard self.shutdown.withLock({ !$0 }) else {
			throw ServiceError(String(localized: "Service is shutting down"))
		}

		return .with {
			$0.ping = .with {
				$0.message = "pong"
				$0.success = true
			}
		}
	}

	func certificate(request: Caked_CertificateRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func stopService(request: Caked_Empty, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		// Defer the signal so the reply is delivered before the process exits.
		DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
			kill(getpid(), SIGINT)
		}
		return Caked_Reply()
	}

	func compose(request: Caked_ComposeRequest, context: GRPCAsyncServerCallContext) async throws -> Caked_Reply {
		return try self.execute(command: request)
	}

	func provision(request: Caked_ProvisionRequest, responseStream: Caked_ResponseProvisionStreamReply, context: GRPCAsyncServerCallContext) async throws {
		guard let taskID = UUID(uuidString: request.taskID) else {
			throw ServiceError(String(localized: "'\(request.taskID)' is not a valid task id"))
		}

		_ = try await self.executeCancellable(
			command: ProvisionHandler(provider: self, request: request, responseStream: responseStream, runMode: runMode),
			title: "provision \(request.name)",
			id: taskID,
		) {
			self.logger.info("Provision cancelled")
			try? await responseStream.send(
				.with {
					$0.provisioned = .with {
						$0.name = request.name
						$0.provisioned = false
						$0.reason = String(localized: "Cancelled")
					}
				})
		}
	}
}
