//
//  SPICEViewServer.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/11/2025.
//

import AppKit
import Compression
import Foundation
import Virtualization

/// Serveur SPICE utilisant une NSView comme source d'affichage
public class SPICEViewServer {
	private let sourceView: NSView
	private var spiceServer: SPICEServer?
	private let configuration: SPICEServer.Configuration
	private var displayTimer: Timer?
	private var frameBuffer: CGContext?
	private var lastFrameData: Data?
	private let queue: DispatchQueue
	private var isCapturing = false

	/// Configuration de capture d'écran
	public struct CaptureConfiguration {
		public let frameRate: Double
		public let quality: CGFloat
		public let useCompression: Bool
		public let colorSpace: CGColorSpace
		public let bitmapInfo: CGBitmapInfo

		public init(
			frameRate: Double = 30.0,
			quality: CGFloat = 0.8,
			useCompression: Bool = true,
			colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB(),
			bitmapInfo: CGBitmapInfo = [.byteOrder32Big, CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)]
		) {
			self.frameRate = frameRate
			self.quality = quality
			self.useCompression = useCompression
			self.colorSpace = colorSpace
			self.bitmapInfo = bitmapInfo
		}

		/// Configuration optimisée pour la performance
		public static let performance = CaptureConfiguration(
			frameRate: 60.0,
			quality: 0.6,
			useCompression: false
		)

		/// Configuration optimisée pour la qualité
		public static let quality = CaptureConfiguration(
			frameRate: 24.0,
			quality: 1.0,
			useCompression: true
		)

