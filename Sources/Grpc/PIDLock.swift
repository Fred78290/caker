//
//  PIDLock.swift
//  Caker
//
//  Created by Frederic BOLTZ on 05/02/2025.
//
import Foundation
import System

public class PIDLock {
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

	public func trylock() throws -> (Bool, flock) {
		try flockWrapper(F_SETLK, F_WRLCK)
	}

	public func lock() throws {
		_ = try flockWrapper(F_SETLKW, F_WRLCK)
	}

	public func unlock() throws {
		_ = try flockWrapper(F_SETLK, F_UNLCK)
	}

	public func pid() throws -> pid_t {
		let (_, result) = try flockWrapper(F_GETLK, F_RDLCK)

		return result.l_pid
	}

	func flockWrapper(_ operation: Int32, _ type: Int32) throws -> (Bool, flock) {
		var result = flock(l_start: 0, l_len: 0, l_pid: 0, l_type: Int16(type), l_whence: Int16(SEEK_SET))

		if fcntl(fd, operation, &result) != 0 {
			let details: Errno = Errno(rawValue: CInt(errno))

			if operation == F_SETLK && details == .resourceTemporarilyUnavailable {
				return (false, result)
			}

			throw FileLockError.Failed("failed to handle lock \(url): \(details)")
		}

		return (true, result)
	}
}
