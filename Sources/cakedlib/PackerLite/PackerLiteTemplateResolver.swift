//
//  PackerLiteTemplateResolver.swift
//  CakedLib
//
//  Decides which provisioning template content to use for a build:
//
//  IPSW (macOS):
//    1. an explicit --template path always wins.
//    2. otherwise, auto-detect the macOS version from the IPSW filename and use the
//       matching built-in template bundled in CakedLib's resources.
//    3. otherwise, fall back to an explicit --macos-version.
//    4. otherwise, fail with a message telling the user what to pass.
//
//  ISO (Linux):
//    1. an explicit --template path always wins.
//    2. otherwise, auto-detect the distro from the ISO filename/URL (GRPCLib.SupportedPlatform)
//       and use the matching built-in template, if one is bundled.
//    3. otherwise, resolve to nil (no provisioning) — e.g. Ubuntu, which has its own
//       cloud-init/subiquity autoinstall path instead, or a genuinely unrecognized distro.
//

import CakeAgentLib
import Foundation
import GRPCLib

extension SupportedPlatform {
	/// The bundled template resource name, e.g. "linux-fedora.packerlite" (paired with a ".yaml"
	/// extension), for distros with a built-in PackerLite template. `nil` for platforms that either
	/// have their own autoinstall mechanism already (Ubuntu, via cloud-init/subiquity) or have no
	/// bundled template yet — both cases mean "don't auto-select anything, require --template".
	fileprivate var bundledPackerLiteTemplateResourceName: String? {
		switch self {
		case .fedora: return "linux-fedora.packerlite"
		case .centos: return "linux-centos.packerlite"
		case .redhat: return "linux-redhat.packerlite"
		case .openSUSE: return "linux-opensuse.packerlite"
		case .debian: return "linux-debian.packerlite"
		case .ubuntu, .macos, .windows, .alpine, .unknown: return nil
		}
	}
}

public enum PackerLiteTemplateResolver {
	private static let logger = Logger("PackerLiteTemplateResolver")

	/// Determines the macOS version for an IPSW build: auto-detected from the filename, falling back
	/// to an explicit `--macos-version`. Returns nil if neither yields anything. Exposed on its own
	/// (not just as a `resolve` implementation detail) so callers that don't need template content —
	/// e.g. persisting the detected version into `CakeConfig.osName` at build time — can reuse the
	/// exact same detection `resolve` uses, instead of re-deriving it.
	public static func resolveVersion(explicitVersion: MacOSVersion?, ipswURL: URL) -> (name: MacOSVersion?, version: String?) {
		let filename = ipswURL.lastPathComponent

		if let detected = MacOSVersion.detect(fromIPSWFilename: filename), let name = detected.name {
			logger.info("Detected macOS \(name.rawValue) from IPSW filename '\(filename)'")

			return detected
		}

		logger.warn("Could not determine the macOS version from IPSW filename '\(filename)'")

		return (explicitVersion, nil)
	}

	public static func resolve(explicitPath: String?, explicitVersion: MacOSVersion?, ipswURL: URL) throws -> String {
		if let explicitPath {
			return try String(contentsOfFile: explicitPath, encoding: .utf8)
		}
		
		let version = resolveVersion(explicitVersion: explicitVersion, ipswURL: ipswURL)
		
		guard let name = version.name else {
			throw ServiceError(
				String(
					localized:
						"Could not determine the macOS version from the IPSW filename '\(ipswURL.lastPathComponent)'. Specify --macos-version (\(MacOSVersion.allCases.map(\.rawValue).joined(separator: ", "))) or provide your own template with --template."
				))
		}

		return try bundledTemplateContent(named: name.bundledTemplateResourceName, orThrow: String(localized: "No built-in provisioning template is bundled for macOS \(name.rawValue) yet. Provide your own with --template."))
	}

	/// Resolves provisioning template content for an ISO (Linux) build: an explicit `--template`
	/// always wins; otherwise auto-detects the distro from the ISO filename/URL and returns the
	/// matching built-in template if one is bundled. Returns `nil` — not an error — when there's no
	/// explicit path and no bundled default for the detected platform, since that's the expected,
	/// valid outcome for e.g. Ubuntu (its own cloud-init/subiquity path handles autoinstall instead)
	/// or a distro caker doesn't recognize; callers should treat `nil` as "don't provision".
	public static func resolveLinuxTemplate(explicitPath: String?, imageURL: URL) throws -> String? {
		try resolveLinuxTemplate(explicitPath: explicitPath, platform: SupportedPlatform(rawValue: imageURL.lastPathComponent), source: imageURL.lastPathComponent)
	}

	/// Same resolution as above, but for a VM whose platform is already known (e.g. an already-built
	/// VM's stored `CakeConfig.configuredPlatform`) rather than needing to be detected from a filename.
	public static func resolveLinuxTemplate(explicitPath: String?, platform: SupportedPlatform) throws -> String? {
		try resolveLinuxTemplate(explicitPath: explicitPath, platform: platform, source: platform.rawValue)
	}

	/// Whether `platform` has a built-in PackerLite template, without loading its content — for
	/// callers (like `caked provision`'s `validate()`) that just need to decide whether `--template`
	/// can be treated as optional before actually running anything.
	public static func hasBuiltInLinuxTemplate(for platform: SupportedPlatform) -> Bool {
		platform.bundledPackerLiteTemplateResourceName != nil
	}

	private static func resolveLinuxTemplate(explicitPath: String?, platform: SupportedPlatform, source: String) throws -> String? {
		if let explicitPath {
			return try String(contentsOfFile: explicitPath, encoding: .utf8)
		}

		guard let resourceName = platform.bundledPackerLiteTemplateResourceName else {
			logger.info("No built-in provisioning template for platform \(platform.rawValue) (from '\(source)') — skipping auto-provisioning unless --template is given")

			return nil
		}

		logger.info("Detected \(platform.rawValue) from '\(source)', using its built-in provisioning template")

		return try bundledTemplateContent(named: resourceName, orThrow: String(localized: "No built-in provisioning template is bundled for \(platform.rawValue) yet. Provide your own with --template."))
	}

	private static func bundledTemplateContent(named resourceName: String, orThrow notFoundError: String) throws -> String {
		guard let url = Bundle.main.url(forResource: resourceName, withExtension: "yaml") else {
			guard let url = resourceBundle.url(forResource: resourceName, withExtension: "yaml") else {
				throw ServiceError(notFoundError)
			}

			return try String(contentsOf: url, encoding: .utf8)
		}

		return try String(contentsOf: url, encoding: .utf8)
	}
}

/// `Bundle.module` only exists in genuine `swift build`/`swift test` builds (SPM generates its accessor
/// per target). Caker.xcodeproj hand-mirrors CakedLib as a native Xcode target with no such accessor, so
/// resource lookup has to branch on which build system produced this binary.
private final class PackerLiteResourceBundleMarker {}

private let resourceBundle: Bundle = {
	#if SWIFT_PACKAGE
		return Bundle.module
	#else
		let containingBundle = Bundle(for: PackerLiteResourceBundleMarker.self)

		for candidate in ["Caker_CakedLib.bundle", "CakedLib_CakedLib.bundle"] {
			if let url = containingBundle.resourceURL?.appendingPathComponent(candidate), let bundle = Bundle(url: url) {
				return bundle
			}
		}

		return containingBundle
	#endif
}()
