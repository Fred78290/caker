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
	static let configuration = ProvisionOptions.configuration

	@OptionGroup(title: String(localized: "Client options"))
	var options: Client.Options

	@OptionGroup(title: String(localized: "Provisioning options"))
	var provision: ProvisionOptions

	func validate() throws {
		if let template = self.provision.template {
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
						ProgressObserver.progressHandler(.terminated(.success(self.provision.name), v))
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
