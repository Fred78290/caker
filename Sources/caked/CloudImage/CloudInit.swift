import Foundation
import ISO9660
import Virtualization
import Yams
import GRPCLib
import Gzip

let CAKEAGENT_SNAPSHOT = "20b4fb45"

let emptyCloudInit = "#cloud-config\n{}".data(using: .ascii)!

extension Dictionary {
	init(contentsOf: URL) throws {
		self = try JSONSerialization.jsonObject(with: try Data(contentsOf: contentsOf), options: []) as! Dictionary
	}

	var jsonData: Data? {
		return try? JSONSerialization.data(withJSONObject: self, options: [.prettyPrinted])
	}

	func toJSONString() -> String? {
		if let jsonData: Data = jsonData {
			let jsonString = String(data: jsonData, encoding: .utf8)
			return jsonString
		}

		return nil
	}

	func write(to: URL) throws {
		guard let jsonData = self.jsonData else {
			throw ServiceError("Can't get data")
		}

		try jsonData.write(to: to)
	}
}

struct Compression {
	static func compress(_ data: Data) throws -> Data {
		return try (data as NSData).compressed(using: .zlib) as Data
	}

	static func compressEncoded(_ data: Data) throws -> String {
		let data = try data.gzipped()

		return data.base64EncodedString()
	}

	static func compressEncoded(contentOf: URL) throws -> String {
		try Self.compressEncoded(try Data(contentsOf: contentOf))
	}

	static func decompress(_ data: Data) throws -> Data {
		return try (data as NSData).decompressed(using: .zlib) as Data
	}
}

func newYAMLEncoder() -> YAMLEncoder {
	let encoder: YAMLEncoder = YAMLEncoder()

	encoder.options = .init(indent: 2, width: -1, sortKeys: true)
	return encoder
}

struct NetworkConfig: Codable {
	var network: CloudInitNetwork = CloudInitNetwork()

	init(config: CakeConfig) {
		let networks = config.qualifiedNetworks

		var index: Int = 1

		networks.forEach { network in
			let name = "enp0s\(index)"

			index += 1

			if network.network == "nat" {
				if let macAddress = config.macAddress {
					self.network.ethernets[name] = Interface(match: Match(macAddress: macAddress.string), setName: name, dhcp4: true, dhcp6: true, dhcpIdentifier: "mac")
				} else {
					self.network.ethernets[name] = Interface(match: Match(macAddress: network.macAddress), setName: name, dhcp4: true, dhcp6: true, dhcpIdentifier: "mac")
				}
			} else if network.mode == nil || network.mode == .auto {
				self.network.ethernets[name] = Interface(match: Match(macAddress: network.macAddress), setName: name, dhcp4: true, dhcp6: true, dhcpIdentifier: "mac", dhcp4Overrides: .init(routeMetric: 200), dhcp6Overrides: .init(routeMetric: 200))
			}
		}
	}

	func toCloudInit() throws -> Data {
		let encoder: YAMLEncoder = newYAMLEncoder()
		let encoded: String = try encoder.encode(self)

		guard let result = "#cloud-config\n\(encoded)".data(using: .ascii) else {
			throw CloudInitGenerateError("Failed to encode networkConfig")
		}

		return result
	}
}

typealias Ethernets = [String: Interface]

struct CloudInitNetwork: Codable {
	var version: Int = 2
	var ethernets: Ethernets = [:]

	func encode(to encoder: Encoder) throws {
		var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)

		try container.encodeIfPresent(version, forKey: .version)
		try container.encodeIfPresent(ethernets, forKey: .ethernets)
	}
}


struct DHCPOverides: Codable {
	var routeMetric: Int = 200

	enum CodingKeys: String, CodingKey {
		case routeMetric = "route-metric"
	}
}

struct Interface: Codable {
	var match: Match? = nil
	var setName: String? = nil
	var dhcp4: Bool? = nil
	var dhcp6: Bool? = nil
	var dhcpIdentifier: String? = nil
	var dhcp4Overrides: DHCPOverides? = nil
	var dhcp6Overrides: DHCPOverides? = nil

