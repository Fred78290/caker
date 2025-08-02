import Foundation
import GRPCLib
import Qcow2convert

class CloudImageConverter {
	static func convertVmdkToRawQemu(from: URL, to: URL, outputHandle: FileHandle? = nil, errorHandle: FileHandle? = nil) throws {
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
			Logger(self).info(convertOuput)
		} catch {
			Logger(self).error(error)

			throw error
		}
	}

	static func convertCloudImageToRawQemu(from: URL, to: URL, outputHandle: FileHandle? = nil, errorHandle: FileHandle? = nil) throws {
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
			Logger(self).info(convertOuput)
		} catch {
			Logger(self).error(error)

			throw error
		}
	}

	static func convertCloudImageToRaw(from: URL, to: URL) throws {
		var outputData: Data = Data()
		let outputPipe = Pipe()

		outputPipe.fileHandleForReading.readabilityHandler = { handler in
			outputData.append(handler.availableData)
		}

		if let converter = Qcow2convertQCow2Converter(
			from.absoluteURL.path,
			destination: to.absoluteURL.path,
			outputFileHandle: outputPipe.fileHandleForWriting.fileDescriptor)
		{
			if converter.convert() < 0 {
				throw ServiceError(String(data: outputData, encoding: .utf8)!)
			}
		}
	}

	static func downloadLinuxImage(fromURL: URL, toURL: URL, runMode: Utils.RunMode, progressHandler: VMBuilder.BuildProgressHandler?) async throws -> URL {
		if FileManager.default.fileExists(atPath: toURL.path) {
			throw ServiceError("file already exists: \(toURL.path)")
		}

		// Download the cloud-image
		Logger(self).debug("Fetching \(fromURL.lastPathComponent)...")

		let temporaryLocation = try Home(runMode: runMode).temporaryDirectory.appendingPathComponent(UUID().uuidString + ".img")

		defer {
			try? FileManager.default.removeItem(at: temporaryLocation)
		}

		try await Curl(fromURL: fromURL).get(store: temporaryLocation, observer: ProgressObserver(progressHandler: progressHandler).log("Fetching \(fromURL.lastPathComponent)"))

		return try FileManager.default.replaceItemAt(toURL, withItemAt: temporaryLocation)!
	}

	static func downloadLinuxImage(remoteURL: URL, runMode: Utils.RunMode, progressHandler: VMBuilder.BuildProgressHandler?) async throws -> URL {
		// Check if we already have this linux image in cache
		let fileName = remoteURL.lastPathComponent.deletingPathExtension
		let imageCache = try CloudImageCache(name: remoteURL.host()!, runMode: runMode)
		let cacheLocation = imageCache.locationFor(fileName: "\(fileName).img")

		if FileManager.default.fileExists(atPath: cacheLocation.path) {
			Logger(self).info("Using cached \(cacheLocation.path) file...")
			try cacheLocation.updateAccessDate()
			return cacheLocation
		}

		return try await downloadLinuxImage(fromURL: remoteURL, toURL: cacheLocation, runMode: runMode, progressHandler: progressHandler)
	}

	static func retrieveCloudImageAndConvert(from: URL, to: URL, runMode: Utils.RunMode, progressHandler: VMBuilder.BuildProgressHandler?) async throws {
		let fileName = from.lastPathComponent.deletingPathExtension
		let imageCache: CloudImageCache = try CloudImageCache(name: from.host()!, runMode: runMode)
		let cacheLocation = imageCache.locationFor(fileName: "\(fileName).img")

		try await retrieveRemoteImageCacheItAndConvert(from: from, to: to, cacheLocation: cacheLocation, runMode: runMode, progressHandler: progressHandler)
	}

	static func retrieveRemoteImageCacheItAndConvert(from: URL, to: URL?, cacheLocation: URL, runMode: Utils.RunMode, progressHandler: VMBuilder.BuildProgressHandler?) async throws {
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
			Logger(self).info("Using cached \(cacheLocation.path) file...")
			try cacheLocation.updateAccessDate()
		} else {
			// Download the cloud-image
			Logger(self).info("Fetching \(from.lastPathComponent)...")

			try await Curl(fromURL: from).get(store: temporaryLocation, observer: ProgressObserver(progressHandler: progressHandler).log("Fetching \(from.lastPathComponent)"))

			try convertCloudImageToRaw(from: temporaryLocation, to: cacheLocation)
			try FileManager.default.removeItem(at: temporaryLocation)
		}

		if let to = to {
			try FileManager.default.copyItem(at: cacheLocation, to: temporaryLocation)
			_ = try FileManager.default.replaceItemAt(to, withItemAt: temporaryLocation)
		}
	}
}
