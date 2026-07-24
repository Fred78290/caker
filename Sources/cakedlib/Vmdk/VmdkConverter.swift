import Foundation

// Grain Table Entry (GTE) special values (VMDK spec §3):
//   0 = grain not allocated  → reads as zeros (sparse)
//   1 = grain explicitly zero → reads as zeros
//  ≥4 = sector offset of grain data in the VMDK file
private let kGTEZero: UInt32 = 1

public final class VmdkConverter {

    /// Called periodically during conversion.
    /// - Parameters:
    ///   - bytesProcessed: virtual bytes written so far
    ///   - totalBytes: total virtual disk size in bytes
    public typealias ProgressHandler = (_ bytesProcessed: Int64, _ totalBytes: Int64) -> Void

    // MARK: - Public API

    /// Converts a VMDK to a flat raw disk image.
    /// Accepts both a monolithic-sparse binary VMDK and a text descriptor file
    /// (e.g. `twoGbMaxExtentSparse`) whose extents are resolved relative to the
    /// descriptor's parent directory.
    public static func convert(
        from source: URL,
        to destination: URL,
        progress: ProgressHandler? = nil
    ) throws {
        try convert(fromPath: source.path(percentEncoded: false), toPath: destination.path(percentEncoded: false), progress: progress)
    }

    /// Path-based overload.
    public static func convert(
        fromPath sourcePath: String,
        toPath destinationPath: String,
        progress: ProgressHandler? = nil
    ) throws {
        let sourceURL = URL(fileURLWithPath: sourcePath)

        if try isDescriptorFile(at: sourceURL) {
            let descriptor = try VmdkDescriptor.parse(contentsOf: sourceURL)
            let baseDir = sourceURL.deletingLastPathComponent()
            try convertDescriptor(descriptor, baseDir: baseDir, toPath: destinationPath, progress: progress)
        } else {
            try convertBinary(fromPath: sourcePath, toPath: destinationPath, progress: progress)
        }
    }

    // MARK: - Format detection

    private static func isDescriptorFile(at url: URL) throws -> Bool {
        guard let fh = FileHandle(forReadingAtPath: url.path(percentEncoded: false)) else {
            throw VmdkError.ioError("Cannot open '\(url.path(percentEncoded: false))'")
        }
        defer { try? fh.close() }
        let probe = try fh.readExact(count: 4)
        return probe.count < 4 || probe.readUInt32LE(at: 0) != VmdkHeader.magic
    }

    // MARK: - Descriptor-based (multi-extent) conversion

    private static func convertDescriptor(
        _ descriptor: VmdkDescriptor,
        baseDir: URL,
        toPath destinationPath: String,
        progress: ProgressHandler?
    ) throws {
        let totalDiskSize = descriptor.totalDiskSize
        let totalSizeSigned = Int64(bitPattern: totalDiskSize)

        FileManager.default.createFile(atPath: destinationPath, contents: nil)
        guard let dst = FileHandle(forWritingAtPath: destinationPath) else {
            throw VmdkError.ioError("Cannot open '\(destinationPath)' for writing")
        }
        defer { try? dst.close() }

        try dst.truncate(atOffset: totalDiskSize)

        var baseOffset: UInt64 = 0
        var bytesProcessed: Int64 = 0

        for extent in descriptor.extents {
            switch extent.type {
            case .zero:
                bytesProcessed += Int64(extent.sectors * 512)
                progress?(bytesProcessed, totalSizeSigned)

            case .flat:
                let extentURL = baseDir.appendingPathComponent(extent.filename!)
                guard let src = FileHandle(forReadingAtPath: extentURL.path(percentEncoded: false)) else {
                    throw VmdkError.ioError("Cannot open extent '\(extentURL.path(percentEncoded: false))'")
                }
                defer { try? src.close() }
                try src.seek(toOffset: extent.flatOffset * 512)
                try writeFlatData(from: src, to: dst, at: baseOffset, size: extent.sectors * 512,
                                  bytesProcessed: &bytesProcessed, totalSize: totalSizeSigned, progress: progress)

            case .sparse:
                let extentURL = baseDir.appendingPathComponent(extent.filename!)
                guard let src = FileHandle(forReadingAtPath: extentURL.path(percentEncoded: false)) else {
                    throw VmdkError.ioError("Cannot open extent '\(extentURL.path(percentEncoded: false))'")
                }
                defer { try? src.close() }
                let header = try parseAndValidateHeader(src, path: extentURL.path(percentEncoded: false))
                try writeAllGrains(src: src, dst: dst, header: header, baseOffset: baseOffset,
                                   bytesProcessed: &bytesProcessed, totalSize: totalSizeSigned, progress: progress)
            }

            baseOffset += extent.sectors * 512
        }
    }

