//
//  SPICEShared.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/11/2025.
//

import AppKit
import Foundation

/// Structures partagées pour le protocole SPICE
public struct SPICEShared {

	// MARK: - Événements d'entrée centralisés

	/// Événements d'entrée SPICE unifiés
	public enum InputEvent {
		case keyboard(KeyboardEvent)
		case mouse(MouseEvent)
	}

	/// Événement clavier SPICE unifié
	public struct KeyboardEvent {
		public let keyCode: UInt32
		public let pressed: Bool
		public let modifiers: UInt32

		public init(keyCode: UInt32, pressed: Bool, modifiers: UInt32 = 0) {
			self.keyCode = keyCode
			self.pressed = pressed
			self.modifiers = modifiers
		}

		public var data: Data {
			var data = Data()
			data.appendInteger(keyCode)
			data.append(pressed ? 1 : 0)
			data.appendInteger(modifiers)
			return data
		}
	}

	/// Événement souris SPICE unifié
	public struct MouseEvent {
		public let x: Int32
		public let y: Int32
		public let buttonMask: UInt8
		public let wheelDelta: Int8

		public init(x: Int32, y: Int32, buttonMask: UInt8 = 0, wheelDelta: Int8 = 0) {
			self.x = x
			self.y = y
			self.buttonMask = buttonMask
			self.wheelDelta = wheelDelta
		}

		public var data: Data {
			var data = Data()
			data.appendInteger(x)
			data.appendInteger(y)
			data.append(buttonMask)
			data.append(UInt8(bitPattern: wheelDelta))
			return data
		}
	}

	// MARK: - Configuration de capture unifiée

	/// Configuration de capture pour NSView
	public struct CaptureConfiguration {
		public let frameRate: Double
		public let enableAdaptiveFrameRate: Bool
		public let enableMotionDetection: Bool
		public let compressionQuality: Float
		public let enableHDRCapture: Bool
		public let maxFrameSize: CGSize?

		public init(
			frameRate: Double = 30.0,
			enableAdaptiveFrameRate: Bool = true,
			enableMotionDetection: Bool = true,
			compressionQuality: Float = 0.8,
			enableHDRCapture: Bool = false,
			maxFrameSize: CGSize? = nil
		) {
			self.frameRate = frameRate
			self.enableAdaptiveFrameRate = enableAdaptiveFrameRate
			self.enableMotionDetection = enableMotionDetection
			self.compressionQuality = compressionQuality
			self.enableHDRCapture = enableHDRCapture
			self.maxFrameSize = maxFrameSize
		}

		/// Configuration optimisée pour les jeux
		public static let gaming = CaptureConfiguration(
			frameRate: 60.0,
			enableAdaptiveFrameRate: false,
			enableMotionDetection: false,
			compressionQuality: 0.6,
			enableHDRCapture: false
		)

		/// Configuration équilibrée
		public static let balanced = CaptureConfiguration(
			frameRate: 30.0,
			enableAdaptiveFrameRate: true,
			enableMotionDetection: true,
			compressionQuality: 0.8,
			enableHDRCapture: false
		)

		/// Configuration haute qualité
		public static let highQuality = CaptureConfiguration(
			frameRate: 30.0,
			enableAdaptiveFrameRate: true,
			enableMotionDetection: true,
			compressionQuality: 1.0,
			enableHDRCapture: true
		)
	}

	// MARK: - Statistiques unifiées

	/// Statistiques de performance SPICE
	public struct PerformanceStatistics {
		public let currentFPS: Double
		public let averageFrameTime: TimeInterval
		public let totalFramesCaptured: UInt64
		public let compressionRatio: Double
		public let activeConnections: Int
		public let networkBandwidth: UInt64  // bytes/sec
		public let lastFrameSize: Int
		public let viewResolution: CGSize

		public var description: String {
			return """
				=== Statistiques SPICE ===
				FPS: \(String(format: "%.1f", currentFPS))
				Frame Time: \(String(format: "%.2f ms", averageFrameTime * 1000))
				Frames totales: \(totalFramesCaptured)
				Compression: \(String(format: "%.1f%%", compressionRatio * 100))
				Connexions: \(activeConnections)
				Bande passante: \(networkBandwidth / 1024) KB/s
				Dernière frame: \(lastFrameSize) bytes
				Résolution: \(Int(viewResolution.width))x\(Int(viewResolution.height))
				"""
		}
	}

	// MARK: - Utilitaires NSEvent

	/// Convertit les événements SPICE en événements NSEvent
	public struct EventConverter {

		/// Convertit un événement clavier SPICE en NSEvent
		public static func keyboardEventToNSEvent(_ event: KeyboardEvent, for view: NSView) -> NSEvent? {
			let eventType: NSEvent.EventType = event.pressed ? .keyDown : .keyUp
			let modifierFlags = NSEvent.ModifierFlags(rawValue: UInt(event.modifiers))

			return NSEvent.keyEvent(
				with: eventType,
				location: NSPoint.zero,
				modifierFlags: modifierFlags,
				timestamp: ProcessInfo.processInfo.systemUptime,
				windowNumber: view.window?.windowNumber ?? 0,
				context: nil,
				characters: "",
				charactersIgnoringModifiers: "",
				isARepeat: false,
				keyCode: UInt16(event.keyCode)
			)
		}

