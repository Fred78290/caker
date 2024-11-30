import Foundation
import ISO9660
import Virtualization
import Yams

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

struct NetworkConfig: Codable {
	var network: CloudInitNetwork = CloudInitNetwork()

	func toCloudInit() throws -> Data {
		let encoder: YAMLEncoder = YAMLEncoder()
		let encoded: String = try encoder.encode(self)

		guard let result = "#cloud-config\n\(encoded)".data(using: .ascii) else {
			throw CloudInitGenerateError("Failed to encode networkConfig")
		}

		return result
	}
}

struct CloudInitNetwork: Codable {
	var version: Int = 2
	var ethernets: Ethernets = Ethernets()
}

struct Ethernets: Codable {
	var all: All = All()
}

struct All: Codable {
	var match: Match = Match()
	var dhcp4: Bool = true
	var dhcpIdentifier: String = "mac"

	enum CodingKeys: String, CodingKey {
		case match = "match"
		case dhcp4 = "dhcp4"
		case dhcpIdentifier = "dhcp-identifier"
	}
}

struct Match: Codable {
	var name: String = "en*"
}

struct VendorData: Codable {
	var growpart: Growpart? = Growpart()
	var manageEtcHosts: Bool?
	var packages: [String]?
	var sshAuthorizedKeys: [String]?
	var sshPwAuth: Bool?
	var systemInfo: SystemInfo?
	var timezone: String?
	var users: [User]?
	var writeFiles: [WriteFile]?

	enum CodingKeys: String, CodingKey {
		case growpart = "growpart"
		case manageEtcHosts = "manage_etc_hosts"
		case packages = "packages"
		case sshAuthorizedKeys = "ssh_authorized_keys"
		case sshPwAuth = "ssh_pwauth"
		case systemInfo = "system_info"
		case timezone = "timezone"
		case users = "users"
		case writeFiles = "write_files"
	}

	init(defaultUser: String, mainGroup: String, clearPassword: Bool, sshAuthorizedKeys: [String]?, tz: String, packages: [String]?, writeFiles: [WriteFile]?, growPart: Bool) {
		self.manageEtcHosts = true
		self.packages = packages
		self.sshAuthorizedKeys = sshAuthorizedKeys
		self.sshPwAuth = clearPassword
		self.systemInfo = SystemInfo(defaultUser: defaultUser)
		self.timezone = tz
		self.users = [User.userClass(UserClass(name: defaultUser, password: clearPassword ? defaultUser : nil, sshAuthorizedKeys: sshAuthorizedKeys, primaryGroup: mainGroup, groups: nil, sudo: true))]
		self.writeFiles = writeFiles

		if growPart {
			self.growpart = Growpart()
		}
	}

	init(from decoder: Decoder) throws {
		let container: KeyedDecodingContainer<VendorData.CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)

