import Foundation
import GRPCLib

let fingerprint64 = try! NSRegularExpression(pattern: "^[0-9a-fA-F]{64}$")
let fingerprint12 = try! NSRegularExpression(pattern: "^[0-9a-fA-F]{12}$")

extension String {
	func isFingerPrint() -> Bool {
		if fingerprint64.firstMatch(in: self, options: [], range: NSRange(location: 0, length: self.count)) != nil {
			return true
		}

		if fingerprint12.firstMatch(in: self, options: [], range: NSRange(location: 0, length: self.count)) != nil {
			return true
		}

		return false
	}

}
struct SimpleStreamError: Error {
	let description: String

	init(_ what: String) {
		self.description = what
	}
}

/// A type that can decode itself from an external representation.
public protocol JsonDecodable: Decodable {
	init(fromJSON: Data) throws
	init(fromURL: URL) throws
}

class Streamable {
	static func loadSimpleStreamObject<T: JsonDecodable>(remoteURL: URL, remoteName: String, cachedFile: String, kind: CacheEntryKind) async throws -> T {
		let simpleStreamCache = try SimpleStreamsImageCache(name: remoteName)
		let indexLocation: URL = simpleStreamCache.locationFor(fileName: cachedFile)
		let (_, headResponse) = try await Curl(fromURL: remoteURL).head()

		if let etag: String = headResponse.ETag() {
			if FileManager.default.fileExists(atPath: indexLocation.path) {
				if let cached = simpleStreamCache.findCache(fingerprintOrAlias: cachedFile) {
					if cached.fingerprint == etag {
						Logger.info("Using cached \(cachedFile) file...")
						try indexLocation.updateAccessDate()
						return try T(fromURL: indexLocation)
					} else {
						Logger.info("Cached \(cachedFile) file is outdated...")
						try simpleStreamCache.deleteCache(fingerprint: cached.fingerprint)
					}
				}
			}

			try simpleStreamCache.addCache(fingerprint: etag, url: remoteURL, kind: kind, alias: [cachedFile])
		}

		// Download the index
		Logger.debug("Fetching \(remoteURL.lastPathComponent)...")

		let channel = try await Curl(fromURL: remoteURL).get(observer: ProgressObserver(totalUnitCount: 100).log("Fetching \(remoteURL.lastPathComponent)"))

		FileManager.default.createFile(atPath: indexLocation.path, contents: nil)

		let lock = try FileLock(lockURL: indexLocation)
		try lock.lock()

		let fileHandle = try FileHandle(forWritingTo: indexLocation)

		for try await chunk in channel.0 {
			let chunkAsData = Data(chunk)
			fileHandle.write(chunkAsData)
		}

		try fileHandle.close()

		return try T(fromURL: indexLocation)
	}
}

// SimpleStream master index format (https://images.linuxcontainers.org/streams/v1/index.json)
struct SimpleStream: JsonDecodable {
	let updated: String?
	let format: String
	let index: Dictionary<String, SimpleStreamImageInfos>

	enum CodingKeys: String, CodingKey {
		case updated
		case format
		case index
	}

	init(fromJSON: Data) throws {
		self = try JSONDecoder().decode(Self.self, from: fromJSON)
	}

	init(fromURL: URL) throws {
		self = try Self(fromJSON: try Data(contentsOf: fromURL))
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		updated = try container.decodeIfPresent(String.self, forKey: .updated)
		format = try container.decode(String.self, forKey: .format)
		index = try container.decode(Dictionary<String, SimpleStreamImageInfos>.self, forKey: .index)
	}

	var linuxContainers: Bool {
		return self.index["images"] != nil
	}

	var images: SimpleStreamImageInfos {
		get throws {
			for infos: SimpleStreamImageInfos in self.index.values {
				if infos.datatype == "image-downloads" {
					return infos
				}
			}

			throw SimpleStreamError("unable to find known products for images")
		}
	}
}

struct SimpleStreamImageInfos: Codable {
	let datatype: String
	let path: String
	let format: String
	let updated: String?
	let products: [String]

	func filter(arch: String) -> [String] {
		var products: [String] = []

		for product in self.products {
			if product.contains(arch) {
				products.append(product)
			}
		}

		return products
	}
}

// SimpleStream image index format (https://images.linuxcontainers.org/streams/v1/image.json)
struct SimpleStreamImageIndex: JsonDecodable {
	let contentID: String
	let format: String
	let datatype: String
	let products: Dictionary<String, SimpleStreamProduct>
	let updated: String?
	let license: String?
	let creator: String?

