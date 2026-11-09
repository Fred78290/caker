//
//  AuthorizationHelperProtocol.swift
//  Caker
//
//  Created by Frederic BOLTZ on 03/11/2026.
//
import Foundation
import GRPCLib

@objc(AuthorizationHelperReply)
public final class AuthorizationHelperReply: NSObject, NSSecureCoding, @unchecked Sendable, Codable {
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
		self.success = coder.decodeBool(forKey: "success")
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
	/// Start vmnet network with DHCP server. `authData` must be an AuthorizationExternalForm embedded in a Data.
	@objc(startNetworkWithAuthorization:cakeHome:networkName:withReply:)
	func startNetwork(authorization authData: Data, cakeHome: String, networkName: String, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void)

	#if !APPSTORE
		/// Run a standalone network (`caked networks run`) as root on a descriptor handed over by the caller: the VM end of the
		/// socketpair stays with the caller. The network is the one named by `--interface=` in `arguments`: its pid file and its control
		/// socket are the ones of that network in the cake home. Replies with the pid of the process once its pid file exists.
		/// `authData` must be an AuthorizationExternalForm embedded in a Data.
		@objc(runNetworkWithAuthorization:cakeHome:arguments:fileHandle:withReply:)
		func runNetwork(authorization authData: Data, cakeHome: String, arguments: [String], fileHandle: FileHandle, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void)
	/// Set DHCP Lease. `authData` must be an AuthorizationExternalForm embedded in a Data.
	#endif

	@objc(setDHCPLeaseWithAuthorization:leaseTime:withReply:)
	func setDHCPLease(authorization authData: Data, leaseTime: Int32, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void)

	/// Import external virtual machine from multipass. `authData` must be an AuthorizationExternalForm embedded in a Data.
	@objc(importVirtualMachineWithAuthorization:cakeHome:arguments:withReply:)
	func importVirtualMachine(authorization authData: Data, cakeHome: String, arguments: [String], withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void)

	/// Install or remove imds redirect. `authData` must be an AuthorizationExternalForm embedded in a Data.
	@objc(imdsRedirectWithAuthorization:externalAddress:internalAddress:internalPort:install:withReply:)
	func imdsRedirect(authorization authData: Data, externalAddress: String, internalAddress: String, internalPort: Int, install: Bool, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void)

	/// Install files in /etc/sudoers.d/caked & /etc/paths.d/com.aldunelabs.caker. `authData` must be an AuthorizationExternalForm embedded in a Data.
	@objc(installPriviligedFilesWithAuthorization:cakerPath:withReply:)
	func installPriviligedFiles(authorization authData: Data, cakerPath: String, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void)

	#if APPSTORE && USE_AUTHORIZATION_HELPER
		/// Get serialization network. `authData` must be an AuthorizationExternalForm embedded in a Data.
		@objc(getSerializationWithAuthorization:cakeHome:networkName:withReply:)
		func getSerialization(authorization authData: Data, cakeHome: String, networkName: String, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void)

		/// Create network. `authData` must be an AuthorizationExternalForm embedded in a Data.
		@objc(createNetworkWithAuthorization:cakeHome:networkName:options:withReply:)
		func createNetwork(authorization authData: Data, cakeHome: String, networkName: String, options: [String: Any], withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void)

		/// Configure network. `authData` must be an AuthorizationExternalForm embedded in a Data.
		@objc(configureNetworkWithAuthorization:cakeHome:networkName:options:withReply:)
		func configureNetwork(authorization authData: Data, cakeHome: String, networkName: String, options: [String: Any], withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void)

		/// Restart vmnet network with DHC server. `authData` must be an AuthorizationExternalForm embedded in a Data.
		@objc(restartNetworkWithAuthorization:cakeHome:networkName:withReply:)
		func restartNetwork(authorization authData: Data, cakeHome: String, networkName: String, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void)

		/// Stop vmnet network with DHC server. `authData` must be an AuthorizationExternalForm embedded in a Data.
		@objc(stopNetworkWithAuthorization:cakeHome:networkName:withReply:)
		func stopNetwork(authorization authData: Data, cakeHome: String, networkName: String, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void)

		/// Delete vmnet network with DHC server. `authData` must be an AuthorizationExternalForm embedded in a Data.
		@objc(deleteNetworkWithAuthorization:cakeHome:networkName:withReply:)
		func deleteNetwork(authorization authData: Data, cakeHome: String, networkName: String, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void)

		/// List network. `authData` must be an AuthorizationExternalForm embedded in a Data.
		@objc(listNetworkWithAuthorization:cakeHome:withReply:)
		func listNetwork(authorization authData: Data, cakeHome: String, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void)

		/// get network infos. `authData` must be an AuthorizationExternalForm embedded in a Data.
		@objc(infosNetworkWithAuthorization:cakeHome:networkName:withReply:)
		func infosNetwork(authorization authData: Data, cakeHome: String, networkName: String, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void)

