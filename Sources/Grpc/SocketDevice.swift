import Foundation
import ArgumentParser

public enum SocketMode: String, Codable {
	case bind = "bind"  // Listen on unix socket
	case connect = "connect"  // Connect to unix socket
	case tcp = "tcp"  // Listen on tcp socket
	case udp = "udp"  // Listen on udp socket
	case fd = "fd"  // File descriptor
}

public struct SocketDevice: Codable {
	public var mode: SocketMode = .bind
	public var port: Int = -1
	public var bind: String

	public init(mode: SocketMode, port: Int, bind: String) {
		self.mode = mode
		self.port = port
		self.bind = bind
	}
}

extension SocketDevice: CustomStringConvertible, ExpressibleByArgument {
	public var description: String {
		if mode == .bind || mode == .connect {
			return "\(mode)://vsock:\(port)\(bind)"
		}

		return "\(mode)://\(bind):\(port)"
	}

	public init?(argument: String) {
		do {
			try self.init(parseFrom: argument)
		} catch {
			return nil
		}
	}

	public init(parseFrom: String) throws {
		guard let url = URL(string: parseFrom) else {
			throw ValidationError("unsupported socket declaration: \"\(parseFrom)\"")
		}

		guard let scheme = url.scheme else {
			throw ValidationError("unsupported socket declaration: \"\(parseFrom)\"")
		}

		guard let mode = SocketMode(rawValue: scheme) else {
			throw ValidationError("unsupported socket mode: \"\(parseFrom)\"")
		}

		guard let port = url.port else {
			throw ValidationError("port number must be defined")
		}

		guard let host: String = url.host, !host.isEmpty else {
			throw ValidationError("host must be defined")
		}

		if port < 1024 {
			throw ValidationError("port number must be greater than 1023")
		}

		self.mode = mode
		self.port = port

		if mode == .fd {
			let fds = host.split(separator: ",")

			if fds.count == 0 {
				throw ValidationError("Invalid file descriptor")
			}

			for fd in fds {
				guard let fd = Int32(fd) else {
					throw ValidationError("Invalid file descriptor fd=\(fd)")
				}

				if fcntl(fd, F_GETFD) == -1 {
					throw ValidationError("File descriptor is not valid errno=\(errno)")
				}
			}

			self.bind = host
		} else if mode == .tcp || mode == .udp {
			self.bind = host
		} else {
			if url.path.isEmpty {
				throw ValidationError("socket path must be defined")
			}

			if url.path.utf8.count > 103 {
				throw ValidationError("The socket path is too long")
			}

			self.bind = url.path
		}
	}

	public var fileDescriptors: (Int32, Int32) {
		let fd = bind.split(separator: Character(",")).compactMap { Int32($0) ?? nil }

		return (fd[0], fd.count == 2 ? fd[1] : dup(fd[0]))
	}

	public var sharedFileDescriptors: [Int32]? {
		if self.mode == .fd {
			return bind.split(separator: Character(",")).compactMap { Int32($0) ?? nil }
		}

		return nil
	}
}

