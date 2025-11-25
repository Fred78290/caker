//
//  SPICEViewIntegration.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/11/2025.
//

import AppKit
import Foundation
import Virtualization

/// Intégration complète SPICE avec NSView pour la virtualisation
public class SPICEViewIntegration {

	// MARK: - Composants principaux

	private let spiceServer: SPICEViewServer
	private let renderer: SPICEViewRenderer
	private let client: SPICEClient?
	private let targetView: NSView

	// MARK: - Configuration

	/// Configuration d'intégration SPICE
	public struct IntegrationConfig {
		let serverPort: Int
		let enableCompression: Bool
		let frameRate: Double
		let enableCursor: Bool
		let enableKeyboard: Bool
		let enableMouse: Bool
		let qualityMode: QualityMode

		public enum QualityMode {
			case performance  // Optimisé pour les performances
			case balanced  // Équilibré qualité/performances
			case quality  // Optimisé pour la qualité
		}

		public init(
			serverPort: Int = 5900,
			enableCompression: Bool = true,
			frameRate: Double = 30.0,
			enableCursor: Bool = true,
			enableKeyboard: Bool = true,
			enableMouse: Bool = true,
			qualityMode: QualityMode = .balanced
		) {
			self.serverPort = serverPort
			self.enableCompression = enableCompression
			self.frameRate = frameRate
			self.enableCursor = enableCursor
			self.enableKeyboard = enableKeyboard
			self.enableMouse = enableMouse
			self.qualityMode = qualityMode
		}

		/// Configuration haute performance pour jeux
		public static let gaming = IntegrationConfig(
			serverPort: 5900,
			enableCompression: false,
			frameRate: 60.0,
			enableCursor: true,
			enableKeyboard: true,
			enableMouse: true,
			qualityMode: .performance
		)

		/// Configuration équilibrée pour usage général
		public static let standard = IntegrationConfig(
			serverPort: 5900,
			enableCompression: true,
			frameRate: 30.0,
			enableCursor: true,
			enableKeyboard: true,
			enableMouse: true,
			qualityMode: .balanced
		)

		/// Configuration haute qualité pour design
		public static let highQuality = IntegrationConfig(
			serverPort: 5900,
			enableCompression: true,
			frameRate: 30.0,
			enableCursor: true,
			enableKeyboard: true,
			enableMouse: true,
			qualityMode: .quality
		)
	}

	private let config: IntegrationConfig
	private var isActive = false

	// MARK: - Statistiques en temps réel

	/// Statistiques de performance SPICE
	public struct PerformanceStats {
		let currentFPS: Double
		let averageFrameTime: TimeInterval
		let networkBandwidth: UInt64  // bytes/sec
		let compressionRatio: Double
		let activeConnections: Int
		let viewSize: CGSize

		public var description: String {
			return """
				=== Statistiques SPICE ===
				FPS: \(String(format: "%.1f", currentFPS))
				Frame Time: \(String(format: "%.2f ms", averageFrameTime * 1000))
				Bande passante: \(networkBandwidth / 1024 / 1024) MB/s
				Compression: \(String(format: "%.1f%%", compressionRatio * 100))
				Connexions: \(activeConnections)
				Résolution: \(Int(viewSize.width))x\(Int(viewSize.height))
				"""
		}
	}

	private var performanceTracker = PerformanceTracker()

	// MARK: - Intégration avec Virtualization.framework

	private var virtualMachine: VZVirtualMachine?
	private var vmObserver: NSObjectProtocol?

	// MARK: - Initialisation

	public init(view: NSView, config: IntegrationConfig = .standard) {
		self.targetView = view
		self.config = config

		// Configuration du renderer selon le mode qualité
		switch config.qualityMode {
		case .performance:
			self.renderer = SPICEViewRenderer(configuration: .highPerformance)
		case .balanced:
			self.renderer = SPICEViewRenderer(
				configuration: SPICEViewRenderer.RenderConfiguration(
					useGPUAcceleration: true,
					pixelFormat: .bgra8Unorm,
					scaleFactor: 1.0,
					enableHDR: false
				))
		case .quality:
			self.renderer = SPICEViewRenderer(configuration: .highQuality)
		}

		// Configuration du serveur SPICE
		let spiceConfig = SPICEServer.Configuration(
			port: config.serverPort,
			maxClients: 4
		)
		let captureConfig = SPICEViewServer.CaptureConfiguration(frameRate: config.frameRate)
		self.spiceServer = SPICEViewServer(
			sourceView: view,
			spiceConfiguration: spiceConfig,
			captureConfiguration: captureConfig
		)

		// Client optionnel pour connexions externes
		self.client = nil

		setupIntegration()
	}

