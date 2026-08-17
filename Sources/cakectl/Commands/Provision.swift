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

	func validate() throws {
		if let template = self.provision.template {
			let u = URL(fileURLWithPath: template.expandingTildeInPath)

			if FileManager.default.fileExists(atPath: u.path(percentEncoded: false)) == false {
				throw ValidationError(String(localized: "Provided provisioning template file doesn't exist: \(template)"))
			}
		}
	}

	private func doVNC(_ vncURL: URL, client: CakedServiceClient, config: CakedConfiguration, screenSize: ViewSize, channel: Channel, handlerStatus: @escaping () -> Status) {
		do {
			try VNCApp.startVncClient(
				name: self.provision.name,
				config: config,
				vncURL: vncURL,
				screenSize: screenSize,
				isDebugLoggingEnabled: vncDebug,
				vmStatus: handlerStatus)
		} catch {
			// Handle or log the error; the closure itself must not throw
			fputs("VNC client failed to start: \(error)\n", stderr)
		}

		channel.close(promise: nil)
	}

	private func doVNC(_ infos: Caked_ProvisionStreamReply.ProvisionInfo, client: CakedServiceClient, handlerStatus: @escaping () -> Status) {
		if let vncURL = URL(string: infos.vncURL) {
			do {
				let (channel, port) = try client.createVNCTunnel(eventLoopGroup: Utilities.group, vmName: self.provision.name)
				var components = URLComponents()

				components.scheme = "vnc"
				components.host = "127.0.0.1"
				components.port = port

				if let password = vncURL.password {
					components.password = password
				}

				if let vncURL = components.url {
					self.doVNC(vncURL, client: client, config: CakedConfiguration(infos.config), screenSize: ViewSize(infos.screenSize), channel: channel, handlerStatus: handlerStatus)
					//try VNCApp.connectVncClient(
					//	name: self.provision.name,
					//	config: CakedConfiguration(infos.config),
					//	vncURL: vncURL,
					//	screenSize: ViewSize(infos.screenSize),
					//	isDebugLoggingEnabled: vncDebug,
					//	vmStatus: handlerStatus)

					//VNCConnectionAppState.state.vncURL = vncURL
					//VNCConnectionAppState.state.screenSize = ViewSize(infos.screenSize)
					//VNCConnectionAppState.state.config = CakedConfiguration(infos.config)
					//VNCConnectionAppState.state.vmStatus = handlerStatus

					//VNCConnectionAppState.state.tryVNCConnect()
				}
			} catch {
				Logger(self).error(String(localized: "Unable to start vnc client, error occurred: \(error.reason)"))
			}
		} else {
			Logger(self).error(String(localized: "Unable to start vnc client, invalid VNC URL received from server: \(infos.vncURL)"))
		}
	}

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) throws -> String {
		var result: String = ""
		var terminated = false
		let infos = try withAsyncResult {
			return try await withCheckedThrowingContinuation { (checkedContinuation: CheckedContinuation<Caked_ProvisionStreamReply.ProvisionInfo, Error>) in

				// Launch async work inside a Task so the continuation closure stays synchronous
				Task {
					do {
						try await withThrowingTaskGroup(of: Void.self, returning: Void.self) { group in
							let context: ProgressObserver.ProgressHandlerContext = .init()
							let (stream, continuation) = AsyncStream.makeStream(of: Caked_ProvisionStreamReply.OneOf_Current?.self)
							let logger = Logger(self)

							group.addTask {
								defer {
									continuation.finish()
								}

								let stream = try client.provision(Caked_ProvisionRequest(command: self)) { stream in
									continuation.yield(stream.current)
								}

								_ = try await stream.status.get()

								logger.info("Provisioning completed")
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
										checkedContinuation.resume(returning: infos)
									} else if case .terminated(let status) = current {
										if case .success(let v)? = status.result {
											ProgressObserver.progressHandler(.terminated(.success(self.provision.name), v))
										} else if case .failure(let v)? = status.result {
											ProgressObserver.progressHandler(.terminated(.failure(GrpcError(code: 1, reason: v)), nil))
										}
									} else if case .provisioned(let provisioned) = current {
										result = self.options.format.render(ProvisionedReply(provisioned))
										break
									}
								}

								terminated = true

								logger.info("Provisioning stream ended")
							}

							try await group.next()

							continuation.finish()
							group.cancelAll()

							DispatchQueue.main.async {
								logger.debug("Terminating application after provisioning")
								NSApp.terminate(nil)
							}
						}
					} catch {
						// Ensure the continuation is resumed even on error paths
						checkedContinuation.resume(throwing: error)
					}
				}
			}
		}

		doVNC(infos, client: client) {
			return terminated ? .stopped : .running
		}

		return result
	}
}
