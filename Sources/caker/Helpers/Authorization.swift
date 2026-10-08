//
//  Authorization.swift
//  Caker
//
//  Created by Frederic BOLTZ on 24/03/2026.
//

import Foundation
import Swift
import CakedLib
import Security

// https://github.com/sveinbjornt/STPrivilegedTask/blob/master/STPrivilegedTask.m
// https://github.com/gui-dos/Guigna/blob/9fdd75ca0337c8081e2a2727960389c7dbf8d694/Legacy/Guigna-Swift/Guigna/GAgent.swift#L42-L80

public struct Authorization {
	public static func requestAdminAuthorizationIfNeeded() throws -> AuthorizationRef? {
		if geteuid() == 0 {
			return nil
		}
		let authorizationEnvironmentIcon = kAuthorizationEnvironmentIcon.cString(using: .utf8)!
		let authorizationEnvironmentPrompt = kAuthorizationEnvironmentPrompt.cString(using: .utf8)!
		let authorizationRightExecute = kAuthorizationRightExecute.cString(using: .utf8)!

		var authorizationRef: AuthorizationRef? = nil
		let iconPath = Bundle.main.path(forResource: "Prompt", ofType: "png")!.cString(using: .utf8)!
		let prompt = String(localized: "Allow to install privileged bootstrap files").cString(using: .utf8)!

		var environmentItems: [AuthorizationItem] = [
			authorizationEnvironmentPrompt.withUnsafeBufferPointer { authorizationEnvironmentPrompt in
				prompt.withUnsafeBufferPointer { prompt in
					let promptPtr = UnsafeMutableRawPointer(mutating: prompt.baseAddress!)

					return AuthorizationItem(name: authorizationEnvironmentPrompt.baseAddress!, valueLength: prompt.count - 1, value: promptPtr, flags: 0)
				}
			},

			authorizationEnvironmentIcon.withUnsafeBufferPointer { authorizationEnvironmentIcon in
				iconPath.withUnsafeBufferPointer { iconPath in
					let iconPathPtr = UnsafeMutableRawPointer(mutating: iconPath.baseAddress!)

					return AuthorizationItem(name: authorizationEnvironmentIcon.baseAddress!, valueLength: iconPath.count - 1, value: iconPathPtr, flags: 0)
				}
			}
		]

		// Build an AuthorizationEnvironment from the Swift array by using its baseAddress
		var environment: AuthorizationEnvironment = environmentItems.withUnsafeMutableBufferPointer { buffer in
			guard let base = buffer.baseAddress else {
				return AuthorizationEnvironment(count: 0, items: nil)
			}
			return AuthorizationEnvironment(count: UInt32(buffer.count), items: base)
		}

		var rightsItem = authorizationRightExecute.withUnsafeBufferPointer { authorizationRightExecute in
			return AuthorizationItem(name: authorizationRightExecute.baseAddress!, valueLength: 0, value: nil, flags: 0)
		}

		var rights: AuthorizationRights = withUnsafeMutablePointer(to: &rightsItem) { rightsItem in
			return AuthorizationRights(count: 1, items: rightsItem)
		}

		var err = AuthorizationCreate(nil, &environment, AuthorizationFlags(rawValue: 0), &authorizationRef)

		guard err == errAuthorizationSuccess, let authorizationRef else {
			throw ServiceError(String(localized: "AuthorizationCreate failed with status \(err)"))
		}

		err = AuthorizationCopyRights(authorizationRef, &rights, &environment,  [ AuthorizationFlags(rawValue: 0), .extendRights, .interactionAllowed, .preAuthorize ], nil)

		guard err == errAuthorizationSuccess else {
			AuthorizationFree(authorizationRef, [.destroyRights])
			throw ServiceError(String(localized: "AuthorizationCopyRights failed with status \(err)"))
		}

		return authorizationRef
	}

	public static func requestAdminAuthorizationIfNeeded(_ command: String) throws -> AuthorizationRef? {
		if geteuid() == 0 {
			return nil
		}

		var authorizationRef: AuthorizationRef? = nil
		var err = AuthorizationCreate(nil, nil, [], &authorizationRef)

		guard err == errAuthorizationSuccess, let authorizationRef else {
			throw ServiceError(String(localized: "AuthorizationCreate failed with status \(err)"))
		}

		let flags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]
		let path = command.cString(using: .utf8)!
		let name = kAuthorizationRightExecute.cString(using: .utf8)!
		
