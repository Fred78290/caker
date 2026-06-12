import Foundation
import GRPCLib
import CakeAgentLib
import SwiftUI

public class CloudImageConverter {
	private static func step(_ message: String, progressHandler: ProgressObserver.BuildProgressHandler?) {
		if let progressHandler = progressHandler {
			Logger(self).info(message)
			progressHandler(.step(message))
		} else {
			Logger(self).info(message)
		}
	}

	public static func convertVmdkToRaw(from: URL, to: URL, progressHandler: ProgressObserver.BuildProgressHandler?) throws {
		let context = ProgressObserver.ProgressHandlerContext()

		try VmdkConverter.convert(from: from, to: to) { (written, total) in
			if let progressHandler {
				let fractionCompleted = Double(written) / Double(total)
				progressHandler(.progress(context, fractionCompleted))

				context.oldFractionCompleted = fractionCompleted
			}
		}
	}

	public static func convertCloudImageToRaw(from: URL, to: URL, progressHandler: ProgressObserver.BuildProgressHandler?) throws {
		let context = ProgressObserver.ProgressHandlerContext()

		try Qcow2Converter.convert(from: from, to: to) { (written, total) in
			if let progressHandler {
				let fractionCompleted = Double(written) / Double(total)
				progressHandler(.progress(context, fractionCompleted))

				context.oldFractionCompleted = fractionCompleted
			}
		}
	}

	public static func downloadRemoteFile(fromURL: URL, toURL: URL, runMode: Utils.RunMode, progressHandler: ProgressObserver.BuildProgressHandler?) async throws -> URL {
		if FileManager.default.fileExists(atPath: toURL.path) {
			throw ServiceError(String(localized: "file already exists: \(toURL.path)"))
		}
		var pathExtension = fromURL.pathExtension
		
		if pathExtension.isEmpty {
			pathExtension = "img"
		}

		// Download the cloud-image
		self.step(String(localized: "Fetching \(fromURL.lastPathComponent)..."), progressHandler: progressHandler)

		let temporaryLocation = try Home(runMode: runMode).temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + fromURL.pathExtension)

		defer {
			try? FileManager.default.removeItem(at: temporaryLocation)
		}

		try await Curl(fromURL: fromURL).get(store: temporaryLocation, observer: ProgressObserver(progressHandler: progressHandler).log("Fetching \(fromURL.lastPathComponent)"))

		return try FileManager.default.replaceItemAt(toURL, withItemAt: temporaryLocation)!
	}

	public static func downloadRemoteToCache(remoteURL: URL, imageCache: CommonCacheImageCache, runMode: Utils.RunMode, progressHandler: ProgressObserver.BuildProgressHandler?) async throws -> URL {
		// Check if we already have this linux image in cache
		let fileName = remoteURL.lastPathComponent.deletingPathExtension
		let cacheLocation = imageCache.locationFor(fileName: "\(fileName).\(imageCache.ext)")

		if FileManager.default.fileExists(atPath: cacheLocation.path) {
			self.step(String(localized: "Using cached \(cacheLocation.path(percentEncoded: false)) file..."), progressHandler: progressHandler)
			try cacheLocation.updateAccessDate()
			return cacheLocation
		}

		return try await downloadRemoteFile(fromURL: remoteURL, toURL: cacheLocation, runMode: runMode, progressHandler: progressHandler)
	}

	public static func downloadIPSW(remoteURL: URL, runMode: Utils.RunMode, progressHandler: ProgressObserver.BuildProgressHandler?) async throws -> URL {
		// Check if we already have this linux image in cache
		let imageCache = try IPSWCache(name: remoteURL.host()!, runMode: runMode)

		return try await downloadRemoteToCache(remoteURL: remoteURL, imageCache: imageCache, runMode: runMode, progressHandler: progressHandler)
	}

	public static func downloadISO(remoteURL: URL, runMode: Utils.RunMode, progressHandler: ProgressObserver.BuildProgressHandler?) async throws -> URL {
		// Check if we already have this linux image in cache
		let imageCache = try IsoCache(name: remoteURL.host()!, runMode: runMode)

		return try await downloadRemoteToCache(remoteURL: remoteURL, imageCache: imageCache, runMode: runMode, progressHandler: progressHandler)
	}

	public static func downloadLinuxImage(remoteURL: URL, runMode: Utils.RunMode, progressHandler: ProgressObserver.BuildProgressHandler?) async throws -> URL {
		// Check if we already have this linux image in cache
		let imageCache = try CloudImageCache(name: remoteURL.host()!, runMode: runMode)

		return try await downloadRemoteToCache(remoteURL: remoteURL, imageCache: imageCache, runMode: runMode, progressHandler: progressHandler)
	}

	public static func retrieveCloudImageAndConvert(from: URL, to: URL, runMode: Utils.RunMode, progressHandler: ProgressObserver.BuildProgressHandler?) async throws {
		let fileName = from.lastPathComponent.deletingPathExtension
		let imageCache: CloudImageCache = try CloudImageCache(name: from.host()!, runMode: runMode)
		let cacheLocation = imageCache.locationFor(fileName: "\(fileName).img")

		try await retrieveRemoteImageCacheItAndConvert(from: from, to: to, cacheLocation: cacheLocation, runMode: runMode, progressHandler: progressHandler)
	}

	public static func retrieveRemoteImageCacheItAndConvert(from: URL, to: URL?, cacheLocation: URL, runMode: Utils.RunMode, progressHandler: ProgressObserver.BuildProgressHandler?) async throws {
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
			self.step(String(localized: "Using cached \(cacheLocation.path(percentEncoded: false)) file..."), progressHandler: progressHandler)
			try cacheLocation.updateAccessDate()
		} else {
			// Download the cloud-image
			self.step(String(localized: "Fetching \(from.lastPathComponent)..."), progressHandler: progressHandler)

			try await Curl(fromURL: from).get(store: temporaryLocation, observer: ProgressObserver(progressHandler: progressHandler).log("Fetching \(from.lastPathComponent)"))

			self.step(String(localized: "Done fetching \(from.lastPathComponent)..."), progressHandler: progressHandler)

			self.step(String(localized: "Convert \(from.lastPathComponent) qcow2 to raw..."), progressHandler: progressHandler)
			try convertCloudImageToRaw(from: temporaryLocation, to: cacheLocation, progressHandler: progressHandler)
			self.step(String(localized: "Done convert \(from.lastPathComponent) qcow2 to raw..."), progressHandler: progressHandler)

			try FileManager.default.removeItem(at: temporaryLocation)

		}

		if let to = to {
			try FileManager.default.copyItem(at: cacheLocation, to: temporaryLocation)
			_ = try FileManager.default.replaceItemAt(to, withItemAt: temporaryLocation)
		}
	}
}
