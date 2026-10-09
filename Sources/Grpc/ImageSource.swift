import ArgumentParser
//
//  ImageSource.swift
//  Caker
//
//  Created by Frederic BOLTZ on 02/03/2026.
//
import Foundation

public enum ImageSource: Int, Sendable, Codable, CaseIterable, CustomStringConvertible, ExpressibleByArgument {

	#if arch(arm64)
		public static let schemes: [String: ImageSource] = [
			"http": .qcow2,
			"https": .qcow2,
			"qcow2": .qcow2,

			"file": .raw,
			"img": .raw,
			"imgs": .raw,

			"oci": .oci,
			"ocis": .oci,

			"template": .template,

			"iso": .iso,
			"isos": .iso,
			"ipsw": .ipsw,
		]
	#else
		public static let schemes: [String: ImageSource] = [
			"http": .qcow2,
			"https": .qcow2,
			"qcow2": .qcow2,

			"file": .raw,
			"img": .raw,
			"imgs": .raw,

			"oci": .oci,
			"ocis": .oci,

			"template": .template,

			"iso": .iso,
			"isos": .iso,
		]
	#endif

	public var description: String {
		switch self {
		case .raw: return "raw"
		case .qcow2: return "qcow2"
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
	case qcow2
	case oci
	case template
	case stream
	case iso
	#if arch(arm64)
		case ipsw
	#endif

	public init?(argument: String) {
		switch argument.lowercased() {
		case "iso": self = .iso
		case "raw": self = .raw
		case "qcow2": self = .qcow2
		case "oci": self = .oci
		case "template": self = .template
		case "stream": self = .stream
		#if arch(arm64)
			case "ipsw": self = .ipsw
		#endif
		default:
			return nil
		}
	}

	public init(stringValue: String) {
		switch stringValue.lowercased() {
		case "iso": self = .iso
		case "raw": self = .raw
		case "qcow2": self = .qcow2
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
			["iso", "ipsw", "raw", "qcow2", "oci", "template", "stream"]
		#else
			["iso", "raw", "qcow2", "oci", "template", "stream"]
		#endif
	}

	public var isMacOS: Bool {
		#if arch(arm64)
			return self == .ipsw
		#else
			return false
		#endif
	}

	public var supportProvisionning: Bool {
		#if arch(arm64)
			if self == .ipsw || self == .iso {
				return true
			}
		#else
			if self == .iso {
				return true
			}
		#endif

		return false
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

	public static func resolveHttpSchemeURL(imageURL: URL) -> URL {
		guard var components = URLComponents(url: imageURL, resolvingAgainstBaseURL: false) else {
			return imageURL
		}

		switch imageURL.scheme {
		case "qcow2":
			components.scheme = "file"
		case "img", "iso":
			components.scheme = "http"
		case "cloud", "imgs", "isos", "ipsw":
			components.scheme = "https"
		default:
			return imageURL
		}

		if let imageURL = components.url {
			return imageURL
		}

		return imageURL
	}

	public func supportedDiskFormat(for format: SupportedDiskFormat) -> SupportedDiskFormat {
		switch self {
		case .raw, .qcow2, .oci, .stream:
			return .raw
		default:
			return format
		}
	}
}
