//
//  GuestApplicationsView.swift
//  Caker
//
import AppKit
import CakeAgentLib
import CakedLib
import GRPC
import GRPCLib
import SwiftUI

/// How the app runs a command line in a guest: through caked's `Run` call when the VM belongs to a service (the rule
/// `InfosHandler.infos` uses), straight to the agent of an embedded VM otherwise.
enum GuestApplicationsHandler {
	static func runner(client: CakedServiceClient?, vmURL: URL, runMode: Utils.RunMode) throws -> GuestApplications.Runner {
		if let client, vmURL.isFileURL == false {
			let name = vmURL.vmName

			return { line in
				try client.run(.with {
					$0.vmname = name
					$0.command = line
				}).response.wait().run
			}
		}

		let location = VMLocation(rootURL: vmURL)
		let connection = try CakeAgentConnection.createCakeAgentConnection(on: Utilities.group.next(), listeningAddress: location.agentURL, timeout: 10, runMode: runMode, retries: .upTo(1))

		return { line in try connection.run(command: line) }
	}

	/// The tool a launcher runs. A VM of the local service goes through the `cakectl` inside this app (the service shows the
	/// windows through the tunnel). A VM run by this app itself (`.app` mode) has no service to connect to: the launcher runs
	/// the `caked` inside this app, which reaches its agent directly and shows the windows of a VM it starts, while a VM
	/// already running here keeps showing its windows in this app. A remote one needs an address this app keeps to itself.
	static func launcherTool(connectionMode: ConnectionManager.ConnectionMode) -> (url: URL, arguments: [String])? {
		func inPlugIns(_ app: String, _ executable: String) -> URL? {
			let url = Bundle.main.bundleURL.appendingPathComponent("Contents/PlugIns/\(app).app/Contents/MacOS/\(executable)")

			return FileManager.default.isExecutableFile(atPath: url.path(percentEncoded: false)) ? url : nil
		}

		switch connectionMode {
		case .user:
			return inPlugIns("cakectl", "cakectl").map { ($0, []) }
		case .system:
			return inPlugIns("cakectl", "cakectl").map { ($0, ["--system"]) }
		case .app:
			return inPlugIns("caked", "caked").map { ($0, []) }
		case .remote:
			return nil
		}
	}
}

/// How to reach the agent, built on the icon loader's own queue. The service client it captures is thread safe.
struct GuestRunnerMaker: @unchecked Sendable {
	let make: () throws -> GuestApplications.Runner
}

/// Reads the icons of the applications from the guest as the rows appear. Every read is two calls to the agent, so they
/// run one at a time, and an icon (or its absence) is kept for as long as the popover lives.
@MainActor
final class GuestIconLoader: ObservableObject {
	/// Only used on `queue`.
	private final class RunnerBox: @unchecked Sendable {
		var runner: GuestApplications.Runner?
	}

	private var images: [String: NSImage] = [:]
	private var missing: Set<String> = []
	private var pending: [String: Task<NSImage?, Never>] = [:]
	private let queue = DispatchQueue(label: "com.aldunelabs.caker.guest-icons")
	private let box = RunnerBox()

	func image(for application: GuestApplication, makeRunner: GuestRunnerMaker) async -> NSImage? {
		if let image = self.images[application.id] {
			return image
		}

		if self.missing.contains(application.id) {
			return nil
		}

		if let task = self.pending[application.id] {
			return await task.value
		}

		let queue = self.queue
		let box = self.box
		let task = Task { () -> NSImage? in
			let data: Data? = await withCheckedContinuation { continuation in
				queue.async {
					do {
						if box.runner == nil {
							box.runner = try makeRunner.make()
						}

						continuation.resume(returning: try GuestApplications.icon(for: application, run: box.runner!))
					} catch {
						continuation.resume(returning: nil)
					}
				}
			}

			return data.flatMap { NSImage(data: $0) }.flatMap { $0.isValid ? $0 : nil }
		}

		self.pending[application.id] = task

		let image = await task.value

		self.pending[application.id] = nil

		if let image {
			self.images[application.id] = image
		} else {
			self.missing.insert(application.id)
		}

		return image
	}
}

