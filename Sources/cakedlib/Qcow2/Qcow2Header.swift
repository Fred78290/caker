import Foundation

// QCOW2 format: all multi-byte fields are big-endian.
//
// v2 header layout (72 bytes):
//   0  uint32 magic
//   4  uint32 version
//   8  uint64 backing_file_offset
//  16  uint32 backing_file_size
//  20  uint32 cluster_bits
//  24  uint64 disk_size
//  32  uint32 encryption_method
//  36  uint32 l1_size
//  40  uint64 l1_table_offset
//  48  uint64 refcount_table_offset
//  56  uint32 refcount_table_clusters
//  60  uint32 nb_snapshots
//  64  uint64 snapshots_offset
//
// v3 appends (104 bytes total):
//  72  uint64 incompatible_features
//  80  uint64 compatible_features
//  88  uint64 autoclear_features
//  96  uint32 refcount_order
// 100  uint32 header_length

struct Qcow2Header {
    static let magic: UInt32 = 0x514649FB  // "QFI\xfb"
    static let v2Size = 72
    static let v3Size = 104

    let version: UInt32
    let backingFileOffset: UInt64
    let backingFileSize: UInt32
    let clusterBits: UInt32
    let diskSize: UInt64
    let encryptionMethod: UInt32
    let l1Size: UInt32
    let l1TableOffset: UInt64

    // v3
    let incompatibleFeatures: UInt64
    let compatibleFeatures: UInt64
    let autoclearFeatures: UInt64

    var clusterSize: Int { 1 << Int(clusterBits) }

    // Each L2 entry is 8 bytes, so one L2 table holds clusterSize/8 entries.
    var l2EntryCount: Int { clusterSize / 8 }

    // Bits per L2 table index = log2(l2EntryCount) = clusterBits - 3
    var l2Bits: Int { Int(clusterBits) - 3 }

    static func parse(from data: Data) throws -> Qcow2Header {
        guard data.count >= v2Size else { throw Qcow2Error.invalidMagic }

        guard data.readUInt32BE(at: 0) == magic else { throw Qcow2Error.invalidMagic }

        let version = data.readUInt32BE(at: 4)
        guard version == 2 || version == 3 else {
            throw Qcow2Error.unsupportedVersion(version)
        }

        let backingFileOffset = data.readUInt64BE(at: 8)
        let backingFileSize   = data.readUInt32BE(at: 16)
        let clusterBits       = data.readUInt32BE(at: 20)
        let diskSize          = data.readUInt64BE(at: 24)
        let encryptionMethod  = data.readUInt32BE(at: 32)
        let l1Size            = data.readUInt32BE(at: 36)
        let l1TableOffset     = data.readUInt64BE(at: 40)

        var incompatible: UInt64 = 0
        var compatible: UInt64   = 0
        var autoclear: UInt64    = 0

        if version == 3 {
            guard data.count >= v3Size else { throw Qcow2Error.invalidMagic }
            incompatible = data.readUInt64BE(at: 72)
            compatible   = data.readUInt64BE(at: 80)
            autoclear    = data.readUInt64BE(at: 88)
        }

        return Qcow2Header(
            version: version,
            backingFileOffset: backingFileOffset,
            backingFileSize: backingFileSize,
            clusterBits: clusterBits,
            diskSize: diskSize,
            encryptionMethod: encryptionMethod,
            l1Size: l1Size,
            l1TableOffset: l1TableOffset,
            incompatibleFeatures: incompatible,
            compatibleFeatures: compatible,
            autoclearFeatures: autoclear
        )
    }
}

// MARK: - Data helpers

extension Data {
    func readUInt32BE(at offset: Int) -> UInt32 {
        precondition(offset + 4 <= count)
        return withUnsafeBytes { ptr in
            UInt32(bigEndian: ptr.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
        }
    }

    func readUInt64BE(at offset: Int) -> UInt64 {
        precondition(offset + 8 <= count)
        return withUnsafeBytes { ptr in
            UInt64(bigEndian: ptr.loadUnaligned(fromByteOffset: offset, as: UInt64.self))
        }
    }
}

// MARK: - FileHandle helpers

extension FileHandle {
    /// Reads exactly `count` bytes, retrying on short reads until EOF.
    func readExact(count: Int) throws -> Data {
        var result = Data()
        result.reserveCapacity(count)
        while result.count < count {
            let chunk = try read(upToCount: count - result.count) ?? Data()
            if chunk.isEmpty { break }
            result.append(chunk)
        }
        return result
    }
}