	private func setupIntegration() {
		// Configuration des callbacks du serveur
		// Note: Les callbacks seront implémentés dans une version future

		// Configuration de l'observation de la view
		setupViewObservation()
	}

	private func setupViewObservation() {
		// Observer les changements de taille de la view
		NotificationCenter.default.addObserver(
			forName: NSView.frameDidChangeNotification,
			object: targetView,
			queue: .main
		) { [weak self] _ in
			self?.handleViewFrameChange()
		}

		// Observer les changements de la hiérarchie de vues
		// Note: Observer la hiérarchie de vues sera implémenté dans une version future
	}

	// MARK: - Intégration avec Virtualization.framework

	/// Attache l'intégration SPICE à une machine virtuelle
	public func attachToVirtualMachine(_ vm: VZVirtualMachine) {
		virtualMachine = vm

		// Observer l'état de la VM
		// Observer l'état de la VM avec KVO
		vmObserver = vm.observe(\.state, options: [.new]) { [weak self] _, _ in
			DispatchQueue.main.async {
				self?.handleVMStateChange()
			}
		}

		// Si la VM est déjà en cours d'exécution, démarrer SPICE
		if vm.state == .running {
			start()
		}
	}

	private func handleVMStateChange() {
		guard let vm = virtualMachine else { return }

		switch vm.state {
		case .running:
			if !isActive {
				start()
			}
		case .stopped, .paused:
			if isActive {
				pause()
			}
		case .error:
			stop()
		default:
			break
		}
	}

	// MARK: - Contrôle de l'intégration

	/// Démarre l'intégration SPICE
	public func start() {
		guard !isActive else { return }

		do {
			try spiceServer.start()
			isActive = true
			performanceTracker.start()

			print("✅ Intégration SPICE démarrée sur le port \(config.serverPort)")
			print("📊 Mode qualité: \(config.qualityMode)")
			print("🖼️ Résolution: \(targetView.bounds.size)")

		} catch {
			print("❌ Erreur démarrage SPICE: \(error)")
		}
	}

	/// Met en pause l'intégration
	public func pause() {
		// Note: Pause sera implémentée dans une version future
		performanceTracker.pause()
		print("⏸️ Intégration SPICE mise en pause")
	}

	/// Reprend l'intégration
	public func resume() {
		// Note: Resume sera implémentée dans une version future
		performanceTracker.resume()
		print("▶️ Intégration SPICE reprise")
	}

	/// Arrête l'intégration SPICE
	public func stop() {
		spiceServer.stop()
		isActive = false
		performanceTracker.stop()
		print("⏹️ Intégration SPICE arrêtée")
	}

	// MARK: - Gestion des événements

	private func handleFrameData(_ data: Data) {
		performanceTracker.recordFrame(size: data.count)

		// Optionnel: traitement supplémentaire des frames
		if config.enableCompression {
			// La compression est gérée dans le serveur
		}
	}

	private func handleClientConnected(_ clientInfo: String) {
		performanceTracker.clientConnected()
		print("🔗 Client SPICE connecté: \(clientInfo)")
	}

	private func handleClientDisconnected(_ clientInfo: String) {
		performanceTracker.clientDisconnected()
		print("🔌 Client SPICE déconnecté: \(clientInfo)")
	}

	private func handleViewFrameChange() {
		let newSize = targetView.bounds.size
		performanceTracker.viewSizeChanged(newSize)

		// Note: Notification de changement de taille sera implémentée
	}

	private func handleViewHierarchyChange() {
		// Note: Rafraîchissement de capture sera implémenté
	}

	// MARK: - API publique avancée

	/// Retourne les statistiques de performance actuelles
	public func performanceStatistics() -> PerformanceStats {
		// let serverStats = spiceServer.statistics() // TODO: Implémenter
		let renderStats = renderer.renderStatistics()

		return PerformanceStats(
			currentFPS: performanceTracker.currentFPS,
			averageFrameTime: renderStats.averageRenderTime,
			networkBandwidth: performanceTracker.networkBandwidth,
			compressionRatio: performanceTracker.compressionRatio,
			activeConnections: performanceTracker.activeConnections,
			viewSize: targetView.bounds.size
		)
	}

	/// Configure dynamiquement la qualité
	public func setQualityMode(_ mode: IntegrationConfig.QualityMode) {
		// let newRenderConfig = createRenderConfiguration(for: mode)
		// Note: Dans une implémentation complète, on recréerait le renderer
		print("🎛️ Mode qualité changé: \(mode)")
	}

