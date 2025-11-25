import Foundation
import GRPCLib
import Gzip
import ISO9660
import Multipart
import Virtualization
import Yams

public let CAKEAGENT_SNAPSHOT = "352249d5"

let emptyCloudInit = "#cloud-config\n{}".data(using: .ascii)!

extension Multipart {
	mutating func appendCloudInitData(_ data: Data, withName name: String) {
		var filePart = Part(body: data.base64EncodedString(options: .lineLength76Characters), contentType: "text/cloud-config")

		filePart.setValue("base64", forHeaderField: "Content-Transfer-Encoding")
		filePart.setValue("attachment", forHeaderField: "Content-Disposition")
		filePart.setAttribute(attribute: "filename", value: name, forHeaderField: "Content-Disposition")

		self.append(filePart)
	}

	var cloudInit: String {
		var descriptionString = self.headers.string()

		descriptionString += "MIME-Version: 1.0" + Multipart.CRLF
		descriptionString += "Number-Attachments: \(self.entities.count)" + Multipart.CRLF

		if let preamble = self.preamble {
			descriptionString += preamble + Multipart.CRLF + Multipart.CRLF
		} else {
			descriptionString += Multipart.CRLF
		}

		if self.entities.count > 0 {
			for entity in self.entities {
				descriptionString += self.boundary.delimiter + Multipart.CRLF + entity.description + Multipart.CRLF + Multipart.CRLF + Multipart.CRLF
			}
		} else {
			descriptionString += self.boundary.delimiter + Multipart.CRLF + Multipart.CRLF
		}

		descriptionString += self.boundary.distinguishedDelimiter

		return descriptionString
	}
}

extension Data {
	mutating func appendMergeDirective() throws -> Data {
		let encoder: YAMLEncoder = newYAMLEncoder()
		let merge: [Merging] = [
			Merging(name: "list", settings: ["append", "recurse_dict", "recurse_list"]),
			Merging(name: "dict", settings: ["no_replace", "recurse_dict", "recurse_list"]),
		]

		guard let mergeData = "\r\n\(try encoder.encode(CloudConfigData(merge: merge)))".data(using: .ascii) else {
			throw CloudInitGenerateError("Failed to encode merge directive")
		}

		self.append(mergeData)

		return self
	}

	func buildConfigData() throws -> Data {
		guard var cloudConfigHeader: Data = "#cloud-config\n".data(using: .ascii) else {
			throw CloudInitGenerateError("unable to encode buildConfigData")
		}

		cloudConfigHeader.append(self)

		return cloudConfigHeader
	}
}

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

func newYAMLDecoder() -> YAMLDecoder {
	let encoder: YAMLDecoder = YAMLDecoder()
	return encoder
}

struct NetworkConfig: Codable {
	var network: CloudInitNetwork = CloudInitNetwork()

