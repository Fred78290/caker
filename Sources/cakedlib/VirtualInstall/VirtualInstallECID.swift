//
// Derives the device ECID from a VM's machine identifier.
// Ported from VirtualBuddy 2.2-b2 / UTM, adapted for Caker.
// Not available in the App Store build (private SPI + non-sandboxed only).

#if !APPSTORE && arch(arm64)

import Foundation

/// Extracts the `ECID` (UInt64) from a machine identifier's `dataRepresentation`.
///
/// `VZMacMachineIdentifier.dataRepresentation` is a binary property list that
/// contains an `"ECID"` key. Caker stores that blob in `CakeConfig.ecid`, so
/// the ECID can be derived directly from the stored `Data` without constructing
/// a full `VZMacMachineIdentifier`.
///
/// - Parameter data: the raw `dataRepresentation` of a `VZMacMachineIdentifier`.
/// - Returns: the device ECID, or `nil` if the plist could not be parsed or has
///   no `"ECID"` key.
func cakerECID(fromMachineIdentifierData data: Data) -> ECID? {
    guard let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
        return nil
    }
    return dict["ECID"] as? ECID
}

#if arch(arm64)
import Virtualization

@available(macOS 12.0, *)
extension VZMacMachineIdentifier {
    /// The device ECID encoded in this machine identifier, or `nil` if it could
    /// not be parsed.
    var ecid: ECID? {
        cakerECID(fromMachineIdentifierData: dataRepresentation)
    }
}
#endif

#endif
