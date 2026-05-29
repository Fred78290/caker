import Foundation

public enum VmdkError: Error, LocalizedError {
    case invalidMagic
    case unsupportedVersion(UInt32)
    case compressionNotSupported(UInt16)
    case corruptedImage(String)
    case ioError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidMagic:
            return "Not a VMDK file (bad magic number)"
        case .unsupportedVersion(let v):
            return "Unsupported VMDK version: \(v)"
        case .compressionNotSupported(let algo):
            return "Compressed VMDK images are not supported (algorithm \(algo)); use qemu-img to convert first"
        case .corruptedImage(let msg):
            return "Corrupted VMDK image: \(msg)"
        case .ioError(let msg):
            return "I/O error: \(msg)"
        }
    }
}
