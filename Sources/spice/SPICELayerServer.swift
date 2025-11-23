//
//  SPICELayerServer.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/11/2025.
//

import Foundation
import AppKit
import QuartzCore
import CoreGraphics
import Virtualization

/// Serveur SPICE utilisant un CALayer comme source d'affichage
public class SPICELayerServer {
    private let sourceLayer: CALayer
    private var spiceServer: SPICEServer?
    private let configuration: SPICEServer.Configuration
    private var displayLink: CADisplayLink?
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
        
        public init(frameRate: Double = 30.0,
                   quality: CGFloat = 0.8,
                   useCompression: Bool = true,
                   colorSpace: CGColorSpace = CGColorSpaceCreateDeviceRGB(),
                   bitmapInfo: CGBitmapInfo = [.byteOrder32Big, CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)]) {
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
        let layerSize: CGSize
        
        public var description: String {
            return """
            === Stats Capture SPICE ===
            FPS actuel: \(String(format: "%.1f", currentFPS))
            FPS moyen: \(String(format: "%.1f", averageFPS))
            Frames totales: \(totalFrames)
            Données: \(dataTransferred / 1024 / 1024) MB
            Compression: \(String(format: "%.1f%%", compressionRatio * 100))
            Taille: \(Int(layerSize.width))x\(Int(layerSize.height))
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
    
    public init(sourceLayer: CALayer, 
               spiceConfiguration: SPICEServer.Configuration,
               captureConfiguration: CaptureConfiguration = .balanced) {
        self.sourceLayer = sourceLayer
        self.configuration = spiceConfiguration
        self.captureConfig = captureConfiguration
        self.queue = DispatchQueue(label: "com.caker.spice.layer", qos: .userInteractive)
        
        setupFrameBuffer()
    }
    
    /// Démarre le serveur SPICE avec capture du layer
    public func start() throws {
        // Démarrer le serveur SPICE
        spiceServer = SPICEServer(configuration: configuration)
        try spiceServer?.start()
        
        // Démarrer la capture du layer
        try startLayerCapture()
        
        captureEventHandler?(.started)
        print("Serveur SPICE Layer démarré - Port: \(configuration.port)")
    }
    
    /// Arrête le serveur et la capture
    public func stop() {
        stopLayerCapture()
        spiceServer?.stop()
        spiceServer = nil
        
        captureEventHandler?(.stopped)
        print("Serveur SPICE Layer arrêté")
    }
    
    /// URL de connexion SPICE
    public var connectionURL: URL? {
        return spiceServer?.connectionURL()
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
            dataTransferred: 0, // TODO: Calculer depuis le serveur SPICE
            compressionRatio: captureConfig.useCompression ? 0.7 : 1.0,
            layerSize: sourceLayer.bounds.size
        )
    }
    
    // MARK: - Capture du Layer
    
    private func setupFrameBuffer() {
        let bounds = sourceLayer.bounds
        let width = Int(bounds.width)
        let height = Int(bounds.height)
        
        guard width > 0 && height > 0 else { return }
        
        let bytesPerRow = width * 4
        let bufferSize = height * bytesPerRow
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: captureConfig.colorSpace,
            bitmapInfo: captureConfig.bitmapInfo.rawValue
        ) else { return }
        
        frameBuffer = context
    }
    
    private func startLayerCapture() throws {
        guard !isCapturing else { return }
        
        isCapturing = true

        // Utiliser CADisplayLink pour synchroniser avec l'affichage
        displayLink = CADisplayLink(target: self, selector: #selector(captureFrame))
        displayLink?.preferredFramesPerSecond = Int(captureConfig.frameRate)
        displayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopLayerCapture() {
        guard isCapturing else { return }
        
        displayLink?.invalidate()
        displayLink = nil
        isCapturing = false
    }
    
    @objc private func captureFrame(_ displayLink: CADisplayLink) {
        queue.async { [weak self] in
            self?.performFrameCapture()
        }
    }
    
    private func performFrameCapture() {
        guard let context = frameBuffer else { return }
        
        let startTime = CACurrentMediaTime()
        
        // Capturer le contenu du layer
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        sourceLayer.render(in: context)
        
        CATransaction.commit()
        
        // Extraire les données de l'image
        guard let data = context.makeImage()?.dataProvider?.data else { return }
        
        let frameData = Data(bytes: CFDataGetBytePtr(data), count: CFDataGetLength(data))
        
        // Traitement optionnel de compression
        let processedData = captureConfig.useCompression ? 
            compressFrameData(frameData) : frameData
        
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
        // Implémentation de compression simple
        // Dans une version complète, utiliser des algorithmes comme LZ4 ou Zlib
		guard let compressed = try? (data as NSData).compressed(using: .lz4) else {
			return data
		}

		return compressed as Data
	}
    
    private func sendFrameToSPICE(_ frameData: Data) {
        // Créer un message SPICE pour envoyer le frame
        let spiceMessage = createSPICEDisplayMessage(frameData)
        
        // TODO: Envoyer via le serveur SPICE
        // spiceServer?.sendMessage(spiceMessage)
    }
    
    private func createSPICEDisplayMessage(_ frameData: Data) -> Data {
        // Créer un message d'affichage SPICE
        let bounds = sourceLayer.bounds
        let width = UInt32(bounds.width)
        let height = UInt32(bounds.height)
        
        var message = Data()
        
        // En-tête du message d'affichage SPICE
        message.appendInteger(UInt16(SPICEProtocol.DisplayMessage.mode.rawValue))
        message.appendInteger(UInt32(frameData.count + 8)) // Taille des données + métadonnées
        message.appendInteger(width)
        message.appendInteger(height)
        
        // Données de l'image
        message.append(frameData)
        
        return message
    }
    
    deinit {
        stop()
    }
}

// MARK: - Extensions pour l'interaction avec le layer

extension SPICELayerServer {
    
    /// Met à jour la taille de capture quand le layer change
    public func updateCaptureSize() {
        setupFrameBuffer()
    }
    
    /// Force la capture d'un frame immédiatement
    public func captureNow() {
        guard isCapturing else { return }
        performFrameCapture()
    }
    
    /// Configure les propriétés du layer pour une capture optimale
    public func optimizeSourceLayer() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        // Optimisations pour la capture
        sourceLayer.shouldRasterize = true
        sourceLayer.rasterizationScale = 1.0
        sourceLayer.drawsAsynchronously = false
        
        // Améliorer les performances de rendu
        if let metalLayer = sourceLayer as? CAMetalLayer {
            metalLayer.presentsWithTransaction = false
            metalLayer.allowsNextDrawableTimeout = false
        }
        
        CATransaction.commit()
    }
}

// MARK: - Support pour différents types de layers

extension SPICELayerServer {
    
    /// Crée un serveur SPICE pour un CAMetalLayer
    public static func forMetalLayer(_ metalLayer: CAMetalLayer,
                                   spiceConfig: SPICEServer.Configuration,
                                   captureConfig: CaptureConfiguration = .performance) -> SPICELayerServer {
        let server = SPICELayerServer(sourceLayer: metalLayer, 
                                    spiceConfiguration: spiceConfig,
                                    captureConfiguration: captureConfig)
        server.optimizeSourceLayer()
        return server
    }
    
    /// Crée un serveur SPICE pour un CAOpenGLLayer  
    public static func forOpenGLLayer(_ openGLLayer: CAOpenGLLayer,
                                    spiceConfig: SPICEServer.Configuration,
                                    captureConfig: CaptureConfiguration = .balanced) -> SPICELayerServer {
        return SPICELayerServer(sourceLayer: openGLLayer,
                              spiceConfiguration: spiceConfig,
                              captureConfiguration: captureConfig)
    }
    
    /// Crée un serveur SPICE pour un layer de contenu générique
    public static func forContentLayer(_ layer: CALayer,
                                     spiceConfig: SPICEServer.Configuration,
                                     captureConfig: CaptureConfiguration = .quality) -> SPICELayerServer {
        return SPICELayerServer(sourceLayer: layer,
                              spiceConfiguration: spiceConfig,
                              captureConfiguration: captureConfig)
    }
}

// MARK: - Gestion des événements d'entrée SPICE

extension SPICELayerServer {
    
    /// Traite les événements d'entrée SPICE et les transmet au layer
    public func handleSPICEInputEvent(_ event: SPICEInputEvent) {
        switch event {
        case .keyboard(let keyEvent):
            handleKeyboardEvent(keyEvent)
        case .mouse(let mouseEvent):
            handleMouseEvent(mouseEvent)
        }
    }
    
    private func handleKeyboardEvent(_ event: SPICEKeyboardEvent) {
        // Convertir l'événement SPICE en événement système
        // Dans une implémentation complète, ceci interagirait avec le système
        print("Événement clavier SPICE: \(event.keyCode), pressé: \(event.pressed)")
    }
    
    private func handleMouseEvent(_ event: SPICEMouseEvent) {
        // Convertir les coordonnées SPICE en coordonnées du layer
        let layerBounds = sourceLayer.bounds
        let normalizedX = CGFloat(event.x) / layerBounds.width
        let normalizedY = CGFloat(event.y) / layerBounds.height
        
        print("Événement souris SPICE: (\(normalizedX), \(normalizedY)), boutons: \(event.buttonMask)")
        
        // Dans une implémentation complète, ceci déclencherait des événements sur le layer
    }
}

/// Événements d'entrée SPICE
public enum SPICEInputEvent {
    case keyboard(SPICEKeyboardEvent)
    case mouse(SPICEMouseEvent)
}

/// Événement clavier SPICE
public struct SPICEKeyboardEvent {
	let keyCode: UInt32
	let pressed: Bool
	let modifiers: UInt32
	
	var data: Data {
		var data = Data()
		// Type d'événement (clavier)
		data.append(contentsOf: [0x65, 0x00])
		// Taille du message
		data.append(contentsOf: [0x0C, 0x00, 0x00, 0x00])
		// Keycode
		withUnsafeBytes(of: keyCode.littleEndian) { data.append(contentsOf: $0) }
		// État (pressé/relâché)
		data.append(pressed ? 0x01 : 0x00)
		return data
	}
}

/// Événement souris SPICE  
public struct SPICEMouseEvent {
	let x: Int32
	let y: Int32
	let buttonMask: UInt8
	let wheelDelta: Int8
	
	var data: Data {
		var data = Data()
		// Type d'événement (souris)
		data.append(contentsOf: [0x66, 0x00])
		// Taille du message
		data.append(contentsOf: [0x0D, 0x00, 0x00, 0x00])
		// Coordonnées X, Y
		withUnsafeBytes(of: x.littleEndian) { data.append(contentsOf: $0) }
		withUnsafeBytes(of: y.littleEndian) { data.append(contentsOf: $0) }
		// Masque des boutons
		data.append(buttonMask)
		return data
	}
}
