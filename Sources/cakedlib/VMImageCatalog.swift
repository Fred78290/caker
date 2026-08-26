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
//  `aliasEntries` below, used by the `caked aliases`/`cakectl aliases` commands to list them).
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
}

public struct VMImageArchCatalog: Codable, Sendable {
	public let iso: [VMImageEntry]
	public let ipsw: [VMImageEntry]
	public let cloud: [VMImageEntry]
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

	// `shared` is read from the UI and written by `refreshFromGitHub()`'s background task —
	// `Mutex` (matching the pattern already used for e.g. `ARPParser`'s static cache) keeps that
	// safe instead of racing on a bare `static var`.
	private static let storage: Mutex<VMImageCatalog> = Mutex(load())

	public static var shared: VMImageCatalog {
		storage.withLock { $0 }
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

	public var availableIPSWImages: [VMImageEntry] {
		current.ipsw
	}

	public var availableCloudImages: [VMImageEntry] {
		current.cloud
	}

	public func isoImage(_ id: String) -> VMImageEntry {
		guard let entry = current.iso.first(where: { $0.id == id }) else {
			fatalError("Unknown ISO image id \(id) in VMImages.json")
		}

		return entry
	}

	public func ipswImage(_ id: String) -> VMImageEntry {
		guard let entry = current.ipsw.first(where: { $0.id == id }) else {
			fatalError("Unknown IPSW image id \(id) in VMImages.json")
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

	private static func loadFromCakeHome() -> VMImageCatalog? {
		guard let url = cakeHomeCatalogURL(createHomeIfNeeded: false), FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
			return nil
		}

		return try? JSONDecoder().decode(VMImageCatalog.self, from: Data(contentsOf: url))
	}

	private static func loadBundled() -> VMImageCatalog {
		guard let url = vmImageCatalogResourceBundle.url(forResource: "VMImages", withExtension: "json") ?? Bundle.main.url(forResource: "VMImages", withExtension: "json") else {
			fatalError("VMImages.json resource not found in the app bundle — add it to the target's \"Copy Bundle Resources\" build phase in Xcode")
		}

		do {
			let data = try Data(contentsOf: url)
			return try JSONDecoder().decode(VMImageCatalog.self, from: data)
		} catch {
			fatalError("Failed to load VMImages.json: \(error)")
		}
	}

	/// Load order: a `<CAKE_HOME>/VMImages.json` override, if present and valid, else the bundled
	/// resource. A malformed override is skipped (falls through) rather than crashing the app, since
	/// unlike the bundled resource it's user-supplied state, not a packaging invariant.
	private static func load() -> VMImageCatalog {
		loadFromCakeHome() ?? loadBundled()
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

		storage.withLock { $0 = catalog }

		return catalog
	}

	private var usesOnlyHTTPS: Bool {
		[arm64, amd64].allSatisfy { arch in
			(arch.iso + arch.ipsw + arch.cloud).allSatisfy { $0.url.hasPrefix("https://") }
		}
	}
}

/// What a catalog id (`--alias macos12`, `--alias ubuntu2604`, ...) resolves to: the entry's
/// URL, the `GRPCLib.ImageSource` it should be built as, and — for an `ipsw` hit whose id happens
/// to also be a valid `MacOSVersion` raw value — the matching `MacOSVersion`, so callers can
/// auto-populate `BuildOptions.macosVersion` when the user didn't pass `--macos-version`
/// explicitly (see `VMBuilder.buildVM`).
public struct VMImageCatalogResolution: Sendable {
	public let url: String
	public let imageSource: ImageSource
	public let macosVersion: MacOSVersion?
}

extension VMImageCatalog {
	/// Resolves a catalog id (the same ids `--alias` accepts, and that `aliasEntries` below lists)
	/// against this catalog's `current` (arch-appropriate) entries.
	///
	/// Checks `ipsw` → `iso` → `cloud`, in that priority order. `centos9`/`centos10` are — as of
	/// this writing — the only ids that appear in more than one category (both `iso` and
	/// `cloud`), and this priority order means they always resolve to the `iso` entry, never the
	/// `cloud` one; there's no `--centos9-cloud`-style variant to disambiguate further. Returns
	/// `nil` if `id` isn't in this catalog at all — shouldn't normally happen, since `--alias`'s
	/// ids are meant to come from this same catalog, but a caller should still handle it rather
	/// than force-unwrapping.
	public func resolveShorthand(_ id: String) -> VMImageCatalogResolution? {
		if let entry = current.ipsw.first(where: { $0.id == id }) {
			return VMImageCatalogResolution(url: entry.url, imageSource: .ipsw, macosVersion: MacOSVersion(rawValue: id))
		}

		if let entry = current.iso.first(where: { $0.id == id }) {
			return VMImageCatalogResolution(url: entry.url, imageSource: .iso, macosVersion: nil)
		}

		if let entry = current.cloud.first(where: { $0.id == id }) {
			// Cloud images are plain disk images served over https (.img/.qcow2) — exactly what
			// `.qcow2` already means elsewhere in this codebase (see `ImageSource.schemes`'s
			// "https" -> `.qcow2` mapping in `BuildOptions.validateImageSource`). Set it
			// explicitly here rather than leaving `imageSource` nil for a later re-validation
			// pass to infer, since `VMBuilder.buildVM` doesn't re-run that validation.
			return VMImageCatalogResolution(url: entry.url, imageSource: .qcow2, macosVersion: nil)
		}

		return nil
	}
}

/// One row of `caked aliases`/`cakectl aliases` output — every id `--alias` accepts, tagged with
/// which catalog category (`ipsw`/`iso`/`cloud`) it resolves from. `centos9`/`centos10` appear
/// twice here (once per category, see `resolveShorthand`'s doc comment above) since this listing
/// is meant to show the full catalog contents, not just what `--alias` would actually pick.
public struct VMImageAliasEntry: Codable, Sendable {
	public let id: String
	public let category: String
	public let label: String
}

extension VMImageCatalog {
	/// Every `--alias`-able id in `current` (arch-appropriate), across all three categories —
	/// the data behind the `aliases` command in both `caked` and `cakectl`.
	public var aliasEntries: [VMImageAliasEntry] {
		current.ipsw.map { VMImageAliasEntry(id: $0.id, category: "ipsw", label: $0.label) }
			+ current.iso.map { VMImageAliasEntry(id: $0.id, category: "iso", label: $0.label) }
			+ current.cloud.map { VMImageAliasEntry(id: $0.id, category: "cloud", label: $0.label) }
	}
}

extension CakeAgentLib.Format {
	public func render(_ data: [VMImageAliasEntry]) -> String {
		self.renderList(data)
	}
}
