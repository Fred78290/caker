import Foundation
import ArgumentParser

public struct ConsoleAttachment: CustomStringConvertible, ExpressibleByArgument, Codable {
    let consoleURL: String

	public var description: String {
		consoleURL
	}

    public init(argument: String) {
		self.consoleURL = argument
    }

	public func validate() throws {
		if consoleURL !=  "file" && consoleURL != "unix" {
			guard let u: URL = URL(string: consoleURL) else {
				throw ValidationError("Invalid serial console URL")
			}

			if u.scheme != "unix" && u.scheme != "fd" && u.isFileURL == false {
				throw ValidationError("Invalid serial console URL scheme: must be unix, fd or file")
			}

			if u.scheme == "fd" {
				let host = u.host?.split(separator: ",")

				if host == nil || host!.count == 0 {
					throw ValidationError("Invalid console URL: file descriptor is not specified")
				}

				for fd in host! {
					guard let fd = Int32(fd) else {
						throw ValidationError("Invalid console URL: file descriptor \(fd) is not a number")
					}

					if fcntl(fd, F_GETFD) == -1 {
						throw ValidationError("Invalid console URL: file descriptor \(fd) is not valid errno=\(errno)")
					}
				}
			} else {
				if u.path == "" {
					throw ValidationError("Invalid console URL")
				}

				if u.scheme == "unix" && u.path.utf8.count > 103 {
					throw ValidationError("The unix socket is too long")
				}
			}
		}
	}

    public func consoleURL(vmDir: URL) throws -> URL? {
		if consoleURL ==  "file" {
			return vmDir.appendingPathComponent("console.log")
		} else if consoleURL == "unix" {
			return vmDir.appendingPathComponent("console.sock")
		} else {
			return URL(string: consoleURL)
		}
    }

}