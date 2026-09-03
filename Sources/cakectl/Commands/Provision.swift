//
//  Provision.swift
//  Caker
//
//  Created by Frederic BOLTZ on 07/08/2026.
//

import AppKit
import ArgumentParser
import CakeAgentLib
import CakedLib
import Foundation
import GRPC
import GRPCLib
import NIO
import SwiftUI
import Synchronization

/// Drives an already-installed macOS VM's Setup Assistant unattended via PackerLite — the same
/// engine `cakectl build`/`create` run automatically for `.ipsw` sources with `--autoinstall`, exposed
/// here as a standalone step for VMs that skipped it at build time (or need it re-run). Run directly
/// against `cakectl` on the host where the VM lives.
struct Provision: GrpcParsableCommand {
	static let configuration = ProvisionOptions.configuration

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@OptionGroup(title: String(localized: "Provisioning options"))
	var provision: ProvisionOptions

	@Flag(name: .customLong("vnc-debug"), help: ArgumentHelp(String(localized: "Trace vnc traffic"), visibility: .hidden))
	var vncDebug: Bool = false

	mutating func validate() throws {
		if let template = self.provision.template {
			let u = URL(fileURLWithPath: template.expandingTildeInPath)

			if FileManager.default.fileExists(atPath: u.path(percentEncoded: false)) == false {
				throw ValidationError(String(localized: "Provided provisioning template file doesn't exist: \(template)"))
			}
		}

		try self.provision.mergeProvisionVars(provisionVars: ProvisionVariablesStore.load())
	}

	final class Provisionner {
		let command: Provision
		let client: CakedServiceClient
		var tunnel: VNCTunnel? = nil
		var terminated = false

		init(command: Provision, client: CakedServiceClient) {
			self.command = command
			self.client = client
		}

		private func doVNC(_ vncURL: URL, config: CakedConfiguration, screenSize: ViewSize, tunnel: VNCTunnel, handlerStatus: @escaping () -> Status) {
			do {
				try VNCApp.startVncClient(
					name: command.provision.name,
					config: config,
					vncURL: vncURL,
					screenSize: screenSize,
					tunnel: tunnel,
					allowClientResize: false,
					isDebugLoggingEnabled: command.vncDebug,
					vmStatus: handlerStatus)
			} catch {
				// Handle or log the error; the closure itself must not throw
				fputs("VNC client failed to start: \(error)\n", stderr)
			}
		}

		private func doVNC(_ infos: Caked_ProvisionStreamReply.ProvisionInfo) {
			if let vncURL = URL(string: infos.vncURL) {
				do {
					let tunnel = try client.createVNCTunnel(eventLoopGroup: Utilities.group, vmName: command.provision.name)
					var components = URLComponents()

					self.tunnel = tunnel

					components.scheme = "vnc"
					components.host = "127.0.0.1"
					components.port = tunnel.localPort

					if let password = vncURL.password {
						components.password = password
					}

					if let vncURL = components.url {
						self.doVNC(vncURL, config: CakedConfiguration(infos.config), screenSize: ViewSize(infos.screenSize), tunnel: tunnel) {
							return self.terminated ? .stopped : .running
						}
					}
				} catch {
					Logger(self).error(String(localized: "Unable to start vnc client, error occurred: \(error.reason)"))
				}
			} else {
				Logger(self).error(String(localized: "Unable to start vnc client, invalid VNC URL received from server: \(infos.vncURL)"))
			}
		}

		func provisionWithoutView() async throws -> String {
			return try await withThrowingTaskGroup(of: Void.self, returning: String.self) { group in
				let context: ProgressObserver.ProgressHandlerContext = .init()
				let (stream, continuation) = AsyncStream.makeStream(of: Caked_ProvisionStreamReply.OneOf_Current?.self)
				let logger = Logger(self)
				var result = ""

				group.addTask {
					defer {
						continuation.finish()
					}

					let stream = try self.client.provision(Caked_ProvisionRequest(command: self.command)) { stream in
						continuation.yield(stream.current)
					}

					_ = try await stream.status.get()

					logger.debug("Provisioning completed")
				}

				for try await current in stream {
					if case .progress(let progress) = current {
						ProgressObserver.progressHandler(.progress(context, progress.fractionCompleted))
					} else if case .step(let step) = current {
						ProgressObserver.progressHandler(.step(step))
					} else if case .substep(let step) = current {
						ProgressObserver.progressHandler(.substep(step))
					} else if case .infos(let infos) = current {
						ProgressObserver.progressHandler(.provision(.init(infos)))
					} else if case .provisioned(let provisioned) = current {
						result = command.options.format.renderSingle(ProvisionedReply(provisioned))

						if provisioned.provisioned {
							ProgressObserver.progressHandler(.terminated(.success(command.provision.name), provisioned.reason))
						} else {
							ProgressObserver.progressHandler(.terminated(.failure(ServiceError(provisioned.reason)), nil))
						}

						logger.debug("Provisioning stream ended")
						break
					}
				}

				continuation.finish()
				group.cancelAll()

				return result
			}
		}