		/// Configuration équilibrée
		public static let balanced = CaptureConfiguration(
			frameRate: 30.0,
			quality: 0.8,
			useCompression: true
		)
	}

	private let captureConfig: CaptureConfiguration
	private var frameCount: UInt64 = 0
	private var lastCaptureTime: CFTimeInterval = 0

	/// Statistiques de capture
	public struct CaptureStats {
		let currentFPS: Double
		let averageFPS: Double
		let totalFrames: UInt64
		let dataTransferred: UInt64
		let compressionRatio: Double
		let viewSize: CGSize

		public var description: String {
			return """
				=== Stats Capture SPICE ===
				FPS actuel: \(String(format: "%.1f", currentFPS))
				FPS moyen: \(String(format: "%.1f", averageFPS))
				Frames totales: \(totalFrames)
				Données: \(dataTransferred / 1024 / 1024) MB
				Compression: \(String(format: "%.1f%%", compressionRatio * 100))
				Taille: \(Int(viewSize.width))x\(Int(viewSize.height))
				"""
		}
	}

	/// Handler pour les événements de capture
	public var captureEventHandler: ((CaptureEvent) -> Void)?

	public enum CaptureEvent {
		case started
		case frameProcessed(Data, TimeInterval)
		case error(Error)
		case stopped
	}

	public init(
		sourceView: NSView,
		spiceConfiguration: SPICEServer.Configuration,
		captureConfiguration: CaptureConfiguration = .balanced
	) {
		self.sourceView = sourceView
		self.configuration = spiceConfiguration
		self.captureConfig = captureConfiguration
		self.queue = DispatchQueue(label: "com.caker.spice.view", qos: .userInteractive)

		setupFrameBuffer()
	}

	/// Démarre le serveur SPICE avec capture de la view
	public func start() throws {
		// Démarrer le serveur SPICE
		spiceServer = SPICEServer(configuration: configuration)
		try spiceServer?.start()

		// Démarrer la capture de la view
		try startViewCapture()

		captureEventHandler?(.started)
		print("Serveur SPICE View démarré - Port: \(configuration.port)")
	}

	/// Arrête le serveur et la capture
	public func stop() {
		stopViewCapture()
		spiceServer?.stop()
		spiceServer = nil

		captureEventHandler?(.stopped)
		print("Serveur SPICE View arrêté")
	}

	/// URL de connexion SPICE
	public var connectionURL: URL? {
		return spiceServer?.connectionURL()
	}

	/// Vérifie si le serveur est en cours d'exécution
	public var running: Bool {
		return isCapturing && (spiceServer?.running ?? false)
	}

	/// Statistiques de capture actuelles
	public func captureStatistics() -> CaptureStats {
		let currentTime = CACurrentMediaTime()
		let deltaTime = currentTime - lastCaptureTime
		let currentFPS = deltaTime > 0 ? 1.0 / deltaTime : 0

		return CaptureStats(
			currentFPS: currentFPS,
			averageFPS: frameCount > 0 ? Double(frameCount) / currentTime : 0,
			totalFrames: frameCount,
			dataTransferred: 0,
			compressionRatio: captureConfig.useCompression ? 0.7 : 1.0,
			viewSize: sourceView.bounds.size
		)
	}

	// MARK: - Capture de la View

	private func setupFrameBuffer() {
		let bounds = sourceView.bounds
		let width = Int(bounds.width)
		let height = Int(bounds.height)

		guard width > 0 && height > 0 else { return }

		let bytesPerRow = width * 4

		guard
			let context = CGContext(
				data: nil,
				width: width,
				height: height,
				bitsPerComponent: 8,
				bytesPerRow: bytesPerRow,
				space: captureConfig.colorSpace,
				bitmapInfo: captureConfig.bitmapInfo.rawValue
			)
		else { return }

		frameBuffer = context
	}

	private func startViewCapture() throws {
		guard !isCapturing else { return }

		isCapturing = true

		// Utiliser un Timer pour capturer les frames
		let interval = 1.0 / captureConfig.frameRate
		displayTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
			self?.captureFrame()
		}
	}

	private func stopViewCapture() {
		guard isCapturing else { return }

		displayTimer?.invalidate()
		displayTimer = nil
		isCapturing = false
	}

	private func captureFrame() {
		queue.async { [weak self] in
			self?.performFrameCapture()
		}
	}

	private func performFrameCapture() {
		guard let context = frameBuffer else { return }

		let startTime = CACurrentMediaTime()

		// Capturer le contenu de la view via son layer
		DispatchQueue.main.sync {
			guard let layer = sourceView.layer else { return }

			CATransaction.begin()
			CATransaction.setDisableActions(true)
			layer.render(in: context)
			CATransaction.commit()
		}

		// Extraire les données de l'image
		guard let data = context.makeImage()?.dataProvider?.data else { return }

		let frameData = Data(bytes: CFDataGetBytePtr(data), count: CFDataGetLength(data))

		// Traitement optionnel de compression
		let processedData = captureConfig.useCompression ? compressFrameData(frameData) : frameData

		// Vérifier si le frame a changé
		if shouldSendFrame(processedData) {
			sendFrameToSPICE(processedData)
			lastFrameData = processedData
		}

		frameCount += 1
		let processingTime = CACurrentMediaTime() - startTime
		lastCaptureTime = startTime

		captureEventHandler?(.frameProcessed(processedData, processingTime))
	}

	private func shouldSendFrame(_ frameData: Data) -> Bool {
		guard let lastFrame = lastFrameData else { return true }

		// Comparaison simple - dans une implémentation complète,
		// on pourrait utiliser un hash ou une comparaison plus sophistiquée
		return frameData != lastFrame
	}

	private func compressFrameData(_ data: Data) -> Data {
		// Implémentation de compression avec l'API Compression
		let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
		defer { buffer.deallocate() }

		let compressedSize = compression_encode_buffer(
			buffer, data.count,
			data.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }, data.count,
			nil, COMPRESSION_LZFSE
		)

		if compressedSize > 0 {
			return Data(bytes: buffer, count: compressedSize)
		} else {
			return data
		}
	}

	private func sendFrameToSPICE(_ frameData: Data) {
		// Créer un message SPICE pour envoyer le frame
		let _ = createSPICEDisplayMessage(frameData)

		// TODO: Envoyer via le serveur SPICE
		// spiceServer?.sendMessage(spiceMessage)
	}

	private func createSPICEDisplayMessage(_ frameData: Data) -> Data {
		// Créer un message d'affichage SPICE
		let bounds = sourceView.bounds
		let width = UInt32(bounds.width)
		let height = UInt32(bounds.height)

		var message = Data()

		// En-tête du message d'affichage SPICE
		Swift.withUnsafeBytes(of: UInt16(SPICEProtocol.DisplayMessage.mode.rawValue).littleEndian) { message.append(contentsOf: $0) }
		Swift.withUnsafeBytes(of: UInt32(frameData.count + 8).littleEndian) { message.append(contentsOf: $0) }
		Swift.withUnsafeBytes(of: width.littleEndian) { message.append(contentsOf: $0) }
		Swift.withUnsafeBytes(of: height.littleEndian) { message.append(contentsOf: $0) }

		// Données de l'image
		message.append(frameData)

		return message
	}

	deinit {
		stop()
	}
}

// MARK: - Extensions pour l'interaction avec la view

extension SPICEViewServer {

	/// Met à jour la taille de capture quand la view change
	public func updateCaptureSize() {
		setupFrameBuffer()
	}

	/// Force la capture d'un frame immédiatement
	public func captureNow() {
		guard isCapturing else { return }
		performFrameCapture()
	}

	/// Configure les propriétés de la view pour une capture optimale
	public func optimizeSourceView() {
		DispatchQueue.main.async { [weak self] in
			guard let self = self, let layer = self.sourceView.layer else { return }

			// Optimisations pour la capture
			layer.shouldRasterize = true
			layer.rasterizationScale = NSScreen.main?.backingScaleFactor ?? 1.0
			layer.drawsAsynchronously = false

			// Assurer que la view a un layer backing
			if self.sourceView.layer == nil {
				self.sourceView.wantsLayer = true
			}
		}
	}
}

