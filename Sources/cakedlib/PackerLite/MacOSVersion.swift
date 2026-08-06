//
//  MacOSVersion.swift
//  CakedLib
//
//  Identifies which bundled provisioning template to use for an IPSW build —
//  either detected from the IPSW filename (Apple's "UniversalMac_<version>_<build>_Restore.ipsw"
//  convention) or supplied explicitly via --macos-version.
//

import Foundation

public enum MacOSVersion: String, CaseIterable, Sendable {
	case monterey
	case ventura
	case sonoma
	case sequoia
	case tahoe
	case goldengate

	/// The bundled template resource name, e.g. "vanilla-sequoia.packerlite" (paired with a ".yaml" extension).
	public var bundledTemplateResourceName: String { "vanilla-\(rawValue).packerlite" }

	public init?(major: Int) {
		switch major {
			case 12: self = .monterey
			case 13: self = .ventura
			case 14: self = .sonoma
			case 15: self = .sequoia
			case 26: self = .tahoe
			case 27: self = .goldengate
			default: return nil
		}
	}

	/// Extracts the macOS version from an Apple restore-image filename, e.g.
	/// "UniversalMac_26.6_25G72_Restore.ipsw" -> .tahoe, "UniversalMac_15.6.1_24G90_Restore.ipsw" -> .sequoia.
	/// Returns nil if the filename doesn't follow that convention or the version has no known codename.
	public static func detect(fromIPSWFilename filename: String) -> (name: MacOSVersion?, version: String?)? {
		let basename = (filename as NSString).lastPathComponent

		guard let regex = try? NSRegularExpression(pattern: #"UniversalMac_(\d{1,2})(?:\.(\d+))?(?:\.\d+)?_"#) else {
			return nil
		}

		let range = NSRange(basename.startIndex..., in: basename)

		guard
			let match = regex.firstMatch(in: basename, range: range),
			let majorRange = Range(match.range(at: 1), in: basename),
			let major = Int(basename[majorRange])
		else {
			return nil
		}

		// Minor is absent in filenames like "UniversalMac_26_..." — treat it as .0.
		let minor = Range(match.range(at: 2), in: basename).flatMap { Int(basename[$0]) } ?? 0

		return (MacOSVersion(major: major), "\(major).\(minor)")
	}
}
