//
//  VMImageCatalog.swift
//  CakedLib
//
//  Created by Frederic BOLTZ on 08/08/2026.
//
//  Originally lived in the `caker` GUI target (as `Sources/caker/VMImageCatalog.swift`, reading
//  `Sources/caker/Resources/VMImages.json`) and was only ever consulted by the wizard. It moved
//  here so `caked`/`cakectl` — which don't depend on `caker` — can resolve catalog ids too (see
//  `BuildOptions.alias`, e.g. `--alias macos12`, and its resolution in `VMBuilder.swift`, plus
//  `aliasEntries` below, listed by `caked aliases` and served to `cakectl aliases` through caked's
//  `Aliases` RPC).
//

import CakeAgentLib
import Foundation
import GRPCLib
import Synchronization

public struct VMImageEntry: Codable, Identifiable, Hashable, Sendable {
	public let id: String
	public let label: String
	public let url: String
	/// Minimum CPU count / memory (MiB) the wizard should apply when this entry is selected.
	public let minCPU: UInt16
	public let minMemoryMiB: UInt64
	
	public init(id: String, label: String, url: String, minCPU: UInt16, minMemoryMiB: UInt64) {
		self.id = id
		self.label = label
		self.url = url
		self.minCPU = minCPU
		self.minMemoryMiB = minMemoryMiB
	}
}

public struct VMImageArchCatalog: Codable, Sendable {
	public let iso: [VMImageEntry]
	public let cloud: [VMImageEntry]
	#if arch(arm64)
		public let ipsw: [VMImageEntry]
	#endif

	enum CodingKeys: String, CodingKey {
		case iso
		case cloud
		#if arch(arm64)
			case ipsw
		#endif
	}

	#if arch(arm64)
		init(iso: [VMImageEntry], cloud: [VMImageEntry], ipsw: [VMImageEntry]) {
			self.iso = iso
			self.cloud = cloud
			self.ipsw = ipsw
		}
	#else
		init(iso: [VMImageEntry], cloud: [VMImageEntry]) {
			self.iso = iso
			self.cloud = cloud
		}
	#endif

	/// A copy whose cloud entry `id` points at `url`; `self` when there is no such entry.
	func replacingCloudURL(id: String, with url: String) -> VMImageArchCatalog {
		guard let entry = cloud.first(where: { $0.id == id }), entry.url != url else {
			return self
		}

		let cloud = self.cloud.map { $0.id == id ? VMImageEntry(id: $0.id, label: $0.label, url: url, minCPU: $0.minCPU, minMemoryMiB: $0.minMemoryMiB) : $0 }

		#if arch(arm64)
			return VMImageArchCatalog(iso: iso, cloud: cloud, ipsw: ipsw)
		#else
			return VMImageArchCatalog(iso: iso, cloud: cloud)
		#endif
	}

	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)

		self.iso = try container.decode([VMImageEntry].self, forKey: .iso)
		self.cloud = try container.decode([VMImageEntry].self, forKey: .cloud)
		#if arch(arm64)
			// Optional: the `amd64` section has no `ipsw` list (macOS guests need Apple Silicon), but an
			// arm64 build still decodes that section, so a required key would fail the whole catalog.
			self.ipsw = try container.decodeIfPresent([VMImageEntry].self, forKey: .ipsw) ?? []
		#endif
	}
}

/// `Bundle.module` only exists in genuine `swift build`/`swift test` builds (SPM generates its accessor
/// per target). The two hand-mirrored Xcode projects (`Caker.xcodeproj`/`CakerAppStore.xcodeproj`)
/// compile this file as part of the plain native `CakedLib` target with no such accessor, so resource
/// lookup has to branch on which build system produced this binary — same pattern already used by
/// `PackerLiteTemplateResolver.swift` for the bundled PackerLite templates.
private final class VMImageCatalogResourceBundleMarker {}

