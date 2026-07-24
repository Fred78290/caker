import Foundation
import zlib

// L1/L2 table entry bit masks (QCOW2 spec §5.1 / §5.2)
private let kL1OffsetMask: UInt64 = 0x00fffffffffffe00  // bits 9-55
private let kL2OffsetMask: UInt64 = 0x00fffffffffffe00  // bits 9-55 (standard cluster)
private let kOflagZero: UInt64    = 1 << 0
private let kOflagCompressed: UInt64 = 1 << 62

// v3 incompatible feature bits
private let kIncompatDirty: UInt64           = 1 << 0  // unclean shutdown – readable
private let kIncompatCorrupt: UInt64         = 1 << 1  // corrupt – refuse
private let kIncompatExternalData: UInt64    = 1 << 2  // external data file – unsupported
private let kIncompatCompressionType: UInt64 = 1 << 3  // non-deflate compression – unsupported
private let kIncompatKnown: UInt64 = 0x0F

public final class Qcow2Converter {

    /// Called periodically during conversion.
    /// - Parameters:
    ///   - bytesProcessed: virtual bytes covered so far
    ///   - totalBytes: total virtual disk size in bytes
    public typealias ProgressHandler = (_ bytesProcessed: Int64, _ totalBytes: Int64) -> Void

    // MARK: - Public API

    /// Converts a QCOW2 image file to a raw disk image.
    ///
    /// - Parameters:
    ///   - source: URL of the source `.qcow2` file.
    ///   - destination: URL for the output raw image (created or overwritten).
    ///   - allowBackingFile: when `false` (default) images that reference a backing file are rejected.
    ///   - progress: optional closure called after each cluster is processed.
    public static func convert(
        from source: URL,
        to destination: URL,
        allowBackingFile: Bool = false,
        progress: ProgressHandler? = nil
    ) throws {
        try convert(
            fromPath: source.path(percentEncoded: false),
            toPath: destination.path(percentEncoded: false),
            allowBackingFile: allowBackingFile,
            progress: progress
        )
    }

    /// Path-based overload.
    public static func convert(
        fromPath sourcePath: String,
        toPath destinationPath: String,
        allowBackingFile: Bool = false,
        progress: ProgressHandler? = nil
    ) throws {
        guard let src = FileHandle(forReadingAtPath: sourcePath) else {
            throw Qcow2Error.ioError("Cannot open '\(sourcePath)'")
        }
        defer { try? src.close() }

        let header = try validateAndParseHeader(src, path: sourcePath, allowBackingFile: allowBackingFile)
        let l1Table = try readL1Table(src, header: header)

        FileManager.default.createFile(atPath: destinationPath, contents: nil)
        guard let dst = FileHandle(forWritingAtPath: destinationPath) else {
            throw Qcow2Error.ioError("Cannot open '\(destinationPath)' for writing")
        }
        defer { try? dst.close() }

        // Pre-size the output as a sparse file; unwritten regions read as zero.
        try dst.truncate(atOffset: header.diskSize)
        try dst.seek(toOffset: 0)

        try writeAllClusters(src: src, dst: dst, header: header, l1Table: l1Table, progress: progress)
    }

    // MARK: - Private

    private static func validateAndParseHeader(
        _ handle: FileHandle,
        path: String,
        allowBackingFile: Bool
    ) throws -> Qcow2Header {
        // Read enough bytes for the largest known header (v3 = 104 bytes).
        let raw = try handle.readExact(count: Qcow2Header.v3Size)
        let header = try Qcow2Header.parse(from: raw)

        guard header.encryptionMethod == 0 else {
            throw Qcow2Error.encryptionNotSupported
        }

        if header.backingFileOffset != 0, !allowBackingFile {
            let name: String
            if header.backingFileSize > 0 {
                try handle.seek(toOffset: header.backingFileOffset)
                let nameData = try handle.readExact(count: Int(header.backingFileSize))
                name = String(data: nameData, encoding: .utf8) ?? "<unknown>"
            } else {
                name = "<unknown>"
            }
            throw Qcow2Error.backingFileNotSupported(name)
        }

        if header.version == 3 {
            let flags = header.incompatibleFeatures
            if flags & kIncompatCorrupt != 0 {
                throw Qcow2Error.corruptedImage("corrupt bit is set; run qemu-img check to repair")
            }
            if flags & kIncompatExternalData != 0 {
                throw Qcow2Error.incompatibleFeatures(flags)
            }
            if flags & kIncompatCompressionType != 0 {
                // Non-deflate compression (e.g. zstd) – unsupported.
                throw Qcow2Error.incompatibleFeatures(flags)
            }
            if flags & ~kIncompatKnown != 0 {
                throw Qcow2Error.incompatibleFeatures(flags)
            }
        }

        return header
    }

    private static func readL1Table(_ handle: FileHandle, header: Qcow2Header) throws -> [UInt64] {
        try handle.seek(toOffset: header.l1TableOffset)
        let data = try handle.readExact(count: Int(header.l1Size) * 8)
        return (0..<Int(header.l1Size)).map { data.readUInt64BE(at: $0 * 8) }
    }