		var items: AuthorizationItem = name.withUnsafeBufferPointer { nameBuf in
			path.withUnsafeBufferPointer { pathBuf in
				let pathPtr = UnsafeMutableRawPointer(mutating: pathBuf.baseAddress!)
				
				return AuthorizationItem(name: nameBuf.baseAddress!, valueLength: path.count - 1, value: pathPtr, flags: 0)
			}
		}

		var rights: AuthorizationRights = withUnsafeMutablePointer(to: &items) { items in
			return AuthorizationRights(count: 1, items: items)
		}
				
		err = AuthorizationCopyRights(authorizationRef, &rights, nil, flags, nil)

		guard err == errAuthorizationSuccess else {
			AuthorizationFree(authorizationRef, [.destroyRights])
			throw ServiceError(String(localized: "AuthorizationCopyRights failed with status \(err)"))
		}

		return authorizationRef
	}

	public static func runPrivileged(_ command: String, arguments: [String], authorization: AuthorizationRef?) throws -> String {
		if geteuid() == 0 {
			return try Shell.command(command, arguments: arguments)
		}

		guard let authorization else {
			throw ServiceError(String(localized: "Missing Authorization Services reference for privileged operation"))
		}

		typealias AuthorizationExecuteWithPrivileges = @convention(c) (
			AuthorizationRef,
			UnsafePointer<CChar>,  // path
			AuthorizationFlags,
			UnsafePointer<UnsafeMutablePointer<CChar>?>,  // args
			UnsafeMutablePointer<UnsafeMutablePointer<FILE>?>?
		) -> OSStatus

		// AuthorizationExecuteWithPrivileges is deprecated and no longer exported by the Swift overlay, resolve it at runtime.
		guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "AuthorizationExecuteWithPrivileges") else {
			throw ServiceError(String(localized: "AuthorizationExecuteWithPrivileges is not available"))
		}

		let authorizationExecuteWithPrivileges = unsafeBitCast(symbol, to: AuthorizationExecuteWithPrivileges.self)

		// NULL terminated argv, the strings must outlive the call
		let args: [UnsafeMutablePointer<CChar>?] = arguments.map { strdup($0) } + [nil]

		defer {
			args.forEach { free($0) }
		}

		var pipe: UnsafeMutablePointer<FILE>? = nil
		let err = command.withCString { command in
			args.withUnsafeBufferPointer { argv in
				authorizationExecuteWithPrivileges(authorization, command, [], argv.baseAddress!, &pipe)
			}
		}

		guard err == errAuthorizationSuccess, let pipe else {
			throw ServiceError(String(format: String(localized: "Authorization failed: %d"), err))
		}

		defer {
			fclose(pipe)
		}

		// Read until the privileged process closes its standard output, then reap it
		let output = try FileHandle(fileDescriptor: fileno(pipe), closeOnDealloc: false).readToEnd()
		var status: Int32 = 0

		wait(&status)

		guard let output else {
			return String.empty
		}

		return String(decoding: output, as: UTF8.self)
	}

	/// Run a shell script as root and fail if the script exits with a non-zero status.
	/// AuthorizationExecuteWithPrivileges does not report the exit status of the launched process,
	/// so the script is wrapped to print it as the last line of its output.
	public static func runPrivilegedScript(_ script: URL, authorization: AuthorizationRef?) throws -> String {
		let marker = "caker-exit-status:"
		let wrapper = "/bin/sh \"$0\" 2>&1; echo \"\(marker)$?\""
		let output = try Self.runPrivileged("/bin/sh", arguments: ["-c", wrapper, script.path(percentEncoded: false)], authorization: authorization)
		var lines = output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

		while let last = lines.last, last.isEmpty {
			lines.removeLast()
		}

		guard let last = lines.last, last.hasPrefix(marker), let exitCode = Int32(last.dropFirst(marker.count)) else {
			throw ServiceError(String(localized: "Unable to get the exit status of the privileged script"))
		}

		lines.removeLast()

		let result = lines.joined(separator: "\n")

		guard exitCode == 0 else {
			throw ServiceError(String(format: String(localized: "Privileged script failed with exit code %d: %@"), exitCode, result))
		}

		return result
	}

	public static func runPrivileged(_ command: String) throws -> String {
		var components = command.components(separatedBy: " ")
		let command = components.remove(at: 0)
		let authorizationRef: AuthorizationRef? = try Self.requestAdminAuthorizationIfNeeded(command)

		defer {
			if let authorizationRef = authorizationRef {
				AuthorizationFree(authorizationRef, [.destroyRights])
			}
		}

		return try Self.runPrivileged(command, arguments: components, authorization: authorizationRef)
	}
}