/// The applications of a Linux VM with seamless windows, to start one: its windows show on the desktop through the
/// seamless windows channel the app already holds for the VM.
struct GuestApplicationsView: View {
	let document: VirtualMachineDocument
	let close: () -> Void

	@StateObject private var icons = GuestIconLoader()
	@State private var applications: [GuestApplication] = []
	@State private var search = ""
	@State private var loading = false
	@State private var loaded = false
	@State private var message: String?
	@State private var starting: String?

	private var filtered: [GuestApplication] {
		let text = self.search.trimmingCharacters(in: .whitespaces)

		guard text.isEmpty == false else {
			return self.applications
		}

		return self.applications.filter { $0.name.localizedCaseInsensitiveContains(text) || $0.id.localizedCaseInsensitiveContains(text) || ($0.comment ?? "").localizedCaseInsensitiveContains(text) }
	}

	private var launcher: (url: URL, arguments: [String])? {
		GuestApplicationsHandler.launcherTool(connectionMode: self.document.connectionManager.connectionMode)
	}

	var body: some View {
		VStack(spacing: 10) {
			HStack(spacing: 8) {
				Image(systemName: "magnifyingglass")
					.foregroundStyle(.secondary)

				TextField("Search", text: self.$search)
					.textFieldStyle(.plain)

				Button("Refresh", systemImage: "arrow.clockwise") {
					self.reload()
				}
				.labelStyle(.iconOnly)
				.buttonStyle(.plain)
				.foregroundStyle(.secondary)
				.help("Read the applications of the VM again")
				.disabled(self.loading)
			}
			.padding(.horizontal, 10)
			.padding(.vertical, 7)
			.background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.07)))

			if let message {
				Text(message)
					.font(.callout)
					.foregroundStyle(.red)
					.frame(maxWidth: .infinity, alignment: .leading)
					.textSelection(.enabled)
			}

			if self.loading && self.loaded == false {
				ProgressView()
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			} else if self.filtered.isEmpty {
				Text(self.loaded ? String(localized: "No application") : "")
					.foregroundStyle(.secondary)
					.frame(maxWidth: .infinity, maxHeight: .infinity)
			} else {
				ScrollView {
					LazyVStack(spacing: 2) {
						ForEach(self.filtered) { application in
							GuestApplicationRow(application: application, icons: self.icons, makeRunner: self.makeRunner, starting: self.starting == application.id, busy: self.starting != nil, canCreateLauncher: self.launcher != nil, start: {
								self.start(application)
							}, createLauncher: {
								self.createLauncher(application)
							})
						}
					}
				}
				.scrollIndicators(.automatic)
			}
		}
		.padding(12)
		.frame(width: 360, height: 420)
		.task {
			self.reload()
		}
	}

	/// How to reach the agent, for the icons: captured now, built on the loader's own queue.
	private var makeRunner: GuestRunnerMaker {
		let client = self.document.connectionManager.serviceClient
		let url = self.document.url
		let runMode = self.document.connectionManager.connectionMode.runMode

		return GuestRunnerMaker { try GuestApplicationsHandler.runner(client: client, vmURL: url, runMode: runMode) }
	}

	private var user: String {
		self.document.virtualMachineConfig.configuredUser
	}

	/// The agent's answer blocks, so it is awaited off the main thread.
	private func work<T: Sendable>(_ body: @escaping @Sendable (GuestApplications.Runner) throws -> T, done: @escaping @MainActor (Result<T, Error>) -> Void) {
		let client = self.document.connectionManager.serviceClient
		let url = self.document.url
		let runMode = self.document.connectionManager.connectionMode.runMode

		Task.detached {
			let result = Result { try body(try GuestApplicationsHandler.runner(client: client, vmURL: url, runMode: runMode)) }

			await MainActor.run { done(result) }
		}
	}

	private func reload() {
		let user = self.user

		self.loading = true
		self.message = nil

		self.work({ try GuestApplications.list(user: user, run: $0) }) { result in
			self.loading = false
			self.loaded = true

			switch result {
			case .success(let applications):
				self.applications = applications
			case .failure(let error):
				self.message = error.localizedDescription
			}
		}
	}

	private func start(_ application: GuestApplication) {
		let user = self.user
		let applications = self.applications

		self.starting = application.id
		self.message = nil

		self.work({ try GuestApplications.launch(application, among: applications, user: user, run: $0) }) { result in
			self.starting = nil

			switch result {
			case .success:
				self.close()
			case .failure(let error):
				self.message = error.localizedDescription
			}
		}
	}

	private func createLauncher(_ application: GuestApplication) {
		guard let launcher = self.launcher else { return }

		let name = self.document.name

		// The icon is read from the guest, which blocks: off the main thread. Without one the launcher has the generic icon.
		self.work({ (try? GuestApplications.icon(for: application, run: $0)) ?? nil }) { result in
			do {
				let icon = try result.get()
				let bundle = try GuestApplicationLauncher.create(vm: name, application: application, tool: launcher.url, extraArguments: launcher.arguments, overwrite: true, icon: icon)

				NSWorkspace.shared.activateFileViewerSelecting([bundle])
			} catch {
				self.message = error.localizedDescription
			}
		}
	}
}