	enum CodingKeys: String, CodingKey {
		case match = "match"
		case setName = "set-name"
		case dhcp4 = "dhcp4"
		case dhcp6 = "dhcp6"
		case dhcpIdentifier = "dhcp-identifier"
		case dhcp4Overrides = "dhcp4-overrides"
		case dhcp6Overrides = "dhcp6-overrides"
	}

	func encode(to encoder: Encoder) throws {
		var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)

		try container.encodeIfPresent(match, forKey: .match)
		try container.encodeIfPresent(setName, forKey: .setName)
		try container.encodeIfPresent(dhcp4, forKey: .dhcp4)
		try container.encodeIfPresent(dhcp6, forKey: .dhcp6)
		try container.encodeIfPresent(dhcpIdentifier, forKey: .dhcpIdentifier)
		try container.encodeIfPresent(dhcp4Overrides, forKey: .dhcp4Overrides)
		try container.encodeIfPresent(dhcp6Overrides, forKey: .dhcp6Overrides)
	}
}

struct Match: Codable {
	var name: String? = nil
	var macAddress: String? = nil

	func encode(to encoder: Encoder) throws {
		var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)

		try container.encodeIfPresent(name, forKey: .name)
		try container.encodeIfPresent(macAddress, forKey: .macAddress)
	}

	enum CodingKeys: String, CodingKey {
		case name = "name"
		case macAddress = "macaddress"
	}
}

struct Merging: Codable {
	var name: String
	var settings: [String]
}

struct CloudConfigData: Codable {
	var merge: [Merging]? = nil
	var packageUpdate: Bool = false
	var packageUpgrade = false
	var growpart: Growpart? = Growpart()
	var manageEtcHosts: Bool?
	var packages: [String]?
	var sshAuthorizedKeys: [String]?
	var sshPwAuth: Bool?
	var systemInfo: SystemInfo?
	var timezone: String?
	var users: [User]?
	var writeFiles: [WriteFile]?
	var runcmd: [String]?

	enum CodingKeys: String, CodingKey {
		case merge = "merge_how"
		case packageUpdate = "package_update"
		case packageUpgrade = "package_upgrade"
		case growpart = "growpart"
		case manageEtcHosts = "manage_etc_hosts"
		case packages = "packages"
		case sshAuthorizedKeys = "ssh_authorized_keys"
		case sshPwAuth = "ssh_pwauth"
		case systemInfo = "system_info"
		case timezone = "timezone"
		case users = "users"
		case writeFiles = "write_files"
		case runcmd = "runcmd"
	}

	init(defaultUser: String = "admin",
	     password: String? = nil,
	     mainGroup: String = "adm",
	     clearPassword: Bool = false,
	     sshAuthorizedKeys: [String]? = nil,
	     tz: String = "UTC",
	     packages: [String]?,
	     writeFiles: [WriteFile]? = nil,
	     runcmd: [String]? = nil,
	     growPart: Bool = true,
	     merge: [Merging]? = nil) {

		self.merge = merge
		self.manageEtcHosts = true
		self.packages = packages
		//self.sshAuthorizedKeys = sshAuthorizedKeys
		self.sshPwAuth = clearPassword
		//self.systemInfo = SystemInfo(defaultUser: defaultUser)
		self.timezone = tz
		self.writeFiles = writeFiles
		self.runcmd = runcmd
		self.users = [User.userClass(UserClass(name: defaultUser,
		                                       password: password,
		                                       lockPasswd: password == nil,
		                                       shell: "/bin/bash",
		                                       sshAuthorizedKeys: sshAuthorizedKeys,
		                                       primaryGroup: mainGroup,
		                                       groups: nil,
		                                       sudo: true))]

		if growPart {
			self.growpart = Growpart()
		}
	}

	init(from decoder: Decoder) throws {
		let container: KeyedDecodingContainer<CloudConfigData.CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)

