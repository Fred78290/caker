import XCTest
import Foundation
@testable import caked

final class ProcessWithSharedFileHandleTests: XCTestCase {

	func createScript(fileHandleForReading: FileHandle, fileHandleForWriting: FileHandle) throws -> URL {
		let scriptPath: URL = URL(fileURLWithPath: "/tmp/echo.py").absoluteURL
		let script = """
#!/usr/bin/env python3
import select
import io

# This script is a simple example of how to communicate with the console device in the guest.
def readmessage(fd):
	while True:
		rlist, _, _ = select.select([fd], [], [], 60)
		if fd in rlist:
			data = fd.read(8)
			if data:
				length = int.from_bytes(data, byteorder='big')

				print('Echo read message length: {0}'.format(length))

				response = bytearray()

				while length > 0:
					data = fd.read(min(8192, length))
					if data:
						length -= len(data)
						response.extend(data)

				with open('/tmp/received.txt', 'w') as text_file:
					text_file.write(response.decode())

				return response
		else:
			raise Exception('Timeout while waiting for message')

def writemessage(fd, message):
	length = len(message).to_bytes(8, 'big')

	print('Echo send message length: {0}'.format(len(message)))

	fd.write(length)
	fd.write(message)

def echo_echomessage(in_pipe, out_pipe):
	print('Reading pipe')
	message = readmessage(in_pipe)

	print('Writing pipe')
	writemessage(out_pipe, message)

	print('Acking pipe')
	response = readmessage(in_pipe)

	print('Received data: {0}'.format(response.decode()))

echo_echomessage(io.FileIO(\(fileHandleForReading.fileDescriptor)), io.FileIO(\(fileHandleForWriting.fileDescriptor), 'w'))
"""

		try script.write(to: scriptPath, atomically: true, encoding: .ascii)
		try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)

		return scriptPath
	}

	func writeMessage(_ message: String, to fileHandle: FileHandle) {
		let strData = message.data(using: .utf8)!
		let lengthBuffer = withUnsafeBytes(of: strData.count.bigEndian) {
			var lengthData = Data(repeating: 0, count: 8)

			for i in 0..<$0.count {
				lengthData[i] = $0[i]
			}

			return lengthData
		}

		fileHandle.write(lengthBuffer)
		fileHandle.write(strData)
	}

	func readMessage(from: FileHandle) -> String {
		let lengthBuffer = from.readData(ofLength: 8)
		let length = lengthBuffer.withUnsafeBytes { $0.load(as: Int.self).bigEndian }
		let message = from.readData(ofLength: length)

		return String(data: message, encoding: .utf8)!
	}

	func echoMessage(input: FileHandle, output: FileHandle, message: String) {
		writeMessage(message, to: output)
		let response = readMessage(from: input)

		writeMessage("end", to: output)

		XCTAssertEqual(message, response)
	}

	func testSharedFileHandle() throws {
		let process: ProcessWithSharedFileHandle = ProcessWithSharedFileHandle()
		let inputPipe = Pipe()
		let outputPipe = Pipe()
		let content = "Hello, World!"
		let location = try createScript(fileHandleForReading: inputPipe.fileHandleForReading, fileHandleForWriting: outputPipe.fileHandleForWriting)
		
		print("execute: \(location)")

		let out = Pipe()

		out.fileHandleForReading.readabilityHandler = { handler in
			let data = handler.availableData
			if data.count > 0 {
				print("\(String(data: data, encoding: .utf8)!)")
			}
		}

		//process.executableURL = URL(fileURLWithPath: "/bin/bash")
		process.executableURL = location
		process.standardInput = FileHandle.standardInput
		process.standardOutput = out
		process.standardError = out
		process.sharedFileHandles = [inputPipe.fileHandleForReading, outputPipe.fileHandleForWriting]
		//process.arguments = ["-c", "exec \(location.path) | tee /tmp/output.txt"]
		process.terminationHandler = { process in
			print("Process terminated: \(process.terminationStatus)")
			XCTAssertEqual(process.terminationStatus, 0)
			//Foundation.exit(process.terminationStatus)
		}

		try process.run()

		//sleep(30)
		echoMessage(input: outputPipe.fileHandleForReading, output: inputPipe.fileHandleForWriting, message: content)
		process.waitUntilExit()

		print("Process terminated")
	}
}