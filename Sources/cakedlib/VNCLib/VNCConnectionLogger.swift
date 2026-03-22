//
//  VNCConnectionLogger.swift
//  Caker
//
//  Created by Frederic BOLTZ on 22/03/2026.
//
import RoyalVNCKit
import CakeAgentLib

public class VNCConnectionLogger: VNCLogger {
	public let logger: Logger = Logger("VNCConnectionLogger")
	public var isDebugLoggingEnabled: Bool = false

	public init(_ isDebugLoggingEnabled: Bool) {
		self.isDebugLoggingEnabled = isDebugLoggingEnabled
	}

	public func logDebug(_ message: String) {
		#if DEBUG
			if isDebugLoggingEnabled {
				self.logger.debug(message)
			}
		#endif
	}

	public func logInfo(_ message: String) {
		self.logger.info(message)
	}

	public func logWarning(_ message: String) {
		self.logger.warn(message)
	}

	public func logError(_ message: String) {
		self.logger.error(message)
	}
}

