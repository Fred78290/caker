import Foundation
import Virtualization

protocol Purgeable {
  var url: URL { get }
  func source() -> String
  func name() -> String
  func delete() throws
  func accessDate() throws -> Date
  func sizeBytes() throws -> Int
  func allocatedSizeBytes() throws -> Int
}

protocol PurgeableStorage {
  func purgeables() throws -> [Purgeable]
}

class CacheError : Error {
	let description: String

	init(_ what: String) {
		self.description = what
	}
}

class CommonCacheImageCache: PurgeableStorage {
	let baseURL: URL
	let scheme: String
	let name: String
	let location: String
	private let ext: String

	init(scheme: String, location: String, name: String, ext: String = "img", root: URL? = nil) throws {
		self.scheme = scheme
		self.name = name
		self.location = location
		self.ext = ext

		if let root = root {
			self.baseURL = root.appendingPathComponent(self.location, isDirectory: true).appendingPathComponent(self.name, isDirectory: true)
		} else {
			self.baseURL = try Home(asSystem: runAsSystem).cacheDir.appendingPathComponent(self.location, isDirectory: true).appendingPathComponent(self.name, isDirectory: true)
		}

		try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
	}

	init(scheme: String, location: String, ext: String = "img", root: URL? = nil) throws {
		self.scheme = scheme
		self.name = ""
		self.location = location
		self.ext = ext

		if let root = root {
			self.baseURL = root.appendingPathComponent(self.location, isDirectory: true)
		} else {
			self.baseURL = try Home(asSystem: runAsSystem).cacheDir.appendingPathComponent(self.location, isDirectory: true)
		}

		try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
	}

	func locationFor(fileName: String) -> URL {
		baseURL.appendingPathComponent(fileName, isDirectory: false).absoluteURL
	}

	func directoryFor(directoryName: String) throws -> URL {
		let dirUrl = baseURL.appendingPathComponent(directoryName, isDirectory: true).absoluteURL

		try FileManager.default.createDirectory(at: dirUrl, withIntermediateDirectories: true)

		return dirUrl
	}

	func purgeables() throws -> [Purgeable] {
		var purgeableItems: [Purgeable] = []

		if let fileURLs: FileManager.DirectoryEnumerator = FileManager.default.enumerator(at: baseURL, includingPropertiesForKeys: [.isRegularFileKey], options: .skipsHiddenFiles) {
			for case let fileURL as URL in fileURLs {
				if fileURL.pathExtension == self.ext {
					purgeableItems.append(fileURL)
				}
			}
		}

		return purgeableItems
	}

	func fqn(_ purgeable: Purgeable) -> String {
		"\(self.scheme)://\(purgeable.source())/\(purgeable.name())"
	}
}

class TemplateImageCache: CommonCacheImageCache {
	static let scheme = "template"

	convenience init() throws {
		try self.init(name: "")
	}

	init(name: String) throws {
		try super.init(scheme: Self.scheme, location: "templates", name: name, root: try Home(asSystem: runAsSystem).homeDir)
	}
}

class CloudImageCache: CommonCacheImageCache {
	static let scheme = "cloud"

	convenience init() throws {
		try self.init(name: "")
	}

	init(name: String) throws {
		try super.init(scheme: Self.scheme, location: "cloud-images", name: name)
	}
}

class RawImageCache: CommonCacheImageCache {
	static let scheme = "img"

	init() throws {
		try super.init(scheme: Self.scheme, location: "raw-images")
	}
}

enum CacheEntryKind: String, Codable {
	case index = "index"
	case stream = "stream"
	case image = "image"
}

struct CacheEntry: Codable {
	let url: URL
	let kind: CacheEntryKind
	let fingerprint: String
	var alias: [String]? = nil
}

struct SimpleStreamCache: Codable {
	private var cache: Dictionary<String, CacheEntry>
	private var dirty: Bool = false

	enum CodingKeys: String, CodingKey {
		case cache
	}

	init () {
		self.cache = [:]
	}

	static func createSimpleStreamCache(from:URL) throws -> SimpleStreamCache {
		if FileManager.default.fileExists(atPath: from.absoluteURL.path()) {
			let content = try Data(contentsOf: from)

			return try PropertyListDecoder().decode(SimpleStreamCache.self, from: content)
		}

		return SimpleStreamCache()
	}

	func compactMap<ElementOfResult>(_ transform: ((key: String, value: CacheEntry)) throws -> ElementOfResult?) rethrows -> [ElementOfResult] {
		return try self.cache.compactMap { (key: String, value: CacheEntry) in
			try transform((key: key, value: value))
		}
	}

	func map<T>(_ transform: ((key: String, value: CacheEntry)) throws -> T) throws -> [T] {
		return try self.cache.map { (key: String, value: CacheEntry) in
			try transform((key: key, value: value))
		}
	}

	func findCache(fingerprintOrAlias: String) -> CacheEntry? {
		let first = self.cache.first { (key: String, value: CacheEntry) in
			if key.contains(fingerprintOrAlias) {
				return true
			}

			if let alias = value.alias {
				return alias.contains(fingerprintOrAlias)
			}

			return false
		}

		if let first = first {
			return first.value
		}

		return nil
	}

	func getCache(fingerprint: String) -> CacheEntry? {
		return self.cache[fingerprint]
	}

	mutating func deleteCache(fingerprint: String) -> CacheEntry?{
		self.dirty = true
		return self.cache.removeValue(forKey: fingerprint)
	}

	mutating func addCache(fingerprint: String, entry: CacheEntry) {
		self.dirty = true
		self.cache[fingerprint] = entry
	}

