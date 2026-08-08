//
//  VMImageCatalog.swift
//  Caker
//
//  Created by Frederic BOLTZ on 08/08/2026.
//

import Foundation

enum VMImageArchKind: String, Codable {
	case ubuntu
	case generic
}

struct VMImageEntry: Codable, Identifiable, Hashable {
	let id: String
	let label: String
	let url: String
	let archKind: VMImageArchKind
	let archOnly: String?

	private static var currentUbuntuArch: String {
		#if arch(x86_64)
			return "amd64"
		#else
			return "arm64"
		#endif
	}

	private static var currentGenericArch: String {
		#if arch(x86_64)
			return "x86_64"
		#else
			return "aarch64"
		#endif
	}

	var resolvedArch: String {
		archKind == .ubuntu ? Self.currentUbuntuArch : Self.currentGenericArch
	}

	var resolvedLabel: String {
		label.replacingOccurrences(of: "{arch}", with: resolvedArch)
	}

	var resolvedURL: String {
		url.replacingOccurrences(of: "{arch}", with: resolvedArch)
	}

	var isAvailableOnCurrentArch: Bool {
		guard let archOnly else {
			return true
		}

		#if arch(x86_64)
			return archOnly == "x86_64"
		#else
			return archOnly == "arm64" || archOnly == "aarch64"
		#endif
	}
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
	let iso: [VMImageEntry]
	let ipsw: [VMImageEntry]
	let cloud: [VMImageEntry]

	static let shared: VMImageCatalog = {
		guard let url = vmImageCatalogResourceBundle.url(forResource: "VMImages", withExtension: "json") else {
			fatalError("VMImages.json resource not found in bundle")
		}

		do {
			let data = try Data(contentsOf: url)
			return try JSONDecoder().decode(VMImageCatalog.self, from: data)
		} catch {
			fatalError("Failed to load VMImages.json: \(error)")
		}
	}()

	var availableISOImages: [VMImageEntry] {
		iso.filter { $0.isAvailableOnCurrentArch }
	}

	var availableIPSWImages: [VMImageEntry] {
		ipsw.filter { $0.isAvailableOnCurrentArch }
	}

	var availableCloudImages: [VMImageEntry] {
		cloud.filter { $0.isAvailableOnCurrentArch }
	}

	func isoImage(_ id: String) -> VMImageEntry {
		guard let entry = iso.first(where: { $0.id == id }) else {
			fatalError("Unknown ISO image id \(id) in VMImages.json")
		}

		return entry
	}

	func ipswImage(_ id: String) -> VMImageEntry {
		guard let entry = ipsw.first(where: { $0.id == id }) else {
			fatalError("Unknown IPSW image id \(id) in VMImages.json")
		}

		return entry
	}

	func cloudImage(_ id: String) -> VMImageEntry {
		guard let entry = cloud.first(where: { $0.id == id }) else {
			fatalError("Unknown cloud image id \(id) in VMImages.json")
		}

		return entry
	}
}