	enum CodingKeys: String, CodingKey {
		case contentID = "content_id"
		case format
		case datatype
		case products
		case updated
		case license
		case creator
	}

	init(fromJSON: Data) throws {
		self = try JSONDecoder().decode(Self.self, from: fromJSON)
	}

	init(fromURL: URL) throws {
		self = try Self(fromJSON: try Data(contentsOf: fromURL))
	}

	init(from decoder: Decoder) throws {
		let container: KeyedDecodingContainer<SimpleStreamImageIndex.CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)

		contentID = try container.decode(String.self, forKey: .contentID)
		format = try container.decode(String.self, forKey: .format)
		datatype = try container.decode(String.self, forKey: .datatype)
		products = try container.decode(Dictionary<String, SimpleStreamProduct>.self, forKey: .products)

		// Ubuntu cloud server
		updated = try container.decodeIfPresent(String.self, forKey: .updated)
		license = try container.decodeIfPresent(String.self, forKey: .license)
		creator = try container.decodeIfPresent(String.self, forKey: .creator)
	}
}

struct SimpleStreamProduct: Codable {
	let aliases: String
	let arch: Architecture
	let distro: String?
	let os: String
	let release: String
	let releaseCodeName: String?
	let releaseTitle: String
	let supportedEOL: String?
	let supported: Bool?
	let variant: String
	let version: String?
	let versions: Dictionary<String, ImageVersion>

	enum CodingKeys: String, CodingKey {
		case aliases
		case arch
		case distro
		case os
		case release
		case releaseTitle = "release_title"
		case releaseCodeName = "release_codename"
		case supportedEOL = "support_eol"
		case supported
		case variant
		case version
		case versions
	}

	init(from decoder: Decoder) throws {
		let container: KeyedDecodingContainer<SimpleStreamProduct.CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)

		aliases = try container.decode(String.self, forKey: .aliases)
		arch = try container.decode(Architecture.self, forKey: .arch)
		distro = try container.decodeIfPresent(String.self, forKey: .distro)
		os = try container.decode(String.self, forKey: .os)
		release = try container.decode(String.self, forKey: .release)
		releaseTitle = try container.decode(String.self, forKey: .releaseTitle)
		releaseCodeName = try container.decodeIfPresent(String.self, forKey: .releaseCodeName)
		supported = try container.decodeIfPresent(Bool.self, forKey: .supported)
		supportedEOL = try container.decodeIfPresent(String.self, forKey: .supportedEOL)
		variant = try container.decodeIfPresent(String.self, forKey: .variant) ?? "cloud"
		version = try container.decodeIfPresent(String.self, forKey: .version)
		versions = try container.decode(Dictionary<String, ImageVersion>.self, forKey: .versions)
	}

	func latest() -> (String, ImageVersion)? {
		if let latest: Dictionary<String, ImageVersion>.Keys.Element = self.versions.keys.sorted().last {
			if let version = self.versions[latest] {
				if version.items.imageDisk != nil {
					return (latest, version)
				}
			}
		}

		return nil
	}
}

struct ImageVersion: Codable {
	let items: ImageVersionItems
	let label: String?
	let pubname: String?

	enum CodingKeys: String, CodingKey {
		case label
		case items
		case pubname
	}

	init(from decoder: Decoder) throws {
		let container: KeyedDecodingContainer<ImageVersion.CodingKeys> = try decoder.container(keyedBy: ImageVersion.CodingKeys.self)

		items = try container.decode(ImageVersionItems.self, forKey: .items)

		// Ubuntu server
		label = try container.decodeIfPresent(String.self, forKey: .label)
		pubname = try container.decodeIfPresent(String.self, forKey: .pubname)
	}
}

struct ImageVersionItems: Codable {
	let diskImg: ImageVersionItem?
	let qcow2: ImageVersionItem?
	let lxd: ImageVersionItem?
	let squashfs: ImageVersionItem?
	let vmdk: ImageVersionItem?
	let ova: ImageVersionItem?
	let targz: ImageVersionItem?
	let vhd: ImageVersionItem?

	enum CodingKeys: String, CodingKey {
		case diskImg = "disk1.img"
		case qcow2 = "disk.qcow2"
		case lxd = "lxd.tar.xz"
		case squashfs = "rootfs.squashfs"
		case vmdk = "vmdk"
		case ova = "ova"
		case targz = "tar.gz"
		case vhd = "vhd.tar.gz"
	}

	init(from decoder: Decoder) throws {
		let container: KeyedDecodingContainer<ImageVersionItems.CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)

