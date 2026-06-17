//
// File-backed log sink for the AMRestore engine.
// Ported from VirtualBuddy 2.2-b2 / UTM, adapted for Caker.
// Not available in the App Store build (private SPI + non-sandboxed only).

#if !APPSTORE

import Foundation
import CakeAgentLib

/// A file-backed log sink for the restore engine.
final class RestoreLog: @unchecked Sendable {
    private let logger: Logger
    let fileURL: URL

    private let lock = NSLock()
    private var _fileHandle: FileHandle?

    init(fileURL: URL) {
        self.fileURL = fileURL
        let name = "RestoreLog(\(fileURL.deletingPathExtension().lastPathComponent))"
        self.logger = Logger(name)
    }

    /// Opens (creating if needed) and returns a handle for reading the log file.
    func fileHandle() throws -> FileHandle {
        lock.lock()
        defer { lock.unlock() }

        if let handle = _fileHandle {
            return handle
        }
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
        let handle = try FileHandle(forReadingFrom: fileURL)
        logger.info("Opened file handle at \(fileURL.path)")
        _fileHandle = handle
        return handle
    }

    func invalidate() {
        lock.lock()
        defer { lock.unlock() }
        _ = try? _fileHandle?.close()
        _fileHandle = nil
    }

    deinit { invalidate() }
}

#endif