		self.merge = try container.decodeIfPresent([Merging].self, forKey: .merge)
		self.growpart = try container.decodeIfPresent(Growpart.self, forKey: .growpart)
		self.users = try container.decodeIfPresent([User].self, forKey: .users)
		self.manageEtcHosts = try container.decodeIfPresent(Bool.self, forKey: .manageEtcHosts)
		self.sshPwAuth = try container.decodeIfPresent(Bool.self, forKey: .sshPwAuth)
		self.sshAuthorizedKeys = try container.decodeIfPresent([String].self, forKey: .sshAuthorizedKeys)
		self.timezone = try container.decodeIfPresent(String.self, forKey: .timezone)
		self.systemInfo = try container.decodeIfPresent(SystemInfo.self, forKey: .systemInfo)
		self.packages = try container.decodeIfPresent([String].self, forKey: .packages)
		self.writeFiles = try container.decodeIfPresent([WriteFile].self, forKey: .writeFiles)
		self.runcmd = try container.decodeIfPresent([String].self, forKey: .runcmd)
	}

	func encode(to encoder: Encoder) throws {
		var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)

		try container.encodeIfPresent(merge, forKey: .merge)
		try container.encodeIfPresent(growpart, forKey: .growpart)
		try container.encodeIfPresent(users, forKey: .users)
		try container.encodeIfPresent(manageEtcHosts, forKey: .manageEtcHosts)
		try container.encodeIfPresent(sshAuthorizedKeys, forKey: .sshAuthorizedKeys)
		try container.encodeIfPresent(sshPwAuth, forKey: .sshPwAuth)
		try container.encodeIfPresent(timezone, forKey: .timezone)
		try container.encodeIfPresent(systemInfo, forKey: .systemInfo)
		try container.encodeIfPresent(packages, forKey: .packages)
		try container.encodeIfPresent(writeFiles, forKey: .writeFiles)
		try container.encodeIfPresent(runcmd, forKey: .runcmd)
	}

	func toCloudInit(_ encodedPart1: Data? = nil) throws -> Data {
		let encoder: YAMLEncoder = newYAMLEncoder()
		let encoded: String

		if let encodedPart1 = encodedPart1 {
			guard let encodedPart2 = try encoder.encode(self).data(using: .ascii) else {
				throw CloudInitGenerateError("Failed to encode userData")
			}

			encoded =
				"""
				Content-Type: multipart/mixed; boundary="===============2389165605550749110=="
				MIME-Version: 1.0
				Number-Attachments: 2

				--===============2389165605550749110==
				Content-Type: text/cloud-config; charset="utf-8"
				MIME-Version: 1.0
				Content-Transfer-Encoding: base64
				Content-Disposition: attachment; filename="user-data"


				"""

				+ encodedPart1.base64EncodedString(options: .lineLength76Characters) +

				"""


				--===============2389165605550749110==
				Content-Type: text/cloud-config; charset="utf-8"
				MIME-Version: 1.0
				Content-Transfer-Encoding: base64
				Content-Disposition: attachment; filename="vendor-data"


				"""
				+ encodedPart2.base64EncodedString(options: .lineLength76Characters) +

				"""


				--===============2389165605550749110==--
				"""
		} else {
			encoded = "#cloud-config\n\(try encoder.encode(self))"
		}

		guard let result = encoded.data(using: .ascii) else {
			throw CloudInitGenerateError("Failed to encode vendorData")
		}

		return result
	}
}

struct Growpart: Codable {
	var mode: String = "auto"
	var devices: [String] = ["/"]
	var ignoreGrowrootDisabled: Bool = false

	enum CodingKeys: String, CodingKey {
		case ignoreGrowrootDisabled = "ignore_growroot_disabled"
		case mode = "mode"
		case devices = "devices"
	}
}

struct SystemInfo: Codable {
	var defaultUser: DefaultUser?

	init(defaultUser: String) {
		self.defaultUser = DefaultUser(name: defaultUser)
	}

	enum CodingKeys: String, CodingKey {
		case defaultUser = "default_user"
	}
}

struct DefaultUser: Codable {
	var name: String = "admin"
}

struct WriteFile: Codable {
	var path: String
	var content: String
	var encoding: String?
	var permissions: String?
	var owner: String?

	init(path: String,  content: String, encoding: String? = nil, permissions: String? = nil, owner: String? = "root:adm") {
		self.path = path
		self.content = content
		self.encoding = encoding
		self.permissions = permissions
		self.owner = owner
	}

	init(from decoder: Decoder) throws {
		let container: KeyedDecodingContainer<WriteFile.CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)

