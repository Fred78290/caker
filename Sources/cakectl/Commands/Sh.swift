import ArgumentParser
import Foundation
import GRPCLib
@preconcurrency import GRPC
import NIO
import NIOPosix
import NIOSSL

extension FileHandle {
	func makeRaw() -> termios {
		var term: termios = termios()
		let inputTTY: Bool = isatty(self.fileDescriptor) != 0

		if inputTTY {
			if tcgetattr(self.fileDescriptor, &term) != 0 {
				perror("tcgetattr error")
			}

			var newState: termios = term

			newState.c_iflag &= UInt(IGNBRK) | ~UInt(BRKINT | INPCK | ISTRIP | IXON)
			newState.c_cflag |= UInt(CS8)
			newState.c_lflag &= ~UInt(ECHO | ICANON | IEXTEN | ISIG)
			newState.c_cc.16 = 1
			newState.c_cc.17 = 17

			if tcsetattr(self.fileDescriptor, TCSANOW, &newState) != 0 {
				perror("tcsetattr error")
			}
		}

		return term
	}

	func restoreState(_ term: UnsafePointer<termios>) {
		if tcsetattr(self.fileDescriptor, TCSANOW, term) != 0 {
			perror("tcsetattr error")
		}
	}
}

struct Sh: AsyncGrpcParsableCommand {
	static var configuration = CommandConfiguration(commandName: "shell", abstract: "Run a shell on a VM")

	@OptionGroup var options: Client.Options

	@Argument(help: "VM name")
	var name: String = ""

	func run(client: CakeAgentClient, arguments: [String], callOptions: CallOptions?) async throws -> Caked_Reply {
		Foundation.exit(try await client.shell(name: name, callOptions: callOptions))
	}
}
