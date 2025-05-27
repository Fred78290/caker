//
//  FileLock.swift
//  Caker
//
//  Created by Frederic BOLTZ on 05/02/2025.
//
import Foundation
import System

public enum FileLockError: Error, Equatable {
	case Failed(_ message: String)
	case AlreadyLocked
}

public class FileLock {
	let url: URL
	let fd: Int32

	deinit {
		close(fd)
	}

	public init(lockURL: URL) throws {
		url = lockURL
		fd = open(lockURL.path, 0)

		if fd == -1 {
			throw FileLockError.Failed("failed to open \(lockURL)")
		}
	}

	public func trylock() throws -> Bool {
		try flockWrapper(LOCK_EX | LOCK_NB)
	}

	public func lock() throws {
		_ = try flockWrapper(LOCK_EX)
	}

	public func unlock() throws {
		_ = try flockWrapper(LOCK_UN)
	}

	func flockWrapper(_ operation: Int32) throws -> Bool {
		if flock(fd, operation) != 0 {
			let details: Errno = Errno(rawValue: CInt(errno))

			if (operation & LOCK_NB) != 0 && details == .wouldBlock {
				return false
			}

			throw FileLockError.Failed("failed to lock \(url): \(details)")
		}

		return true
	}
}