		self.path = try container.decode(String.self, forKey: .path)
		self.content = try container.decode(String.self, forKey: .content)
		self.encoding = try container.decodeIfPresent(String.self, forKey: .encoding)
		self.permissions = try container.decodeIfPresent(String.self, forKey: .permissions)
		self.owner = try container.decodeIfPresent(String.self, forKey: .owner)
	}

	func encode(to encoder: Encoder) throws {
		var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)

		try container.encode(path, forKey: .path)
		try container.encode(content, forKey: .content)
		try container.encodeIfPresent(encoding, forKey: .encoding)
		try container.encodeIfPresent(permissions, forKey: .permissions)
		try container.encodeIfPresent(owner, forKey: .owner)
	}

	enum CodingKeys: String, CodingKey {
		case path = "path"
		case content = "content"
		case encoding = "encoding"
		case permissions = "permissions"
		case owner = "owner"
	}
}

enum User: Codable {
	case string(String)
	case userClass(UserClass)

	func encode(to encoder: Encoder) throws {
		switch self {
		case .string(let userName):
			try userName.encode(to: encoder)
		case .userClass(let userClass):
			try userClass.encode(to: encoder)
		}
	}
}

struct UserClass: Codable {
	var expiredate: String?
	var gecos: String?
	var groups: String?
	var inactive: String?
	var lockPasswd: Bool?
	var name: String?
	var passwd: String?
	var plainTextPasswd: String?
	var primaryGroup: String?
	var selinuxUser: String?
	var shell: String?
	var snapuser: String?
	var sshAuthorizedKeys: [String]?
	var sshImportID: [String]?
	var sshRedirectUser: Bool?
	var sudo: Sudo?
	var system: Bool?

	enum CodingKeys: String, CodingKey {
		case expiredate
		case gecos 
		case groups
		case inactive
		case lockPasswd = "lock_passwd"
		case name
		case passwd
		case plainTextPasswd = "plain_text_passwd"
		case primaryGroup = "primary_group"
		case selinuxUser = "selinux_user"
		case shell
		case snapuser
		case sshAuthorizedKeys  = "ssh_authorized_keys"
		case sshImportID = "ssh_import_id"
		case sshRedirectUser = "ssh_redirect_user"
		case sudo
		case system
	}

	init(name: String,
	     password: String?,
	     lockPasswd: Bool?,
	     shell :String?,
	     sshAuthorizedKeys: [String]?,
	     primaryGroup: String?,
	     groups: [String]?,
	     sudo: Bool?) {
		self.name = name
		self.shell = shell
		self.plainTextPasswd = password
		self.primaryGroup = primaryGroup
		self.groups = groups?.joined(separator: ",")
		self.sshAuthorizedKeys = sshAuthorizedKeys
		self.lockPasswd = lockPasswd

		if let sudo = sudo {
			if sudo {
				self.sudo = Sudo.string("ALL=(ALL) NOPASSWD:ALL")
			}
		}
	}

	init(from decoder: Decoder) throws {
		let container: KeyedDecodingContainer<UserClass.CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)

