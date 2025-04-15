import Foundation
import Virtualization

protocol Purgeable {
	var url: URL { get }
	func source() -> String
	func name() -> String
	func fingerprint() -> String?
	func delete() throws
	func accessDate() throws -> Date
	func sizeBytes() throws -> Int
	func allocatedSizeBytes() throws -> Int
}

extension Purgeable {
	func fingerprint() -> String? {
		nil
	}
}

protocol PurgeableStorage {
	func purgeables() throws -> [Purgeable]
}

final class CacheError : Error, Sendable {
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
			self.baseURL = try Home(asSystem: runAsSystem).cacheDirectory.appendingPathComponent(self.location, isDirectory: true).appendingPathComponent(self.name, isDirectory: true)
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
			self.baseURL = try Home(asSystem: runAsSystem).cacheDirectory.appendingPathComponent(self.location, isDirectory: true)
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

	func fqn(_ purgeable: Purgeable) -> [String] {
		["\(self.scheme)://\(purgeable.source())/\(purgeable.name())"]
	}

	func type() -> String {
		self.location
	}
}

class TemplateImageCache: CommonCacheImageCache {
	static let scheme = "template"

	convenience init() throws {
		try self.init(name: "")
	}

	init(name: String) throws {
		try super.init(scheme: Self.scheme, location: "templates", name: name, root: try Home(asSystem: runAsSystem).cakeHomeDirectory)
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
		if FileManager.default.fileExists(atPath: from.absoluteURL.path) {
			let content = try Data(contentsOf: from)

			return try PropertyListDecoder().decode(SimpleStreamCache.self, from: content)
		}

		return SimpleStreamCache()
	}

	func reduce<Result>(_ initialResult: Result, _ nextPartialResult: (Result, (key: String, value: CacheEntry)) throws -> Result) rethrows -> Result {
		return try self.cache.reduce(initialResult) { (result: Result, element: (key: String, value: CacheEntry)) in
			try nextPartialResult(result, element)
		}
	}

	func reduce<Result>(into initialResult: Result, _ updateAccumulatingResult: (inout Result, String) throws -> ()) rethrows -> Result {
		return try self.cache.reduce(into: initialResult) { (result: inout Result, element: (key: String, value: CacheEntry)) in
			try updateAccumulatingResult(&result, element.key)
		}
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

	override func type() -> String {
		"stream"
	}

	override func fqn(_ purgeable: Purgeable) -> [String] {
		guard let purgeable = purgeable as? SimpleStreamsImageCachePurgeable else {
			return super.fqn(purgeable)
		}

		return purgeable.fqn()
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
		let _remote: String
		let _fingerprint: String
		let _aliases: [String]?
		let _source: String
		let _cache: SimpleStreamsImageCache

		init(remote: String, fingerprint: String, aliases: [String]?, url: URL, source: String, cache: SimpleStreamsImageCache) {
			self._url = url
			self._remote = remote
			self._fingerprint = fingerprint
			self._aliases = aliases
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
			self._fingerprint
		}

		func fingerprint() -> String? {
			self._fingerprint
		}

		func delete() throws {
			try _cache.deleteCache(fingerprint: self._fingerprint)

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

		func fqn() -> [String] {
			if let aliases = self._aliases {
				return aliases.reduce(into: ["\(_remote)://\(self._fingerprint)"]) { fqn, alias in
					fqn.append("\(self._remote)://\(alias)")
				}
			} else {
				return ["\(_remote)://\(self._fingerprint)"]
			}
		}			
	}

	func purgeables(remote: String) throws -> [Purgeable] {
		let purgeableItems: [Purgeable] = []

		return self.cache!.reduce(into: purgeableItems) { (result: inout [Purgeable], key: String) in
			if let cache = self.cache?.getCache(fingerprint: key) {
				if cache.kind == .image {
					let baseURL = self.baseURL.appendingPathComponent("\(key)/disk.img")
					let source = baseURL.lastPathComponent

					result.append(SimpleStreamsImageCachePurgeable(remote: remote, fingerprint: key, aliases: cache.alias, url: baseURL, source: source, cache: self))
				}
			}
		}

	}

	override func purgeables() throws -> [Purgeable] {
		let remoteDb = try Home(asSystem: runAsSystem).remoteDatabase()
		var purgeableItems: [Purgeable] = []

		try FileManager.default.contentsOfDirectory(at: self.baseURL, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles).forEach { url in
			if let remote = remoteDb.reverseLookup(url.lastPathComponent) {
				purgeableItems.append(contentsOf: try SimpleStreamsImageCache(name: url.lastPathComponent).purgeables(remote: remote))	
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
		let _sha256: String
		let _source: String

		init(name: String, sha256: String, url: URL, source: String) {
			self._url = url
			self._name = name
			self._source = source
			self._sha256 = sha256
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

		func fingerprint() -> String? {
			String(self._sha256.dropFirst("sha256:".count))
		}

		func fqn() -> [String] {
			["\(OCIImageCache.scheme)://\(self._source)@\(self._sha256)"]
		}
	}

	override func purgeables() throws -> [Purgeable] {
		return try super.purgeables().map { purgeable in
			let root = purgeable.url.deletingLastPathComponent()
			let container = root.deletingLastPathComponent()
			let source = container.absoluteURL.path.stringAfter(after: self.baseURL.absoluteURL.path).stringBeforeLast(before: "/")

			return OCIImageCachePurgeable(name: container.lastPathComponent, sha256: root.lastPathComponent, url: purgeable.url, source: source)
		}
	}

	override func fqn(_ purgeable: Purgeable) -> [String] {
		guard let purgeable = purgeable as? OCIImageCachePurgeable else {
			return super.fqn(purgeable)
		}

		return purgeable.fqn()
	}
}