	init(netIfnames: Bool, config: CakeConfig) {
		let networks = config.qualifiedNetworks

		var index: Int = 1

		networks.forEach { network in
			let name = netIfnames ? "eth\(index - 1)" : "enp0s\(index)"

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

struct NameServer: Codable {
	var search: [String]? = nil
	var addresses: [String]? = nil
}

struct NetworkRoute: Codable {
	var to: String
	var via: String
	var metric: Int? = nil
	var onLink: Bool? = nil

	enum CodingKeys: String, CodingKey {
		case to
		case via
		case metric
		case onLink = "on-link"
	}
}

struct Interface: Codable {
	var match: Match? = nil
	var setName: String? = nil
	var addresses: [String]? = nil
	var nameservers: NameServer? = nil
	var gateway4: String? = nil
	var gateway6: String? = nil
	var dhcp4: Bool? = nil
	var dhcp6: Bool? = nil
	var dhcpIdentifier: String? = nil
	var dhcp4Overrides: DHCPOverides? = nil
	var dhcp6Overrides: DHCPOverides? = nil
	var routes: [NetworkRoute]? = nil

	enum CodingKeys: String, CodingKey {
		case match = "match"
		case setName = "set-name"
		case addresses = "addresses"
		case nameservers = "nameservers"
		case gateway4 = "gateway4"
		case gateway6 = "gateway6"
		case dhcp4 = "dhcp4"
		case dhcp6 = "dhcp6"
		case dhcpIdentifier = "dhcp-identifier"
		case dhcp4Overrides = "dhcp4-overrides"
		case dhcp6Overrides = "dhcp6-overrides"
		case routes = "routes"
	}

	func encode(to encoder: Encoder) throws {
		var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)

		try container.encodeIfPresent(match, forKey: .match)
		try container.encodeIfPresent(setName, forKey: .setName)
		try container.encodeIfPresent(addresses, forKey: .addresses)
		try container.encodeIfPresent(nameservers, forKey: .nameservers)
		try container.encodeIfPresent(gateway4, forKey: .gateway4)
		try container.encodeIfPresent(gateway6, forKey: .gateway6)
		try container.encodeIfPresent(dhcp4, forKey: .dhcp4)
		try container.encodeIfPresent(dhcp6, forKey: .dhcp6)
		try container.encodeIfPresent(dhcpIdentifier, forKey: .dhcpIdentifier)
		try container.encodeIfPresent(dhcp4Overrides, forKey: .dhcp4Overrides)
		try container.encodeIfPresent(dhcp6Overrides, forKey: .dhcp6Overrides)
		try container.encodeIfPresent(routes, forKey: .routes)
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

struct AutoInstall: Codable {
	struct Identity: Codable {
		var realName: String?
		var userName: String
		var password: String
		var hostname: String

		enum CodingKeys: String, CodingKey {
			case realName = "realname"
			case userName = "username"
			case password = "password"
			case hostname = "hostname"
		}

		init(from decoder: Decoder) throws {
			let container: KeyedDecodingContainer<Identity.CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)

			self.realName = try container.decodeIfPresent(String.self, forKey: .realName)
			self.userName = try container.decode(String.self, forKey: .userName)
			self.password = try container.decode(String.self, forKey: .password)
			self.hostname = try container.decode(String.self, forKey: .hostname)
		}

		func encode(to encoder: Encoder) throws {
			var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)

			try container.encodeIfPresent(realName, forKey: .realName)
			try container.encode(userName, forKey: .userName)
			try container.encode(password, forKey: .password)
			try container.encode(hostname, forKey: .hostname)
		}
	}

	struct Ssh: Codable {
		var enabled: Bool
		var authorizedKeys: [String]
		var allowPassword: Bool

		enum CodingKeys: String, CodingKey {
			case enabled = "install-server"
			case authorizedKeys = "authorized-keys"
			case allowPassword = "allow-pw"
		}

		init(enabled: Bool, authorizedKeys: [String], allowPassword: Bool) {
			self.enabled = enabled
			self.authorizedKeys = authorizedKeys
			self.allowPassword = allowPassword
		}

		init(from decoder: Decoder) throws {
			let container: KeyedDecodingContainer<Ssh.CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)

			self.enabled = try container.decode(Bool.self, forKey: .enabled)
			self.authorizedKeys = try container.decode([String].self, forKey: .authorizedKeys)
			self.allowPassword = try container.decode(Bool.self, forKey: .allowPassword)
		}

		func encode(to encoder: Encoder) throws {
			var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)

			try container.encode(enabled, forKey: .enabled)
			try container.encode(authorizedKeys, forKey: .authorizedKeys)
			try container.encode(allowPassword, forKey: .allowPassword)
		}
	}

	struct RefreshInstaller: Codable {
		var update: Bool
		var channel: String?

		enum CodingKeys: String, CodingKey {
			case update = "update"
			case channel = "channel"
		}

		init(from decoder: Decoder) throws {
			let container: KeyedDecodingContainer<RefreshInstaller.CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)

			self.update = try container.decode(Bool.self, forKey: .update)
			self.channel = try container.decodeIfPresent(String.self, forKey: .channel)
		}

		func encode(to encoder: Encoder) throws {
			var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)

