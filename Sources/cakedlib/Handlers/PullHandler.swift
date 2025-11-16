//
//  PullHandler.swift
//  Caker
//
//  Created by Frederic BOLTZ on 14/11/2025.
//
import GRPCLib
import Containerization
import ContainerizationArchive
import ContainerizationError
import ContainerizationExtras
import ContainerizationOCI
import Foundation

public struct PullHandler {
	private static func withAuthentication<T>(ref: String, _ body: @Sendable @escaping (_ auth: Authentication?) async throws -> T?) async throws -> T? {
		let ref = try Reference.parse(ref)

		guard let host = ref.resolvedDomain else {
			throw ContainerizationError(.invalidArgument, message: "No host specified in image reference")
		}

		let keychain = KeychainHelper(id: Utilities.keychainID)
		let authentication = try? keychain.lookup(domain: host)

		return try await body(authentication)
	}

	public static func pull(location: VMLocation, image: String, insecure: Bool, runMode: Utils.RunMode, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async -> PullReply {
		do {
			let imageStore = try Home(runMode: runMode).imageStore
			let reference = try Reference.parse(image)

			reference.normalize()

			let normalizedReference = reference.description
			let image = try await Self.withAuthentication(ref: normalizedReference) { auth in
				try await imageStore.pull(reference: normalizedReference, platform: nil, insecure: insecure, auth: auth)
			}
			
			return PullReply(success: true, message: "Success")
		} catch {
			return PullReply(success: false, message: "\(error)")
		}
	}

	public static func pull(name: String, image: String, insecure: Bool, runMode: Utils.RunMode, progressHandler: @escaping ProgressObserver.BuildProgressHandler) async -> PullReply {
		PullReply(success: false, message: "Not implemented")
	}
}
