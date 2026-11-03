//
//  AuthorizationHelperProtocol.swift
//  Caker
//
//  Created by Frederic BOLTZ on 03/11/2026.
//
import Foundation
import GRPCLib

@objc(AuthorizationHelperReply)
public final class AuthorizationHelperReply: NSObject, NSSecureCoding, @unchecked Sendable {
	public static var supportsSecureCoding: Bool { true }

	@objc public let operation: String
	@objc public let success: Bool
	@objc public let reason: String

	public init(operation: String, success: Bool, reason: String) {
		self.operation = operation
		self.success = success
		self.reason = reason
		super.init()
	}

	public required init?(coder: NSCoder) {
		guard let operation = coder.decodeObject(of: NSString.self, forKey: "operation") as String?,
			let reason = coder.decodeObject(of: NSString.self, forKey: "reason") as String?
		else {
			return nil
		}

		self.operation = operation
		self.success = coder.decodeBool(forKey: "started")
		self.reason = reason
		super.init()
	}

	public func encode(with coder: NSCoder) {
		coder.encode(self.operation as NSString, forKey: "operation")
		coder.encode(self.success, forKey: "success")
		coder.encode(self.reason as NSString, forKey: "reason")
	}
}

@objc(AuthorizationHelperProtocol)
public protocol AuthorizationHelperProtocol {
	/// Start vmnet network with DHC server. `authData` must be an AuthorizationExternalForm embedded in a Data.
	@objc(startNetworkWithAuthorization:cakeHome:networkName:withReply:)
	func startNetwork(authorization authData: Data, cakeHome: String, networkName: String, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void)

	/// Set DHCP Lease. `authData` must be an AuthorizationExternalForm embedded in a Data.
	@objc(setDHCPLeaseWithAuthorization:leaseTime:withReply:)
	func setDHCPLease(authorization authData: Data, leaseTime: Int32, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void)

	/// Import external virtual machine from multipass. `authData` must be an AuthorizationExternalForm embedded in a Data.
	@objc(importVirtualMachineWithAuthorization:cakeHome:arguments:withReply:)
	func importVirtualMachine(authorization authData: Data, cakeHome: String, arguments: [String], withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void)

	/// Install or remove imds redirect. `authData` must be an AuthorizationExternalForm embedded in a Data.
	@objc(imdsRedirectWithAuthorization:cakeHome:externalAddress:internalAddress:internalPort:install:withReply:)
	func imdsRedirect(authorization authData: Data, cakeHome: String, externalAddress: String, internalAddress: String, internalPort: Int, install: Bool, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void)

	/// Install files in /etc/sudoers.d/caked & /etc/paths.d/com.aldunelabs.caker. `authData` must be an AuthorizationExternalForm embedded in a Data.
	@objc(installPriviligedFilesWithAuthorization:cakerPath:withReply:)
	func installPriviligedFiles(authorization authData: Data, cakerPath: String, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void)
}

public enum AuthorizationHelperCommon {
	public static let kAuthorizationHelperToolMachServiceName = "com.aldunelabs.caker.authorization"

	// commandInfo represents everything we need to know about the authorized commands supported by
	// the app.  Each key is the selector of the command.  The corresponding value contains three items:
	//
	// o authRightName is the name of the authorization right itself.  This is used by both the app
	//   (when creating rights and when pre-authorizing rights) and by the tool (when doing the final
	//   authorization check).
	//
	// o authRightDefault is the default right specification, used by the app when it needs to create
	//   the default right specification.  This is commonly a string containing a rule name, but it can
	//   potentially be more complex.  See the discussion of the rightDefinition parameter of
	//   AuthorizationRightSet.
	//
	// o authRightDescription is a user-visible description of the right.  This is used by the app when
	//   it needs to create the default right specification.  Actually, the string is used to look up
	//   a localized version of the string in "Common.strings".
	//
	//   The strings here contain EBAS as a shortcut for EvenBetterAuthorizationSample.  However, the
	//   values in "Common.strings" contain the fully expanded name, which allows you to see whether
	//   localization is working properly.
	//
	//   These strings are also surrounded by NSLocalizedString, which makes it easy to use
	//   genstrings to create an initial "Common.strings".