private let vmImageCatalogResourceBundle: Bundle = {
	#if SWIFT_PACKAGE
		return Bundle.module
	#else
		let containingBundle = Bundle(for: VMImageCatalogResourceBundleMarker.self)

		for candidate in ["Caker_CakedLib.bundle", "CakedLib_CakedLib.bundle"] {
			if let url = containingBundle.resourceURL?.appendingPathComponent(candidate), let bundle = Bundle(url: url) {
				return bundle
			}
		}

		return containingBundle
	#endif
}()

public struct VMImageCatalog: Codable, Sendable {
	public let arm64: VMImageArchCatalog
	public let amd64: VMImageArchCatalog

	/// The loaded catalog, and the modification date of the `<CAKE_HOME>/VMImages.json` override it
	/// was read with (nil: no override) — what `reloadIfChanged()` compares against.
	private struct Loaded: Sendable {
		let catalog: VMImageCatalog
		let overrideDate: Date?
	}

	// `shared` is read from the UI and written by `refreshFromGitHub()`'s background task —
	// `Mutex` (matching the pattern already used for e.g. `ARPParser`'s static cache) keeps that
	// safe instead of racing on a bare `static var`.
	private static let storage: Mutex<Loaded> = Mutex(load())

	public static var shared: VMImageCatalog {
		storage.withLock { $0.catalog }.applyingLatestImages()
	}

	/// `shared`, re-read first when `<CAKE_HOME>/VMImages.json` was added, changed or removed since it
	/// was loaded. For a long-running caked, which would otherwise keep serving (and resolving
	/// `--alias` against) the catalog it read at startup after Caker.app's `refreshFromGitHub()`
	/// or a hand edit replaces the file. Costs one `stat` per call.
	public static func reloadIfChanged() -> VMImageCatalog {
		reloadIfChanged(overrideURL: cakeHomeCatalogURL(createHomeIfNeeded: false))
	}

	/// `internal` so tests can point it at a temporary file instead of the real `<CAKE_HOME>`.
	static func reloadIfChanged(overrideURL: URL?) -> VMImageCatalog {
		let date = modificationDate(overrideURL)

		return storage.withLock { loaded in
			if loaded.overrideDate != date {
				loaded = Loaded(catalog: load(overrideURL: overrideURL) ?? loadBundled(), overrideDate: date)
			}

			return loaded.catalog
		}.applyingLatestImages()
	}

	/// Raw JSON on the `main` branch — kept in sync with `Sources/cakedlib/Resources/VMImages.json`.
	public static let githubCatalogURL = URL(string: "https://raw.githubusercontent.com/Fred78290/caker/main/Sources/cakedlib/Resources/VMImages.json")!

	public var current: VMImageArchCatalog {
		#if arch(arm64)
			return arm64
		#else
			return amd64
		#endif
	}

	public var availableISOImages: [VMImageEntry] {
		current.iso
	}

	#if arch(arm64)
		public var availableIPSWImages: [VMImageEntry] {
			current.ipsw
		}
		public func ipswImage(_ id: String) -> VMImageEntry {
			guard let entry = current.ipsw.first(where: { $0.id == id }) else {
				fatalError("Unknown IPSW image id \(id) in VMImages.json")
			}

			return entry
		}

	#endif

	public var availableCloudImages: [VMImageEntry] {
		current.cloud
	}

	public func isoImage(_ id: String) -> VMImageEntry {
		guard let entry = current.iso.first(where: { $0.id == id }) else {
			fatalError("Unknown ISO image id \(id) in VMImages.json")
		}

		return entry
	}

	public func cloudImage(_ id: String) -> VMImageEntry {
		guard let entry = current.cloud.first(where: { $0.id == id }) else {
			fatalError("Unknown cloud image id \(id) in VMImages.json")
		}

		return entry
	}

	/// `<CAKE_HOME>/VMImages.json` — when present, overrides the bundled catalog. Written by
	/// `refreshFromGitHub()`, or dropped there by hand to pin/customize the wizard's image list.
	private static func cakeHomeCatalogURL(createHomeIfNeeded: Bool) -> URL? {
		guard let home = try? Utils.getHome(runMode: .app, createItIfNotExists: createHomeIfNeeded) else {
			return nil
		}

		return home.appendingPathComponent("VMImages.json", isDirectory: false)
	}

