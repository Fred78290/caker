import XCTest
import Foundation
@testable import caked

final class ProcessWithSharedFileHandleTests: XCTestCase {

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

		process.executableURL = URL(fileURLWithPath: "/opt/bin/tart")
		process.standardInput = FileHandle.standardInput
		process.standardOutput = FileHandle.standardOutput
		process.standardError = FileHandle.standardError
		process.sharedFileHandles = [inputPipe.fileHandleForReading, outputPipe.fileHandleForWriting]
		process.arguments = [
			"run",
			"noble-cloud-image",
			"--disk=~/.cake/vms/noble-cloud-image/cloud-init.iso",
			"--console=fd://\(inputPipe.fileHandleForReading.fileDescriptor),\(outputPipe.fileHandleForWriting.fileDescriptor)"
		]

		try process.run()

		//sleep(30)
		echoMessage(input: outputPipe.fileHandleForReading, output: inputPipe.fileHandleForWriting, message: content)
		process.waitUntilExit()
	}
}