// MARK: - Support pour différents types de views

extension SPICEViewServer {

	/// Crée un serveur SPICE pour une NSView avec contenu OpenGL/Metal
	public static func forGLView(
		_ glView: NSView,
		spiceConfig: SPICEServer.Configuration,
		captureConfig: CaptureConfiguration = .performance
	) -> SPICEViewServer {
		let server = SPICEViewServer(
			sourceView: glView,
			spiceConfiguration: spiceConfig,
			captureConfiguration: captureConfig)
		server.optimizeSourceView()
		return server
	}

	/// Crée un serveur SPICE pour une view de contenu générique
	public static func forContentView(
		_ view: NSView,
		spiceConfig: SPICEServer.Configuration,
		captureConfig: CaptureConfiguration = .quality
	) -> SPICEViewServer {
		return SPICEViewServer(
			sourceView: view,
			spiceConfiguration: spiceConfig,
			captureConfiguration: captureConfig)
	}

	/// Crée un serveur SPICE pour une NSWindow complète
	public static func forWindow(
		_ window: NSWindow,
		spiceConfig: SPICEServer.Configuration,
		captureConfig: CaptureConfiguration = .balanced
	) -> SPICEViewServer {
		return SPICEViewServer(
			sourceView: window.contentView!,
			spiceConfiguration: spiceConfig,
			captureConfiguration: captureConfig)
	}
}

// MARK: - Gestion des événements d'entrée SPICE

extension SPICEViewServer {

	/// Traite les événements d'entrée SPICE et les transmet à la view
	public func handleSPICEInputEvent(_ event: SPICEInputEvent) {
		switch event {
		case .keyboard(let keyEvent):
			handleKeyboardEvent(keyEvent)
		case .mouse(let mouseEvent):
			handleMouseEvent(mouseEvent)
		}
	}

	private func handleKeyboardEvent(_ event: SPICEKeyboardEvent) {
		DispatchQueue.main.async { [weak self] in
			guard let self = self else { return }

			// Convertir l'événement SPICE en NSEvent
			let nsEvent = NSEvent.keyEvent(
				with: event.pressed ? .keyDown : .keyUp,
				location: NSPoint.zero,
				modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(event.modifiers)),
				timestamp: ProcessInfo.processInfo.systemUptime,
				windowNumber: self.sourceView.window?.windowNumber ?? 0,
				context: nil,
				characters: "",
				charactersIgnoringModifiers: "",
				isARepeat: false,
				keyCode: UInt16(event.keyCode)
			)

			// Envoyer l'événement à la view
			if let event = nsEvent {
				self.sourceView.keyDown(with: event)
			}
		}
	}

	private func handleMouseEvent(_ event: SPICEMouseEvent) {
		DispatchQueue.main.async { [weak self] in
			guard let self = self else { return }

			// Convertir les coordonnées SPICE en coordonnées de la view
			let viewBounds = self.sourceView.bounds
			let point = NSPoint(
				x: CGFloat(event.x) * viewBounds.width / viewBounds.width,
				y: viewBounds.height - CGFloat(event.y) * viewBounds.height / viewBounds.height
			)

			// Créer un NSEvent de souris
			let nsEvent = NSEvent.mouseEvent(
				with: .leftMouseDown,
				location: point,
				modifierFlags: [],
				timestamp: ProcessInfo.processInfo.systemUptime,
				windowNumber: self.sourceView.window?.windowNumber ?? 0,
				context: nil,
				eventNumber: 0,
				clickCount: 1,
				pressure: 1.0
			)

			// Envoyer l'événement à la view
			if let event = nsEvent {
				self.sourceView.mouseDown(with: event)
			}
		}
	}
}

/// Événements d'entrée SPICE
public enum SPICEInputEvent {
	case keyboard(SPICEKeyboardEvent)
	case mouse(SPICEMouseEvent)
}

/// Événement clavier SPICE
public struct SPICEKeyboardEvent {
	public let keyCode: UInt32
	public let pressed: Bool
	public let modifiers: UInt32

	public init(keyCode: UInt32, pressed: Bool, modifiers: UInt32 = 0) {
		self.keyCode = keyCode
		self.pressed = pressed
		self.modifiers = modifiers
	}
}

/// Événement souris SPICE
public struct SPICEMouseEvent {
	public let x: Int32
	public let y: Int32
	public let buttonMask: UInt8
	public let wheelDelta: Int8

	public init(x: Int32, y: Int32, buttonMask: UInt8, wheelDelta: Int8 = 0) {
		self.x = x
		self.y = y
		self.buttonMask = buttonMask
		self.wheelDelta = wheelDelta
	}
}
