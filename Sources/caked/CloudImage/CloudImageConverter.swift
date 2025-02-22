import Foundation
import Qcow2convert
import GRPCLib

class CloudImageConverter {
	static func convertCloudImageToRawQemu(from: URL, to: URL) throws {
		do {
			let convertOuput = try Shell.execute(to: "qemu-img", arguments: [
				"convert", "-p", "-f", "qcow2", "-O", "raw",
				from.path(),
				to.path()
			])
			Logger.info(convertOuput)
		} catch {
			Logger.error(error)

			throw error
		}
	}

	static func convertCloudImageToRaw(from: URL, to: URL) throws {
		var outputData: Data = Data()
		let outputPipe = Pipe()

		outputPipe.fileHandleForReading.readabilityHandler = { handler in
			outputData.append(handler.availableData)
		}

		if let converter = Qcow2convertQCow2Converter(from.absoluteURL.path(),
													  destination: to.absoluteURL.path(),
													  outputFileHandle: outputPipe.fileHandleForWriting.fileDescriptor) {
			if converter.convert() < 0 {
				throw ServiceError(String(data: outputData, encoding: .utf8)!)
			}
		}
	}

	static func downloadLinuxImage(fromURL: URL, toURL: URL) async throws -> URL{
		if FileManager.default.fileExists(atPath: toURL.path()) {
			throw ServiceError("file already exists: \(toURL.path())")
		}

		// Download the cloud-image
		Logger.debug("Fetching \(fromURL.lastPathComponent)...")

		let channel = try await Curl(fromURL: fromURL).get(observer: ProgressObserver(totalUnitCount: 100).log("Fetching \(fromURL.lastPathComponent)"))
		let temporaryLocation = try Home(asSystem: runAsSystem).temporaryDir.appendingPathComponent(UUID().uuidString + ".img")

		FileManager.default.createFile(atPath: temporaryLocation.path, contents: nil)

		let lock = try FileLock(lockURL: temporaryLocation)
		try lock.lock()

		let fileHandle: FileHandle = try FileHandle(forWritingTo: temporaryLocation)

		for try await chunk in channel.0 {
			let chunkAsData = Data(chunk)
			fileHandle.write(chunkAsData)
		}

		try fileHandle.close()
		try lock.unlock()

		defer {
			do {
				if try temporaryLocation.exists() {
					try FileManager.default.removeItem(at: temporaryLocation)
				}
			} catch {
				Logger.error(error)
			}
		}

		return try FileManager.default.replaceItemAt(toURL, withItemAt: temporaryLocation)!
	}

	static func downloadLinuxImage(remoteURL: URL) async throws -> URL{
		// Check if we already have this linux image in cache
		let fileName = (remoteURL.lastPathComponent as NSString).deletingPathExtension
		let imageCache = try CloudImageCache(name: remoteURL.host()!)
		let cacheLocation = imageCache.locationFor(fileName: "\(fileName).img")

		if FileManager.default.fileExists(atPath: cacheLocation.path) {
			Logger.info("Using cached \(cacheLocation.path) file...")
			try cacheLocation.updateAccessDate()
			return cacheLocation
		}

		return try await downloadLinuxImage(fromURL: remoteURL, toURL: cacheLocation)
	}

	static func retrieveCloudImageAndConvert(from: URL, to: URL) async throws {
		let fileName = (from.lastPathComponent as NSString).deletingPathExtension
		let imageCache: CloudImageCache = try CloudImageCache(name: from.host()!)
		let cacheLocation = imageCache.locationFor(fileName: "\(fileName).img")

		try await retrieveRemoteImageCacheItAndConvert(from: from, to: to, cacheLocation: cacheLocation)
	}

	static func retrieveRemoteImageCacheItAndConvert(from: URL, to: URL?, cacheLocation: URL) async throws {
		let temporaryLocation = try Home(asSystem: runAsSystem).temporaryDir.appendingPathComponent(UUID().uuidString + ".img")

		defer {
			if FileManager.default.fileExists(atPath: temporaryLocation.path()) {
				do {
					try FileManager.default.removeItem(at: temporaryLocation)
				} catch {
					Logger.error(error)
				}
			}
		}

		if FileManager.default.fileExists(atPath: cacheLocation.path) {
			Logger.info("Using cached \(cacheLocation.path) file...")
			try cacheLocation.updateAccessDate() 
		} else {
			// Download the cloud-image
			Logger.info("Fetching \(from.lastPathComponent)...")

			let channel = try await Curl(fromURL: from).get(observer: ProgressObserver(totalUnitCount: 100).log("Fetching \(from.lastPathComponent)"))

			FileManager.default.createFile(atPath: temporaryLocation.path, contents: nil)

			let lock = try FileLock(lockURL: temporaryLocation)
			try lock.lock()

			let fileHandle: FileHandle = try FileHandle(forWritingTo: temporaryLocation)

			for try await chunk in channel.0 {
				let chunkAsData = Data(chunk)
				fileHandle.write(chunkAsData)
			}

			try fileHandle.close()
			try lock.unlock()

			try convertCloudImageToRaw(from: temporaryLocation, to: cacheLocation)
			try FileManager.default.removeItem(at: temporaryLocation)
		}

		if let to = to {
			try FileManager.default.copyItem(at: cacheLocation, to: temporaryLocation)
			_ = try FileManager.default.replaceItemAt(to, withItemAt: temporaryLocation)
		}
	}
}
