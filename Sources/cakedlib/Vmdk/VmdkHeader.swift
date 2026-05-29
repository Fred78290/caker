import Foundation

// VMDK SparseExtentHeader layout (all little-endian), 512 bytes total:
//   0   uint32  magicNumber = 0x564D444B ('KDMV' on disk)
//   4   uint32  version
//   8   uint32  flags
//  12   uint64  capacity         (sectors)
//  20   uint64  grainSize        (sectors, must be a power of 2, ≥ 8)
//  28   uint64  descriptorOffset (sectors)
//  36   uint64  descriptorSize   (sectors)
//  44   uint32  numGTEsPerGT     (= 512 for standard images)
//  48   uint64  rgdOffset        (redundant grain directory, sectors)
//  56   uint64  gdOffset         (primary grain directory, sectors)
//  64   uint64  overHead         (sectors to first grain)
//  72   uint8   uncleanShutdown
//  73   uint8   singleEndLineChar   = 0x0a
//  74   uint8   nonEndLineChar      = 0x20
//  75   uint8   doubleEndLineChar1  = 0x0d
//  76   uint8   doubleEndLineChar2  = 0x0a
//  77   uint16  compressAlgorithm   (0 = none, 1 = deflate/stream-optimized)
//  79   uint8[433] pad

struct VmdkHeader {
    static let magic: UInt32 = 0x564D444B
    static let headerSize = 512
    // Sentinel meaning the GD is appended at end-of-file (stream-optimized images).
    static let gdOffsetUnset: UInt64 = 0xffffffffffffffff

    let version: UInt32
    let flags: UInt32
    let capacity: UInt64
    let grainSize: UInt64
    let descriptorOffset: UInt64
    let descriptorSize: UInt64
    let numGTEsPerGT: UInt32
    let rgdOffset: UInt64
    let gdOffset: UInt64
    let overHead: UInt64
    let uncleanShutdown: Bool
    let compressAlgorithm: UInt16

    var diskSize: UInt64 { capacity * 512 }
    var grainBytes: Int { Int(grainSize) * 512 }
    var numGDEntries: Int {
        Int((capacity + UInt64(numGTEsPerGT) * grainSize - 1) / (UInt64(numGTEsPerGT) * grainSize))
    }

    // Prefer the primary GD; fall back to the redundant one if the primary is absent.
    var effectiveGdOffset: UInt64? {
        if gdOffset != 0, gdOffset != VmdkHeader.gdOffsetUnset { return gdOffset }
        if rgdOffset != 0, rgdOffset != VmdkHeader.gdOffsetUnset { return rgdOffset }
        return nil
    }

    static func parse(from data: Data) throws -> VmdkHeader {
        guard data.count >= headerSize else { throw VmdkError.invalidMagic }
        guard data.readUInt32LE(at: 0) == magic else { throw VmdkError.invalidMagic }

        let version = data.readUInt32LE(at: 4)
        guard version >= 1, version <= 3 else {
            throw VmdkError.unsupportedVersion(version)
        }

        let flags            = data.readUInt32LE(at: 8)
        let capacity         = data.readUInt64LE(at: 12)
        let grainSize        = data.readUInt64LE(at: 20)
        let descriptorOffset = data.readUInt64LE(at: 28)
        let descriptorSize   = data.readUInt64LE(at: 36)
        let numGTEsPerGT     = data.readUInt32LE(at: 44)
        let rgdOffset        = data.readUInt64LE(at: 48)
        let gdOffset         = data.readUInt64LE(at: 56)
        let overHead         = data.readUInt64LE(at: 64)
        let uncleanShutdown  = data[72] != 0

        // The four newline-detection bytes act as a file-corruption canary.
        guard data[73] == 0x0a, data[74] == 0x20, data[75] == 0x0d, data[76] == 0x0a else {
            throw VmdkError.corruptedImage("newline-detection bytes are wrong; file may have been corrupted by a text-mode transfer")
        }

        let compressAlgorithm = data.readUInt16LE(at: 77)

        return VmdkHeader(
            version: version,
            flags: flags,
            capacity: capacity,
            grainSize: grainSize,
            descriptorOffset: descriptorOffset,
            descriptorSize: descriptorSize,
            numGTEsPerGT: numGTEsPerGT,
            rgdOffset: rgdOffset,
            gdOffset: gdOffset,
            overHead: overHead,
            uncleanShutdown: uncleanShutdown,
            compressAlgorithm: compressAlgorithm
        )
    }
}

// MARK: - Data helpers (little-endian)

extension Data {
    func readUInt16LE(at offset: Int) -> UInt16 {
        precondition(offset + 2 <= count)
        return withUnsafeBytes { ptr in
            UInt16(littleEndian: ptr.loadUnaligned(fromByteOffset: offset, as: UInt16.self))
        }
    }

    func readUInt32LE(at offset: Int) -> UInt32 {
        precondition(offset + 4 <= count)
        return withUnsafeBytes { ptr in
            UInt32(littleEndian: ptr.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
        }
    }

    func readUInt64LE(at offset: Int) -> UInt64 {
        precondition(offset + 8 <= count)
        return withUnsafeBytes { ptr in
            UInt64(littleEndian: ptr.loadUnaligned(fromByteOffset: offset, as: UInt64.self))
        }
    }
}