		self.name = try container.decodeIfPresent(String.self, forKey: .name)
		self.expiredate = try container.decodeIfPresent(String.self, forKey: .expiredate)
		self.gecos = try container.decodeIfPresent(String.self, forKey: .gecos)
		self.groups = try container.decodeIfPresent(String.self, forKey: .groups)
		self.inactive = try container.decodeIfPresent(String.self, forKey: .inactive)
		self.lockPasswd = try container.decodeIfPresent(Bool.self, forKey: .lockPasswd)
		self.passwd = try container.decodeIfPresent(String.self, forKey: .passwd)
		self.plainTextPasswd = try container.decodeIfPresent(String.self, forKey: .plainTextPasswd)
		self.primaryGroup = try container.decodeIfPresent(String.self, forKey: .primaryGroup)
		self.selinuxUser = try container.decodeIfPresent(String.self, forKey: .selinuxUser)
		self.shell = try container.decodeIfPresent(String.self, forKey: .shell)
		self.snapuser = try container.decodeIfPresent(String.self, forKey: .snapuser)
		self.sshAuthorizedKeys = try container.decodeIfPresent([String].self, forKey: .sshAuthorizedKeys)
		self.sshImportID = try container.decodeIfPresent([String].self, forKey: .sshImportID)
		self.sshRedirectUser = try container.decodeIfPresent(Bool.self, forKey: .sshRedirectUser)
		self.sudo = try container.decodeIfPresent(Sudo.self, forKey: .sudo)
		self.system = try container.decodeIfPresent(Bool.self, forKey: .system)
	}

	func encode(to encoder: Encoder) throws {
		var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)

		try container.encodeIfPresent(name, forKey: .name)
		try container.encodeIfPresent(expiredate, forKey: .expiredate)
		try container.encodeIfPresent(gecos, forKey: .gecos)
		try container.encodeIfPresent(groups, forKey: .groups)
		try container.encodeIfPresent(inactive, forKey: .inactive)
		try container.encodeIfPresent(lockPasswd, forKey: .lockPasswd)
		try container.encodeIfPresent(passwd, forKey: .passwd)
		try container.encodeIfPresent(plainTextPasswd, forKey: .plainTextPasswd)
		try container.encodeIfPresent(primaryGroup, forKey: .primaryGroup)
		try container.encodeIfPresent(selinuxUser, forKey: .selinuxUser)
		try container.encodeIfPresent(shell, forKey: .shell)
		try container.encodeIfPresent(snapuser, forKey: .snapuser)
		try container.encodeIfPresent(sshAuthorizedKeys, forKey: .sshAuthorizedKeys)
		try container.encodeIfPresent(sshImportID, forKey: .sshImportID)
		try container.encodeIfPresent(sshRedirectUser, forKey: .sshRedirectUser)
		try container.encodeIfPresent(sudo, forKey: .sudo)
		try container.encodeIfPresent(system, forKey: .system)
	}
}

enum Sudo: Codable {
	case bool(Bool)
	case string(String)

	func encode(to encoder: Encoder) throws {
		switch self {
		case .bool(let bool):
			try bool.encode(to: encoder)
		case .string(let string):
			try string.encode(to: encoder)
		}
	}
}

class CloudInit {
	var userData: Data?
	var vendorData: Data?
	var networkConfig: Data?
	var userName: String = "admin"
	var password: String? = nil
	var mainGroup: String = "admin"
	var sshAuthorizedKeys: [String]?
	var clearPassword: Bool = false
	var asSystem: Bool = false

	private static func loadPublicKey(sshAuthorizedKey: String) throws -> String {
		let datas: Data = try Data(contentsOf: URL(fileURLWithPath: sshAuthorizedKey))

		if let publicKey = String(data: datas, encoding: .ascii) {
			return publicKey.trimmingCharacters(in: .whitespacesAndNewlines)
		}

		throw CypherKeyGeneratorError("unable to decode public key")
	}

	public static func sshAuthorizedKeys(sshAuthorizedKeyPath: String?, asSystem: Bool) throws -> [String] {
		let home: Home = try Home(asSystem: asSystem)
		let sharedPublicKey = try home.getSharedPublicKey()

		if var sshAuthorizedKey = sshAuthorizedKeyPath {
			sshAuthorizedKey = try loadPublicKey(sshAuthorizedKey: sshAuthorizedKey)
			return [sharedPublicKey, sshAuthorizedKey]
		} else {
			return [sharedPublicKey]
		}
	}

	init(userName: String, password: String?, mainGroup: String, clearPassword: Bool, sshAuthorizedKey: [String]?, vendorData: Data?, userData:Data?, networkConfig: Data?, asSystem: Bool) throws {
		self.userName = userName
		self.password = password
		self.mainGroup = mainGroup
		self.clearPassword = clearPassword
		self.sshAuthorizedKeys = sshAuthorizedKey
		self.userData = userData
		self.vendorData = vendorData
		self.networkConfig = networkConfig
		self.asSystem = asSystem
	}

	convenience init(userName: String, password: String?, mainGroup: String, clearPassword: Bool, sshAuthorizedKeyPath: String?, vendorDataPath: String?, userDataPath: String?, networkConfigPath: String?, asSystem: Bool) throws {
		try self.init(userName: userName,
		              password: password,
		              mainGroup: mainGroup,
		              clearPassword: clearPassword,
		              sshAuthorizedKey: try Self.sshAuthorizedKeys(sshAuthorizedKeyPath: sshAuthorizedKeyPath, asSystem: asSystem),
		              vendorData: vendorDataPath != nil ? try Data(contentsOf: URL(fileURLWithPath: vendorDataPath!)) : nil,
		              userData:userDataPath != nil ? try Data(contentsOf: URL(fileURLWithPath: userDataPath!)) : nil,
		              networkConfig: networkConfigPath != nil ? try Data(contentsOf: URL(fileURLWithPath: networkConfigPath!)) : nil, asSystem: asSystem)
	}

