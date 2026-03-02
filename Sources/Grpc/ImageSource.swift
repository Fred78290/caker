//
//  ImageSource.swift
//  Caker
//
//  Created by Frederic BOLTZ on 02/03/2026.
//
import Foundation
import ArgumentParser

public enum ImageSource: Int, Hashable, CaseIterable, CustomStringConvertible, Sendable {
	public var description: String {
		switch self {
		case .raw: return "local"
		case .cloud: return "cloud"
		case .oci: return "oci"
		case .template: return "template"
		case .stream: return "stream"
		case .iso: return "iso"
		#if arch(arm64)
			case .ipsw: return "ipsw"
		#endif
		}
	}

	case raw
	case cloud
	case oci
	case template
	case stream
	case iso
	#if arch(arm64)
		case ipsw
	#endif

	public init(stringValue: String) {
		switch stringValue.lowercased() {
		case "iso": self = .iso
		case "raw": self = .raw
		case "cloud": self = .cloud
		case "oci": self = .oci
		case "template": self = .template
		case "stream": self = .stream
		#if arch(arm64)
			case "ipsw": self = .ipsw
		#endif
		default:
			self = .iso
		}
	}

	static var allCases: [String] {
		#if arch(arm64)
			["iso", "ipsw", "raw", "cloud", "oci", "template", "stream"]
		#else
			["iso", "raw", "cloud", "oci", "template", "stream"]
		#endif
	}

	public var supportCloudInit: Bool {
		#if arch(arm64)
			if self == .ipsw || self == .iso {
				return false
			}
		#else
			if self == .iso {
				return false
			}
		#endif

		return true
	}
}