		// Linux containers
		qcow2 = try container.decodeIfPresent(ImageVersionItem.self, forKey: .qcow2)
		lxd = try container.decodeIfPresent(ImageVersionItem.self, forKey: .lxd)
		squashfs = try container.decodeIfPresent(ImageVersionItem.self, forKey: .squashfs)

		// Ubuntu server
		diskImg = try container.decodeIfPresent(ImageVersionItem.self, forKey: .diskImg)
		vmdk = try container.decodeIfPresent(ImageVersionItem.self, forKey: .vmdk)
		ova = try container.decodeIfPresent(ImageVersionItem.self, forKey: .ova)
		targz = try container.decodeIfPresent(ImageVersionItem.self, forKey: .targz)
		vhd = try container.decodeIfPresent(ImageVersionItem.self, forKey: .vhd)
	}

	var imageDisk: ImageVersionItem? {
		if let diskImage = self.diskImg {
			return diskImage
		}

		if let qcow2 = self.qcow2 {
			return qcow2
		}

		return nil
	}
}

struct ImageVersionItem: Codable {
	let ftype: String
	let path: String
	let size: Int
	let sha256: String
	let md5: String?

	enum CodingKeys: String, CodingKey {
		case ftype
		case path
		case size
		case sha256
		case md5
	}

	init(from decoder: Decoder) throws {
		let container: KeyedDecodingContainer<ImageVersionItem.CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)

		ftype = try container.decode(String.self, forKey: .ftype)
		path = try container.decode(String.self, forKey: .path)
		size = try container.decode(Int.self, forKey: .size)
		sha256 = try container.decode(String.self, forKey: .sha256)
		md5 = try container.decodeIfPresent(String.self, forKey: .md5)
	}
}

class LinuxContainerImage: Codable {
	let alias: [String]?
	let path: URL
	let size: Int
	let fingerprint: String
	let remoteName: String
	let description: String

	init(remoteName: String, fingerprint: String, alias: [String]?, description: String, path: URL, size: Int) {
		self.alias = alias
		self.path = path
		self.size = size
		self.fingerprint = fingerprint
		self.remoteName = remoteName
		self.description = description
	}

	func pullSimpleStreamImageAndConvert() async throws {
		let imageCache: SimpleStreamsImageCache = try SimpleStreamsImageCache(name: remoteName)
		let cacheLocation = try imageCache.directoryFor(directoryName: self.fingerprint).appendingPathComponent("disk.img", isDirectory: false)

		if let cached = imageCache.getCache(fingerprint: fingerprint) {
			if FileManager.default.fileExists(atPath: cacheLocation.path) && cached.fingerprint == self.fingerprint {
				return
			}
		}

		try imageCache.addCache(fingerprint: fingerprint, url: self.path.absoluteURL, kind: CacheEntryKind.image, alias: self.alias)

		try await CloudImageConverter.retrieveRemoteImageCacheItAndConvert(from: self.path, to: nil, cacheLocation: cacheLocation)
	}

	func retrieveSimpleStreamImageAndConvert(to: URL) async throws {
		let imageCache: SimpleStreamsImageCache = try SimpleStreamsImageCache(name: remoteName)
		let cacheLocation = try imageCache.directoryFor(directoryName: self.fingerprint).appendingPathComponent("disk.img", isDirectory: false)

		if let cached = imageCache.getCache(fingerprint: fingerprint) {
			if FileManager.default.fileExists(atPath: cacheLocation.path) && cached.fingerprint == self.fingerprint {
				let temporaryLocation = try Home(asSystem: runAsSystem).temporaryDirectory.appendingPathComponent(UUID().uuidString + ".img")

				try cacheLocation.updateAccessDate() 
				try FileManager.default.copyItem(at: cacheLocation, to: temporaryLocation)

				_ = try FileManager.default.replaceItemAt(to, withItemAt: temporaryLocation)
			}
		}

		try imageCache.addCache(fingerprint: fingerprint, url: self.path.absoluteURL, kind: CacheEntryKind.image, alias: self.alias)

		try await CloudImageConverter.retrieveRemoteImageCacheItAndConvert(from: self.path, to: to, cacheLocation: cacheLocation)
	}
}

extension HTTPURLResponse {
	func ETag() -> String? {
		guard var etag = self.value(forHTTPHeaderField: "etag") else {
			return nil
		}

		// Strange etag returned....
		if etag.starts(with: "W/\"") && etag.hasSuffix("\"") {
			let range = etag.index(etag.startIndex, offsetBy: 3)..<etag.index(etag.startIndex, offsetBy: etag.count - 1)

			etag = String(etag[range])
		} else {
			etag.trim { (ch: Character) in
				ch == "\""
			}
		}

		return etag
	}
}

