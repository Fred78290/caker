import Foundation

public enum Qcow2Error: Error, LocalizedError {
    case invalidMagic
    case unsupportedVersion(UInt32)
    case encryptionNotSupported
    case backingFileNotSupported(String)
    case incompatibleFeatures(UInt64)
    case corruptedImage(String)
    case decompressionFailed
    case ioError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidMagic:
            return "Not a QCOW2 file (bad magic number)"
        case .unsupportedVersion(let v):
            return "Unsupported QCOW2 version: \(v)"
        case .encryptionNotSupported:
            return "Encrypted QCOW2 images are not supported"
        case .backingFileNotSupported(let name):
            return "QCOW2 images with a backing file are not supported: \(name)"
        case .incompatibleFeatures(let flags):
            return "Unsupported QCOW2 incompatible features: 0x\(String(flags, radix: 16))"
        case .corruptedImage(let msg):
            return "Corrupted QCOW2 image: \(msg)"
        case .decompressionFailed:
            return "Failed to decompress QCOW2 cluster"
        case .ioError(let msg):
            return "I/O error: \(msg)"
        }
    }
}