	private struct CommandInfo {
		let authRightName: String
		let authRightDefault: String
		let authRightDescription: String
	}

	private static let commandInfo: [Selector: CommandInfo] = [
		#selector(AuthorizationHelperProtocol.startNetwork(authorization:cakeHome:networkName:withReply:)): CommandInfo(
			authRightName: "com.aldunelabs.caker.authorization.start-network",
			authRightDefault: kAuthorizationRuleClassAllow,
			authRightDescription: NSLocalizedString(
				"Helper is trying to start named network with DHCP server.",
				comment: "prompt shown when user is required to authorize to start vmnet network with DHCP server"
			)
		),
		#selector(AuthorizationHelperProtocol.setDHCPLease(authorization:leaseTime:withReply:)): CommandInfo(
			authRightName: "com.aldunelabs.caker.authorization.set-dhcp-lease",
			authRightDefault: kAuthorizationRuleClassAllow,
			authRightDescription: NSLocalizedString(
				"Helper is trying to set global dhcp lease time for DHCP server.",
				comment: "prompt shown when user is required to authorize to set global dhcp lease time for DHCP server"
			)
		),
		#selector(AuthorizationHelperProtocol.imdsRedirect(authorization:cakeHome:externalAddress:internalAddress:internalPort:install:withReply:)): CommandInfo(
			authRightName: "com.aldunelabs.caker.authorization.imds-redirect",
			authRightDefault: kAuthorizationRuleClassAllow,
			authRightDescription: NSLocalizedString(
				"Helper is trying to install or remove imds redirect.",
				comment: "prompt shown when user is required to authorize to install or remove imds redirect"
			)
		),
		#selector(AuthorizationHelperProtocol.importVirtualMachine(authorization:cakeHome:arguments:withReply:)): CommandInfo(
			authRightName: "com.aldunelabs.caker.authorization.import-virtual-machine",
			authRightDefault: kAuthorizationRuleClassAllow,
			authRightDescription: NSLocalizedString(
				"Helper is trying to import external virtual machine.",
				comment: "prompt shown when user is required to authorize to import external virtual machine"
			)
		),
		#selector(AuthorizationHelperProtocol.installPriviligedFiles(authorization:cakerPath:withReply:)): CommandInfo(
			authRightName: "com.aldunelabs.caker.authorization.install-priviliged-files",
			authRightDefault: kAuthorizationRuleAuthenticateAsAdmin,
			authRightDescription: NSLocalizedString(
				"Helper is trying to install some priviliged files.",
				comment: "prompt shown when user is required to authorize to install some priviliged files"
			)
		),
	]

	/// For a given command selector, returns the associated authorization right name.
	public static func authorizationRight(for command: Selector) -> String? {
		commandInfo[command]?.authRightName
	}

	/// Sets up the default authorization rights in the authorization database.
	public static func setupAuthorizationRights(_ authRef: AuthorizationRef) {
		for info in commandInfo.values {
			// First get the right.  If we get back errAuthorizationDenied that means there's
			// no current definition, so we add our default one.
			guard AuthorizationRightGet(info.authRightName, nil) == errAuthorizationDenied else {
				// A right already exists (err == noErr) or any other error occurs, we assume that it
				// has been set up in advance by the system administrator or this is the second time
				// we've run.  Either way, there's nothing more for us to do.
				continue
			}

			let err = AuthorizationRightSet(
				authRef,  // authRef
				info.authRightName,  // rightName
				info.authRightDefault as CFString,  // rightDefinition
				info.authRightDescription as CFString,  // descriptionKey
				nil,  // bundle (nil implies main bundle)
				"AuthorizationHelperCommon" as CFString  // localeTableName
			)
			assert(err == errAuthorizationSuccess)
		}
	}
}
