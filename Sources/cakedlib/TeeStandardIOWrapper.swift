//
//  TeeStandardIOWrapper.swift
//  Caker
//
//  Created by Frederic BOLTZ on 03/06/2026.
//
import Foundation
import Synchronization
import Combine

public final class TeeStandardIOWrapper: Cancellable {
	private let outputPipe = Pipe()
	private let errorPipe = Pipe()
	private let originalOutputHandle: FileHandle
	private let originalErrorHandle: FileHandle
	private let logURL: URL
	private let outputLogHandle: Mutex<FileHandle>
	private var rotationTimer: DispatchSourceTimer?
	private let ioQueue = DispatchQueue(label: "caker.vmrun.tee")
	private let stdoutFD = FileHandle.standardOutput.fileDescriptor
	private let stderrFD = FileHandle.standardError.fileDescriptor
	private let stopped = Mutex(false)
	private static let rotationInterval: DispatchTimeInterval = .seconds(15)

	public init(logURL: URL) throws {
		self.logURL = logURL
		_ = try Self.rotateLog(to: logURL)

		let outputLogHandle = try FileHandle(forWritingTo: logURL)
		try outputLogHandle.seekToEnd()

		self.outputLogHandle = .init(outputLogHandle)

		let outputDupFD = dup(stdoutFD)
		let errorDupFD = dup(stderrFD)

		guard outputDupFD != -1, errorDupFD != -1 else {
			if outputDupFD != -1 {
				close(outputDupFD)
			}

			if errorDupFD != -1 {
				close(errorDupFD)
			}

			throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
		}

		self.originalOutputHandle = FileHandle(fileDescriptor: outputDupFD, closeOnDealloc: true)
		self.originalErrorHandle = FileHandle(fileDescriptor: errorDupFD, closeOnDealloc: true)

		outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handler in
			guard let self else {
				return
			}

			tee(handler, target: self.originalOutputHandle)
		}

		errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handler in
			guard let self else {
				return
			}

			self.tee(handler, target: self.originalErrorHandle)
		}

		guard dup2(outputPipe.fileHandleForWriting.fileDescriptor, stdoutFD) != -1 else {
			throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
		}

		var setupComplete = false
		defer {
			if !setupComplete { stop() }
		}

		guard dup2(errorPipe.fileHandleForWriting.fileDescriptor, stderrFD) != -1 else {
			throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
		}

		scheduleLogRotation()
		setupComplete = true
	}

	private func tee(_ source: FileHandle, target: FileHandle) {
		let data = source.availableData

		guard data.isEmpty == false else {
			return
		}

		var logHandle: FileHandle? = nil

		self.outputLogHandle.withLock {
			logHandle = $0
		}

		guard let logHandle else {
			return
		}

		self.ioQueue.async {
			try? target.write(contentsOf: data)
			try? logHandle.write(contentsOf: data)
		}
	}

	private func scheduleLogRotation() {
		let timer = DispatchSource.makeTimerSource(queue: ioQueue)
		timer.schedule(deadline: .now() + Self.rotationInterval, repeating: Self.rotationInterval)
		timer.setEventHandler { [weak self] in
			self?.rotateAndRefreshHandleIfNeeded()
		}
		rotationTimer = timer
		timer.resume()
	}

	private func rotateAndRefreshHandleIfNeeded() {
		guard stopped.withLock({ $0 }) == false else {
			return
		}

		do {
			try self.outputLogHandle.withLock { outputLogHandle in
				let rotated = try Self.rotateLog(to: logURL, currentOutputHandle: outputLogHandle)

				guard rotated else {
					return
				}

				let newHandle = try FileHandle(forWritingTo: logURL)
				try newHandle.seekToEnd()

				outputLogHandle = newHandle
			}

		} catch {
			// Best effort: keep current handle when rotation fails.
		}
	}

	private static func rotateLog(to logURL: URL, currentOutputHandle: FileHandle? = nil) throws -> Bool {
		// Ensure directory exists
		try FileManager.default.createDirectory(at: logURL.deletingLastPathComponent(), withIntermediateDirectories: true)

		// Rotate logs if needed (size-based)
		let maxSize: UInt64 = 5 * 1024 * 1024  // 5 MB
		let maxFiles = 5
		let fm = FileManager.default
		var didRotate = false

		func rotatedURL(_ index: Int) -> URL {
			logURL.appendingPathExtension("\(index)")
		}

		func rotatedGZURL(_ index: Int) -> URL {
			rotatedURL(index).appendingPathExtension("gz")
		}

		if fm.fileExists(atPath: logURL.path) {
			if let fileSize = try? logURL.fileSize(), fileSize >= maxSize {
				didRotate = true

				if let currentOutputHandle = currentOutputHandle {
					try? currentOutputHandle.synchronize()
					try? currentOutputHandle.close()
				}

				// Delete the oldest rotated generation in either format.
				if fm.fileExists(atPath: rotatedURL(maxFiles).path) {
					try? fm.removeItem(at: rotatedURL(maxFiles))
				}

				if fm.fileExists(atPath: rotatedGZURL(maxFiles).path) {
					try? fm.removeItem(at: rotatedGZURL(maxFiles))
				}

				// Shift others
				if maxFiles >= 2 {
					for i in stride(from: maxFiles - 1, through: 1, by: -1) {
						let src = rotatedURL(i)
						let dst = rotatedURL(i + 1)
						let srcGZ = rotatedGZURL(i)
						let dstGZ = rotatedGZURL(i + 1)

						if fm.fileExists(atPath: srcGZ.path) {
							try? fm.moveItem(at: srcGZ, to: dstGZ)
						}

						if fm.fileExists(atPath: src.path) {
							try? fm.moveItem(at: src, to: dst)
						}
					}
				}

				// Move current to .1
				try? fm.moveItem(at: logURL, to: rotatedURL(1))

				// Keep rotated files consistently as .N.gz (and clean legacy .N files).
				for i in 1...maxFiles {
					let src = rotatedURL(i)
					let gz = rotatedGZURL(i)

					if fm.fileExists(atPath: src.path) {
						if fm.fileExists(atPath: gz.path) {
							try? fm.removeItem(at: src)
						} else if let d = try? Data(contentsOf: src), let gzData = try? d.gzipped() {
							try? gzData.write(to: gz, options: .atomic)
							try? fm.removeItem(at: src)
						}
					}
				}
			}
		}

		// Create file if missing
		if fm.fileExists(atPath: logURL.path) == false {
			fm.createFile(atPath: logURL.path, contents: nil)
		}

		return didRotate
	}

	public func stop() {
		guard stopped.withLock({
			guard !$0 else {
				return false
			}
			$0 = true; return true
		}) else {
			return
		}

		outputPipe.fileHandleForReading.readabilityHandler = nil
		errorPipe.fileHandleForReading.readabilityHandler = nil

		_ = dup2(originalOutputHandle.fileDescriptor, stdoutFD)
		_ = dup2(originalErrorHandle.fileDescriptor, stderrFD)

		ioQueue.sync {
			self.rotationTimer?.setEventHandler {}
			self.rotationTimer?.cancel()
			self.rotationTimer = nil
			try? self.outputPipe.close()
			try? self.errorPipe.close()

			outputLogHandle.withLock { outputLogHandle in
				try? outputLogHandle.synchronize()
				try? outputLogHandle.close()
			}
		}
	}

	public func cancel() {
		self.stop()
	}

	deinit {
		stop()
	}
}