	private static func load(overrideURL: URL?) -> VMImageCatalog? {
		guard let url = overrideURL, FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
			return nil
		}

		return try? JSONDecoder().decode(VMImageCatalog.self, from: Data(contentsOf: url))
	}

	private static func modificationDate(_ url: URL?) -> Date? {
		guard let url else {
			return nil
		}

		return (try? FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false)))?[.modificationDate] as? Date
	}

	/// `internal` (not `private`) so tests can load the bundled file directly — `shared` prefers a
	/// `<CAKE_HOME>/VMImages.json` override, which would hide a bundled-file decoding failure.
	static func loadBundled() -> VMImageCatalog {
		func loadCatalog(_ url: URL) -> VMImageCatalog {
			do {
				let data = try Data(contentsOf: url)
				return try JSONDecoder().decode(VMImageCatalog.self, from: data)
			} catch {
				fatalError("Failed to load VMImages.json: \(error)")
			}
		}

		if let url = Bundle.main.url(forResource: "VMImages", withExtension: "json") {
			return loadCatalog(url)
		}

		guard let url = vmImageCatalogResourceBundle.url(forResource: "VMImages", withExtension: "json") else {
			fatalError("VMImages.json resource not found in the app bundle — add it to the target's \"Copy Bundle Resources\" build phase in Xcode")
		}

		return loadCatalog(url)
	}

	/// Load order: a `<CAKE_HOME>/VMImages.json` override, if present and valid, else the bundled
	/// resource. A malformed override is skipped (falls through) rather than crashing the app, since
	/// unlike the bundled resource it's user-supplied state, not a packaging invariant.
	private static func load() -> Loaded {
		let overrideURL = cakeHomeCatalogURL(createHomeIfNeeded: false)

		return Loaded(catalog: load(overrideURL: overrideURL) ?? loadBundled(), overrideDate: modificationDate(overrideURL))
	}

	/// Downloads the latest catalog from GitHub, caches it to `<CAKE_HOME>/VMImages.json`, and updates
	/// `shared` in place so an already-running session picks it up (SwiftUI reads `.shared` live on
	/// every render rather than caching it in view state). Throws on network/decode/validation
	/// failure — callers that want a best-effort background refresh should `try?` this.
	///
	/// This trusts `main` on GitHub as a live, mutable source for URLs the wizard hands to the user
	/// as download links — a deliberately narrow extension of the trust the app already places in its
	/// own repo (that's where the binary's source comes from), not a new trust root. The one check
	/// applied here is that every entry resolves to `https://`, so a compromised or malformed catalog
	/// can't quietly downgrade a link to plaintext HTTP or a non-http(s) scheme; it does not attempt
	/// content signing or pinning to a specific release/commit.
	@discardableResult
	public static func refreshFromGitHub(session: URLSession = .shared) async throws -> VMImageCatalog {
		let (data, response) = try await session.data(from: githubCatalogURL)

		guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
			throw ServiceError("Failed to download VMImages.json from GitHub")
		}

		let catalog = try JSONDecoder().decode(VMImageCatalog.self, from: data)

		guard catalog.usesOnlyHTTPS else {
			throw ServiceError("Downloaded VMImages.json contains a non-https:// URL, refusing to trust it")
		}

		// `Utils.getHome` only creates the directory on its first-ever call (it caches the
		// resolved path afterwards), so a prior `createHomeIfNeeded: false` lookup — e.g. from
		// `load()` — can leave it uncreated here despite passing `true`. Create it ourselves too.
		if let destination = cakeHomeCatalogURL(createHomeIfNeeded: true) {
			try? FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
			try? data.write(to: destination, options: .atomic)
		}

		let overrideDate = modificationDate(cakeHomeCatalogURL(createHomeIfNeeded: false))

		storage.withLock { $0 = Loaded(catalog: catalog, overrideDate: overrideDate) }

		return catalog
	}

	private var usesOnlyHTTPS: Bool {
		#if arch(arm64)
			(arm64.iso + arm64.ipsw + arm64.cloud).allSatisfy { $0.url.hasPrefix("https://") }
		#else
			(amd64.iso + amd64.cloud).allSatisfy { $0.url.hasPrefix("https://") }
		#endif
	}
}