		/// Read the shared networks configuration (`networks.json`) of the cake home. Replies with its JSON. `authData` must be an AuthorizationExternalForm embedded in a Data.
		@objc(getSharedNetworksWithAuthorization:cakeHome:withReply:)
		func getSharedNetworks(authorization authData: Data, cakeHome: String, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void)

		/// Store the shared networks configuration (`networks.json`) of the cake home, given as JSON. `authData` must be an AuthorizationExternalForm embedded in a Data.
		@objc(setSharedNetworksWithAuthorization:cakeHome:configuration:withReply:)
		func setSharedNetworks(authorization authData: Data, cakeHome: String, configuration: String, withReply reply: @escaping @Sendable (AuthorizationHelperReply) -> Void)

	#endif
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

	#if APPSTORE
		private static let authRightDefault = kAuthorizationRuleAuthenticateAsSessionUser
	#else
		private static let authRightDefault = kAuthorizationRuleClassAllow
	#endif

	private static let commandInfo: [Selector: CommandInfo] = {
		var commandInfo: [Selector: CommandInfo] = [
			#selector(AuthorizationHelperProtocol.startNetwork(authorization:cakeHome:networkName:withReply:)): CommandInfo(
				authRightName: "com.aldunelabs.caker.authorization.start-network",
				authRightDefault: authRightDefault,
				authRightDescription: NSLocalizedString(
					"Helper is trying to start named network with DHCP server.",
					comment: "prompt shown when user is required to authorize to start vmnet network with DHCP server"
				)
			),
			#selector(AuthorizationHelperProtocol.setDHCPLease(authorization:leaseTime:withReply:)): CommandInfo(
				authRightName: "com.aldunelabs.caker.authorization.set-dhcp-lease",
				authRightDefault: authRightDefault,
				authRightDescription: NSLocalizedString(
					"Helper is trying to set global dhcp lease time for DHCP server.",
					comment: "prompt shown when user is required to authorize to set global dhcp lease time for DHCP server"
				)
			),
			#selector(AuthorizationHelperProtocol.imdsRedirect(authorization:externalAddress:internalAddress:internalPort:install:withReply:)): CommandInfo(
				authRightName: "com.aldunelabs.caker.authorization.imds-redirect",
				authRightDefault: authRightDefault,
				authRightDescription: NSLocalizedString(
					"Helper is trying to install or remove imds redirect.",
					comment: "prompt shown when user is required to authorize to install or remove imds redirect"
				)
			),
			#selector(AuthorizationHelperProtocol.importVirtualMachine(authorization:cakeHome:arguments:withReply:)): CommandInfo(
				authRightName: "com.aldunelabs.caker.authorization.import-virtual-machine",
				authRightDefault: authRightDefault,
				authRightDescription: NSLocalizedString(
					"Helper is trying to import external virtual machine.",
					comment: "prompt shown when user is required to authorize to import external virtual machine"
				)
			),
			#selector(AuthorizationHelperProtocol.installPriviligedFiles(authorization:cakerPath:withReply:)): CommandInfo(
				authRightName: "com.aldunelabs.caker.authorization.install-priviliged-files",
				authRightDefault: authRightDefault,
				authRightDescription: NSLocalizedString(
					"Helper is trying to install some priviliged files.",
					comment: "prompt shown when user is required to authorize to install some priviliged files"
				)
			),
		]

		#if !APPSTORE
			commandInfo[#selector(AuthorizationHelperProtocol.runNetwork(authorization:cakeHome:arguments:fileHandle:withReply:))] = CommandInfo(
				authRightName: "com.aldunelabs.caker.authorization.run-network",
				authRightDefault: authRightDefault,
				authRightDescription: NSLocalizedString(
					"Helper is trying to run a network on a file descriptor.",
					comment: "prompt shown when user is required to authorize to run a network on a file descriptor"
				)
			)
		#endif

		#if APPSTORE && USE_AUTHORIZATION_HELPER
			let appStore: [Selector: CommandInfo] = [
				#selector(AuthorizationHelperProtocol.getSerialization(authorization:cakeHome:networkName:withReply:)): CommandInfo(
					authRightName: "com.aldunelabs.caker.authorization.get-serialization-network",
					authRightDefault: authRightDefault,
					authRightDescription: NSLocalizedString(
						"Helper is trying to get serialization network.",
						comment: "prompt shown when user is required to get serialization network"
					)
				),
				#selector(AuthorizationHelperProtocol.createNetwork(authorization:cakeHome:networkName:options:withReply:)): CommandInfo(
					authRightName: "com.aldunelabs.caker.authorization.create-network",
					authRightDefault: authRightDefault,
					authRightDescription: NSLocalizedString(
						"Helper is trying to create named network.",
						comment: "prompt shown when user is required to create named network"
					)
				),
				#selector(AuthorizationHelperProtocol.configureNetwork(authorization:cakeHome:networkName:options:withReply:)): CommandInfo(
					authRightName: "com.aldunelabs.caker.authorization.configure-network",
					authRightDefault: authRightDefault,
					authRightDescription: NSLocalizedString(
						"Helper is trying to configure named network.",
						comment: "prompt shown when user is required to configure named network"
					)
				),
				#selector(AuthorizationHelperProtocol.stopNetwork(authorization:cakeHome:networkName:withReply:)): CommandInfo(
					authRightName: "com.aldunelabs.caker.authorization.stop-network",
					authRightDefault: authRightDefault,
					authRightDescription: NSLocalizedString(
						"Helper is trying to stop named network with DHCP server.",
						comment: "prompt shown when user is required to authorize to stop vmnet network with DHCP server"
					)
				),
				#selector(AuthorizationHelperProtocol.deleteNetwork(authorization:cakeHome:networkName:withReply:)): CommandInfo(
					authRightName: "com.aldunelabs.caker.authorization.delete-network",
					authRightDefault: authRightDefault,
					authRightDescription: NSLocalizedString(
						"Helper is trying to delete named network with DHCP server.",
						comment: "prompt shown when user is required to authorize to delete vmnet network with DHCP server"
					)
				),
				#selector(AuthorizationHelperProtocol.listNetwork(authorization:cakeHome:withReply:)): CommandInfo(
					authRightName: "com.aldunelabs.caker.authorization.list-network",
					authRightDefault: authRightDefault,
					authRightDescription: NSLocalizedString(
						"Helper is trying to list network with DHCP server.",
						comment: "prompt shown when user is required to authorize to list network"
					)
				),
				#selector(AuthorizationHelperProtocol.infosNetwork(authorization:cakeHome:networkName:withReply:)): CommandInfo(
					authRightName: "com.aldunelabs.caker.authorization.infos-network",
					authRightDefault: authRightDefault,
					authRightDescription: NSLocalizedString(
						"Helper is trying to get infos for named network.",
						comment: "prompt shown when user is required to authorize to get infos for named network"
					)
				),
				#selector(AuthorizationHelperProtocol.getSharedNetworks(authorization:cakeHome:withReply:)): CommandInfo(
					authRightName: "com.aldunelabs.caker.authorization.get-shared-networks",
					authRightDefault: authRightDefault,
					authRightDescription: NSLocalizedString(
						"Helper is trying to read the shared networks configuration.",
						comment: "prompt shown when user is required to authorize to read the shared networks configuration"
					)
				),
				#selector(AuthorizationHelperProtocol.setSharedNetworks(authorization:cakeHome:configuration:withReply:)): CommandInfo(
					authRightName: "com.aldunelabs.caker.authorization.set-shared-networks",
					authRightDefault: authRightDefault,
					authRightDescription: NSLocalizedString(
						"Helper is trying to store the shared networks configuration.",
						comment: "prompt shown when user is required to authorize to store the shared networks configuration"
					)
				),
				#selector(AuthorizationHelperProtocol.restartNetwork(authorization:cakeHome:networkName:withReply:)): CommandInfo(
					authRightName: "com.aldunelabs.caker.authorization.restart-network",
					authRightDefault: authRightDefault,
					authRightDescription: NSLocalizedString(
						"Helper is trying to restart named network with DHCP server.",
						comment: "prompt shown when user is required to authorize to restart vmnet network with DHCP server"
					)
				),
			]

			commandInfo.merge(appStore) { current, _ in current }
		#endif

		return commandInfo
	}()

	/// The XPC interface both ends use. `options: [String: Any]` of `createNetwork`/`configureNetwork` is a collection: NSXPCConnection
	/// refuses to decode what it holds unless the classes allowed inside it are listed, so each end builds its interface here.
	public static func makeInterface() -> NSXPCInterface {
		let interface = NSXPCInterface(with: AuthorizationHelperProtocol.self)

		// Only the sandboxed build has the operations that take options.
		#if APPSTORE && USE_AUTHORIZATION_HELPER
			let optionClasses = NSSet(array: [NSDictionary.self, NSString.self, NSNumber.self]) as! Set<AnyHashable>

			// Argument 3 (counting from 0, the reply block excluded) is `options`.
			for selector in [
				#selector(AuthorizationHelperProtocol.createNetwork(authorization:cakeHome:networkName:options:withReply:)),
				#selector(AuthorizationHelperProtocol.configureNetwork(authorization:cakeHome:networkName:options:withReply:)),
			] {
				interface.setClasses(optionClasses, for: selector, argumentIndex: 3, ofReply: false)
			}
		#endif

		return interface
	}

	/// For a given command selector, returns the associated authorization right name.
	public static func authorizationRight(for command: Selector) -> String? {
		commandInfo[command]?.authRightName
	}

	/// Sets up the default authorization rights in the authorization database.
	public static func setupAuthorizationRights(_ authRef: AuthorizationRef) {
		#if !APPSTORE
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
		#endif
	}
}