	func save(to: URL) throws {
		if self.dirty {
			let encoder: PropertyListEncoder = PropertyListEncoder()
			encoder.outputFormat = .xml

			let data = try encoder.encode(self)
			try data.write(to: to)
		}
	}
}

class SimpleStreamsImageCache: CommonCacheImageCache {
	static let scheme = "stream"
	private var cache: SimpleStreamCache?

	convenience init() throws {
		try self.init(name: "")
	}

	init(name: String) throws {
		try super.init(scheme: Self.scheme, location: "container-images", name: name, ext: ".img")

		if name.count > 0 {
			self.cache = try SimpleStreamCache.createSimpleStreamCache(from: URL(fileURLWithPath: "cache.plist", relativeTo: self.baseURL))
		}
	}

	deinit {
		if let cache = self.cache {
			try? cache.save(to: URL(fileURLWithPath: "cache.plist", relativeTo: self.baseURL))
		}
	}

	func findCache(fingerprintOrAlias: String) -> CacheEntry? {
		return self.cache?.findCache(fingerprintOrAlias: fingerprintOrAlias)
	}

	func getCache(fingerprint: String) -> CacheEntry? {
		return self.cache?.getCache(fingerprint: fingerprint)
	}

	func deleteCache(fingerprint: String) throws {
		if self.cache?.deleteCache(fingerprint: fingerprint) != nil {
			try? self.cache?.save(to: URL(fileURLWithPath: "cache.plist", relativeTo: self.baseURL))
		}
	}

	func addCache(fingerprint: String, url: URL, kind: CacheEntryKind, alias: [String]?) throws {
		self.cache?.addCache(fingerprint: fingerprint, entry: CacheEntry(url: url, kind: kind, fingerprint: fingerprint, alias: alias))
		try? self.cache?.save(to: URL(fileURLWithPath: "cache.plist", relativeTo: self.baseURL))
	}

	func purgeDirectory() throws {
		try FileManager.default.removeItem(at: self.baseURL)
		try FileManager.default.createDirectory(at: self.baseURL, withIntermediateDirectories: true)
	}

	func _aliasLocation(alias: String) throws -> URL {
		var alias = alias

		alias.replace("/", with: ":")

		return try self.directoryFor(directoryName: alias)
	}

	private class SimpleStreamsImageCachePurgeable: Purgeable {
		let _url: URL
		let _name: String
		let _source: String
		let _cache: SimpleStreamsImageCache

		init(name: String, url: URL, source: String, cache: SimpleStreamsImageCache) {
			self._url = url
			self._name = name
			self._source = source
			self._cache = cache
		}

	    var url: URL {
	        self._url
		}

	    func source() -> String {
	        self._source
	    }

	    func name() -> String {
	        self._name
	    }

	    func delete() throws {
			try _cache.deleteCache(fingerprint: self._name)

			try FileManager.default.removeItem(at: self._url.deletingLastPathComponent())
	    }

	    func accessDate() throws -> Date {
	        try self._url.accessDate()
	    }

	    func sizeBytes() throws -> Int {
	        try self._url.sizeBytes()
	    }

	    func allocatedSizeBytes() throws -> Int {
	        try self._url.allocatedSizeBytes()
	    }

		func fqn() -> String {
			"\(_cache.scheme)://\(_source)/@\(_name)"
		}
	}

	override func purgeables() throws -> [Purgeable] {
		var purgeableItems: [Purgeable] = []

		if let cache = self.cache {
			purgeableItems.append(contentsOf: cache.compactMap { (key: String, value: CacheEntry) in
				var result: SimpleStreamsImageCachePurgeable? = nil

				if value.kind == .image {
					result = SimpleStreamsImageCachePurgeable(name: key, url: self.baseURL.appendingPathComponent("\(key)/disk.img"), source: self.baseURL.lastPathComponent, cache: self)
				}

				return result
			})
		} else {
			try FileManager.default.contentsOfDirectory(at: self.baseURL, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles).forEach { url in
				let cache = try SimpleStreamsImageCache(name: url.lastPathComponent)

				try purgeableItems.append(contentsOf: cache.purgeables())
			}
		}

		return purgeableItems
	}
}

class OCIImageCache: CommonCacheImageCache {
	static let scheme = "oci"

	init() throws {
		try super.init(scheme: Self.scheme, location: "OCIs")
	}

	private class OCIImageCachePurgeable: Purgeable {
		let _url: URL
		let _name: String
		let _source: String

		init(name: String, url: URL, source: String) {
			self._url = url
			self._name = name
			self._source = source
		}

	    var url: URL {
	        self._url
		}

	    func source() -> String {
	        self._source
	    }

	    func name() -> String {
	        self._name
	    }

	    func delete() throws {
			try self._url.deletingLastPathComponent().delete()
	    }

	    func accessDate() throws -> Date {
	        try self._url.accessDate()
	    }

	    func sizeBytes() throws -> Int {
	        try self._url.sizeBytes()
	    }

	    func allocatedSizeBytes() throws -> Int {
	        try self._url.allocatedSizeBytes()
	    }
	}

	override func purgeables() throws -> [Purgeable] {
		return try super.purgeables().map { purgeable in
			let root = purgeable.url.deletingLastPathComponent()
			let container = root.deletingLastPathComponent()
			let name = root.lastPathComponent
			let source = container.absoluteURL.path().stringAfter(after: self.baseURL.absoluteURL.path()).stringBeforeLast(before: "/")

			return OCIImageCachePurgeable(name: name, url: purgeable.url, source: source)
		}
	}

	override func fqn(_ purgeable: Purgeable) -> String {
		"\(self.scheme)://\(purgeable.source())@\(purgeable.name())"
	}
}
