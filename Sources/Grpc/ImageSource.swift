//
//  ImageSource.swift
//  Caker
//
//  Created by Frederic BOLTZ on 02/03/2026.
//
import Foundation
import ArgumentParser

public enum ImageSource: Int, Sendable, Codable, CaseIterable, CustomStringConvertible, ExpressibleByArgument {
	
	public static let schemes : [String:ImageSource] = [
		"http" : .qcow2,
		"https" : .qcow2,
		"qcow2" : .qcow2,

		"file" : .raw,
		"img" : .raw,
		"imgs" : .raw,

		"oci" : .oci,
		"ocis" : .oci,

		"template" : .template,

		"iso" : .iso,
		"isos" : .iso,

		"ipsw" : .ipsw,
	]
	
	public var description: String {
		switch self {
		case .raw: return "raw"
		case .qcow2: return "qcow2"
		case .oci: return "oci"
		case .template: return "template"
		case .stream: return "stream"
		case .iso: return "iso"
		case .ipsw: return "ipsw"
		}
	}
	
	case raw
	case qcow2
	case oci
	case template
	case stream
	case iso
	case ipsw
	
	public init?(argument: String) {
		switch argument.lowercased() {
		case "iso": self = .iso
		case "raw": self = .raw
		case "qcow2": self = .qcow2
		case "oci": self = .oci
		case "template": self = .template
		case "stream": self = .stream
		case "ipsw": self = .ipsw
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
		case "ipsw": self = .ipsw
		default:
			self = .iso
		}
	}
	
	static var allCases: [String] {
		["iso", "ipsw", "raw", "qcow2", "oci", "template", "stream"]
	}
	
	public var supportCloudInit: Bool {
		if self == .ipsw || self == .iso {
			return false
		}
		
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
}

