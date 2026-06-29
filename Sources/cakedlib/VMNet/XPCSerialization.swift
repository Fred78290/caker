//
//  XPCSerialization.swift
//  Caker
//
//  Converts xpc_object_t ↔ Data so the vmnet serialization can be transmitted
//  over a gRPC channel (Unix socket).  Each XPC value is wrapped in a typed
//  tag so round-trip fidelity is preserved even when the vmnet dictionary
//  contains mixed numeric / boolean / uuid types.
//

import Foundation
import vmnet

// MARK: - Encoding

/// Converts an `xpc_object_t` to binary property-list `Data`.
func encodeXPCObject(_ obj: xpc_object_t) throws -> Data {
    let tagged = xpcToTagged(obj)
    return try PropertyListSerialization.data(fromPropertyList: tagged, format: .binary, options: 0)
}

/// Converts binary property-list `Data` back to an `xpc_object_t`.
func decodeXPCObject(_ data: Data) throws -> xpc_object_t {
    let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
    guard let obj = taggedToXPC(plist) else {
        throw ServiceError(String(localized: "Failed to reconstruct XPC object from serialization data"))
    }
    return obj
}

// MARK: - XPC → tagged Foundation

/// Tags used to identify the original XPC type inside the property-list wrapper.
private let kTagKey   = "T"
private let kValueKey = "V"

private let tagDict   = "d"
private let tagArray  = "a"
private let tagData   = "b"
private let tagString = "s"
private let tagInt64  = "i"
private let tagUInt64 = "u"
private let tagBool   = "B"
private let tagDouble = "f"
private let tagUUID   = "U"

private func xpcToTagged(_ obj: xpc_object_t) -> NSDictionary {
    let type = xpc_get_type(obj)

    if type == XPC_TYPE_DICTIONARY {
        var dict = [String: NSDictionary]()
        xpc_dictionary_apply(obj) { key, value in
            dict[String(cString: key)] = xpcToTagged(value)
            return true
        }
        return [kTagKey: tagDict, kValueKey: dict as NSDictionary] as NSDictionary

    } else if type == XPC_TYPE_ARRAY {
        var array = [NSDictionary]()
        xpc_array_apply(obj) { _, value in
            array.append(xpcToTagged(value))
            return true
        }
        return [kTagKey: tagArray, kValueKey: array as NSArray] as NSDictionary

    } else if type == XPC_TYPE_DATA {
        let ptr = xpc_data_get_bytes_ptr(obj)!
        let count = xpc_data_get_length(obj)
        let nsdata = NSData(bytes: ptr, length: count)
        return [kTagKey: tagData, kValueKey: nsdata] as NSDictionary

    } else if type == XPC_TYPE_STRING {
        let str = xpc_string_get_string_ptr(obj).map { String(cString: $0) } ?? ""
        return [kTagKey: tagString, kValueKey: str as NSString] as NSDictionary

    } else if type == XPC_TYPE_INT64 {
        let val = xpc_int64_get_value(obj)
        return [kTagKey: tagInt64, kValueKey: NSNumber(value: val)] as NSDictionary

    } else if type == XPC_TYPE_UINT64 {
        // Store uint64 as a hex string to avoid NSNumber sign issues.
        let val = xpc_uint64_get_value(obj)
        return [kTagKey: tagUInt64, kValueKey: String(val, radix: 16) as NSString] as NSDictionary

    } else if type == XPC_TYPE_BOOL {
        let val = xpc_bool_get_value(obj)
        return [kTagKey: tagBool, kValueKey: NSNumber(value: val)] as NSDictionary

    } else if type == XPC_TYPE_DOUBLE {
        let val = xpc_double_get_value(obj)
        return [kTagKey: tagDouble, kValueKey: NSNumber(value: val)] as NSDictionary

    } else if type == XPC_TYPE_UUID {
        let ptr = xpc_uuid_get_bytes(obj)!
        let uuidData = NSData(bytes: ptr, length: 16)
        return [kTagKey: tagUUID, kValueKey: uuidData] as NSDictionary
    }

    // Fallback: treat unknown types as empty data
    return [kTagKey: tagData, kValueKey: NSData()] as NSDictionary
}

// MARK: - Tagged Foundation → XPC

private func taggedToXPC(_ plist: Any) -> xpc_object_t? {
    guard let dict = plist as? [String: Any],
          let tag = dict[kTagKey] as? String,
          let value = dict[kValueKey]
    else { return nil }

    switch tag {
    case tagDict:
        guard let entries = value as? [String: Any] else { return nil }
        let xpcDict = xpc_dictionary_create(nil, nil, 0)
        for (key, entry) in entries {
            if let xpcVal = taggedToXPC(entry) {
                xpc_dictionary_set_value(xpcDict, key, xpcVal)
            }
        }
        return xpcDict

    case tagArray:
        guard let items = value as? [Any] else { return nil }
        let xpcArray = xpc_array_create(nil, 0)
        for item in items {
            if let xpcVal = taggedToXPC(item) {
                xpc_array_append_value(xpcArray, xpcVal)
            }
        }
        return xpcArray

    case tagData:
        guard let data = value as? Data else { return nil }
        return data.withUnsafeBytes { xpc_data_create($0.baseAddress!, data.count) }

    case tagString:
        guard let str = value as? String else { return nil }
        return xpc_string_create(str)

    case tagInt64:
        guard let num = value as? NSNumber else { return nil }
        return xpc_int64_create(num.int64Value)

    case tagUInt64:
        guard let hex = value as? String, let val = UInt64(hex, radix: 16) else { return nil }
        return xpc_uint64_create(val)

    case tagBool:
        guard let num = value as? NSNumber else { return nil }
        return xpc_bool_create(num.boolValue)

    case tagDouble:
        guard let num = value as? NSNumber else { return nil }
        return xpc_double_create(num.doubleValue)

    case tagUUID:
        guard let data = value as? Data, data.count == 16 else { return nil }
        return data.withUnsafeBytes { ptr -> xpc_object_t in
            xpc_uuid_create(ptr.bindMemory(to: UInt8.self).baseAddress!)
        }

    default:
        return nil
    }
}