/// What a catalog id (`--alias macos12`, `--alias ubuntu2604`, ...) resolves to: the entry's
/// URL, the `GRPCLib.ImageSource` it should be built as, and — for an `ipsw` hit whose id happens
/// to also be a valid `MacOSVersion` raw value — the matching `MacOSVersion`, so callers can
/// auto-populate `BuildOptions.macosVersion` when the user didn't pass `--macos-version`
/// explicitly (see `VMBuilder.buildVM`). Also carries the matched entry's own `minCPU`/
/// `minMemoryMiB`, so callers can raise the build's cpu/memory to at least the catalog's stated
/// minimum for this image — the same `max(current, minimum)` semantics `VMImageEntry
/// .applyMinimumResources` (`Sources/caker/Views/VirtualMachineWizard.swift`) and the web UI's
/// `CreateInstanceModal.tsx` already apply when an entry is picked there (see
/// `VMBuilder.resolveImageId`).
public struct VMImageCatalogResolution: Sendable {
	public let url: String
	public let imageSource: ImageSource
	public let macosVersion: MacOSVersion?
	public let minCPU: UInt16
	public let minMemoryMiB: UInt64
}

extension VMImageCatalog {
	/// Resolves a catalog id (the same ids `--alias` accepts, and that `aliasEntries` below lists)
	/// against this catalog's `current` (arch-appropriate) entries.
	///
	/// Checks `ipsw` → `iso` → `cloud`, in that priority order. Every id in `VMImages.json` is
	/// unique across all three categories — an id that would otherwise collide between `iso` and
	/// `cloud` (e.g. CentOS/openSUSE/Alpine, which ship both an installer ISO and a prebuilt cloud
	/// image) gets an `-iso`-suffixed id on its `iso` entry (`centos10-iso`, `alpine324-iso`, ...),
	/// leaving the bare id on the `cloud` entry, so both remain independently reachable via
	/// `--alias` rather than relying on this priority order to pick one over the other. Returns
	/// `nil` if `id` isn't in this catalog at all —
	/// shouldn't normally happen, since `--alias`'s ids are meant to come from this same catalog,
	/// but a caller should still handle it rather than force-unwrapping.
	public func resolveShorthand(_ id: String) -> VMImageCatalogResolution? {
		#if arch(arm64)
			if let entry = current.ipsw.first(where: { $0.id == id }) {
				return VMImageCatalogResolution(url: entry.url, imageSource: .ipsw, macosVersion: MacOSVersion(rawValue: id), minCPU: entry.minCPU, minMemoryMiB: entry.minMemoryMiB)
			}
		#endif

		if let entry = current.iso.first(where: { $0.id == id }) {
			return VMImageCatalogResolution(url: entry.url, imageSource: .iso, macosVersion: nil, minCPU: entry.minCPU, minMemoryMiB: entry.minMemoryMiB)
		}

		if let entry = current.cloud.first(where: { $0.id == id }) {
			// Cloud images are plain disk images served over https (.img/.qcow2) — exactly what
			// `.qcow2` already means elsewhere in this codebase (see `ImageSource.schemes`'s
			// "https" -> `.qcow2` mapping in `BuildOptions.validateImageSource`). Set it
			// explicitly here rather than leaving `imageSource` nil for a later re-validation
			// pass to infer, since `VMBuilder.buildVM` doesn't re-run that validation.
			return VMImageCatalogResolution(url: entry.url, imageSource: .qcow2, macosVersion: nil, minCPU: entry.minCPU, minMemoryMiB: entry.minMemoryMiB)
		}

		return nil
	}
}

