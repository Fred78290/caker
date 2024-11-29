import Foundation

public struct ShellError: Swift.Error {
	/// The termination status of the command that was run
	public let terminationStatus: Int32
	/// The error message as a UTF8 string, as returned through `STDERR`
	public var message: String { return errorData.shellOutput() }
	/// The raw error buffer data, as returned through `STDERR`
	public let errorData: Data
	/// The raw output buffer data, as retuned through `STDOUT`
	public let outputData: Data
	/// The output of the command as a UTF8 string, as returned through `STDOUT`
	public var output: String { return outputData.shellOutput() }
}

struct Shell {
	@discardableResult static public func execute(
		to command: String,
		arguments: [String] = [],
		at path: String = ".",
		process: Process = .init(),
		outputHandle: FileHandle? = nil,
		errorHandle: FileHandle? = nil
	) throws -> String {
		let command = "cd \(path.replacingOccurrences(of: " ", with: "\\ ")) && \(command) \(arguments.joined(separator: " "))"

		return try process.bash(
			with: command,
			outputHandle: outputHandle,
			errorHandle: errorHandle
		)
	}

	@discardableResult static func runTart(command: String, arguments: [String], direct: Bool = false) throws -> String{
		var args: [String] = []
		var outputData: Data = Data()
		let outputPipe = Pipe()
		let errorPipe : Pipe = direct ? Pipe() : outputPipe
		let cakeHomeDir = try Utils.getHome(asSystem: runAsSystem)

		if command.count > 0 {
			args.append(command)
		}

		args += arguments

		outputPipe.fileHandleForReading.readabilityHandler = { handler in
			if direct {
				try? FileHandle.standardOutput.write(contentsOf: handler.availableData)
			} else {
				outputData.append(handler.availableData)
			}
		}

		if direct {
			errorPipe.fileHandleForReading.readabilityHandler = { handler in
				try? FileHandle.standardError.write(contentsOf: handler.availableData)
			}
		}

		var environment = ProcessInfo.processInfo.environment

		environment["TART_HOME"] = cakeHomeDir.path()

		let _ = try Self.bash(to: "tart", arguments: args,
		                      outputHandle: outputPipe.fileHandleForWriting,
		                      errorHandle: errorPipe.fileHandleForWriting,
							  environment: environment)

		return String(data: outputData,  encoding: .utf8)!
	}

	@discardableResult static public func bash(
		to command: String,
		arguments: [String] = [],
		at path: String = ".",
		process: Process = .init(),
		outputHandle: FileHandle? = nil,
		errorHandle: FileHandle? = nil,
		environment: [String : String]? = nil
	) throws -> String {
		let command = "cd \(path.replacingOccurrences(of: " ", with: "\\ ")) && \(command) \(arguments.joined(separator: " "))"

		return try process.bash(
			with: command,
			outputHandle: outputHandle,
			errorHandle: errorHandle,
			environment: environment
		)
	}

}

private extension FileHandle {
	var isStandard: Bool {
		return self === FileHandle.standardOutput ||
			self === FileHandle.standardError ||
			self === FileHandle.standardInput
	}
}

private extension Process {
	@discardableResult func bash(with command: String,
	                                   outputHandle: FileHandle? = nil,
	                                   errorHandle: FileHandle? = nil,
	                                   environment: [String : String]? = nil) throws -> String {

		if #available(OSX 10.13, *) {
			self.executableURL = URL(fileURLWithPath: "/bin/bash")
		} else {
			self.launchPath = "/bin/bash"
		}
		self.arguments = ["-c", command]

		if environment != nil {
			self.environment = environment
		}

		// Because FileHandle's readabilityHandler might be called from a
		// different queue from the calling queue, avoid a data race by
		// protecting reads and writes to outputData and errorData on
		// a single dispatch queue.
		let outputQueue = DispatchQueue(label: "bash-output-queue")

		var outputData = Data()
		var errorData = Data()

		let outputPipe = Pipe()
		standardOutput = outputPipe

		let errorPipe = Pipe()
		standardError = errorPipe

		outputPipe.fileHandleForReading.readabilityHandler = { handler in
			let data = handler.availableData
			outputQueue.async {
				outputData.append(data)
				outputHandle?.write(data)
			}
		}

		errorPipe.fileHandleForReading.readabilityHandler = { handler in
			let data = handler.availableData
			outputQueue.async {
				errorData.append(data)
				errorHandle?.write(data)
			}
		}

		if #available(OSX 10.13, *) {
			try self.run()
		} else {
			self.launch()
		}

		waitUntilExit()

		if let handle = outputHandle, !handle.isStandard {
			handle.closeFile()
		}

		if let handle = errorHandle, !handle.isStandard {
			handle.closeFile()
		}

		outputPipe.fileHandleForReading.readabilityHandler = nil
		errorPipe.fileHandleForReading.readabilityHandler = nil

		// Block until all writes have occurred to outputData and errorData,
		// and then read the data back out.
		return try outputQueue.sync {
			if terminationStatus != 0 {
				throw ShellError(
					terminationStatus: terminationStatus,
					errorData: errorData,
					outputData: outputData
				)
			}

			return outputData.shellOutput()
		}
	}
}

private extension Data {
	func shellOutput() -> String {
		guard let output = String(data: self, encoding: .utf8) else {
			return ""
		}

		guard !output.hasSuffix("\n") else {
			let endIndex = output.index(before: output.endIndex)
			return String(output[..<endIndex])
		}

		return output

	}
}
