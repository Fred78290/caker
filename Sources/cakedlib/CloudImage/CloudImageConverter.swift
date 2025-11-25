import Foundation
import GRPCLib
import Qcow2convert

class CloudImageConverter {
	private static func step(_ message: String, progressHandler: ProgressObserver.BuildProgressHandler?) {
		if let progressHandler = progressHandler {
			Logger(self).info(message)
			progressHandler(.step(message))
		} else {
			Logger(self).info(message)
		}
	}

	static func convertVmdkToRawQemu(from: URL, to: URL, outputHandle: FileHandle? = nil, errorHandle: FileHandle? = nil, progressHandler: ProgressObserver.BuildProgressHandler? = nil) throws {
		do {
			let convertOuput = try Shell.execute(
				to: "qemu-img",
				arguments: [
					"convert", "-p", "-f", "vmdk", "-O", "raw",
					"'\(from.path)'",
					"'\(to.path)'",
				],
				outputHandle: outputHandle,
				errorHandle: errorHandle)
			step(convertOuput, progressHandler: progressHandler)
		} catch {
			Logger(self).error(error)

			throw error
		}
	}

	static func convertCloudImageToRawQemu(from: URL, to: URL, outputHandle: FileHandle? = nil, errorHandle: FileHandle? = nil, progressHandler: ProgressObserver.BuildProgressHandler? = nil) throws {
		do {
			let convertOuput = try Shell.execute(
				to: "qemu-img",
				arguments: [
					"convert", "-p", "-f", "qcow2", "-O", "raw",
					"'\(from.path)'",
					"'\(to.path)'",
				],
				outputHandle: outputHandle,
				errorHandle: errorHandle)
			step(convertOuput, progressHandler: progressHandler)
		} catch {
			Logger(self).error(error)

			throw error
		}
	}

	static func convertCloudImageToRaw(from: URL, to: URL, progressHandler: ProgressObserver.BuildProgressHandler?) throws {
		var outputData: Data = Data()
		let outputPipe = Pipe()

		outputPipe.fileHandleForReading.readabilityHandler = { handler in
			outputData.append(handler.availableData)
		}

		class QCow2ConverterProgressHandler: NSObject, Qcow2convertProgressCallbackProtocol {
			var progressHandler: ProgressObserver.BuildProgressHandler
			var context: ProgressObserver.ProgressHandlerContext

			init(progressHandler: @escaping ProgressObserver.BuildProgressHandler) {
				self.progressHandler = progressHandler

				self.context = .init()

				super.init()
			}

			@objc func progressCallback(_ readed: Int64, totalSize: Int64) {
				let fractionCompleted = Double(readed) / Double(totalSize)

				self.progressHandler(.progress(context, fractionCompleted))

				self.context.oldFractionCompleted = fractionCompleted
			}
		}

		let progressHandlerImpl: QCow2ConverterProgressHandler?

		if let progressHandler = progressHandler {
			progressHandlerImpl = QCow2ConverterProgressHandler(progressHandler: progressHandler)
		} else {
			progressHandlerImpl = nil
		}

		if let converter = Qcow2convertQCow2Converter(
			from.absoluteURL.path,
			destination: to.absoluteURL.path,
			outputFileHandle: outputPipe.fileHandleForWriting.fileDescriptor,
			progress: progressHandlerImpl)
		{
			if converter.convert() < 0 {
				throw ServiceError(String(data: outputData, encoding: .utf8)!)
			}
		}
	}

	static func downloadLinuxImage(fromURL: URL, toURL: URL, runMode: Utils.RunMode, progressHandler: ProgressObserver.BuildProgressHandler?) async throws -> URL {
		if FileManager.default.fileExists(atPath: toURL.path) {
			throw ServiceError("file already exists: \(toURL.path)")
		}

		// Download the cloud-image
		self.step("Fetching \(fromURL.lastPathComponent)...", progressHandler: progressHandler)

		let temporaryLocation = try Home(runMode: runMode).temporaryDirectory.appendingPathComponent(UUID().uuidString + ".img")

		defer {
			try? FileManager.default.removeItem(at: temporaryLocation)
		}

		try await Curl(fromURL: fromURL).get(store: temporaryLocation, observer: ProgressObserver(progressHandler: progressHandler).log("Fetching \(fromURL.lastPathComponent)"))

		return try FileManager.default.replaceItemAt(toURL, withItemAt: temporaryLocation)!
	}

	static func downloadLinuxImage(remoteURL: URL, runMode: Utils.RunMode, progressHandler: ProgressObserver.BuildProgressHandler?) async throws -> URL {
		// Check if we already have this linux image in cache
		let fileName = remoteURL.lastPathComponent.deletingPathExtension
		let imageCache = try CloudImageCache(name: remoteURL.host()!, runMode: runMode)
		let cacheLocation = imageCache.locationFor(fileName: "\(fileName).img")

		if FileManager.default.fileExists(atPath: cacheLocation.path) {
			self.step("Using cached \(cacheLocation.path) file...", progressHandler: progressHandler)
			try cacheLocation.updateAccessDate()
			return cacheLocation
		}

		return try await downloadLinuxImage(fromURL: remoteURL, toURL: cacheLocation, runMode: runMode, progressHandler: progressHandler)
	}

	static func retrieveCloudImageAndConvert(from: URL, to: URL, runMode: Utils.RunMode, progressHandler: ProgressObserver.BuildProgressHandler?) async throws {
		let fileName = from.lastPathComponent.deletingPathExtension
		let imageCache: CloudImageCache = try CloudImageCache(name: from.host()!, runMode: runMode)
		let cacheLocation = imageCache.locationFor(fileName: "\(fileName).img")

		try await retrieveRemoteImageCacheItAndConvert(from: from, to: to, cacheLocation: cacheLocation, runMode: runMode, progressHandler: progressHandler)
	}

	static func retrieveRemoteImageCacheItAndConvert(from: URL, to: URL?, cacheLocation: URL, runMode: Utils.RunMode, progressHandler: ProgressObserver.BuildProgressHandler?) async throws {
		let temporaryLocation = try Home(runMode: runMode).temporaryDirectory.appendingPathComponent(UUID().uuidString + ".img")

		defer {
			if FileManager.default.fileExists(atPath: temporaryLocation.path) {
				do {
					try FileManager.default.removeItem(at: temporaryLocation)
				} catch {
					Logger(self).error(error)
				}
			}
		}

		if FileManager.default.fileExists(atPath: cacheLocation.path) {
			self.step("Using cached \(cacheLocation.path) file...", progressHandler: progressHandler)
			try cacheLocation.updateAccessDate()
		} else {
			// Download the cloud-image
			self.step("Fetching \(from.lastPathComponent)...", progressHandler: progressHandler)

			try await Curl(fromURL: from).get(store: temporaryLocation, observer: ProgressObserver(progressHandler: progressHandler).log("Fetching \(from.lastPathComponent)"))

			self.step("Done fetching \(from.lastPathComponent)...", progressHandler: progressHandler)

			self.step("Convert \(from.lastPathComponent) qcow2 to raw...", progressHandler: progressHandler)
			try convertCloudImageToRaw(from: temporaryLocation, to: cacheLocation, progressHandler: progressHandler)
			self.step("Done convert \(from.lastPathComponent) qcow2 to raw...", progressHandler: progressHandler)

			try FileManager.default.removeItem(at: temporaryLocation)

		}

		if let to = to {
			try FileManager.default.copyItem(at: cacheLocation, to: temporaryLocation)
			_ = try FileManager.default.replaceItemAt(to, withItemAt: temporaryLocation)
		}
	}
}
