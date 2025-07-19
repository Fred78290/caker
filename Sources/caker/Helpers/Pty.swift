//
//  Pty.swift
//  Caker
//
//  Created by Frederic BOLTZ on 18/07/2025.
//
import Foundation
import System

struct Pty {
	let ptx: FileHandle
	let pty: FileHandle

	init() throws {
		let master = try Self.createPTY()

		self.ptx = FileHandle(fileDescriptor: master.0, closeOnDealloc: true)
		self.pty = FileHandle(fileDescriptor: master.1, closeOnDealloc: true)
	}

	func setTermSize(rows: Int32, cols: Int32) throws {
		try pty.setTermSize(rows: rows, cols: cols)
	}

	private static func createPTY() throws -> (Int32, Int32) {
		var tty_fd: Int32 = -1
		var sfd: Int32 = -1
		let tty_path = UnsafeMutablePointer<CChar>.allocate(capacity: 1024)

		defer {
			tty_path.deallocate()
		}

		let res = openpty(&tty_fd, &sfd, tty_path, nil, nil);

		if (res < 0) {
			throw Errno(rawValue: errno)
		}

		return (tty_fd, sfd)
	}
}
