import Foundation
import Virtualization

class CacheError : Error {
  let description: String

  init(_ what: String) {
    self.description = what
  }
}

class CommonCacheImageCache: PrunableStorage {
  let baseURL: URL
  let name: String
  let location: String
  let ext: String

  init(location: String, name: String, ext: String) throws {
    self.name = name
    self.location = location
    self.ext = ext

    let root = try Config().tartCacheDir.appendingPathComponent(location, isDirectory: true)
    self.baseURL = root.appendingPathComponent(self.name, isDirectory: true)
    try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
  }

  init(location: String, ext: String) throws {
    self.name = ""
    self.location = location
    self.ext = ext

    baseURL = try Config().tartCacheDir.appendingPathComponent(self.location, isDirectory: true).absoluteURL
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

  func prunables() throws -> [Prunable] {
    try FileManager.default.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: nil)
      .filter { $0.lastPathComponent.hasSuffix(self.ext)}
  }
}

class CloudImageCache: CommonCacheImageCache {
  convenience init() throws {
    try self.init(name: "")
  }

  init(name: String) throws {
    try super.init(location: "cloud-images", name: name, ext: ".img")
  }
}

class RawImageCache: CommonCacheImageCache {
  init() throws {
    try super.init(location: "raw-images", ext: ".img")
  }
}

struct CacheEntry: Codable {
  let url: URL
  let fingerprint: String
}

struct SimpleStreamCache: Codable {
  var cache: Dictionary<String, CacheEntry>
  var dirty: Bool = false

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

  func getCache(name: String) -> CacheEntry? {
    return self.cache[name]
  }

  mutating func addCache(name: String, entry: CacheEntry) {
    self.dirty = true
    self.cache[name] = entry
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
  private var cache: SimpleStreamCache?

  convenience init() throws {
    try self.init(name: "")
  }

  init(name: String) throws {
    try super.init(location: "container-images", name: name, ext: ".img")

    if name.count > 0 {
      self.cache = try SimpleStreamCache.createSimpleStreamCache(from: URL(fileURLWithPath: "cache.plist", relativeTo: self.baseURL))
    }
  }

  deinit {
    if let cache = self.cache {
      try? cache.save(to: URL(fileURLWithPath: "cache.plist", relativeTo: self.baseURL))
    }
  }

  func getCache(name: String) -> CacheEntry? {
    return self.cache?.getCache(name: name)
  }

  func addCache(name: String, url: URL, fingerprint: String) {
    self.cache?.addCache(name: name, entry: CacheEntry(url: url, fingerprint: fingerprint))
    try? self.cache?.save(to: URL(fileURLWithPath: "cache.plist", relativeTo: self.baseURL))
  }

  func purgeDirectory() throws {
    try FileManager.default.removeItem(at: self.baseURL)
    try FileManager.default.createDirectory(at: self.baseURL, withIntermediateDirectories: true)
  }

  func aliasLocation(alias: String) throws -> URL {
    var alias = alias

    alias.replace("/", with: ":")

    return try self.directoryFor(directoryName: alias)
  }
}