	private func createMetaData(hostname: String, instanceID: String) throws -> Data {
		guard let metadata = "instance-id: \(instanceID)\nlocal-hostname: \(hostname)\n".data(using: .ascii) else {
			throw CloudInitGenerateError("unable to encode metada")
		}

		return metadata
	}

	private func cakeagentBinary(config: CakeConfig, asSystem: Bool) throws -> URL {
		let arch = Architecture.current().rawValue
		let os = config.os.rawValue
		let home: Home = try Home(asSystem: asSystem)
		let localAgent = home.agentDirectory.appendingPathComponent("cakeagent-\(CAKEAGENT_SNAPSHOT)-\(os)-\(arch)", isDirectory: false)

		if FileManager.default.fileExists(atPath: localAgent.path) == false {
			guard let remoteURL = URL(string: "https://github.com/Fred78290/cakeagent/releases/download/SNAPSHOT-\(CAKEAGENT_SNAPSHOT)/cakeagent-\(os)-\(arch)") else {
				throw CloudInitGenerateError("unable to get remote cakeagent")
			}

			let data = try Data(contentsOf: remoteURL)
			try data.write(to: localAgent)
		}

		return localAgent
	}

	private func installCakeAgentScript(config: CakeConfig) -> String {
		let install_cakeagent: String =
			"""
			#!/bin/sh
			CIDATA=$(blkid -L CIDATA || :)
			if [ -n \"$CIDATA\" ]; then
				MOUNT=$(mktemp -d)
				mount -L CIDATA $MOUNT || exit 1
				cp $MOUNT/cakeagent /usr/local/bin/cakeagent
				umount $MOUNT
				chmod +x /usr/local/bin/cakeagent
				/usr/local/bin/cakeagent --install \\
					--listen=vsock://any:5000 \\
					--ca-cert=/etc/cakeagent/ssl/ca.pem \\
					--tls-cert=/etc/cakeagent/ssl/server.pem \\
					--tls-key=/etc/cakeagent/ssl/server.key \(config.linuxMounts)
			else
			  echo \"CIDATA not found\"
			  exit 1
			fi
			"""

		return install_cakeagent.data(using: .ascii)?.base64EncodedString() ?? ""
	}

	private func buildVendorData(config: CakeConfig, asSystem: Bool) throws -> CloudConfigData {
		let installCakeagent = installCakeAgentScript(config: config)
		let certificates = try CertificatesLocation.createAgentCertificats(asSystem: self.asSystem)
		let caCert = try Compression.compressEncoded(contentOf: certificates.caCertURL)
		let serverKey = try Compression.compressEncoded(contentOf: certificates.serverKeyURL)
		let serverPem = try Compression.compressEncoded(contentOf: certificates.serverCertURL)
		let merge: [Merging] = [
			Merging(name: "list", settings: ["append", "recurse_dict", "recurse_list"]),
			Merging(name: "dict", settings: ["no_replace", "recurse_dict", "recurse_list"])
		]
		let runCommand = config.mounts.isEmpty ? ["/usr/local/bin/install-cakeagent.sh" ] : ["/usr/local/bin/install-cakeagent.sh"]
		let vendorData = CloudConfigData(defaultUser: self.userName,
		                                 password: self.password,
		                                 mainGroup: self.mainGroup,
		                                 clearPassword: self.clearPassword,
		                                 sshAuthorizedKeys: sshAuthorizedKeys,
		                                 tz: TimeZone.current.identifier,
		                                 packages: nil,
		                                 writeFiles: [
		                                 	WriteFile(path: "/usr/local/bin/install-cakeagent.sh", content: installCakeagent, encoding: "base64", permissions: "0755"),
		                                 	WriteFile(path: "/etc/cloud/cloud.cfg.d/100_datasources.cfg", content: "datasource_list: [ NoCloud, None ]"),
		                                 	WriteFile(path: "/etc/cakeagent/ssl/server.key", content: serverKey, encoding: "gzip+base64", permissions: "0600"),
		                                 	WriteFile(path: "/etc/cakeagent/ssl/server.pem", content: serverPem, encoding: "gzip+base64", permissions: "0600"),
		                                 	WriteFile(path: "/etc/cakeagent/ssl/ca.pem", content: caCert, encoding: "gzip+base64", permissions: "0600"),
		                                 ],
		                                 runcmd: runCommand,
		                                 growPart: true,
		                                 merge: merge)

		return vendorData
	}