		self.growpart = try container.decodeIfPresent(Growpart.self, forKey: .growpart)
		self.users = try container.decodeIfPresent([User].self, forKey: .users)
		self.manageEtcHosts = try container.decodeIfPresent(Bool.self, forKey: .manageEtcHosts)
		self.sshPwAuth = try container.decodeIfPresent(Bool.self, forKey: .sshPwAuth)
		self.sshAuthorizedKeys = try container.decodeIfPresent([String].self, forKey: .sshAuthorizedKeys)
		self.timezone = try container.decodeIfPresent(String.self, forKey: .timezone)
		self.systemInfo = try container.decodeIfPresent(SystemInfo.self, forKey: .systemInfo)
		self.packages = try container.decodeIfPresent([String].self, forKey: .packages)
		self.writeFiles = try container.decodeIfPresent([WriteFile].self, forKey: .writeFiles)
	}

	func encode(to encoder: Encoder) throws {
		var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)

		try container.encodeIfPresent(growpart, forKey: .growpart)
		try container.encodeIfPresent(users, forKey: .users)
		try container.encodeIfPresent(manageEtcHosts, forKey: .manageEtcHosts)
		try container.encodeIfPresent(sshAuthorizedKeys, forKey: .sshAuthorizedKeys)
		try container.encodeIfPresent(sshPwAuth, forKey: .sshPwAuth)
		try container.encodeIfPresent(timezone, forKey: .timezone)
		try container.encodeIfPresent(systemInfo, forKey: .systemInfo)
		try container.encodeIfPresent(packages, forKey: .packages)
		try container.encodeIfPresent(writeFiles, forKey: .writeFiles)
	}

	func toCloudInit() throws -> Data {
		let encoder: YAMLEncoder = YAMLEncoder()
		let encoded: String = try encoder.encode(self)

		guard let result = "#cloud-config\n\(encoded)".data(using: .ascii) else {
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
	var path, content: String
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

	init(name: String, password: String?, sshAuthorizedKeys: [String]?, primaryGroup: String?, groups: [String]?, sudo: Bool?) {
		self.name = name
		self.plainTextPasswd = password
		self.primaryGroup = primaryGroup
		self.groups = groups?.joined(separator: ",")
		self.sshAuthorizedKeys = sshAuthorizedKeys

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
	var mainGroup: String = "adm"
	var sshAuthorizedKeys: [String]?
	var clearPassword: Bool = false

	private static func loadSharedPublicKey(home: Home) throws -> String? {
		let publicKeyURL = URL(fileURLWithPath: "id_rsa.pub", relativeTo: home.homeDir)

		if FileManager.default.fileExists(atPath: publicKeyURL.path) {
			let content = try Data(contentsOf: publicKeyURL)

			return String(data: content, encoding: .ascii)
		} else {
			return nil
		}
	}

	private static func loadPublicKey(sshAuthorizedKey: String) throws -> String {
		let datas: Data = try Data(contentsOf: URL(fileURLWithPath: sshAuthorizedKey))

		if let publicKey = String(data: datas, encoding: .ascii) {
			return publicKey.trimmingCharacters(in: .whitespacesAndNewlines)
		}

		throw CypherKeyGeneratorError("unable to decode public key")
	}

	public static func sshAuthorizedKeys(sshAuthorizedKeyPath: String?) throws -> [String] {
		let sharedPublicKey = try createSharedSshKeys()

		if var sshAuthorizedKey = sshAuthorizedKeyPath {
			sshAuthorizedKey = try loadPublicKey(sshAuthorizedKey: sshAuthorizedKey)
			return [sharedPublicKey, sshAuthorizedKey]
		} else {
			return [sharedPublicKey]
		}
	}

	private static func createSharedSshKeys() throws -> String {
		let home: Home = try Home(asSystem: runAsSystem)

		if let key = try loadSharedPublicKey(home: home) {
			return key
		} else {
			let cypher = try CypherKeyGenerator(identifier: "com.cirruslabs.keys.ssh")
			let key = try cypher.generateKey()

			try key.save(privateURL: URL(fileURLWithPath: "id_rsa", relativeTo: home.homeDir), publicURL: URL(fileURLWithPath: "id_rsa.pub", relativeTo: home.homeDir))

			return try key.publicKeyString()
		}
	}

	init(userName: String, mainGroup: String, clearPassword: Bool, sshAuthorizedKey: [String]?, vendorData: Data?, userData:Data?, networkConfig: Data?) throws {
		self.userName = userName
		self.mainGroup = mainGroup
		self.clearPassword = clearPassword
		self.sshAuthorizedKeys = sshAuthorizedKey
		self.userData = userData
		self.vendorData = vendorData
		self.networkConfig = networkConfig
	}

	convenience init(userName: String, mainGroup: String, clearPassword: Bool, sshAuthorizedKeyPath: String?, vendorDataPath: String?, userDataPath: String?, networkConfigPath: String?) throws {
		try self.init(userName: userName,
					  mainGroup: mainGroup,
					  clearPassword: clearPassword,
					  sshAuthorizedKey: try Self.sshAuthorizedKeys(sshAuthorizedKeyPath: sshAuthorizedKeyPath),
					  vendorData: vendorDataPath != nil ? try Data(contentsOf: URL(fileURLWithPath: vendorDataPath!)) : nil,
					  userData:userDataPath != nil ? try Data(contentsOf: URL(fileURLWithPath: userDataPath!)) : nil,
					  networkConfig: networkConfigPath != nil ? try Data(contentsOf: URL(fileURLWithPath: networkConfigPath!)) : nil)
	}

	private func createMetaData(hostname: String) throws -> Data {
		guard let metadata = "local-hostname: \(hostname)\n".data(using: .ascii) else {
			throw CloudInitGenerateError("unable to encode metada")
		}

		return metadata
	}

	private func createUserData() throws -> Data {
		if let userData = self.userData {
			return userData
		} else {
			guard let userData = "#cloud-config\n{}".data(using: .ascii) else {
				throw CloudInitGenerateError("unable to encode userdata")
			}

			return userData
		}
	}

	private func createVendorData() throws -> Data {
		guard let vendorData = self.vendorData else {
			let vendorData = VendorData(defaultUser: self.userName,
										mainGroup: self.mainGroup,
										clearPassword: self.clearPassword,
										sshAuthorizedKeys: sshAuthorizedKeys,
										tz: TimeZone.current.identifier,
										packages: ["pollinate"],
										writeFiles: [
											WriteFile(path: "/etc/cloud/cloud.cfg.d/100_datasources.cfg", content: "datasource_list: [ NoCloud, None ]"),
											WriteFile(path: "/etc/pollinate/add-user-agent", content: "caked/vz/1.0 # Written by caked")
										],
										growPart: true)

			return try vendorData.toCloudInit()
		}

		return vendorData
	}

	private func createSeed(writer: ISOWriter, path: String, configData: Data) throws -> Data {
		try writer.addFile(path: path, size: UInt64(configData.count), metadata: nil)

		return configData
	}

	private func createNetworkConfig() throws -> Data {
		if let networkConfig = self.networkConfig {
			return networkConfig
		} else {
			let networkConfig: NetworkConfig = NetworkConfig()

			return try networkConfig.toCloudInit()
		}
	}

	func createDefaultCloudInit(name: String, cdromURL: URL) throws {
		self.userData = try self.createUserData()
		self.vendorData = try self.createVendorData()
		self.networkConfig = try self.createNetworkConfig()

		var seed: [String: Data] = [:]

		try? cdromURL.delete()

		// create media
		let media = try! ISOImageFileMedia(cdromURL, readOnly: false)
		// prepare write options
		let writeOptions = ISOWriter.WriteOptions(volumeIdentifier: "CIDATA")

		let writer: ISOWriter = ISOWriter(
			media: media, options: writeOptions, contentCallback: { (path: String) -> InputStream in
				if let data = seed[path] {
					return InputStream(data: data)
				}

				return InputStream(data: emptyCloudInit)
			})

		seed["/user-data"] = try createSeed(writer: writer, path: "user-data", configData: self.createUserData())
		seed["/vendor-data"] = try createSeed(writer: writer, path: "vendor-data", configData: createVendorData())
		seed["/meta-data"] = try createSeed(writer: writer, path: "meta-data", configData: self.createMetaData(hostname: name))
		seed["/network-config"] = try createSeed(writer: writer, path: "network-config", configData: createNetworkConfig())

		// write
		try writer.writeAndClose()
	}
}