class SimpleStreamProtocol {
	private let baseURL: URL
	private let name: String
	private let index: SimpleStream

	convenience init(baseURL: URL) async throws {
		try await self.init(name: baseURL.host()!, baseURL: baseURL)
	}

	init(name: String, baseURL: URL) async throws {
		guard let indexURL = URL(string: "streams/v1/index.json", relativeTo: baseURL) else {
			throw SimpleStreamError("unable to decode url:\(baseURL)")
		}

		self.baseURL = baseURL
		self.name = name
		self.index = try await Streamable.loadSimpleStreamObject(remoteURL: indexURL, remoteName: name, cachedFile: "index.json", kind: CacheEntryKind.index)
	}

	public func GetImagesIndexURL() throws -> URL {
		let images = try self.index.images

		if let imageURL = URL(string: images.path, relativeTo: self.baseURL)?.absoluteURL {
			return imageURL
		}

		throw SimpleStreamError("internal error")
	}

	// Load images index from container URL
	private func loadSimpleStreamImages() async throws -> SimpleStreamImageIndex {
		let imageURL = try self.GetImagesIndexURL()

		return try await Streamable.loadSimpleStreamObject(remoteURL: imageURL, remoteName: self.name, cachedFile: "images.json", kind: CacheEntryKind.stream)
	}

	public func GetImages() async throws -> [SimpleStreamProduct] {
		let currentArch = Architecture.current()

		// Try to load images index
		let imageIndex: SimpleStreamImageIndex = try await self.loadSimpleStreamImages()
		var foundProducts: [SimpleStreamProduct] = []

		imageIndex.products.forEach { (key: String, value: SimpleStreamProduct) in
			if value.arch == currentArch && value.variant == "cloud" {
				foundProducts.append(value)
			}
		}

		return foundProducts
	}

	public func GetImage(alias: String) async throws -> SimpleStreamProduct {
		let currentArch = Architecture.current()
		let images = try self.index.images

		// Check if alias exists in product
		// Ubuntu streams doesn't have the same semantic.
		if alias.isFingerPrint() == false {
			if self.index.linuxContainers {
				let found: [String] = images.filter(arch: currentArch.rawValue).filter { (v: String) in
					var item: String = v

					if let range: Range<String.Index> = item.range(of: ":\(currentArch.rawValue)") {
						item.removeSubrange(range)
					}

					return item.replacing(":", with: "/").starts(with: alias)
				}

				// Not found
				if found.count == 0 {
					throw SimpleStreamError("image alias (\(alias)) not found")
				}
			}
		}

		// Try to load images index
		let imageIndex: SimpleStreamImageIndex = try await self.loadSimpleStreamImages()
		let foundVersions = imageIndex.products.firstNonNil {
			(key: String, value: SimpleStreamProduct) in
			if value.arch == currentArch {
				let productAliases: [String] = value.aliases.components(separatedBy: ",")

				if productAliases.firstIndex(of: alias) != nil {
					return value
				}

				// Try to found by fingerprint
				let version = value.versions.first { (key: String, value: ImageVersion) in
					if let image = value.items.imageDisk {
						if alias.count == 12 {
							return image.sha256.starts(with: alias)
						} else {
							return image.sha256 == alias
						}
					}

					return false
				}

				if version != nil {
					return value
				}
			}

			return nil
		}

		// Must be found!
		guard let foundVersions = foundVersions else {
			throw SimpleStreamError("image alias (\(alias)) not found for current architecture")
		}

		if foundVersions.variant != "cloud" {
			throw SimpleStreamError("image alias (\(alias)) doesn't support cloud-init")
		}

		return foundVersions
	}

	public func GetImageAlias(alias: String) async throws -> LinuxContainerImage {
		let product = try await self.GetImage(alias: alias)

		if let imageVersion = product.latest() {
			let imageDisk: ImageVersionItem = imageVersion.1.items.imageDisk!

			return LinuxContainerImage(
				remoteName: self.name,
				fingerprint: imageDisk.sha256,
				alias: product.aliases.components(separatedBy: ","),
				description: "\(product.os) \(product.releaseTitle) \(product.arch) (\(product.release)) \(imageVersion.0)",
				path: URL(string: imageDisk.path, relativeTo: self.baseURL)!.absoluteURL,
				size: imageDisk.size)
		}

		throw SimpleStreamError("alias (\(alias)) doesn't offer qcow2 image")
	}
}
