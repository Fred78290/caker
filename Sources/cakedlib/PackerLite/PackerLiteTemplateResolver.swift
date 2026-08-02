//
//  PackerLiteTemplateResolver.swift
//  CakedLib
//
//  Decides which provisioning template content to use for an IPSW build:
//    1. an explicit --template path always wins.
//    2. otherwise, auto-detect the macOS version from the IPSW filename and use the
//       matching built-in template bundled in CakedLib's resources.
//    3. otherwise, fall back to an explicit --macos-version.
//    4. otherwise, fail with a message telling the user what to pass.
//

import CakeAgentLib
import Foundation
import GRPCLib

enum PackerLiteTemplateResolver {
	private static let logger = Logger("PackerLiteTemplateResolver")

	static func resolve(explicitPath: String?, explicitVersion: MacOSVersion?, ipswURL: URL) throws -> String {
		if let explicitPath {
			return try String(contentsOfFile: explicitPath, encoding: .utf8)
		}

		let filename = ipswURL.lastPathComponent

		if let detected = MacOSVersion.detect(fromIPSWFilename: filename) {
			logger.info("Detected macOS \(detected.rawValue) from IPSW filename '\(filename)'")

			return try bundledTemplateContent(for: detected)
		}

		logger.warn("Could not determine the macOS version from IPSW filename '\(filename)'")

		guard let explicitVersion else {
			throw ServiceError(
				String(
					localized:
						"Could not determine the macOS version from the IPSW filename '\(filename)'. Specify --macos-version (\(MacOSVersion.allCases.map(\.rawValue).joined(separator: ", "))) or provide your own template with --template."
				))
		}

		return try bundledTemplateContent(for: explicitVersion)
	}

	private static func bundledTemplateContent(for version: MacOSVersion) throws -> String {
		let bundledTemplateResourceName = version.bundledTemplateResourceName

		guard let url = Bundle.main.url(forResource: bundledTemplateResourceName, withExtension: "yaml") else {
			guard let url = resourceBundle.url(forResource: bundledTemplateResourceName, withExtension: "yaml") else {
				throw ServiceError(String(localized: "No built-in provisioning template is bundled for macOS \(version.rawValue) yet. Provide your own with --template."))
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
