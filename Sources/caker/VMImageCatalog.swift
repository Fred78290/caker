//
//  VMImageCatalog.swift
//  Caker
//
//  Created by Frederic BOLTZ on 08/08/2026.
//

import CakedLib
import Foundation
import GRPCLib

struct VMImageEntry: Codable, Identifiable, Hashable {
	let id: String
	let label: String
	let url: String
}

struct VMImageArchCatalog: Codable {
	let iso: [VMImageEntry]
	let ipsw: [VMImageEntry]
	let cloud: [VMImageEntry]
}

/// `Bundle.module` only exists in genuine `swift build`/`swift test` builds (SPM generates its accessor
/// per target). Caker.xcodeproj hand-mirrors `caker` as a native Xcode target with no such accessor, so
/// resource lookup has to branch on which build system produced this binary.
private final class VMImageCatalogResourceBundleMarker {}

private let vmImageCatalogResourceBundle: Bundle = {
	#if SWIFT_PACKAGE
		return Bundle.module
	#else
		return Bundle(for: VMImageCatalogResourceBundleMarker.self)
	#endif
}()

struct VMImageCatalog: Codable {
	let arm64: VMImageArchCatalog
	let amd64: VMImageArchCatalog

	static var shared: VMImageCatalog = load()

	/// Raw JSON on the `main` branch — kept in sync with `Sources/caker/Resources/VMImages.json`.
	static let githubCatalogURL = URL(string: "https://raw.githubusercontent.com/Fred78290/caker/main/Sources/caker/Resources/VMImages.json")!

	var current: VMImageArchCatalog {
		#if arch(arm64)
			return arm64
		#else
			return amd64
		#endif
	}

	var availableISOImages: [VMImageEntry] {
		current.iso
	}

	var availableIPSWImages: [VMImageEntry] {
		current.ipsw
	}

	var availableCloudImages: [VMImageEntry] {
		current.cloud
	}

	func isoImage(_ id: String) -> VMImageEntry {
		guard let entry = current.iso.first(where: { $0.id == id }) else {
			fatalError("Unknown ISO image id \(id) in VMImages.json")
		}

		return entry
	}

	func ipswImage(_ id: String) -> VMImageEntry {
		guard let entry = current.ipsw.first(where: { $0.id == id }) else {
			fatalError("Unknown IPSW image id \(id) in VMImages.json")
		}

		return entry
	}

	func cloudImage(_ id: String) -> VMImageEntry {
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
	/// every render rather than caching it in view state). Throws on network/decode failure — callers
	/// that want a best-effort background refresh should `try?` this.
	@discardableResult
	static func refreshFromGitHub(session: URLSession = .shared) async throws -> VMImageCatalog {
		let (data, response) = try await session.data(from: githubCatalogURL)

		guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
			throw ServiceError("Failed to download VMImages.json from GitHub")
		}

		let catalog = try JSONDecoder().decode(VMImageCatalog.self, from: data)

		// `Utils.getHome` only creates the directory on its first-ever call (it caches the
		// resolved path afterwards), so a prior `createHomeIfNeeded: false` lookup — e.g. from
		// `load()` — can leave it uncreated here despite passing `true`. Create it ourselves too.
		if let destination = cakeHomeCatalogURL(createHomeIfNeeded: true) {
			try? FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
			try? data.write(to: destination, options: .atomic)
		}

		shared = catalog

		return catalog
	}
}
