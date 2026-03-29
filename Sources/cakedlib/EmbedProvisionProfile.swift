//
//  MobileProvision.swift
//  Fluux.io
//
//  Created by Mickaël Rémond on 03/11/2018.
//  Copyright © 2018 ProcessOne.
//  Distributed under Apache License v2
//

import Foundation
import CakeAgentLib

/* Decode mobileprovision plist file

 Usage:

 1. To get mobileprovision data as embedded in your app:

 EmbedProvisionProfile.read()

 2. To get mobile provision data from a file on disk:

 EmbedProvisionProfile.read(from: "my.mobileprovision")

 */

public struct EmbedProvisionProfile: Decodable {
	public var name: String
	public var appIDName: String
	public var platform: [String]
	public var isXcodeManaged: Bool? = false
	public var creationDate: Date
	public var expirationDate: Date
	public var entitlements: Entitlements

	private enum CodingKeys: String, CodingKey {
		case name = "Name"
		case appIDName = "AppIDName"
		case platform = "Platform"
		case isXcodeManaged = "IsXcodeManaged"
		case creationDate = "CreationDate"
		case expirationDate = "ExpirationDate"
		case entitlements = "Entitlements"
	}

	// Sublevel: decode entitlements informations
	public struct Entitlements: Decodable {
		public let keychainAccessGroups: [String]
		public let getTaskAllow: Bool
		public let apsEnvironment: Environment
		public let vmNetworking: Bool
		public let securityVirtualization: Bool

		private enum CodingKeys: String, CodingKey {
			case keychainAccessGroups = "keychain-access-groups"
			case getTaskAllow = "get-task-allow"
			case apsEnvironment = "aps-environment"
			case vmNetworking = "com.apple.vm.networking"
			case securityVirtualization = "com.apple.security.virtualization"
		}

		public enum Environment: String, Decodable {
			case development, production, disabled
		}

		public init(keychainAccessGroups: [String], getTaskAllow: Bool, apsEnvironment: Environment, vmNetworking: Bool, securityVirtualization: Bool) {
			self.keychainAccessGroups = keychainAccessGroups
			self.getTaskAllow = getTaskAllow
			self.apsEnvironment = apsEnvironment
			self.vmNetworking = vmNetworking
			self.securityVirtualization = securityVirtualization
		}

		public init(from decoder: Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)

			let keychainAccessGroups = try container.decodeIfPresent([String].self, forKey: .keychainAccessGroups)
			let getTaskAllow = try container.decodeIfPresent(Bool.self, forKey: .getTaskAllow)
			let apsEnvironment = try container.decodeIfPresent(Environment.self, forKey: .apsEnvironment)
			let vmNetworking = try container.decodeIfPresent(Bool.self, forKey: .vmNetworking)
			let securityVirtualization = try container.decodeIfPresent(Bool.self, forKey: .securityVirtualization)

			self.init(keychainAccessGroups: keychainAccessGroups ?? [], getTaskAllow: getTaskAllow ?? false, apsEnvironment: apsEnvironment ?? .disabled, vmNetworking: vmNetworking ?? false, securityVirtualization: securityVirtualization ?? false)
		}
	}
}

// Factory methods
extension EmbedProvisionProfile {
	// Read mobileprovision file embedded in app.
	public static func load() throws -> EmbedProvisionProfile? {
		let mainBundle = Bundle.main

		guard let path = mainBundle.url(forResource: "embedded", withExtension: "provisionprofile") else {
			if mainBundle.bundlePath.hasSuffix("PlugIns") {
				let local = mainBundle.bundleURL.appendingPathComponent("../embedded.provisionprofile").absoluteURL
				
				if FileManager.default.fileExists(atPath: local.path) {
					return try load(local)
				}
			} else {
				let local = mainBundle.bundleURL.appendingPathComponent("Contents").appendingPathComponent("embedded.provisionprofile")
				
				if FileManager.default.fileExists(atPath: local.path) {
					return try load(local)
				}
			}

			return nil
		}

		return try load(path)
	}

	// Read a .mobileprovision file on disk
	public static func load(_ profilePath: URL) throws -> EmbedProvisionProfile? {
		guard let plistDataString = String(data: try Data(contentsOf: profilePath), encoding: .isoLatin1) else {
			return nil
		}

		// Skip binary part at the start of the mobile provisionning profile
		let scanner = Scanner(string: plistDataString)
		guard scanner.scanUpToString("<plist") != nil else {
			return nil
		}

		// ... and extract plist until end of plist payload (skip the end binary part.
		guard let extractedPlist = scanner.scanUpToString("</plist>") else { return nil }

		guard let plist = extractedPlist.appending("</plist>").data(using: .isoLatin1) else { return nil }
		let decoder = PropertyListDecoder()

		do {
			return try decoder.decode(EmbedProvisionProfile.self, from: plist)
		} catch {
			Logger(self).error("unable to decode provision profile: \(error)")
			return nil
		}
	}
}

