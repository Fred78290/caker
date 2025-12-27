//
//  VNCFixedWidthInteger.swift
//  Caker
//
//  Created by Frederic BOLTZ on 07/12/2025.
//

import Foundation

protocol VNCLoadMessage {
	static func load(from data: UnsafeRawBufferPointer) -> Self
}

extension FixedWidthInteger {
	var hexadecimal: String {
		String(self, radix: 16)
	}
}

extension UInt32: VNCLoadMessage {
	static func load(from data: UnsafeRawBufferPointer) -> UInt32 {
		UInt32.init(bigEndian: UInt32(data[0]) << 24 | UInt32(data[1]) << 16 | UInt32(data[2]) << 8 | UInt32(data[3]))
	}
}

extension UInt32 {
	static func build(_ a: UInt8, _ b: UInt8, _ c: UInt8, _ d: UInt8) -> UInt32 {
		var value: UInt32 = 0

		withUnsafeMutableBytes(of: &value) { ptr in
			ptr[3] = a
			ptr[2] = b
			ptr[1] = c
			ptr[0] = d
		}

		return value.littleEndian
	}

	var hexa: String {
		withUnsafeBytes(of: self) { ptr in
			String(format: "%02X %02X %02X %02X", ptr[0], ptr[1], ptr[2], ptr[3])
		}
	}
}

extension Int32: VNCLoadMessage {
	static func load(from data: UnsafeRawBufferPointer) -> Int32 {
		Int32.init(bigEndian: Int32(data[3]) << 24 | Int32(data[2]) << 16 | Int32(data[1]) << 8 | Int32(data[0]))
	}
}

extension Int32 {
	static func build(_ a: UInt8, _ b: UInt8, _ c: UInt8, _ d: UInt8) -> Int32 {
		var value: Int32 = 0

		withUnsafeMutableBytes(of: &value) { ptr in
			ptr[3] = a
			ptr[2] = b
			ptr[1] = c
			ptr[0] = d
		}

		return value.littleEndian
	}

	var hexa: String {
		withUnsafeBytes(of: self) { ptr in
			String(format: "%02X %02X %02X %02X", ptr[0], ptr[1], ptr[2], ptr[3])
		}
	}
}

extension UInt16: VNCLoadMessage {
	static func load(from data: UnsafeRawBufferPointer) -> UInt16 {
		UInt16.init(bigEndian: UInt16(data[1]) << 8 | UInt16(data[0]))
	}
}

extension UInt16 {
	static func build(_ a: UInt8, _ b: UInt8) -> UInt16 {
		var value: UInt16 = 0

		withUnsafeMutableBytes(of: &value) { ptr in
			ptr[1] = a
			ptr[0] = b
		}

		return value.littleEndian
	}

	var hexa: String {
		withUnsafeBytes(of: self) { ptr in
			String(format: "%02X %02X", ptr[0], ptr[1])
		}
	}
}

extension Int16: VNCLoadMessage {
	static func load(from data: UnsafeRawBufferPointer) -> Int16 {
		Int16.init(bigEndian: Int16(data[1]) << 8 | Int16(data[0]))
	}
}

extension Int16 {
	static func build(_ a: UInt8, _ b: UInt8) -> Int16 {
		var value: Int16 = 0

		withUnsafeMutableBytes(of: &value) { ptr in
			ptr[1] = a
			ptr[0] = b
		}

		return value.littleEndian
	}

	var hexa: String {
		withUnsafeBytes(of: self) { ptr in
			String(format: "%02X %02X", ptr[0], ptr[1])
		}
	}
}

extension UInt8: VNCLoadMessage {
	static func load(from data: UnsafeRawBufferPointer) -> UInt8 {
		data[0]
	}
}

extension UInt8 {
	var hexa: String {
		withUnsafeBytes(of: self) { ptr in
			String(format: "%02X", ptr[0])
		}
	}
}