		/// Convertit un événement souris SPICE en NSEvent
		public static func mouseEventToNSEvent(_ event: MouseEvent, for view: NSView) -> NSEvent? {
			let location = NSPoint(x: CGFloat(event.x), y: CGFloat(event.y))
			let eventType: NSEvent.EventType = (event.buttonMask & 0x01) != 0 ? .leftMouseDown : .leftMouseUp

			return NSEvent.mouseEvent(
				with: eventType,
				location: location,
				modifierFlags: [],
				timestamp: ProcessInfo.processInfo.systemUptime,
				windowNumber: view.window?.windowNumber ?? 0,
				context: nil,
				eventNumber: 0,
				clickCount: 1,
				pressure: 1.0
			)
		}

		/// Convertit un NSEvent en événement SPICE
		public static func nsEventToKeyboardEvent(_ event: NSEvent) -> KeyboardEvent? {
			guard event.type == .keyDown || event.type == .keyUp else { return nil }

			return KeyboardEvent(
				keyCode: UInt32(event.keyCode),
				pressed: event.type == .keyDown,
				modifiers: UInt32(event.modifierFlags.rawValue)
			)
		}

		/// Convertit un NSEvent de souris en événement SPICE
		public static func nsEventToMouseEvent(_ event: NSEvent) -> MouseEvent? {
			guard event.type.rawValue >= NSEvent.EventType.leftMouseDown.rawValue && event.type.rawValue <= NSEvent.EventType.otherMouseDragged.rawValue else { return nil }

			var buttonMask: UInt8 = 0
			if event.type == .leftMouseDown || event.type == .leftMouseDragged {
				buttonMask |= 0x01
			}
			if event.type == .rightMouseDown || event.type == .rightMouseDragged {
				buttonMask |= 0x02
			}

			return MouseEvent(
				x: Int32(event.locationInWindow.x),
				y: Int32(event.locationInWindow.y),
				buttonMask: buttonMask,
				wheelDelta: Int8(event.deltaY)
			)
		}
	}
}

// MARK: - Extensions partagées

// Extension Data.appendInteger définie dans SPICEProtocol.swift

// MARK: - Gestionnaire d'état partagé

/// Gestionnaire d'état partagé pour les composants SPICE
public class SPICEStateManager {
	public static let shared = SPICEStateManager()

	private var activeConnections: Set<String> = []
	private var performanceHistory: [SPICEShared.PerformanceStatistics] = []
	private let accessQueue = DispatchQueue(label: "com.caker.spice.state", qos: .userInteractive)

	private init() {}

	/// Enregistre une nouvelle connexion
	public func registerConnection(_ identifier: String) {
		accessQueue.async {
			self.activeConnections.insert(identifier)
		}
	}

	/// Supprime une connexion
	public func unregisterConnection(_ identifier: String) {
		accessQueue.async {
			self.activeConnections.remove(identifier)
		}
	}

	/// Retourne le nombre de connexions actives
	public func activeConnectionCount() -> Int {
		return accessQueue.sync {
			return activeConnections.count
		}
	}

	/// Enregistre des statistiques de performance
	public func recordPerformance(_ stats: SPICEShared.PerformanceStatistics) {
		accessQueue.async {
			self.performanceHistory.append(stats)
			if self.performanceHistory.count > 100 {
				self.performanceHistory.removeFirst()
			}
		}
	}

	/// Retourne les statistiques moyennes
	public func averagePerformance() -> SPICEShared.PerformanceStatistics? {
		return accessQueue.sync {
			guard !performanceHistory.isEmpty else { return nil }

			let avgFPS = performanceHistory.reduce(0.0) { $0 + $1.currentFPS } / Double(performanceHistory.count)
			let avgFrameTime = performanceHistory.reduce(0.0) { $0 + $1.averageFrameTime } / Double(performanceHistory.count)
			let totalFrames = performanceHistory.last?.totalFramesCaptured ?? 0
			let avgCompression = performanceHistory.reduce(0.0) { $0 + $1.compressionRatio } / Double(performanceHistory.count)
			let connections = activeConnections.count
			let avgBandwidth = performanceHistory.reduce(UInt64(0)) { $0 + $1.networkBandwidth } / UInt64(performanceHistory.count)
			let lastFrameSize = performanceHistory.last?.lastFrameSize ?? 0
			let resolution = performanceHistory.last?.viewResolution ?? CGSize.zero

			return SPICEShared.PerformanceStatistics(
				currentFPS: avgFPS,
				averageFrameTime: avgFrameTime,
				totalFramesCaptured: totalFrames,
				compressionRatio: avgCompression,
				activeConnections: connections,
				networkBandwidth: avgBandwidth,
				lastFrameSize: lastFrameSize,
				viewResolution: resolution
			)
		}
	}
}
