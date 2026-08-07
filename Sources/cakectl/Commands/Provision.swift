//
//  Provision.swift
//  Caker
//
//  Created by Frederic BOLTZ on 07/08/2026.
//

import ArgumentParser
import Foundation
import GRPC
import GRPCLib
import CakeAgentLib

/// Drives an already-installed macOS VM's Setup Assistant unattended via PackerLite — the same
/// engine `cakectl build`/`create` run automatically for `.ipsw` sources with `--autoinstall`, exposed
/// here as a standalone step for VMs that skipped it at build time (or need it re-run). Run directly
/// against `cakectl` on the host where the VM lives.
struct Provision: AsyncGrpcParsableCommand {
	static let configuration = CommandConfiguration(commandName: "provision",
													abstract: String(localized: "Drive a macOS or Linux VM's Setup Assistant unattended via PackerLite"),
													discussion: String(localized: "Re-runs the same unattended Setup Assistant automation that `build`/`create` drive automatically for .ipsw or .iso sources with --autoinstall — for a VM that skipped it at build time. Uses the VM's stored macOS version and account credentials; fails if the VM is currently running, or has already been provisioned."))

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@Option(help: ArgumentHelp(String(localized: "Provisioning template (YAML) to use, overriding the VM's default built-in template (by stored macOS version or Linux platform); required if the VM's platform has no built-in template"), valueName: "path"))
	var template: String?

	@Option(name: [.customLong("macos-version")], help: ArgumentHelp(String(localized: "macOS version to use for picking the built-in template, overriding the VM's stored osName"), valueName: "version"))
	var macosVersion: MacOSVersion?

	@Option(name: [.customLong("var")], help: ArgumentHelp(String(localized: "Set a provisioning template variable (key=value), may be repeated"), valueName: "key=value"))
	var vars: [String] = []

	@Argument(help: ArgumentHelp(String(localized: "VM name")))
	var name: String

	func validate() throws {
		if let template {
			let u = URL(fileURLWithPath: template.expandingTildeInPath)

			if FileManager.default.fileExists(atPath: u.path(percentEncoded: false)) == false {
				throw ValidationError(String(localized: "Provided provisioning template file doesn't exist: \(template)"))
			}
		}
	}

	func run(client: CakedServiceClient, arguments: [String], callOptions: CallOptions?) async throws -> String {
		return try await withThrowingTaskGroup(of: Void.self, returning: String.self) { group in
			let context: ProgressObserver.ProgressHandlerContext = .init()
			let (stream, continuation) = AsyncStream.makeStream(of: Caked_ProvisionStreamReply.OneOf_Current?.self)
			var result: String = String.empty

			group.addTask {
				defer {
					continuation.finish()
				}

				let stream = try client.provision(Caked_ProvisionRequest(command: self)) { stream in
					continuation.yield(stream.current)
				}
				
				_ = try await stream.status.get()
			}

			for try await current in stream {
				if case .progress(let progress) = current {
					ProgressObserver.progressHandler(.progress(context, progress.fractionCompleted))
				} else if case .step(let step) = current {
					ProgressObserver.progressHandler(.step(step))
				} else if case .substep(let step) = current {
					ProgressObserver.progressHandler(.substep(step))
				} else if case .terminated(let status) = current {
					if case .success(let v)? = status.result {
						ProgressObserver.progressHandler(.terminated(.success(self.name), v))
					} else if case .failure(let v)? = status.result {
						ProgressObserver.progressHandler(.terminated(.failure(GrpcError(code: 1, reason: v)), nil))
					}
				} else if case .provisioned(let provisioned) = current {
					result = self.options.format.render(ProvisionedReply(provisioned))
				}
			}

			return result
		}
	}
}