			try container.encode(update, forKey: .update)
			try container.encodeIfPresent(channel, forKey: .channel)
		}
	}

	enum InstallUpdate: String, Codable {
		case security
		case all
	}

	enum CodingKeys: String, CodingKey {
		case version = "version"
		case identity = "identity"
		case ssh = "ssh"
		case timezone = "timezone"
		case update = "update"
		case packages = "packages"
		case earlyCommands = "early-commands"
		case lateCommands = "late-commands"
		case refreshInstaller = "refresh-installer"
		case userData = "user-data"
		case network = "network"
	}

	var version: Int = 1
	var identity: Identity?
	var ssh: Ssh?
	var timezone: String?
	var update: InstallUpdate?
	var packages: [String]?
	var earlyCommands: [String]?
	var lateCommands: [String]?
	var refreshInstaller: RefreshInstaller?
	var userData: CloudConfigData?
	var network: NetworkConfig?

	init(
		identity: Identity? = nil,
		ssh: Ssh? = nil,
		timezone: String? = nil,
		update: InstallUpdate? = nil,
		packages: [String]? = nil,
		earlyCommands: [String]? = nil,
		lateCommands: [String]? = nil,
		refreshInstaller: RefreshInstaller? = nil,
		userData: CloudConfigData? = nil,
		network: NetworkConfig? = nil
	) {

		self.identity = identity
		self.ssh = ssh
		self.timezone = timezone
		self.update = update
		self.packages = packages
		self.earlyCommands = earlyCommands
		self.lateCommands = lateCommands
		self.refreshInstaller = refreshInstaller
		self.userData = userData
		self.network = network
	}

	init(from decoder: Decoder) throws {
		let container: KeyedDecodingContainer<AutoInstall.CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)

		self.version = try container.decode(Int.self, forKey: .version)
		self.identity = try container.decodeIfPresent(Identity.self, forKey: .identity)
		self.ssh = try container.decodeIfPresent(Ssh.self, forKey: .ssh)
		self.timezone = try container.decodeIfPresent(String.self, forKey: .timezone)
		self.update = try container.decodeIfPresent(InstallUpdate.self, forKey: .update)
		self.packages = try container.decodeIfPresent([String].self, forKey: .packages)
		self.earlyCommands = try container.decodeIfPresent([String].self, forKey: .earlyCommands)
		self.lateCommands = try container.decodeIfPresent([String].self, forKey: .lateCommands)
		self.refreshInstaller = try container.decodeIfPresent(RefreshInstaller.self, forKey: .refreshInstaller)
		self.userData = try container.decodeIfPresent(CloudConfigData.self, forKey: .userData)
		self.network = try container.decodeIfPresent(NetworkConfig.self, forKey: .network)
	}

	func encode(to encoder: Encoder) throws {
		var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)

		try container.encode(version, forKey: .version)
		try container.encodeIfPresent(identity, forKey: .identity)
		try container.encodeIfPresent(ssh, forKey: .ssh)
		try container.encodeIfPresent(timezone, forKey: .timezone)
		try container.encodeIfPresent(packages, forKey: .packages)
		try container.encodeIfPresent(earlyCommands, forKey: .earlyCommands)
		try container.encodeIfPresent(lateCommands, forKey: .lateCommands)
		try container.encodeIfPresent(refreshInstaller, forKey: .refreshInstaller)
		try container.encodeIfPresent(userData, forKey: .userData)
		try container.encodeIfPresent(network, forKey: .network)
	}
}

struct AutoInstallConfig: Codable {
	var autoInstall: AutoInstall

	enum CodingKeys: String, CodingKey {
		case autoInstall = "autoinstall"
	}

	init(
		identity: AutoInstall.Identity? = nil,
		ssh: AutoInstall.Ssh? = nil,
		timezone: String? = nil,
		update: AutoInstall.InstallUpdate? = nil,
		packages: [String]? = nil,
		earlyCommands: [String]? = nil,
		lateCommands: [String]? = nil,
		refreshInstaller: AutoInstall.RefreshInstaller? = nil,
		userData: CloudConfigData? = nil,
		network: NetworkConfig? = nil
	) {

		self.autoInstall = .init(identity: identity, ssh: ssh, timezone: timezone, update: update, packages: packages, earlyCommands: earlyCommands, lateCommands: lateCommands, refreshInstaller: refreshInstaller, userData: userData, network: network)
	}

	init(from decoder: Decoder) throws {
		let container: KeyedDecodingContainer<AutoInstallConfig.CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)

		self.autoInstall = try container.decode(AutoInstall.self, forKey: .autoInstall)
	}

	func encode(to encoder: Encoder) throws {
		var container: KeyedEncodingContainer<CodingKeys> = encoder.container(keyedBy: CodingKeys.self)

		try container.encode(autoInstall, forKey: .autoInstall)
	}

	func toCloudInit() throws -> Data {
		let encoder: YAMLEncoder = newYAMLEncoder()
		let encoded = "#cloud-config\n\(try encoder.encode(self))"

		guard let result = encoded.data(using: .ascii) else {
			throw CloudInitGenerateError("Failed to encode vendorData")
		}

		return result
	}
}

struct CloudConfigData: Codable {
	var merge: [Merging]? = nil
	var packageUpdate: Bool = false
	var packageUpgrade = false
	var growpart: Growpart? = nil
	var manageEtcHosts: Bool? = nil
	var packages: [String]? = nil
	var sshAuthorizedKeys: [String]?
	var sshPwAuth: Bool? = nil
	var systemInfo: SystemInfo?
	var timezone: String? = nil
	var users: [User]? = nil
	var writeFiles: [WriteFile]?
	var runcmd: [String]? = nil

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

	init(merge: [Merging]) {
		self.merge = merge
	}