    private static func writeAllClusters(
        src: FileHandle,
        dst: FileHandle,
        header: Qcow2Header,
        l1Table: [UInt64],
        progress: ProgressHandler?
    ) throws {
        let clusterBits  = Int(header.clusterBits)
        let clusterSize  = header.clusterSize
        let l2EntryCount = header.l2EntryCount
        let l2Bits       = header.l2Bits
        let l1Shift      = clusterBits + l2Bits   // bits per L1 entry's address range
        let diskSize     = Int64(header.diskSize)

        // L2 table cache: file offset → decoded entries
        var l2Cache = [UInt64: [UInt64]](minimumCapacity: 64)

        var virtualOffset: Int64 = 0
        var bytesProcessed: Int64 = 0

        while virtualOffset < diskSize {
            let remaining = diskSize - virtualOffset
            let writeSize = Int(min(Int64(clusterSize), remaining))

            let vOff     = UInt64(bitPattern: virtualOffset)
            let l1Index  = Int(vOff >> UInt64(l1Shift))
            let l2Index  = Int((vOff >> UInt64(clusterBits)) & UInt64(l2EntryCount - 1))

            let l1Entry       = l1Index < l1Table.count ? l1Table[l1Index] : 0
            let l2TableOffset = l1Entry & kL1OffsetMask

            if l2TableOffset != 0 {
                let l2Table = try cachedL2Table(
                    at: l2TableOffset,
                    entryCount: l2EntryCount,
                    src: src,
                    cache: &l2Cache
                )

                let l2Entry = l2Table[l2Index]

                if l2Entry != 0 {
                    if l2Entry & kOflagCompressed != 0 {
                        // Compressed cluster: bit 0 of the entry is the low bit of the file
                        // offset, not the zero-cluster flag — do not test kOflagZero here.
                        let clusterData = try decompressCluster(
                            from: src,
                            l2Entry: l2Entry,
                            clusterBits: clusterBits,
                            clusterSize: clusterSize
                        )
                        try dst.seek(toOffset: vOff)
                        try dst.write(contentsOf: writeSize < clusterSize ? clusterData.prefix(writeSize) : clusterData)
                    } else if l2Entry & kOflagZero == 0 {
                        // Standard cluster: read and write.
                        let dataOffset = l2Entry & kL2OffsetMask
                        if dataOffset != 0 {
                            try src.seek(toOffset: dataOffset)
                            let clusterData = try src.readExact(count: writeSize)
                            try dst.seek(toOffset: vOff)
                            try dst.write(contentsOf: clusterData)
                        }
                    }
                }
                // l2Entry == 0 or zero-cluster flag on uncompressed entry → sparse zeros suffice.
            }
            // l2TableOffset == 0 → entire L1 range is unallocated → zeros via sparse file.

            bytesProcessed += Int64(writeSize)
            progress?(bytesProcessed, diskSize)
            virtualOffset += Int64(clusterSize)
        }
    }

    private static func cachedL2Table(
        at offset: UInt64,
        entryCount: Int,
        src: FileHandle,
        cache: inout [UInt64: [UInt64]]
    ) throws -> [UInt64] {
        if let hit = cache[offset] { return hit }
        try src.seek(toOffset: offset)
        let data  = try src.readExact(count: entryCount * 8)
        let table = (0..<entryCount).map { data.readUInt64BE(at: $0 * 8) }
        cache[offset] = table
        return table
    }

    // MARK: - Compressed clusters

    // From the QCOW2 spec and qemu source (qcow2.h):
    //   cluster_offset_mask = (1 << (63 - cluster_bits)) - 1
    //   csize_shift         = 62 - (cluster_bits - 8)  = 70 - cluster_bits
    //   csize_mask          = (1 << (cluster_bits - 8)) - 1
    //
    // Derivation:
    //   coffset    = l2_entry & cluster_offset_mask          (raw byte offset in file)
    //   nb_sectors = ((l2_entry >> csize_shift) & csize_mask) + 1
    //   read_bytes = nb_sectors * 512 - (coffset & 511)
    private static func decompressCluster(
        from handle: FileHandle,
        l2Entry: UInt64,
        clusterBits: Int,
        clusterSize: Int
    ) throws -> Data {
        let csizeShift: Int    = 70 - clusterBits
        let csizeMask: UInt64  = (UInt64(1) << (clusterBits - 8)) - 1
        let offsetMask: UInt64 = (UInt64(1) << (63 - clusterBits)) - 1

        let coffset   = l2Entry & offsetMask
        let nbSectors = Int((l2Entry >> csizeShift) & csizeMask) + 1
        let readBytes = nbSectors * 512 - Int(coffset & 511)

        try handle.seek(toOffset: coffset)
        let compressed = try handle.readExact(count: readBytes)

        return try inflate(compressed, expectedSize: clusterSize)
    }

    private static func inflate(_ data: Data, expectedSize: Int) throws -> Data {
        var output = Data(count: expectedSize)
        var success = false

        data.withUnsafeBytes { src in
            output.withUnsafeMutableBytes { dst in
                var strm = z_stream()
                strm.next_in = UnsafeMutablePointer(mutating: src.bindMemory(to: UInt8.self).baseAddress)
                strm.avail_in = uInt(src.count)
                strm.next_out = dst.bindMemory(to: UInt8.self).baseAddress
                strm.avail_out = uInt(dst.count)

                // Raw DEFLATE (negative windowBits, no zlib header). QCOW2 spec uses windowBits=-12.
                guard inflateInit2_(&strm, -12, zlibVersion(), Int32(MemoryLayout<z_stream>.size)) == Z_OK else { return }
                let ret = zlib.inflate(&strm, Z_FINISH)
                inflateEnd(&strm)
                success = (ret == Z_STREAM_END)
            }
        }

        guard success else { throw Qcow2Error.decompressionFailed }
        return output
    }
}
