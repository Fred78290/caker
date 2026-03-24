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
	public static func requestAdminAuthorizationIfNeeded(_ command: String) throws -> AuthorizationRef? {
		if geteuid() == 0 {
			return nil
		}

		var authorizationRef: AuthorizationRef? = nil
		var err = AuthorizationCreate(nil, nil, [], &authorizationRef)

		guard err == errAuthorizationSuccess, let authorizationRef else {
			throw ServiceError("AuthorizationCreate failed with status \(err)")
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
			throw ServiceError("AuthorizationCopyRights failed with status \(err)")
		}

		return authorizationRef
	}

	public static func runPrivileged(_ command: String, arguments: [String], authorization: AuthorizationRef?) throws -> String {
		if geteuid() == 0 {
			return try Shell.command(command, arguments: arguments)
		}

		guard let authorization else {
			throw ServiceError("Missing Authorization Services reference for privileged operation")
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
			let err = authorizationExecuteWithPrivileges(authorization, command, [], &args, &pipe)

			guard err == errAuthorizationSuccess else {
				throw ServiceError("Authorization failed: \(err)")
			}

			return FileHandle(fileDescriptor: fileno(pipe), closeOnDealloc: true)
		}

		guard let output = try fh.readToEnd() else {
			return ""
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
