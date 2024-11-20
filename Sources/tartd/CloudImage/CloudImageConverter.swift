import Foundation
import ShellOut

class CloudImageConverter {
  static func convertCloudImageToRaw(from: URL, to: URL) throws {
    do {
      let convertOuput = try shellOut(to: "qemu-img", arguments: [
        "convert", "-p", "-f", "qcow2", "-O", "raw",
        from.path(),
        to.path()
      ])
      defaultLogger.appendNewLine(convertOuput)
    } catch {
      let error = error as! ShellOutError

      defaultLogger.appendNewLine(error.message)
      defaultLogger.appendNewLine(error.output)

      throw error
    }
  }

  static func downloadLinuxImage(remoteURL: URL) async throws -> URL{
    // Check if we already have this linux image in cache
    let fileName = (remoteURL.lastPathComponent as NSString).deletingPathExtension
    let imageCache = try CloudImageCache(name: remoteURL.host()!)
    let cacheLocation = imageCache.locationFor(fileName: "\(fileName).img")

    if FileManager.default.fileExists(atPath: cacheLocation.path) {
      defaultLogger.appendNewLine("Using cached \(cacheLocation.path) file...")
      try cacheLocation.updateAccessDate()
      return cacheLocation
    }

    // Download the cloud-image
    defaultLogger.appendNewLine("Fetching \(remoteURL.lastPathComponent)...")

    let downloadProgress = Progress(totalUnitCount: 100)
    ProgressObserver(downloadProgress).log(defaultLogger)

    let request = URLRequest(url: remoteURL)
    let (channel, response) = try await Fetcher.fetch(request, viaFile: true, progress: downloadProgress)

    let temporaryLocation = try Config().tartTmpDir.appendingPathComponent(UUID().uuidString + ".img")
    defaultLogger.appendNewLine("Computing digest for \(temporaryLocation.path)...")
    let digestProgress = Progress(totalUnitCount: response.expectedContentLength)
    ProgressObserver(digestProgress).log(defaultLogger)

    FileManager.default.createFile(atPath: temporaryLocation.path, contents: nil)
    let lock = try FileLock(lockURL: temporaryLocation)
    try lock.lock()

    let fileHandle: FileHandle = try FileHandle(forWritingTo: temporaryLocation)
    let digest: Digest = Digest()

    for try await chunk in channel {
      let chunkAsData = Data(chunk)
      fileHandle.write(chunkAsData)
      digest.update(chunkAsData)
      digestProgress.completedUnitCount += Int64(chunk.count)
    }

    try fileHandle.close()
    try lock.unlock()

    defer {
      do {
        try FileManager.default.removeItem(at: temporaryLocation)
      } catch {
        defaultLogger.appendNewLine("Unexpected error: \(error).")
      }
    }

    return try FileManager.default.replaceItemAt(cacheLocation, withItemAt: temporaryLocation)!
  }
  
  static func retrieveCloudImageAndConvert(from: URL, to: URL) async throws {
    let fileName = (from.lastPathComponent as NSString).deletingPathExtension
    let imageCache: CloudImageCache = try CloudImageCache(name: from.host()!)
    let cacheLocation = imageCache.locationFor(fileName: "\(fileName).img")

    try await retrieveRemoteImageCacheItAndConvert(from: from, to: to, cacheLocation: cacheLocation)
  }
  
  static func retrieveRemoteImageCacheItAndConvert(from: URL, to: URL?, cacheLocation: URL) async throws {
    let temporaryLocation = try Config().tartTmpDir.appendingPathComponent(UUID().uuidString + ".img")

    defer {
        if FileManager.default.fileExists(atPath: temporaryLocation.path()) {
          do {
            try FileManager.default.removeItem(at: temporaryLocation)
          } catch {
            defaultLogger.appendNewLine("Unexpected error: \(error).")
          }
        }
    }

    if FileManager.default.fileExists(atPath: cacheLocation.path) {
      defaultLogger.appendNewLine("Using cached \(cacheLocation.path) file...")
      try cacheLocation.updateAccessDate() 
    } else {
      // Download the cloud-image
      defaultLogger.appendNewLine("Fetching \(from.lastPathComponent)...")

      let downloadProgress = Progress(totalUnitCount: 100)
      ProgressObserver(downloadProgress).log(defaultLogger)

      let request = URLRequest(url: from)
      let (channel, response) = try await Fetcher.fetch(request, viaFile: true, progress: downloadProgress)

      defaultLogger.appendNewLine("Computing digest for \(temporaryLocation.path)...")
      let digestProgress = Progress(totalUnitCount: response.expectedContentLength)
      ProgressObserver(digestProgress).log(defaultLogger)

      FileManager.default.createFile(atPath: temporaryLocation.path, contents: nil)
      let lock = try FileLock(lockURL: temporaryLocation)
      try lock.lock()

      let fileHandle: FileHandle = try FileHandle(forWritingTo: temporaryLocation)
      let digest: Digest = Digest()

      for try await chunk in channel {
        let chunkAsData = Data(chunk)
        fileHandle.write(chunkAsData)
        digest.update(chunkAsData)
        digestProgress.completedUnitCount += Int64(chunk.count)
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
