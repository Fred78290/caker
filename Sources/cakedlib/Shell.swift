import Foundation
import GRPCLib
import Subprocess
import System
import CakeAgentLib

nonisolated(unsafe) private var tartLocation: String = String.empty

public enum ShellProcessQueues {
	static let commandOutput = DispatchQueue(label: "caker.shell.command-output-queue")
	static let sudoOutput = DispatchQueue(label: "caker.shell.sudo-output-queue")
	static let bashOutput = DispatchQueue(label: "caker.shell.bash-output-queue")
}

fileprivate actor ProcessExitContinuationActor {
	private var continuation: CheckedContinuation<Void, Never>?

	init(_ continuation: CheckedContinuation<Void, Never>) {
		self.continuation = continuation
	}

	func resume() {
		continuation?.resume()
		continuation = nil
	}
}

public struct ShellError: Swift.Error {
	/// The termination status of the command that was run
	public let terminationStatus: Int32
	public let error: String
	public let message: String

	var description: String {
		return String(localized: "exitCode:\(terminationStatus), reason: \(error) infos: \(message)")
	}

	var localizedDescription: String {
		self.description
	}
}

public struct Shell {
	/// Cap buffered subprocess output to avoid unbounded memory growth for noisy commands.
	/// 100 MB keeps typical command output intact while preventing OOM on very verbose tools.
	private static let maxSubprocessOutputSize = 100 * 1024 * 1024
	
	public typealias ExecCompletion = (TerminationStatus.Code, String, String) throws -> String
	
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
		input: String? = nil,
		outputHandle: FileHandle? = nil,
		errorHandle: FileHandle? = nil,
		sharedFileHandles: [FileHandle]?
	) throws -> String {
		let process: ProcessWithSharedFileHandle = .init()
		let command = "cd \(path.replacingOccurrences(of: " ", with: "\\ ")) && \(command) \(arguments.joined(separator: " "))"
		
		return try process.bash(
			with: command,
			input: input,
			outputHandle: outputHandle,
			errorHandle: errorHandle,
			sharedFileHandles: sharedFileHandles
		)
	}
	
	@discardableResult static public func execute(
		to command: String,
		arguments: [String] = [],
		at path: String = ".",
		input: String? = nil,
		outputHandle: FileHandle? = nil,
		errorHandle: FileHandle? = nil,
	) throws -> String {
		let process: Process = .init()
		let command = "cd \(path.replacingOccurrences(of: " ", with: "\\ ")) && \(command) \(arguments.joined(separator: " "))"
		
		return try process.bash(
			with: command,
			input: input,
			outputHandle: outputHandle,
			errorHandle: errorHandle
		)
	}
	
	@discardableResult static public func command(
		_ command: String,
		arguments: [String],
		process: Process = .init(),
		input: String? = nil,
		outputHandle: FileHandle? = nil,
		errorHandle: FileHandle? = nil,
	) throws -> String {
		return try process.command(
			command,
			arguments: arguments,
			input: input,
			outputHandle: outputHandle,
			errorHandle: errorHandle
		)
	}
	
	@discardableResult static public func exec(_ name: String, arguments: [String], _ completion: ExecCompletion? = nil) throws -> String {
#if TRACE
		var debug: [String] = [name]
		debug.append(contentsOf: arguments)
		print("🚀 \(debug.joined(separator: " "))")
#endif
		
		return try Task.sync {
			let result = try await Subprocess.run(
				.name(name),
				arguments: .init(arguments),
				output: .string(limit: Self.maxSubprocessOutputSize),
				error: .string(limit: Self.maxSubprocessOutputSize)
			)
			
			if let stderr = result.standardError, stderr.isEmpty == false {
				Logger("Shell").error(stderr)
			}
			
			guard let completion else {
				// Fail if subprocess exited with non-zero status
				if case .exited(let exitCode) = result.terminationStatus, exitCode != 0 {
					let stdout = result.standardOutput?.trimmingCharacters(in: .whitespacesAndNewlines) ?? String.empty
					let stderr = result.standardError?.trimmingCharacters(in: .whitespacesAndNewlines) ?? String.empty
					
					throw ShellError(terminationStatus: exitCode, error: stderr, message: stdout)
				}
				
				if let out: String = result.standardOutput {
					return out.trimmingCharacters(in: .whitespacesAndNewlines)
				}
				
				return String.empty
			}
			
			// Extract numeric exit code from TerminationStatus enum
			let exitCode: TerminationStatus.Code
			
			switch result.terminationStatus {
			case .exited(let code):
				exitCode = code
			case .signaled:
				// Use a conventional negative code for signalled termination
				exitCode = -1
			}
			
			return try completion(exitCode, result.standardOutput ?? String.empty, result.standardError ?? String.empty)
		}
	}
	
	@discardableResult static public func exec(_ command: FilePath, arguments: [String], _ completion: ExecCompletion? = nil) throws -> String {
#if TRACE
		var debug: [String] = [command.description]
		debug.append(contentsOf: arguments)
		print("🚀 \(debug.joined(separator: " "))")
#endif
		
		return try Task.sync {
			let result = try await Subprocess.run(
				.path(command),
				arguments: .init(arguments),
				output: .string(limit: Self.maxSubprocessOutputSize),
				error: .string(limit: Self.maxSubprocessOutputSize)
			)
			
			if let stderr = result.standardError, stderr.isEmpty == false {
				Logger("Shell").error(stderr)
			}
			
			guard let completion else {
				// Fail if subprocess exited with non-zero status
				if case .exited(let exitCode) = result.terminationStatus, exitCode != 0 {
					let stdout = result.standardOutput?.trimmingCharacters(in: .whitespacesAndNewlines) ?? String.empty
					let stderr = result.standardError?.trimmingCharacters(in: .whitespacesAndNewlines) ?? String.empty
					
					throw ShellError(terminationStatus: exitCode, error: stderr, message: stdout)
				}
				
				if let out: String = result.standardOutput {
					return out.trimmingCharacters(in: .whitespacesAndNewlines)
				}
				
				return String.empty
			}
			
			// Extract numeric exit code from TerminationStatus enum
			let exitCode: TerminationStatus.Code
			
			switch result.terminationStatus {
			case .exited(let code):
				exitCode = code
			case .signaled:
				// Use a conventional negative code for signalled termination
				exitCode = -1
			}
			
			return try completion(exitCode, result.standardOutput ?? String.empty, result.standardError ?? String.empty)
		}
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
		sharedFileHandles: [FileHandle]
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
	
	@discardableResult static public func bash(
		to command: String,
		arguments: [String] = [],
		at path: String = ".",
		process: Process = .init(),
		input: String? = nil,
		outputHandle: FileHandle? = nil,
		errorHandle: FileHandle? = nil,
		environment: [String: String]? = nil,
	) throws -> String {
		let command = "cd \(path.replacingOccurrences(of: " ", with: "\\ ")) && exec \(command) \(arguments.joined(separator: " "))"

		return try process.bash(
			with: command,
			input: input,
			outputHandle: outputHandle,
			errorHandle: errorHandle,
			environment: environment
		)
	}
}

