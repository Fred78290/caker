import Foundation
import GRPCLib

/// Classifies an image-cache entry as reported by `ListHandler.list(vmonly: false, ...)` — i.e. the
/// `type` string each `PurgeableStorage.type()` returns — and says whether (and as which
/// `ImageSource`) a VM can be created from it. Pure mapping logic, kept here rather than in the
/// `caker` view so it is unit-testable. Mirrors `LXDImagesController.lxdImageType(for:)`, which
/// does the same classification for the REST API.
public enum CachedImageKind: Equatable, Sendable {
	case cloudImage
	case rawImage
	case iso
	case ipsw
	case oci
	case ociLayers
	case simpleStream
	case template
	case unknown(String)

	public init(cacheType: String) {
		switch cacheType {
		case "cloud-images": self = .cloudImage
		case "raw-images": self = .rawImage
		case "iso": self = .iso
		case "ipsw": self = .ipsw
		case "oci": self = .oci
		case "OCIs": self = .ociLayers
		case "simplestream": self = .simpleStream
		case "templates": self = .template
		default: self = .unknown(cacheType)
		}
	}

	/// The wizard/`BuildOptions` image source to build this entry with, or `nil` if it can't be built from cache.
	/// Raw images are a local-disk source (a path the user picks), the OCI layer cache isn't a pullable
	/// reference, and templates have their own sidebar category, so none of these is offered.
	public var imageSource: ImageSource? {
		switch self {
		case .cloudImage: return .qcow2
		case .iso: return .iso
		case .ipsw: return .ipsw
		case .oci: return .oci
		case .simpleStream: return .stream
		case .rawImage, .ociLayers, .template, .unknown: return nil
		}
	}

	public var os: VirtualizedOS {
		self == .ipsw ? .darwin : .linux
	}

	public var canCreateVirtualMachine: Bool {
		self.imageSource != nil
	}

	/// Templates are excluded from the cache list because `My templates` already lists them.
	public var isListed: Bool {
		self != .template
	}
}