	init(
		defaultUser: String = "admin",
		password: String? = nil,
		mainGroup: String = "adm",
		clearPassword: Bool = false,
		sshAuthorizedKeys: [String]? = nil,
		tz: String = "UTC",
		packages: [String]? = nil,
		writeFiles: [WriteFile]? = nil,
		runcmd: [String]? = nil,
		growPart: Bool = true,
		merge: [Merging]? = nil
	) {

		self.growpart = Growpart()
		self.merge = merge
		self.manageEtcHosts = true
		self.packages = packages
		//self.sshAuthorizedKeys = sshAuthorizedKeys
		self.sshPwAuth = clearPassword
		//self.systemInfo = SystemInfo(defaultUser: defaultUser)
		self.timezone = tz
		self.writeFiles = writeFiles
		self.runcmd = runcmd
		self.users = [
			User.userClass(
				UserClass(
					name: defaultUser,
					password: password,
					lockPasswd: password == nil,
					shell: "/bin/sh",
					sshAuthorizedKeys: sshAuthorizedKeys,
					primaryGroup: mainGroup,
					groups: nil,
					sudo: true))
		]

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

		if var userData = try encodedPart1?.buildConfigData() {
			guard let vendorData = try encoder.encode(self).data(using: .ascii)?.buildConfigData() else {
				throw CloudInitGenerateError("Failed to encode userData")
			}

			var message = Multipart(type: .mixed)

			message.appendCloudInitData(vendorData, withName: "vendor-data")
			message.appendCloudInitData(try userData.appendMergeDirective(), withName: "user-data")

			encoded = message.cloudInit
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

	init(path: String, content: String, encoding: String? = nil, permissions: String? = nil, owner: String? = nil) {
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
		case sshAuthorizedKeys = "ssh_authorized_keys"
		case sshImportID = "ssh_import_id"
		case sshRedirectUser = "ssh_redirect_user"
		case sudo
		case system
	}

	init(
		name: String,
		password: String?,
		lockPasswd: Bool?,
		shell: String?,
		sshAuthorizedKeys: [String]?,
		primaryGroup: String?,
		groups: [String]?,
		sudo: Bool?
	) {
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

public enum SupportedPlatform: String, CaseIterable {
	case ubuntu
	case centos
	case macos
	case windows
	case debian
	case fedora
	case redhat
	case openSUSE
	case alpine
	case unknown

	public init(rawValue: String) {
		let rawValue = rawValue.lowercased()
		let value = Self.allCases.first {
			rawValue.contains($0.rawValue)
		}

		if let value = value {
			self = value
		} else {
			self = .unknown
		}
	}

	public init(stringValue: String?) {
		if let rawValue = stringValue {
			self.init(rawValue: rawValue)
		} else {
			self = .unknown
		}
	}
}

class CloudInit {
	var userData: Data?
	var vendorData: Data?
	var networkConfig: Data?
	var userName: String = "admin"
	var password: String? = nil
	var mainGroup: String = "adm"
	var sshAuthorizedKeys: [String]?
	var clearPassword: Bool = false
	var runMode: Utils.RunMode = .user
	var netIfnames: Bool = true
	var platform: SupportedPlatform = .ubuntu

	private static func loadPublicKey(sshAuthorizedKey: String) throws -> String {
		let datas: Data = try Data(contentsOf: URL(fileURLWithPath: sshAuthorizedKey.expandingTildeInPath))

		if let publicKey = String(data: datas, encoding: .ascii) {
			return publicKey.trimmingCharacters(in: .whitespacesAndNewlines)
		}

		throw CypherKeyGeneratorError("unable to decode public key")
	}

	public static func sshAuthorizedKeys(sshAuthorizedKeyPath: String?, runMode: Utils.RunMode) throws -> [String] {
		let home: Home = try Home(runMode: runMode)
		let sharedPublicKey = try home.getSharedPublicKey()

		if var sshAuthorizedKey = sshAuthorizedKeyPath {
			sshAuthorizedKey = try loadPublicKey(sshAuthorizedKey: sshAuthorizedKey)
			return [sharedPublicKey, sshAuthorizedKey]
		} else {
			return [sharedPublicKey]
		}
	}

	init(
		plateform: SupportedPlatform, userName: String, password: String?, mainGroup: String, clearPassword: Bool, sshAuthorizedKey: [String]?, vendorData: Data?, userData: Data?, networkConfig: Data?, netIfnames: Bool = true, runMode: Utils.RunMode
	) throws {
		self.platform = plateform
		self.userName = userName
		self.password = password
		self.mainGroup = mainGroup
		self.clearPassword = clearPassword
		self.sshAuthorizedKeys = sshAuthorizedKey
		self.userData = userData
		self.vendorData = vendorData
		self.networkConfig = networkConfig
		self.netIfnames = netIfnames
		self.runMode = runMode
	}

	convenience init(
		plateform: SupportedPlatform, userName: String, password: String?, mainGroup: String, clearPassword: Bool, sshAuthorizedKeyPath: String?, vendorDataPath: String?, userDataPath: String?, networkConfigPath: String?, netIfnames: Bool = true,
		runMode: Utils.RunMode
	)
		throws
	{
		try self.init(
			plateform: plateform,
			userName: userName,
			password: password,
			mainGroup: mainGroup,
			clearPassword: clearPassword,
			sshAuthorizedKey: try Self.sshAuthorizedKeys(sshAuthorizedKeyPath: sshAuthorizedKeyPath, runMode: runMode),
			vendorData: vendorDataPath != nil ? try Data(contentsOf: URL(fileURLWithPath: vendorDataPath!)) : nil,
			userData: userDataPath != nil ? try Data(contentsOf: URL(fileURLWithPath: userDataPath!)) : nil,
			networkConfig: networkConfigPath != nil ? try Data(contentsOf: URL(fileURLWithPath: networkConfigPath!)) : nil,
			netIfnames: netIfnames, runMode: runMode)
	}

	private func createMetaData(hostname: String, instanceID: String) throws -> Data {
		guard let metadata = "instance-id: \(instanceID)\nlocal-hostname: \(hostname)\n".data(using: .ascii) else {
			throw CloudInitGenerateError("unable to encode metada")
		}

		return metadata
	}

	private func cakeagentBinary(config: CakeConfig) throws -> URL {
		let arch = Architecture.current().rawValue
		let os = config.os.rawValue
		let home: Home = try Home(runMode: self.runMode)
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
				/usr/local/bin/cakeagent service install \\
					--listen=vsock://any:5000 \\
					--ca-cert=/etc/cakeagent/ssl/ca.pem \\
					--tls-cert=/etc/cakeagent/ssl/server.pem \\
					--tls-key=/etc/cakeagent/ssl/server.key \(config.linuxMounts)
			else
			  echo \"CIDATA not found\"
			  exit 1
			fi
			"""

		return install_cakeagent
	}

	private func buildVendorData(config: CakeConfig, runMode: Utils.RunMode) throws -> CloudConfigData {
		let installCakeagent = installCakeAgentScript(config: config).base64EncodedString()
		let certificates = try CertificatesLocation.createAgentCertificats(runMode: self.runMode)
		let caCert = try Compression.compressEncoded(contentOf: certificates.caCertURL)
		let serverKey = try Compression.compressEncoded(contentOf: certificates.serverKeyURL)
		let serverPem = try Compression.compressEncoded(contentOf: certificates.serverCertURL)
		let merge: [Merging] = [
			Merging(name: "list", settings: ["append", "recurse_dict", "recurse_list"]),
			Merging(name: "dict", settings: ["no_replace", "recurse_dict", "recurse_list"]),
		]
		let runCommand = config.mounts.isEmpty ? ["/usr/local/bin/install-cakeagent.sh"] : ["/usr/local/bin/install-cakeagent.sh"]
		let vendorData = CloudConfigData(
			defaultUser: self.userName,
			password: self.password,
			mainGroup: self.mainGroup,
			clearPassword: self.clearPassword,
			sshAuthorizedKeys: sshAuthorizedKeys,
			tz: TimeZone.current.identifier,
			packages: nil,
			writeFiles: [
				WriteFile(path: "/usr/local/bin/install-cakeagent.sh", content: installCakeagent, encoding: "base64", permissions: "0755", owner: "root:\(self.mainGroup)"),
				WriteFile(path: "/etc/cloud/cloud.cfg.d/100_datasources.cfg", content: "datasource_list: [ NoCloud, None ]", permissions: "0644", owner: "root:\(self.mainGroup)"),
				WriteFile(path: "/etc/cakeagent/ssl/server.key", content: serverKey, encoding: "gzip+base64", permissions: "0600", owner: "root:\(self.mainGroup)"),
				WriteFile(path: "/etc/cakeagent/ssl/server.pem", content: serverPem, encoding: "gzip+base64", permissions: "0600", owner: "root:\(self.mainGroup)"),
				WriteFile(path: "/etc/cakeagent/ssl/ca.pem", content: caCert, encoding: "gzip+base64", permissions: "0600", owner: "root:\(self.mainGroup)"),
			],
			runcmd: runCommand,
			growPart: true,
			merge: merge)

		return vendorData
	}

	private func loadNetworkConfig(config: CakeConfig) throws -> NetworkConfig {
		if let networkConfig = self.networkConfig {
			return try YAMLDecoder().decode(NetworkConfig.self, from: networkConfig)
		} else {
			return NetworkConfig(netIfnames: self.netIfnames, config: config)
		}
	}

	private func createPreseedData(config: CakeConfig) throws -> Data {
		let networks = try loadNetworkConfig(config: config).network
		var scripts: [String] = []

		if let network = networks.ethernets.first {
			let inf = network.key
			let ethernet = network.value

			scripts.append("#d-i netcfg/choose_interface select \(inf)")

			if let dhcp4 = ethernet.dhcp4, dhcp4 == false {
				if let cidr = ethernet.addresses?.first {
					let addr = cidr.stringBefore(before: "/")
					let netmask = cidr.stringAfter(after: "/").cidrToNetmask()

					scripts.append("d-i netcfg/get_ipaddress string \(addr)")
					scripts.append("d-i netcfg/get_netmask string \(netmask)")

					if let gateway4 = ethernet.gateway4 {
						scripts.append("d-i netcfg/get_netmask string \(gateway4)")
					} else if let routes = ethernet.routes, let defaultRoute = routes.first(where: { $0.to.lowercased() == "default" }) {
						scripts.append("d-i netcfg/get_netmask string \(defaultRoute.via)")
					} else {
						let network = IP.Block<IP.V4>(base: IP.V4(addr)!, bits: UInt8(netmask.netmaskToCidr())).network
						let gateway = network.range.lowerBound

						scripts.append("d-i netcfg/get_netmask string \(gateway.value)")
					}

					if let dns = ethernet.nameservers, let addresses = dns.addresses {
						addresses.forEach {
							scripts.append("d-i netcfg/get_nameservers string \($0)")
						}
					}

					scripts.append("d-i netcfg/confirm_static boolean true")
				}
			}
		}

		scripts.append("d-i partman-auto/method string regular")

		scripts.append("d-i passwd/user-fullname string \(self.userName)")
		scripts.append("d-i passwd/username string \(self.userName)")
		scripts.append("d-i passwd/user-default-groups string \(self.mainGroup)")

		if let password = self.password {
			scripts.append("d-i passwd/user-password password \(password)")
			scripts.append("d-i passwd/user-password-again password \(password)")
		}

		scripts.append("d-i preseed/late_command string mkdir -p /target/etc/cakeagent/ssl /target/usr/local/bin")

		scripts.append("d-i preseed/late_command string cp /cdrom/install-cakeagent.sh /target/usr/local/bin")
		scripts.append("d-i preseed/late_command string cp /cdrom/server.key /target/etc/cakeagent/ssl")
		scripts.append("d-i preseed/late_command string cp /cdrom/server.pem /target/etc/cakeagent/ssl")
		scripts.append("d-i preseed/late_command string cp /cdrom/ca.pem /target/etc/cakeagent/ssl")

		scripts.append("d-i preseed/late_command string chown root:\(self.mainGroup) /target/usr/local/bin/install-cakeagent.sh")
		scripts.append("d-i preseed/late_command string chown root:\(self.mainGroup) /target/etc/cakeagent/ssl/*")

		scripts.append("d-i preseed/late_command string chmod 755 /target/usr/local/bin/install-cakeagent.sh")
		scripts.append("d-i preseed/late_command string chmod 600 /target/etc/cakeagent/ssl/*")

		scripts.append("d-i preseed/late_command string sh -c \"echo '\(self.userName) ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/\(self.userName)\"")
		scripts.append("d-i preseed/late_command string sh -c \"echo 'datasource_list: [ NoCloud, None ]' > /etc/cloud/cloud.cfg.d/100_datasources.cfg\"")
		scripts.append("d-i preseed/late_command string cloud-init clean")

		scripts.append("d-i preseed/late_command string sh -c \"echo '\(self.userName) ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/\(self.userName)\"")

		return String(scripts.joined(by: "\n")).data(using: .ascii)!
	}

	private func createKickStartData(config: CakeConfig) throws -> Data {
		let certificates = try CertificatesLocation.createAgentCertificats(runMode: self.runMode)
		let caCert = try String(contentsOf: certificates.caCertURL, encoding: .ascii)
		let serverKey = try String(contentsOf: certificates.serverKeyURL, encoding: .ascii)
		let serverPem = try String(contentsOf: certificates.serverCertURL, encoding: .ascii)
		let networks = try loadNetworkConfig(config: config).network
		var scripts: [String] = [
			"bootloader --location=none"
		]

		if let password = self.password {
			scripts.append("user --name=\(self.userName) --password=\(password) --plaintext --groups=\(self.mainGroup)")
		} else {
			scripts.append("user --name=\(self.userName) --groups=\(self.mainGroup)")
		}

		self.sshAuthorizedKeys?.forEach {
			scripts.append("sshkey --username=\(self.userName) '\($0)'")
		}

		networks.ethernets.forEach {
			let inf = $0.key
			let ethernet = $0.value
			var network = [
				"network"
			]

			if let match = ethernet.match {
				if let macAddress = match.macAddress {
					network.append("--device=\(macAddress)")
				} else if let name = match.name {
					network.append("--device=\(name)")
				}
			} else {
				network.append("--device=\(inf)")
			}

			if let dns = ethernet.nameservers, let addresses = dns.addresses {
				addresses.forEach {
					network.append("--nameserver=\($0)")
				}
			}

			if let gateway4 = ethernet.gateway4 {
				network.append("--gateway=\(gateway4)")
			} else if let routes = ethernet.routes, let defaultRoute = routes.first(where: { $0.to.lowercased() == "default" }) {
				network.append("--gateway=\(defaultRoute.via)")
			} else if let cidr = ethernet.addresses?.first {
				let addr = cidr.stringBefore(before: "/")
				let netmask = cidr.stringAfter(after: "/").cidrToNetmask()
				let gateway = IP.Block<IP.V4>(base: IP.V4(addr)!, bits: UInt8(netmask.netmaskToCidr())).network.range.lowerBound

				network.append("--gateway=\(gateway.value)")
			}

			if let gateway6 = ethernet.gateway6 {
				network.append("--ipv6gateway=\(gateway6)")
			}

			if let dhcp4 = ethernet.dhcp4, dhcp4 {
				scripts.append("--bootproto=dhcp")
			} else if let cidr = ethernet.addresses?.first {
				let addr = cidr.stringBefore(before: "/")
				let netmask = cidr.stringAfter(after: "/").cidrToNetmask()

				scripts.append("--bootproto=static")
				scripts.append("--ip=\(addr)")
				scripts.append("--netmask=\(netmask)")
			}
		}

		scripts.append("%post --interpreter=/bin/bash")

		scripts.append("echo '\(self.userName) ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/\(self.userName)")

		scripts.append("echo 'datasource_list: [ NoCloud, None ]' > /etc/cloud/cloud.cfg.d/100_datasources.cfg")

		scripts.append("cat > /usr/local/bin/install-cakeagent.sh <<EOF\n\(self.installCakeAgentScript(config:config))\nEOF\n")
		scripts.append("chown root:\(self.mainGroup) /usr/local/bin/install-cakeagent.sh")
		scripts.append("chmod 755 /usr/local/bin/install-cakeagent.sh")

		scripts.append("cat > /etc/cakeagent/ssl/server.key <<EOF\n\(serverKey)\nEOF\n")
		scripts.append("chown root:\(self.mainGroup) /etc/cakeagent/ssl/server.key")
		scripts.append("chmod 600 /etc/cakeagent/ssl/server.key")

		scripts.append("cat > /etc/cakeagent/ssl/server.pem <<EOF\n\(serverPem)\nEOF\n")
		scripts.append("chown root:\(self.mainGroup) /etc/cakeagent/ssl/server.pem")
		scripts.append("chmod 600 /etc/cakeagent/ssl/server.pem")

		scripts.append("cat > /etc/cakeagent/ssl/ca.pem <<EOF\n\(caCert)\nEOF\n")
		scripts.append("chown root:\(self.mainGroup) /etc/cakeagent/ssl/ca.pem")
		scripts.append("chmod 600 /etc/cakeagent/ssl/ca.pem")

		scripts.append("%end")

		scripts.append("%addon reboot")

		return String(scripts.joined(by: "\n")).data(using: .ascii)!
	}

	private func createAutoInstallData(config: CakeConfig) throws -> Data {
		let installCakeagent = installCakeAgentScript(config: config).base64EncodedString()
		let certificates = try CertificatesLocation.createAgentCertificats(runMode: self.runMode)
		let caCert = try Compression.compressEncoded(contentOf: certificates.caCertURL)
		let serverKey = try Compression.compressEncoded(contentOf: certificates.serverKeyURL)
		let serverPem = try Compression.compressEncoded(contentOf: certificates.serverCertURL)
		let runCommand = config.mounts.isEmpty ? ["/usr/local/bin/install-cakeagent.sh"] : ["/usr/local/bin/install-cakeagent.sh"]
		let userData = CloudConfigData(
			defaultUser: self.userName,
			password: self.password,
			mainGroup: self.mainGroup,
			clearPassword: self.clearPassword,
			sshAuthorizedKeys: sshAuthorizedKeys,
			tz: TimeZone.current.identifier,
			packages: nil,
			writeFiles: [
				WriteFile(path: "/usr/local/bin/install-cakeagent.sh", content: installCakeagent, encoding: "base64", permissions: "0755", owner: "root:\(self.mainGroup)"),
				WriteFile(path: "/etc/cloud/cloud.cfg.d/100_datasources.cfg", content: "datasource_list: [ NoCloud, None ]", permissions: "0644", owner: "root:\(self.mainGroup)"),
				WriteFile(path: "/etc/cakeagent/ssl/server.key", content: serverKey, encoding: "gzip+base64", permissions: "0600", owner: "root:\(self.mainGroup)"),
				WriteFile(path: "/etc/cakeagent/ssl/server.pem", content: serverPem, encoding: "gzip+base64", permissions: "0600", owner: "root:\(self.mainGroup)"),
				WriteFile(path: "/etc/cakeagent/ssl/ca.pem", content: caCert, encoding: "gzip+base64", permissions: "0600", owner: "root:\(self.mainGroup)"),
			],
			runcmd: runCommand,
			growPart: true)

		let ssh = AutoInstall.Ssh(enabled: true, authorizedKeys: self.sshAuthorizedKeys ?? [], allowPassword: self.clearPassword)
		let network = try loadNetworkConfig(config: config)
		let autoInstall = AutoInstallConfig(ssh: ssh, timezone: TimeZone.current.identifier, userData: userData, network: network)

		return try autoInstall.toCloudInit()
	}

	private func createUserData(config: CakeConfig) throws -> Data {
		if let userData = self.userData {
			return try buildVendorData(config: config, runMode: self.runMode).toCloudInit(userData)
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
				return try buildVendorData(config: config, runMode: self.runMode).toCloudInit()
			} else {
				guard let userData: Data = "#cloud-config\n{}".data(using: .ascii) else {
					throw CloudInitGenerateError("unable to encode userdata")
				}

				return userData
			}
		}

		return vendorData
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
		let configData = try self.createSeed(writer: writer, path: path, configData: configData)

		try configData.write(to: config.location.appendingPathComponent(path))

		return configData
	}

	private func createSeed(writer: ISOWriter, path: String, configData: Data) throws -> Data {
		try writer.addFile(path: path, size: UInt64(configData.count), metadata: nil)

		return configData
	}

	private func createNetworkConfig(config: CakeConfig) throws -> Data {
		if let networkConfig = self.networkConfig {
			return networkConfig
		} else {
			let networkConfig: NetworkConfig = NetworkConfig(netIfnames: self.netIfnames, config: config)

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
			media: media, options: writeOptions,
			contentCallback: { (path: String) -> InputStream in
				if let data = seed[path] as? Data {
					return InputStream(data: data)
				} else if let url = seed[path] as? URL, let input = InputStream(url: url) {
					return input
				}

				return InputStream(data: emptyCloudInit)
			})

		if config.source == .iso && (self.platform == .ubuntu || self.platform == .fedora || self.platform == .debian || self.platform == .redhat || self.platform == .centos) {
			let certificates = try CertificatesLocation.createAgentCertificats(runMode: self.runMode)

			if self.platform != .ubuntu {
				seed["/server.key"] = try createSeed(writer: writer, path: "server.key", configUrl: certificates.serverKeyURL)
				seed["/server.pem"] = try createSeed(writer: writer, path: "server.pem", configUrl: certificates.serverCertURL)
				seed["/ca.pem"] = try createSeed(writer: writer, path: "ca.pem", configUrl: certificates.caCertURL)
				seed["/install-cakeagent.sh"] = try createSeed(writer: writer, path: "install-cakeagent.sh", configData: installCakeAgentScript(config: config).data(using: .utf8)!)
			}

			if self.platform == .ubuntu {
				seed["/user-data"] = try createSeed(config: config, writer: writer, path: "user-data", configData: self.createAutoInstallData(config: config))
			} else if self.platform == .fedora || self.platform == .redhat || self.platform == .centos {
				seed["/ks.cfg"] = try createSeed(config: config, writer: writer, path: "ks.cfg", configData: self.createKickStartData(config: config))
			} else if self.platform == .debian {
				seed["/preseed.cfg"] = try createSeed(config: config, writer: writer, path: "preseed.cfg", configData: self.createPreseedData(config: config))
			}
		} else {
			seed["/user-data"] = try createSeed(config: config, writer: writer, path: "user-data", configData: self.createUserData(config: config))
			seed["/vendor-data"] = try createSeed(config: config, writer: writer, path: "vendor-data", configData: createVendorData(config: config))
			seed["/network-config"] = try createSeed(config: config, writer: writer, path: "network-config", configData: createNetworkConfig(config: config))
		}

		seed["/meta-data"] = try createSeed(config: config, writer: writer, path: "meta-data", configData: self.createMetaData(hostname: name, instanceID: config.instanceID))
		seed["/cakeagent"] = try createSeed(writer: writer, path: "cakeagent", configUrl: try cakeagentBinary(config: config))

		// write
		try writer.writeAndClose()
	}
}