/// One application: an icon tile with its initial, the name and what it says it is, highlighted under the pointer like the
/// rows of the other Caker lists.
private struct GuestApplicationRow: View {
	let application: GuestApplication
	@ObservedObject var icons: GuestIconLoader
	let makeRunner: GuestRunnerMaker
	let starting: Bool
	let busy: Bool
	let canCreateLauncher: Bool
	let start: () -> Void
	let createLauncher: () -> Void

	@State private var hovering = false
	@State private var icon: NSImage?

	private var initial: String {
		String(self.application.name.first.map { Character($0.uppercased()) } ?? "?")
	}

	var body: some View {
		HStack(spacing: 4) {
			Button(action: self.start) {
				HStack(spacing: 10) {
					// The application's own icon once read from the guest, its initial meanwhile (and when it has none)
					Group {
						if let icon = self.icon {
							Image(nsImage: icon)
								.resizable()
								.interpolation(.high)
								.scaledToFit()
						} else {
							Text(self.initial)
								.font(.system(size: 15, weight: .semibold, design: .rounded))
								.foregroundStyle(Color.accentColor)
								.frame(maxWidth: .infinity, maxHeight: .infinity)
								.background(RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.15)))
						}
					}
					.frame(width: 32, height: 32)

					VStack(alignment: .leading, spacing: 1) {
						Text(self.application.name)
							.lineLimit(1)

						if let comment = self.application.comment, comment.isEmpty == false {
							Text(comment)
								.font(.caption)
								.foregroundStyle(.secondary)
								.lineLimit(1)
						}
					}

					Spacer(minLength: 0)

					if self.starting {
						ProgressView()
							.scaleEffect(0.6)
					}
				}
				.contentShape(Rectangle())
			}
			.buttonStyle(.plain)
			.disabled(self.busy)

			// Shown under the pointer, like the inline actions of the other Caker lists
			if self.canCreateLauncher && self.hovering {
				Button(action: self.createLauncher) {
					Image(systemName: "plus.app")
						.font(.system(size: 16))
						.foregroundStyle(Color.accentColor)
						.frame(width: 26, height: 26)
						.contentShape(Rectangle())
				}
				.buttonStyle(.plain)
				.help("Create a launcher for this application")
				.disabled(self.busy)
			}
		}
		.padding(.horizontal, 8)
		.padding(.vertical, 5)
		.frame(maxWidth: .infinity, alignment: .leading)
		.background(RoundedRectangle(cornerRadius: 10).fill(self.hovering ? Color.primary.opacity(0.09) : Color.clear))
		.onHover { self.hovering = $0 }
		.task(id: self.application.id) {
			self.icon = await self.icons.image(for: self.application, makeRunner: self.makeRunner)
		}
	}
}