/// One row of `caked aliases`/`cakectl aliases` output — every id `--alias` accepts, tagged with
/// which catalog category (`ipsw`/`iso`/`cloud`) it resolves from.
public struct VMImageAliasEntry: Codable, Sendable {
	public let id: String
	public let category: String
	public let label: String
}

extension VMImageCatalog {
	/// Every entry of `current` (arch-appropriate) tagged with its category, in `ipsw` → `iso` →
	/// `cloud` order — the one list `aliasEntries` and `aliasesReply` are both built from.
	var categorizedEntries: [(category: String, entry: VMImageEntry)] {
		#if arch(arm64)
			current.ipsw.map { (category: "ipsw", entry: $0) } + current.iso.map { (category: "iso", entry: $0) } + current.cloud.map { (category: "cloud", entry: $0) }
		#else
			current.iso.map { (category: "iso", entry: $0) } + current.cloud.map { (category: "cloud", entry: $0) }
		#endif
	}

	/// Every `--alias`-able id in `current` (arch-appropriate), across all three categories —
	/// the data behind `caked aliases` and the `Aliases` RPC that `cakectl aliases` calls.
	public var aliasEntries: [VMImageAliasEntry] {
		categorizedEntries.map { VMImageAliasEntry(id: $0.entry.id, category: $0.category, label: $0.entry.label) }
	}

	/// The `Aliases` RPC's reply: every entry of `current` with its category, URL and minimum
	/// resources — `cakectl aliases` lists it, Caker.app's wizard rebuilds its pickers from it
	/// (`VMImageArchCatalog.init?(_:)`).
	public var aliasesReply: Caked_Reply {
		Caked_Reply.with {
			$0.aliases = .with {
				$0.aliases = self.categorizedEntries.map { item in
					Caked_AliasEntry.with {
						$0.id = item.entry.id
						$0.category = item.category
						$0.label = item.entry.label
						$0.url = item.entry.url
						$0.minCpu = UInt32(item.entry.minCPU)
						$0.minMemoryMiB = item.entry.minMemoryMiB
					}
				}
			}
		}
	}
}

extension VMImageAliasEntry {
	/// Rebuilds an entry received from caked's `Aliases` RPC (`cakectl aliases`).
	public init(_ from: Caked_AliasEntry) {
		self.init(id: from.id, category: from.category, label: from.label)
	}
}

extension VMImageArchCatalog {
	/// Rebuilds a caked's catalog from its `Aliases` reply, for Caker.app's wizard pickers when it is
	/// connected to a caked. Entries without a URL are dropped (a caked that predates the `url` field
	/// sends none), and so are `ipsw` entries in an x86_64 build, which can't offer macOS guests. Nil
	/// when no usable entry is left, so the caller keeps its own catalog.
	public init?(_ from: Caked_AliasesReply) {
		let usable = from.aliases.filter { $0.url.isEmpty == false }

		guard usable.isEmpty == false else {
			return nil
		}

		func entries(_ category: String) -> [VMImageEntry] {
			usable.filter { $0.category == category }.map {
				VMImageEntry(id: $0.id, label: $0.label, url: $0.url, minCPU: UInt16(clamping: $0.minCpu), minMemoryMiB: $0.minMemoryMiB)
			}
		}

		self.iso = entries("iso")
		self.cloud = entries("cloud")
		#if arch(arm64)
			self.ipsw = entries("ipsw")
		#endif
	}
}

extension CakeAgentLib.Format {
	public func render(_ data: [VMImageAliasEntry]) -> String {
		self.renderList(data)
	}
}

// MARK: - Images published under a dated name

extension VMImageCatalog {
	/// Gentoo republishes its cloud image under a new dated name (`di-amd64-cloudinit-20261025T170057Z.qcow2`)
	/// and only keeps a `latest-di-<arch>-cloudinit.txt` manifest pointing at the current one, so the URL
	/// pinned in `VMImages.json` goes stale. The catalog entry `id` is kept as is; its URL is replaced by
	/// the one the manifest names once `refreshLatestImages()` has read it.
	struct LatestImageSource: Sendable {
		let id: String
		let arch: String
		let manifest: URL
	}