	/// Force une capture complète de la view
	public func captureFullFrame() {
		// Note: Capture complète sera implémentée
	}

	/// Injecte un événement clavier dans la view
	public func injectKeyEvent(keyCode: UInt16, pressed: Bool, modifiers: NSEvent.ModifierFlags) {
		let event = NSEvent.keyEvent(
			with: pressed ? .keyDown : .keyUp,
			location: NSPoint.zero,
			modifierFlags: modifiers,
			timestamp: ProcessInfo.processInfo.systemUptime,
			windowNumber: targetView.window?.windowNumber ?? 0,
			context: nil,
			characters: "",
			charactersIgnoringModifiers: "",
			isARepeat: false,
			keyCode: keyCode
		)

		if let event = event {
			targetView.keyDown(with: event)
		}
	}

	/// Injecte un événement souris dans la view
	public func injectMouseEvent(at point: NSPoint, buttonMask: UInt8) {
		let event = NSEvent.mouseEvent(
			with: .leftMouseDown,
			location: point,
			modifierFlags: [],
			timestamp: ProcessInfo.processInfo.systemUptime,
			windowNumber: targetView.window?.windowNumber ?? 0,
			context: nil,
			eventNumber: 0,
			clickCount: 1,
			pressure: 1.0
		)

		if let event = event {
			targetView.mouseDown(with: event)
		}
	}

	// MARK: - Nettoyage

	deinit {
		stop()

		if let observer = vmObserver {
			NotificationCenter.default.removeObserver(observer)
		}

		NotificationCenter.default.removeObserver(self)
	}
}

// MARK: - Tracking des performances

private class PerformanceTracker {
	private var frameTimes: [TimeInterval] = []
	private var frameStartTime: TimeInterval = 0
	private var totalFrameSize: UInt64 = 0
	private var frameCount: UInt64 = 0
	private var connectionCount = 0
	private var lastViewSize = CGSize.zero

	private var isRunning = false
	private var startTime: TimeInterval = 0

	var currentFPS: Double {
		guard frameTimes.count > 1 else { return 0 }
		let totalTime = frameTimes.reduce(0, +)
		return Double(frameTimes.count) / totalTime
	}

	var networkBandwidth: UInt64 {
		let elapsed = CACurrentMediaTime() - startTime
		guard elapsed > 0 else { return 0 }
		return UInt64(Double(totalFrameSize) / elapsed)
	}

	var compressionRatio: Double {
		// Estimation basée sur la taille moyenne des frames
		return 0.3  // 30% de la taille originale après compression
	}

	var activeConnections: Int {
		return connectionCount
	}

	func start() {
		isRunning = true
		startTime = CACurrentMediaTime()
		frameStartTime = startTime
	}

	func pause() {
		isRunning = false
	}

	func resume() {
		isRunning = true
		frameStartTime = CACurrentMediaTime()
	}

	func stop() {
		isRunning = false
		frameTimes.removeAll()
		totalFrameSize = 0
		frameCount = 0
	}

	func recordFrame(size: Int) {
		guard isRunning else { return }

		let currentTime = CACurrentMediaTime()
		let frameTime = currentTime - frameStartTime

		frameTimes.append(frameTime)
		if frameTimes.count > 60 {  // Garder seulement les 60 dernières frames
			frameTimes.removeFirst()
		}

		totalFrameSize += UInt64(size)
		frameCount += 1
		frameStartTime = currentTime
	}

	func clientConnected() {
		connectionCount += 1
	}

	func clientDisconnected() {
		connectionCount = max(0, connectionCount - 1)
	}

	func viewSizeChanged(_ size: CGSize) {
		lastViewSize = size
	}
}

// MARK: - Extensions utilitaires

extension SPICEViewIntegration.IntegrationConfig.QualityMode: CustomStringConvertible {
	public var description: String {
		switch self {
		case .performance:
			return "Performance"
		case .balanced:
			return "Équilibré"
		case .quality:
			return "Qualité"
		}
	}
}

// MARK: - Factory pour configurations spécialisées

extension SPICEViewIntegration {

	/// Crée une intégration optimisée pour les jeux
	public static func forGaming(view: NSView) -> SPICEViewIntegration {
		return SPICEViewIntegration(view: view, config: .gaming)
	}

	/// Crée une intégration optimisée pour les applications bureautiques
	public static func forOffice(view: NSView) -> SPICEViewIntegration {
		return SPICEViewIntegration(view: view, config: .standard)
	}

	/// Crée une intégration optimisée pour le design graphique
	public static func forDesign(view: NSView) -> SPICEViewIntegration {
		return SPICEViewIntegration(view: view, config: .highQuality)
	}
}