	private func buildConfigData(_ userData: Data) throws -> Data {
		guard var cloudConfigHeader: Data = "#cloud-config\n".data(using: .ascii) else {
			throw CloudInitGenerateError("unable to encode buildConfigData")
		}

		cloudConfigHeader.append(userData)

		return cloudConfigHeader
	}

	private func createUserData(config: CakeConfig) throws -> Data {
		if let userData = self.userData {
			return try buildVendorData(config: config, asSystem: self.asSystem).toCloudInit(userData)
		} else {
			guard let userData: Data = "#cloud-config\n{}".data(using: .ascii) else {
				throw CloudInitGenerateError("unable to encode userdata")
			}

			return userData
		}
	}

	private func createVendorData(config: CakeConfig) throws -> Data {
		guard let vendorData = self.vendorData else {
			if self.userData == nil {
				return try buildVendorData(config: config, asSystem: self.asSystem).toCloudInit()
			} else {
				guard let userData: Data = "#cloud-config\n{}".data(using: .ascii) else {
					throw CloudInitGenerateError("unable to encode userdata")
				}

				return userData
			}
		}

		return try buildConfigData(vendorData)
	}

	private func createSeed(writer: ISOWriter, path: String, configUrl: URL) throws -> URL {
		guard configUrl.isFileURL else {
			throw CloudInitGenerateError("configUrl is not a file URL")
		}

		let attr = try FileManager.default.attributesOfItem(atPath: configUrl.absoluteURL.path)
		let fileSize = attr[FileAttributeKey.size] as! UInt64

		try writer.addFile(path: path, size: fileSize, metadata: nil)

		return configUrl
	}

	private func createSeed(config: CakeConfig, writer: ISOWriter, path: String, configData: Data) throws -> Data {
		try writer.addFile(path: path, size: UInt64(configData.count), metadata: nil)
		try configData.write(to: config.location.appendingPathComponent(path))

		return configData
	}

	private func createNetworkConfig(config: CakeConfig) throws -> Data {
		if let networkConfig = self.networkConfig {
			return networkConfig
		} else {
			let networkConfig: NetworkConfig = NetworkConfig(config: config)

			return try networkConfig.toCloudInit()
		}
	}

	func createDefaultCloudInit(config: CakeConfig, name: String, cdromURL: URL) throws {
		var seed: [String: Any] = [:]

		try? cdromURL.delete()

		// create media
		let media = try! ISOImageFileMedia(cdromURL, readOnly: false)
		// prepare write options
		let writeOptions = ISOWriter.WriteOptions(volumeIdentifier: "CIDATA")

		let writer: ISOWriter = ISOWriter(
			media: media, options: writeOptions, contentCallback: { (path: String) -> InputStream in
				if let data = seed[path] as? Data {
					return InputStream(data: data)
				} else if let url = seed[path] as? URL, let input = InputStream(url: url) {
					return input
				}

				return InputStream(data: emptyCloudInit)
			})

		seed["/user-data"] = try createSeed(config: config, writer: writer, path: "user-data", configData: self.createUserData(config: config))
		seed["/vendor-data"] = try createSeed(config: config, writer: writer, path: "vendor-data", configData: createVendorData(config: config))
		seed["/meta-data"] = try createSeed(config: config, writer: writer, path: "meta-data", configData: self.createMetaData(hostname: name, instanceID: config.instanceID))
		seed["/network-config"] = try createSeed(config: config, writer: writer, path: "network-config", configData: createNetworkConfig(config: config))
		seed["/cakeagent"] = try createSeed(writer: writer, path: "cakeagent", configUrl: try cakeagentBinary(config: config, asSystem: self.asSystem))

		// write
		try writer.writeAndClose()
	}
}