	static let latestImageSources: [LatestImageSource] = [
		LatestImageSource(id: "gentoo", arch: "amd64", manifest: URL(string: "https://distfiles.gentoo.org/releases/amd64/autobuilds/current-di-amd64-cloudinit/latest-di-amd64-cloudinit.txt")!),
		LatestImageSource(id: "gentoo", arch: "arm64", manifest: URL(string: "https://distfiles.gentoo.org/releases/arm64/autobuilds/current-di-arm64-cloudinit/latest-di-arm64-cloudinit.txt")!),
	]

	/// How long a successful manifest read is trusted before `refreshLatestImages()` reads it again.
	private static let latestImagesTTL: TimeInterval = 600

	private struct LatestImages {
		/// architecture -> resolved image URL
		var urls: [String: String] = [:]
		var refreshedAt: Date? = nil
	}

	private static let latestImages = Mutex(LatestImages())

	/// Forgets what the manifests named, so tests don't leak it into each other.
	static func resetLatestImages() {
		latestImages.withLock { $0 = LatestImages() }
	}

	/// The image name a manifest lists: its first `*.qcow2` line, ignoring the PGP clear-sign armour and the
	/// `#` comments. The name is checked to be a bare file name so a manifest can't point outside its directory.
	static func latestImageName(manifest: String) -> String? {
		for line in manifest.split(whereSeparator: \.isNewline) {
			guard let name = line.split(separator: " ").first.map(String.init), name.hasSuffix(".qcow2"), name.hasPrefix("di-"), name.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" || $0 == "." || $0 == "_" }), name.contains("..") == false else {
				continue
			}

			return name
		}

		return nil
	}

	/// `self` with the cloud entries of `latestImageSources` pointing at the images the manifests last named.
	func applyingLatestImages() -> VMImageCatalog {
		let urls = Self.latestImages.withLock { $0.urls }

		guard urls.isEmpty == false else {
			return self
		}

		var arm64 = self.arm64
		var amd64 = self.amd64

		for source in Self.latestImageSources {
			guard let url = urls[source.arch] else {
				continue
			}

			if source.arch == "arm64" {
				arm64 = arm64.replacingCloudURL(id: source.id, with: url)
			} else {
				amd64 = amd64.replacingCloudURL(id: source.id, with: url)
			}
		}

		return VMImageCatalog(arm64: arm64, amd64: amd64)
	}

	/// Reads the `latest-*.txt` manifests and remembers the image they name, so that `shared`,
	/// `reloadIfChanged()` and `--alias` hand out the current one. Best effort: a manifest that can't be
	/// read keeps the URL of the catalog and is retried on the next call. Skipped for `latestImagesTTL` after
	/// a successful read.
	public static func refreshLatestImages(session: URLSession = .shared) async {
		let due = latestImages.withLock { state -> Bool in
			guard let refreshedAt = state.refreshedAt, Date().timeIntervalSince(refreshedAt) < latestImagesTTL else {
				return true
			}

			return false
		}

		guard due else {
			return
		}

		// The manifests of the other architecture are not read: it is not offered on this host.
		#if arch(arm64)
			let arch = "arm64"
		#else
			let arch = "amd64"
		#endif

		var urls: [String: String] = [:]

		for source in latestImageSources where source.arch == arch {
			var request = URLRequest(url: source.manifest)

			request.timeoutInterval = 10

			guard let (data, response) = try? await session.data(for: request), let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), let text = String(data: data, encoding: .utf8), let name = latestImageName(manifest: text) else {
				Logger("VMImageCatalog").warn("Unable to resolve the latest image of \(source.id) from \(source.manifest.absoluteString)")
				continue
			}

			urls[source.arch] = source.manifest.deletingLastPathComponent().appendingPathComponent(name).absoluteString
		}

		latestImages.withLock { state in
			state.urls.merge(urls) { _, new in new }
			// An unreachable manifest must not hold off the next attempt for the whole TTL.
			if urls.isEmpty == false {
				state.refreshedAt = Date()
			}
		}
	}
}
