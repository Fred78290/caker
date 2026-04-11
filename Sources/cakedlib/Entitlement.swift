//
//  Entitlement.swift
//  Caker
//
//  Created by Frederic BOLTZ on 10/04/2026.
//

import Foundation
import Security

/// A helper for calling the Security framework from Swift.

public struct Entitlement {
	private let entitlements: [String: Any]
	
	private static func secCall<Result>(_ body: (_ resultPtr: UnsafeMutablePointer<Result?>) -> OSStatus  ) throws -> Result {
		var result: Result? = nil
		let err = body(&result)
		guard err == errSecSuccess else {
			throw NSError(domain: NSOSStatusErrorDomain, code: Int(err), userInfo: nil)
		}
		guard let result else {
			throw NSError(
				domain: NSOSStatusErrorDomain,
				code: Int(errSecInternalError),
				userInfo: [
					NSLocalizedDescriptionKey: "Security call succeeded but did not return a result."
				]
			)
		}
		return result
	}
	
	public init() throws {
		let me = try Self.secCall { SecCodeCopySelf([], $0) }
		let meStatic = try Self.secCall { SecCodeCopyStaticCode(me, [], $0) }
		let infoCF = try Self.secCall { SecCodeCopySigningInformation(meStatic, [], $0) }
		let info = infoCF as NSDictionary
		let entitlements = info[kSecCodeInfoEntitlementsDict] as? NSDictionary
		
		self.entitlements = entitlements as? [String: Any] ?? [:]
	}
	
	public func entitlement<T>(_ name: String) throws -> T? {
		return entitlements[name] as? T
	}
	
	public func hasVMNetworking() -> Bool {
		if let value: Bool = try? entitlement("com.apple.vm.networking") {
			return value
		} else {
			return false
		}
	}
	
	public static func hasVMNetworking() -> Bool {
		if let value: Bool = try? Entitlement().hasVMNetworking() {
			return value
		} else {
			return false
		}
	}
}

