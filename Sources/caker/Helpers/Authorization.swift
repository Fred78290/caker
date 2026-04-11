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

		print("execute: \(command) \(arguments.joined(separator: " "))")

		guard let authorization else {
			throw ServiceError(String(localized: "Missing Authorization Services reference for privileged operation"))
		}

		let RTLD_DEFAULT = UnsafeMutableRawPointer(bitPattern: -2)
		var authorizationExecuteWithPrivileges: @convention(c) (
			AuthorizationRef,
			UnsafePointer<CChar>,  // path
			AuthorizationFlags,
			UnsafePointer<UnsafePointer<CChar>?>,  // args
			UnsafeMutablePointer<UnsafeMutablePointer<FILE>>?
		) -> OSStatus

		authorizationExecuteWithPrivileges = unsafeBitCast(
			dlsym(RTLD_DEFAULT, "AuthorizationExecuteWithPrivileges"),
			to: type(of: authorizationExecuteWithPrivileges)
		)

		let command = command.cString(using: .utf8)!
		let arguments = arguments.map { $0.cString(using: .utf8)! }
		var args = Array<UnsafePointer<CChar>?>(
			repeating: nil,
			count: arguments.count + 1
		)

		for (idx, arg) in arguments.enumerated() {
			args[idx] = UnsafePointer<CChar>?(arg)
		}
		
		var file = FILE()
		let fh = try withUnsafeMutablePointer(to: &file) { file in
			var pipe = file
			return try args.withUnsafeBufferPointer { buffer in
				// `args` always has at least one element (the terminating nil),
				// so `baseAddress` is non-nil here.
				let argsPointer = buffer.baseAddress!
				let err = authorizationExecuteWithPrivileges(authorization, command, [], argsPointer, &pipe)

				guard err == errAuthorizationSuccess else {
					throw ServiceError(String(localized: "Authorization failed: \(err)"))
				}

				return FileHandle(fileDescriptor: fileno(pipe), closeOnDealloc: true)
			}
		}

		guard let output = try fh.readToEnd() else {
			return String.empty
		}

		return String(data: output, encoding: .utf8)!
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

