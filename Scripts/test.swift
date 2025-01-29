#!/usr/bin/swift

import Foundation

var process = Process()
var inputPipe = Pipe()
var outputPipe = Pipe()
let content = "Hello, World!"

func clear_close_on_exec(_ fd: Int32) {
	var value = fcntl(fd, F_GETFD)

	if value < 0 {
		perror("fcntl")
	} else {
		value |= FD_CLOEXEC
		if fcntl(fd, F_SETFD, value) < 0 {
			perror("fcntl")
		}
	}
}

inputPipe.fileHandleForReading.readabilityHandler = { handler in
	let data = handler.availableData
	print(String(data: data, encoding: .utf8)!)
}

outputPipe.fileHandleForWriting.writeabilityHandler = { handler in
	handler.write(content.data(using: .utf8)!)
}

print(String(format: "%02X", fcntl(inputPipe.fileHandleForWriting.fileDescriptor, F_GETFD)))

clear_close_on_exec(outputPipe.fileHandleForReading.fileDescriptor)
clear_close_on_exec(inputPipe.fileHandleForWriting.fileDescriptor)

process.executableURL = URL(fileURLWithPath: "/opt/bin/tart")
process.standardInput = FileHandle.standardInput
process.standardOutput = FileHandle.standardOutput
process.standardError = FileHandle.standardError
process.arguments = [
	"run",
	"noble-cloud-image",
	"--vsock=fd://\(outputPipe.fileHandleForReading.fileDescriptor),\(inputPipe.fileHandleForWriting.fileDescriptor):9999"
]

try process.run()

process.waitUntilExit()