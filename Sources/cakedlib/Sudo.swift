//
//  Sudo.swift
//  Caker
//
//  Created by Frederic BOLTZ on 11/11/2025.
//
import Foundation
import GRPCLib

public let SUDO = "sudo"

public final class SudoCaked {
	let process: Process
	let outputQueue = DispatchQueue(label: UUID().uuidString)

	var stdout: Data!
	var stderr: Data!
	var outputPipe: Foundation.Pipe!
	var errorPipe: Foundation.Pipe!

	public convenience init(arguments: [String], runMode: Utils.RunMode, log: FileHandle? = nil) throws {
		try self.init(command: Home.cakedCommandName, arguments: arguments, runMode: runMode, standardOutput: log, standardError: log)
	}

	public convenience init(arguments: [String], runMode: Utils.RunMode, standardOutput: FileHandle? = nil, standardError: FileHandle? = nil) throws {
		try self.init(command: Home.cakedCommandName, arguments: arguments, runMode: runMode, standardOutput: standardOutput, standardError: standardError)
	}

	public init(command: String, arguments: [String], runMode: Utils.RunMode, standardOutput: FileHandle? = nil, standardError: FileHandle? = nil) throws {
		let (sudoable, sudoURL, executableURL) = try Self.checkIfSudoable(command: command)

		guard sudoable else {
			throw ServiceError("\(executableURL.lastPathComponent) is not sudoable")
		}

		let process = Process()

		var runningArguments = ["--non-interactive", "--preserve-env=CAKE_HOME", "--user=root", "--group=#\(getegid())", "--", executableURL.path]

		if runMode.isSystem {
			runningArguments.append("--system")
		}

		runningArguments.append(contentsOf: arguments)

		process.executableURL = sudoURL
		process.arguments = runningArguments
		process.environment = try Utilities.environment(runMode: runMode)
		process.standardInput = FileHandle.nullDevice

		self.stdout = Data()
		self.stderr = Data()
		self.process = process

		if let standardOutput = standardOutput {
			process.standardOutput = standardOutput
			self.stdout = nil
		} else {
			let outputPipe = Pipe()

			self.outputPipe = outputPipe

			outputPipe.fileHandleForReading.readabilityHandler = nil
			outputPipe.fileHandleForReading.readabilityHandler = { handler in
				let data = handler.availableData

				if data.isEmpty == false {
					self.outputQueue.async {
						self.stdout.append(data)
					}
				}
			}

			process.standardOutput = outputPipe
		}

		if let standardError = standardError {
			process.standardError = standardError
			self.stderr = nil
		} else {
			let errorPipe = Pipe()

			self.errorPipe = errorPipe

			errorPipe.fileHandleForReading.readabilityHandler = nil
			errorPipe.fileHandleForReading.readabilityHandler = { handler in
				let data = handler.availableData

				if data.isEmpty == false {
					self.outputQueue.async {
						self.stderr.append(data)
					}
				}
			}

			process.standardError = errorPipe
		}
	}

	public func run() throws -> Self {
		try self.process.run()

		return self
	}

	public func waitUntilExit() -> Int32 {
		self.process.waitUntilExit()

		return outputQueue.sync {
			return self.process.terminationStatus
		}
	}

	public func runAndWait() throws -> Int32 {
		try self.run().waitUntilExit()
	}

	public var standardOutput: String {
		guard let stdout = self.stdout else {
			return ""
		}

		if let output = String(data: stdout, encoding: .utf8) {
			return output
		} else {
			return ""
		}
	}

	public var standardError: String {
		guard let stderr = self.stderr else {
			return ""
		}

		if let error = String(data: stderr, encoding: .utf8) {
			return error
		} else {
			return ""
		}
	}

	public var terminationStatus: Int32 {
		if self.process.isRunning {
			return 0
		}

		let status = self.process.terminationStatus

		if status != 0 {
			if let stdout = self.stdout {
				try? FileHandle.standardOutput.write(contentsOf: stdout)
			}

			if let stderr = self.stderr {
				try? FileHandle.standardError.write(contentsOf: stderr)
			}
		}

		return status
	}

	public var terminationReason: Process.TerminationReason {
		self.process.terminationReason
	}

	public static func checkIfSudoable(command: String) throws -> (Bool, URL, URL) {
		guard let binary = URL.binary(command) else {
			throw ServiceError("\(command) not found in path")
		}

		guard let sudoURL = URL.binary(SUDO) else {
			throw ServiceError("sudo not found in path")
		}

		return (try checkIfSudoable(sudoURL: sudoURL, binary: binary), sudoURL, binary)
	}

	public static func checkIfSudoable() throws -> (Bool, URL, URL) {
		return try checkIfSudoable(command: Home.cakedCommandName)
	}

	public static func checkIfSudoable(sudoURL: URL, binary: URL) throws -> Bool {
		if geteuid() == 0 {
			return true
		}

		let info = try FileManager.default.attributesOfItem(atPath: binary.path) as NSDictionary

		if info.fileOwnerAccountID() == 0 && (info.filePosixPermissions() & Int(S_ISUID)) != 0 {
			return true
		}

		let process = Process()

		process.executableURL = sudoURL
		process.environment = try Utilities.environment(runMode: .user)
		process.arguments = ["--non-interactive", "--preserve-env=CAKE_HOME", "--user=root", "--group=#\(getegid())", "--", binary.path, "--help"]
		process.standardInput = nil

		#if XDEBUG
		process.standardOutput = FileHandle.standardOutput
		process.standardError = FileHandle.standardError
		#else
		process.standardOutput = nil
		process.standardError = nil
		#endif
		
		try process.run()

		process.waitUntilExit()

		if process.terminationStatus == 0 {
			return true
		}

		return false
	}
}