		func provisionWithView() throws -> String {
			var result: String = ""
			let infos = try withAsyncResult {
				return try await withCheckedThrowingContinuation { (checkedContinuation: CheckedContinuation<Caked_ProvisionStreamReply.ProvisionInfo?, Error>) in
					// Launch async work inside a Task so the continuation closure stays synchronous
					Task {
						let resumed: Mutex<Bool> = Mutex(false)

						func finish(_ result: Result<Caked_ProvisionStreamReply.ProvisionInfo?, Error>) {
							resumed.withLock { resumed in
								guard resumed == false else {
									return
								}

								resumed = true

								switch result {
								case .success(let infos):
									checkedContinuation.resume(returning: infos)
								case .failure(let error):
									checkedContinuation.resume(throwing: error)
								}
							}
						}

						do {
							try await withThrowingTaskGroup(of: Void.self, returning: Void.self) { group in
								let context: ProgressObserver.ProgressHandlerContext = .init()
								let (stream, continuation) = AsyncStream.makeStream(of: Caked_ProvisionStreamReply.OneOf_Current?.self)
								let logger = Logger(self)

								group.addTask {
									do {
										defer {
											continuation.finish()
										}

										let stream = try self.client.provision(Caked_ProvisionRequest(command: self.command)) { stream in
											continuation.yield(stream.current)
										}

										_ = try await stream.status.get()

										finish(.success(nil))

										logger.debug("Provisioning completed")
									} catch {
										logger.error("Provisioning failed: \(error)")

										finish(.failure(error))
									}
								}

								group.addTask {
									for try await current in stream {
										if case .progress(let progress) = current {
											ProgressObserver.progressHandler(.progress(context, progress.fractionCompleted))
										} else if case .step(let step) = current {
											ProgressObserver.progressHandler(.step(step))
										} else if case .substep(let step) = current {
											ProgressObserver.progressHandler(.substep(step))
										} else if case .infos(let infos) = current {
											// Resume the continuation as soon as we have enough info to launch VNC
											finish(.success(infos))
										} else if case .provisioned(let provisioned) = current {
											result = self.command.options.format.renderSingle(ProvisionedReply(provisioned))

											if provisioned.provisioned {
												ProgressObserver.progressHandler(.terminated(.success(self.command.provision.name), provisioned.reason))
											} else {
												ProgressObserver.progressHandler(.terminated(.failure(ServiceError(provisioned.reason)), nil))
											}
											break
										}
									}

									self.terminated = true

									logger.debug("Provisioning stream ended")
								}

								try await group.next()

								continuation.finish()
								group.cancelAll()

								if let tunnel = self.tunnel {
									logger.debug("Terminate VNC tunnel")

									tunnel.close().whenComplete { _ in
										DispatchQueue.main.async {
											logger.debug("Terminating application after provisioning")
											NSApp.terminate(nil)
										}
									}
								} else {
									DispatchQueue.main.async {
										logger.debug("Terminating application after provisioning")
										NSApp.terminate(nil)
									}
								}
							}
						} catch {
							// Ensure the continuation is resumed even on error paths
							finish(.failure(error))
						}
					}
				}
			}

			if let infos {
				doVNC(infos)
			}

			return result
		}

		func run() throws -> String {
			if command.provision.foreground {
				return try self.provisionWithView()
			}

			return try withAsyncResult {
				return try await self.provisionWithoutView()
			}
		}
	}

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		try Provisionner(command: self, client: client).run()
	}
}
