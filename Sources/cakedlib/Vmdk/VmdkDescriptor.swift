import Foundation

// VMDK text descriptor parsed from a standalone .vmdk file.
//
// Extent line format (VMDK spec §4):
//   <access> <sectors> <type> ["<filename>"] [<flatOffset>]
//
// Examples:
//   RW 8323072 SPARSE "Disque virtuel-s001.vmdk"
//   RW 4096    FLAT   "Disque virtuel-flat.vmdk" 0
//   RW 2048    ZERO

struct VmdkExtent {
    enum ExtentType {
        case sparse  // monolithic/split sparse (has its own SparseExtentHeader)
        case flat    // pre-allocated raw extent
        case zero    // always-zero region
    }

    let sectors: UInt64
    let type: ExtentType
    let filename: String?    // nil for .zero extents
    let flatOffset: UInt64   // sector offset within flat file (.flat only)
}

struct VmdkDescriptor {
    let createType: String
    let extents: [VmdkExtent]

    var totalDiskSize: UInt64 { extents.reduce(0) { $0 + $1.sectors * 512 } }

    static func parse(contentsOf url: URL) throws -> VmdkDescriptor {
        let text: String
        if let utf8 = try? String(contentsOf: url, encoding: .utf8) {
            text = utf8
        } else if let latin = try? String(contentsOf: url, encoding: .isoLatin1) {
            text = latin
        } else {
            throw VmdkError.ioError("Cannot read descriptor '\(url.path(percentEncoded: false))'")
        }
        return try parse(from: text)
    }

    static func parse(from text: String) throws -> VmdkDescriptor {
        var createType = ""
        var extents: [VmdkExtent] = []
        var inExtentSection = false

        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if line == "# Extent description" {
                inExtentSection = true
                continue
            }

            if line.hasPrefix("#") {
                // Any other comment closes the extent section.
                if inExtentSection { inExtentSection = false }
                continue
            }

            if !inExtentSection {
                if line.lowercased().hasPrefix("createtype") {
                    createType = extractValue(from: line) ?? ""
                }
            } else {
                if let extent = parseExtentLine(line) {
                    extents.append(extent)
                }
            }
        }

        guard !extents.isEmpty else {
            throw VmdkError.corruptedImage("no extents found in VMDK descriptor")
        }

        return VmdkDescriptor(createType: createType, extents: extents)
    }

    // Extract value from "key=value" or `key = "value"`.
    private static func extractValue(from line: String) -> String? {
        guard let eq = line.firstIndex(of: "=") else { return nil }
        return String(line[line.index(after: eq)...])
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: ["\""])
    }

    // Parse: <access> <sectors> <type> ["<filename>"] [<flatOffset>]
    private static func parseExtentLine(_ line: String) -> VmdkExtent? {
        // Pull out the quoted filename (may contain spaces) before splitting.
        var filename: String? = nil
        var scratch = line

        if let openQ = line.firstIndex(of: "\""),
           let closeQ = line.index(after: openQ) < line.endIndex
               ? line[line.index(after: openQ)...].firstIndex(of: "\"")
               : nil
        {
            filename = String(line[line.index(after: openQ)..<closeQ])
            scratch = String(line[line.startIndex..<openQ])
                    + " "
                    + String(line[line.index(after: closeQ)...])
        }

        let parts = scratch.split(whereSeparator: \.isWhitespace).map(String.init)
        // parts: [access, sectors, type, optionalFlatOffset]
        guard parts.count >= 3, let sectors = UInt64(parts[1]) else { return nil }

        let extentType: VmdkExtent.ExtentType
        switch parts[2].uppercased() {
        case "SPARSE", "VMFS", "VMFSSPARSE":
            extentType = .sparse
        case "FLAT", "VMFSRAW", "PARTITIONEDDEVICE":
            extentType = .flat
        case "ZERO":
            extentType = .zero
        default:
            return nil
        }

        if extentType == .zero {
            return VmdkExtent(sectors: sectors, type: .zero, filename: nil, flatOffset: 0)
        }

        guard let fn = filename else { return nil }

        let flatOffset = (extentType == .flat && parts.count >= 4) ? UInt64(parts[3]) ?? 0 : 0

        return VmdkExtent(sectors: sectors, type: extentType, filename: fn, flatOffset: flatOffset)
    }
}
