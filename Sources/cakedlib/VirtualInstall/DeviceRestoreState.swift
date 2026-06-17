//
// Progress/state parsing from the AMRestore callback dictionary.
// Ported from VirtualBuddy 2.2-b2 / UTM, adapted for Caker.
// Not available in the App Store build (private SPI + non-sandboxed only).

#if !APPSTORE

import Foundation
import CakeAgentLib
import VirtualInstallSPI

/// The AMRestore operation code reported alongside each progress update.
typealias RestoreOperation = Int32

/// A `Codable`/`Hashable` snapshot of an `Error`, so that a restore failure can
/// be stored as part of `DeviceRestoreState`.
struct CodableError: LocalizedError, CustomNSError, Codable, Hashable, Sendable {
    private(set) var domain: String
    private(set) var code: Int
    private(set) var errorDescription: String
    private(set) var failureReason: String?
    private(set) var helpAnchor: String?
    private(set) var recoverySuggestion: String?
    private(set) var info: [String: String]
}

extension CodableError {
    init(_ error: any Error) {
        let nsError = error as NSError
        self.domain = nsError.domain
        self.code = nsError.code
        self.errorDescription = nsError.localizedDescription
        self.failureReason = nsError.localizedFailureReason
        self.helpAnchor = nsError.helpAnchor
        self.recoverySuggestion = nsError.localizedRecoverySuggestion
        self.info = [:]
        for (key, value) in nsError.userInfo {
            self.info[key] = String(describing: value)
        }
    }

    init(message: String) {
        self.domain = "com.aldunelabs.caker.VirtualInstall"
        self.code = 0
        self.errorDescription = message
        self.failureReason = nil
        self.helpAnchor = nil
        self.recoverySuggestion = nil
        self.info = [NSLocalizedFailureReasonErrorKey: message]
    }
}

/// The terminal result of a restore, derived from the engine's `Status` field.
enum DeviceRestoreOutcome: Hashable, Codable, Sendable {
    case success
    case failure(_ error: CodableError?)

    var isFailure: Bool {
        if case .failure = self { true } else { false }
    }
}

/// A parsed snapshot of a single restore progress report.
struct DeviceRestoreState: Hashable, Codable, Sendable {
    let progress: Double
    let overallProgress: Double?
    let operation: RestoreOperation
    let operationName: String?
    let status: String?
    private(set) var outcome: DeviceRestoreOutcome?
}

// MARK: - AMRestore parsing

private extension DeviceRestoreOutcome {
    init?(info: [String: Any], status: String) {
        if status.caseInsensitiveCompare("Successful") == .orderedSame {
            self = .success
        } else if status.caseInsensitiveCompare("Failed") == .orderedSame {
            self = .failure((info["Error"] as? NSError).flatMap(CodableError.init))
        } else {
            return nil
        }
    }
}

extension DeviceRestoreState {
    private static let logger = Logger("DeviceRestoreState")

    /// Parses a restore progress report delivered by the AMRestore callback.
    ///
    /// - Parameter info: the bridged progress dictionary (`CFDictionary` →
    ///   `[AnyHashable: Any]`) handed to `DeviceRestoreProgressClosure`.
    init(info: [AnyHashable: Any]) throws {
        guard let dict = info as? [String: Any] else {
			throw CodableError(message: String(localized: "Info dictionary in progress report doesn't match expected dictionary type"))
        }

        let intProgress = dict["Progress"] as? Int ?? 0
        let intOverallProgress = dict["OverallProgress"] as? Int ?? 0
        self.status = dict["Status"] as? String
        self.progress = Double(intProgress) / 100.0
        self.overallProgress = intOverallProgress <= 0 ? nil : Double(intOverallProgress) / 100.0
        self.operation = dict["Operation"] as? RestoreOperation ?? 0

        let operationNameFormat = VIMDLocalizedStringForOperation(operation) as String

        if let queuePosition = dict["QueuePosition"] as? Int, operationNameFormat.contains("%d") {
            self.operationName = String(format: operationNameFormat, queuePosition)
        } else {
            self.operationName = operationNameFormat
        }

        if let status, status != "Restoring" {
            self.outcome = DeviceRestoreOutcome(info: dict, status: status)
        } else {
            self.outcome = nil
        }
    }

    func replacingOutcome(with error: NSError) -> Self {
        var mSelf = self
        mSelf.outcome = .failure(CodableError(error))
        return mSelf
    }
}

#endif