    // MARK: - Binary monolithic-sparse conversion

    private static func convertBinary(
        fromPath sourcePath: String,
        toPath destinationPath: String,
        progress: ProgressHandler?
    ) throws {
        guard let src = FileHandle(forReadingAtPath: sourcePath) else {
            throw VmdkError.ioError("Cannot open '\(sourcePath)'")
        }
        defer { try? src.close() }

        let header = try parseAndValidateHeader(src, path: sourcePath)

        FileManager.default.createFile(atPath: destinationPath, contents: nil)
        guard let dst = FileHandle(forWritingAtPath: destinationPath) else {
            throw VmdkError.ioError("Cannot open '\(destinationPath)' for writing")
        }
        defer { try? dst.close() }

        try dst.truncate(atOffset: header.diskSize)

        let totalSize = Int64(bitPattern: header.diskSize)
        var bytesProcessed: Int64 = 0
        try writeAllGrains(src: src, dst: dst, header: header, baseOffset: 0,
                           bytesProcessed: &bytesProcessed, totalSize: totalSize, progress: progress)
    }

    // MARK: - Shared helpers

    private static func parseAndValidateHeader(_ handle: FileHandle, path: String) throws -> VmdkHeader {
        let raw = try handle.readExact(count: VmdkHeader.headerSize)
        let header = try VmdkHeader.parse(from: raw)

        guard header.compressAlgorithm == 0 else {
            throw VmdkError.compressionNotSupported(header.compressAlgorithm)
        }
        guard header.grainSize > 0, (header.grainSize & (header.grainSize - 1)) == 0 else {
            throw VmdkError.corruptedImage("grainSize \(header.grainSize) is not a power of 2")
        }
        guard header.numGTEsPerGT > 0 else {
            throw VmdkError.corruptedImage("numGTEsPerGT is zero")
        }
        guard header.effectiveGdOffset != nil else {
            throw VmdkError.corruptedImage("grain directory not present (stream-optimized or unfinished image)")
        }

        return header
    }

    // Copy a contiguous flat region in 1 MB chunks.
    private static func writeFlatData(
        from src: FileHandle,
        to dst: FileHandle,
        at baseOffset: UInt64,
        size: UInt64,
        bytesProcessed: inout Int64,
        totalSize: Int64,
        progress: ProgressHandler?
    ) throws {
        let chunkSize: UInt64 = 1 << 20  // 1 MB
        var offset: UInt64 = 0

        while offset < size {
            let toRead = Int(min(chunkSize, size - offset))
            let chunk = try src.readExact(count: toRead)
            try dst.seek(toOffset: baseOffset + offset)
            try dst.write(contentsOf: chunk)
            offset += UInt64(toRead)
            bytesProcessed += Int64(toRead)
            progress?(bytesProcessed, totalSize)
        }
    }

    // Walk grain-directory → grain-table → grain, writing allocated grains to dst.
    // Unallocated and explicitly-zero grains are left as zeros in the pre-truncated output.
    private static func writeAllGrains(
        src: FileHandle,
        dst: FileHandle,
        header: VmdkHeader,
        baseOffset: UInt64,
        bytesProcessed: inout Int64,
        totalSize: Int64,
        progress: ProgressHandler?
    ) throws {
        let gdByteOffset = header.effectiveGdOffset! * 512
        let numGDE    = header.numGDEntries
        let numGTE    = Int(header.numGTEsPerGT)
        let grainSize = UInt64(header.grainSize)
        let grainBytes = header.grainBytes
        let diskSize  = header.diskSize

        try src.seek(toOffset: gdByteOffset)
        let gdData = try src.readExact(count: numGDE * 4)

        var vSector: UInt64 = 0

        outerLoop: for gdi in 0..<numGDE {
            let gtSector = UInt64(gdData.readUInt32LE(at: gdi * 4))

            var gtData: Data? = nil
            if gtSector != 0 {
                try src.seek(toOffset: gtSector * 512)
                gtData = try src.readExact(count: numGTE * 4)
            }

            for gti in 0..<numGTE {
                let vByteOff = vSector * 512
                if vByteOff >= diskSize { break outerLoop }

                let remaining = diskSize - vByteOff
                let writeSize = Int(min(UInt64(grainBytes), remaining))

                if let gtData = gtData {
                    let gte = gtData.readUInt32LE(at: gti * 4)
                    if gte > kGTEZero {
                        try src.seek(toOffset: UInt64(gte) * 512)
                        let grainData = try src.readExact(count: writeSize)
                        try dst.seek(toOffset: baseOffset + vByteOff)
                        try dst.write(contentsOf: grainData)
                    }
                }

                bytesProcessed += Int64(writeSize)
                progress?(bytesProcessed, totalSize)
                vSector += grainSize
            }
        }
    }
}
