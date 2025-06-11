import Foundation
import GRPCLib

nonisolated(unsafe) private var tartLocation: String = ""

public struct ShellError: Swift.Error {
	/// The termination status of the command that was run
	public let terminationStatus: Int32
	public let error: String
	public let message: String

	var description: String {
		return "exitCode:\(terminationStatus), reason: \(error) infos: \(message)"
	}

	var localizedDescription: String {
		self.description
	}
}

struct Shell {
	@discardableResult static public func sudo(
		to command: String,
		at path: String = ".",
		process: Process = .init(),
		input: String? = nil,
		outputHandle: FileHandle? = nil,
		errorHandle: FileHandle? = nil
	) throws -> String {
		return try process.sudo(
			with: command,
			input: input,
			outputHandle: outputHandle,
			errorHandle: errorHandle
		)
	}

	@discardableResult static public func execute(
		to command: String,
		arguments: [String] = [],
		at path: String = ".",
		process: ProcessWithSharedFileHandle = .init(),
		input: String? = nil,
		outputHandle: FileHandle? = nil,
		errorHandle: FileHandle? = nil,
		sharedFileHandles: [FileHandle]? = nil
	) throws -> String {
		let command = "cd \(path.replacingOccurrences(of: " ", with: "\\ ")) && \(command) \(arguments.joined(separator: " "))"

		return try process.bash(
			with: command,
			input: input,
			outputHandle: outputHandle,
			errorHandle: errorHandle,
			sharedFileHandles: sharedFileHandles
		)
	}

	@discardableResult static func runTart(
		command: String, arguments: [String],
		direct: Bool = false,
		input: String? = nil,
		sharedFileHandles: [FileHandle]? = nil,
		runMode: Utils.RunMode
	) throws -> String {
		var args: [String] = []
		var outputData: Data = Data()
		let outputPipe = Pipe()
		let errorPipe: Pipe = direct ? Pipe() : outputPipe
		let cakeHomeDir = try Utils.getHome(runMode: runMode)

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

		environment["TART_HOME"] = cakeHomeDir.path

		Logger(self).debug("Executing tart \(args.joined(separator: " "))")

		let _ = try Self.bash(
			to: "tart", arguments: args,
			input: input,
			outputHandle: outputPipe.fileHandleForWriting,
			errorHandle: errorPipe.fileHandleForWriting,
			environment: environment,
			sharedFileHandles: sharedFileHandles)

		return String(data: outputData, encoding: .utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	@discardableResult static public func bash(
		to command: String,
		arguments: [String] = [],
		at path: String = ".",
		process: ProcessWithSharedFileHandle = .init(),
		input: String? = nil,
		outputHandle: FileHandle? = nil,
		errorHandle: FileHandle? = nil,
		environment: [String: String]? = nil,
		sharedFileHandles: [FileHandle]? = nil
	) throws -> String {
		let command = "cd \(path.replacingOccurrences(of: " ", with: "\\ ")) && exec \(command) \(arguments.joined(separator: " "))"

		return try process.bash(
			with: command,
			input: input,
			outputHandle: outputHandle,
			errorHandle: errorHandle,
			environment: environment,
			sharedFileHandles: sharedFileHandles
		)
	}
}

extension FileHandle {
	fileprivate var isStandard: Bool {
		return self === FileHandle.standardOutput || self === FileHandle.standardError || self === FileHandle.standardInput
	}
}

extension Process {
	@discardableResult fileprivate func sudo(
		with command: String,
		input: String? = nil,
		outputHandle: FileHandle? = nil,
		errorHandle: FileHandle? = nil,
		environment: [String: String]? = nil
	) throws -> String {
		var runningArguments = ["--non-interactive"]

		if #available(OSX 10.13, *) {
			self.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
		} else {
			self.launchPath = "/usr/bin/sudo"
		}

		runningArguments.append(contentsOf: ["--", command])

		self.arguments = runningArguments

		if environment != nil {
			self.environment = environment
		}

		// Because FileHandle's readabilityHandler might be called from a
		// different queue from the calling queue, avoid a data race by
		// protecting reads and writes to outputData and errorData on
		// a single dispatch queue.
		let outputQueue = DispatchQueue(label: "sudo-output-queue")

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

		if var input = input {
			input = input + "\n"
			let inputPipe = Pipe()

			inputPipe.fileHandleForWriting.writeabilityHandler = { handler in
				handler.write(input.data(using: .utf8)!)
			}

			self.standardInput = inputPipe
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
					error: errorData.toString(),
					message: outputData.toString()
				)
			}

			return outputData.toString()
		}
	}
}

extension ProcessWithSharedFileHandle {
	@discardableResult fileprivate func bash(
		with command: String,
		input: String? = nil,
		outputHandle: FileHandle? = nil,
		errorHandle: FileHandle? = nil,
		environment: [String: String]? = nil,
		sharedFileHandles: [FileHandle]? = nil
	) throws -> String {

		if #available(OSX 10.13, *) {
			self.executableURL = URL(fileURLWithPath: "/bin/bash")
		} else {
			self.launchPath = "/bin/bash"
		}
		self.arguments = ["-c", command]
		self.sharedFileHandles = sharedFileHandles

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

		if var input = input {
			input = input + "\n"
			let inputPipe = Pipe()

			inputPipe.fileHandleForWriting.writeabilityHandler = { handler in
				handler.write(input.data(using: .utf8)!)
			}

			self.standardInput = inputPipe
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
					error: errorData.toString(),
					message: outputData.toString()
				)
			}

			return outputData.toString()
		}
	}
}

extension Data {
	func toString() -> String {
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