extension FileHandle {
	public var isStandard: Bool {
		return [
			STDIN_FILENO, STDOUT_FILENO, STDERR_FILENO
		].contains(self.fileDescriptor)
	}
}

extension Process {
	@discardableResult fileprivate func command(
		_ command: String,
		arguments: [String],
		input: String? = nil,
		outputHandle: FileHandle? = nil,
		errorHandle: FileHandle? = nil,
		environment: [String: String]? = nil
	) throws -> String {
		self.executableURL = URL(fileURLWithPath: command)
		self.arguments = arguments

		if environment != nil {
			self.environment = environment
		}

		// Because FileHandle's readabilityHandler might be called from a
		// different queue from the calling queue, avoid a data race by
		// protecting reads and writes to outputData and errorData on
		// a single dispatch queue.
		let outputQueue = ShellProcessQueues.commandOutput

		var outputData = Data()
		var errorData = Data()

		let outputPipe = Pipe()
		standardOutput = outputPipe

		let errorPipe = Pipe()
		var inputPipe: Pipe! = nil

		standardError = errorPipe

		defer {
			try? outputPipe.close()
			try? errorPipe.close()
			try? inputPipe?.close()
		}

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
			inputPipe = Pipe()

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
		let outputQueue = ShellProcessQueues.sudoOutput

		var outputData = Data()
		var errorData = Data()
		let outputPipe = Pipe()
		let errorPipe = Pipe()
		var inputPipe: Pipe! = nil

		defer {
			try? outputPipe.close()
			try? errorPipe.close()
			try? inputPipe?.close()
		}

		standardOutput = outputPipe
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
			inputPipe = Pipe()

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

extension Process {
	fileprivate func waitForExitAsync() async {
		await withCheckedContinuation { continuation in
			let resumeActor = ProcessExitContinuationActor(continuation)

			self.terminationHandler = { process in
				process.terminationHandler = nil
				Task {
					await resumeActor.resume()
				}
			}

			if !self.isRunning {
				self.terminationHandler = nil
				Task {
					await resumeActor.resume()
				}
			}
		}
	}

	@discardableResult fileprivate func bash(
		with command: String,
		input: String? = nil,
		outputHandle: FileHandle? = nil,
		errorHandle: FileHandle? = nil,
		environment: [String: String]? = nil,
	) throws -> String {

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
		let outputQueue = ShellProcessQueues.bashOutput

		var outputData = Data()
		var errorData = Data()
		let outputPipe = Pipe()
		let errorPipe = Pipe()

		standardOutput = outputPipe

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

		var inputPipe: Pipe? = nil

		defer {
			if let inputPipe {
				try? inputPipe.close()
			}
		}

		if var input = input {
			input = input + "\n"
			let pipe = Pipe()
			inputPipe = pipe

			pipe.fileHandleForWriting.writeabilityHandler = { handler in
				handler.write(input.data(using: .utf8)!)
			}

			self.standardInput = pipe.fileHandleForReading
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
	fileprivate func waitForExitAsync() async {
		await withCheckedContinuation { continuation in
			let resumeActor = ProcessExitContinuationActor(continuation)

			self.terminationHandler = { process in
				process.terminationHandler = nil
				Task {
					await resumeActor.resume()
				}
			}

			if !self.isRunning {
				self.terminationHandler = nil
				Task {
					await resumeActor.resume()
				}
			}
		}
	}

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
		let outputQueue = ShellProcessQueues.bashOutput

		var outputData = Data()
		var errorData = Data()
		let outputPipe = Pipe()
		let errorPipe = Pipe()

		standardOutput = outputPipe

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

		var inputPipe: Pipe? = nil

		defer {
			if let inputPipe {
				try? inputPipe.close()
			}
		}

		if var input = input {
			input = input + "\n"
			let pipe = Pipe()
			inputPipe = pipe

			pipe.fileHandleForWriting.writeabilityHandler = { handler in
				handler.write(input.data(using: .utf8)!)
			}

			self.standardInput = pipe.fileHandleForReading
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
			return String.empty
		}

		guard !output.hasSuffix("\n") else {
			let endIndex = output.index(before: output.endIndex)
			return String(output[..<endIndex])
		}

		return output

	}
}

