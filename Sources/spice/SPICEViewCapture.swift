//
//  SPICEViewCapture.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/11/2025.
//

import Foundation
import AppKit
import CoreGraphics
import QuartzCore

/// Gestionnaire de capture avancé pour NSView avec optimisations de performance
public class SPICEViewCapture {
    
    private let sourceView: NSView
    private let renderer: SPICEViewRenderer
    private var captureTimer: Timer?
    private let captureQueue: DispatchQueue
    private let processingQueue: DispatchQueue
    
    /// Configuration de capture avancée
    public struct CaptureSettings {
        let frameRate: Double
        let adaptiveFrameRate: Bool
        let enableMotionDetection: Bool
        let enableRegionOfInterest: Bool
        let regionOfInterest: CGRect?
        let enableDifferentialCapture: Bool
        let compressionQuality: Float
        let enablePredictiveCapture: Bool
        
        public init(frameRate: Double = 30.0,
                   adaptiveFrameRate: Bool = true,
                   enableMotionDetection: Bool = true,
                   enableRegionOfInterest: Bool = false,
                   regionOfInterest: CGRect? = nil,
                   enableDifferentialCapture: Bool = true,
                   compressionQuality: Float = 0.8,
                   enablePredictiveCapture: Bool = false) {
            self.frameRate = frameRate
            self.adaptiveFrameRate = adaptiveFrameRate
            self.enableMotionDetection = enableMotionDetection
            self.enableRegionOfInterest = enableRegionOfInterest
            self.regionOfInterest = regionOfInterest
            self.enableDifferentialCapture = enableDifferentialCapture
            self.compressionQuality = compressionQuality
            self.enablePredictiveCapture = enablePredictiveCapture
        }
        
        /// Configuration optimisée pour les jeux
        public static let gaming = CaptureSettings(
            frameRate: 60.0,
            adaptiveFrameRate: false,
            enableMotionDetection: false,
            enableDifferentialCapture: false,
            compressionQuality: 0.6
        )
        
        /// Configuration équilibrée pour usage général
        public static let standard = CaptureSettings(
            frameRate: 30.0,
            adaptiveFrameRate: true,
            enableMotionDetection: true,
            enableDifferentialCapture: true,
            compressionQuality: 0.8
        )
        
        /// Configuration haute qualité pour design
        public static let highQuality = CaptureSettings(
            frameRate: 30.0,
            adaptiveFrameRate: true,
            enableMotionDetection: true,
            enableDifferentialCapture: true,
            compressionQuality: 1.0
        )
    }
    
    private var settings: CaptureSettings
    private var isCapturing = false
    private var lastCapturedFrame: Data?
    private var motionThreshold: Double = 0.05
    
    /// Statistiques de capture
    public struct CaptureStats {
        let totalFramesCaptured: UInt64
        let averageCaptureTime: TimeInterval
        let currentFPS: Double
        let compressionRatio: Double
        let motionDetected: Bool
        let lastFrameSize: Int
        let adaptiveFrameRateAdjustments: Int
        
        public var description: String {
            return """
            === Statistiques Capture SPICE ===
            Frames capturées: \(totalFramesCaptured)
            FPS actuel: \(String(format: "%.1f", currentFPS))
            Temps capture moyen: \(String(format: "%.2f ms", averageCaptureTime * 1000))
            Ratio compression: \(String(format: "%.1f%%", compressionRatio * 100))
            Mouvement détecté: \(motionDetected ? "Oui" : "Non")
            Taille dernière frame: \(lastFrameSize) bytes
            Ajustements FPS adaptatif: \(adaptiveFrameRateAdjustments)
            """
        }
    }
    
    private var captureStats = CaptureStatsTracker()
    
    /// Gestionnaire pour les frames capturées
    public var frameHandler: ((Data, CaptureMetadata) -> Void)?
    
    /// Métadonnées d'une frame capturée
    public struct CaptureMetadata {
        let timestamp: TimeInterval
        let frameNumber: UInt64
        let viewBounds: CGRect
        let scaleFactor: CGFloat
        let hasMotion: Bool
        let isDifferentialFrame: Bool
        let compressionRatio: Double
    }
    
    public init(view: NSView, settings: CaptureSettings = .standard) {
        self.sourceView = view
        self.settings = settings
        self.renderer = SPICEViewRenderer.balanced()
        
        self.captureQueue = DispatchQueue(label: "com.caker.spice.capture", qos: .userInteractive)
        self.processingQueue = DispatchQueue(label: "com.caker.spice.processing", qos: .default)
        
        setupCaptureTimer()
        setupViewObservation()
    }
    
    private func setupCaptureTimer() {
        captureTimer = Timer.scheduledTimer(withTimeInterval: 1.0/settings.frameRate, repeats: true) { [weak self] _ in
            self?.captureFrame()
        }
        captureTimer?.fireDate = Date.distantFuture // Paused by default
    }
    
    private func setupViewObservation() {
        // Observer les changements de frame de la view
        NotificationCenter.default.addObserver(
            forName: NSView.frameDidChangeNotification,
            object: sourceView,
            queue: .main
        ) { [weak self] _ in
            self?.handleViewFrameChange()
        }
        
        // Observer les changements de bounds
        NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: sourceView,
            queue: .main
        ) { [weak self] _ in
            self?.handleViewBoundsChange()
        }
    }
    
    // MARK: - Contrôle de capture
    
    /// Démarre la capture
    public func start() {
        guard !isCapturing else { return }
        
        isCapturing = true
        captureStats.start()
        captureTimer?.fireDate = Date()
        
        print("📹 Démarrage capture SPICE à \(settings.frameRate) FPS")
    }
    
    /// Arrête la capture
    public func stop() {
        guard isCapturing else { return }
        
        isCapturing = false
        captureTimer?.fireDate = Date.distantFuture
        captureStats.stop()
        
        print("⏹️ Arrêt capture SPICE")
    }
    
    /// Met en pause la capture
    public func pause() {
        captureTimer?.fireDate = Date.distantFuture
        print("⏸️ Pause capture SPICE")
    }
    
    /// Reprend la capture
    public func resume() {
        guard isCapturing else { return }
        captureTimer?.fireDate = Date()
        print("▶️ Reprise capture SPICE")
    }
    
    // MARK: - Capture de frame
    
    private func captureFrame() {
        guard isCapturing else { return }
        
        let startTime = CACurrentMediaTime()
        
        captureQueue.async { [weak self] in
            self?.performCapture(startTime: startTime)
        }
    }
    
    private func performCapture(startTime: TimeInterval) {
        guard let frameData = renderer.renderView(sourceView) else {
            print("⚠️ Échec capture frame")
            return
        }
        
        let captureTime = CACurrentMediaTime() - startTime
        captureStats.recordCapture(time: captureTime, dataSize: frameData.count)
        
        processingQueue.async { [weak self] in
            self?.processFrame(frameData, captureTime: captureTime)
        }
    }
    
    private func processFrame(_ frameData: Data, captureTime: TimeInterval) {
        let frameNumber = captureStats.frameCount
        let viewBounds = sourceView.bounds
        let scaleFactor = sourceView.window?.backingScaleFactor ?? 1.0
        
        // Détection de mouvement si activée
        var hasMotion = false
        if settings.enableMotionDetection {
            hasMotion = detectMotion(in: frameData)
        }
        
        // Capture différentielle si activée
        var isDifferentialFrame = false
        var processedData = frameData
        
        if settings.enableDifferentialCapture, let lastFrame = lastCapturedFrame {
            if let diffData = createDifferentialFrame(current: frameData, previous: lastFrame) {
                processedData = diffData
                isDifferentialFrame = true
            }
        }
        
        // Optimisation FPS adaptatif
        if settings.adaptiveFrameRate {
            adjustFrameRateIfNeeded(captureTime: captureTime, hasMotion: hasMotion)
        }
        
        // Stockage pour comparaison future
        lastCapturedFrame = frameData
        
        // Création des métadonnées
        let metadata = CaptureMetadata(
            timestamp: CACurrentMediaTime(),
            frameNumber: frameNumber,
            viewBounds: viewBounds,
            scaleFactor: scaleFactor,
            hasMotion: hasMotion,
            isDifferentialFrame: isDifferentialFrame,
            compressionRatio: Double(processedData.count) / Double(frameData.count)
        )
        
        // Appel du handler sur la queue principale
        DispatchQueue.main.async { [weak self] in
            self?.frameHandler?(processedData, metadata)
        }
    }
    
    // MARK: - Détection de mouvement
    
    private func detectMotion(in frameData: Data) -> Bool {
        guard let lastFrame = lastCapturedFrame else { return true }
        guard frameData.count == lastFrame.count else { return true }
        
        // Comparaison simplifiée des données
        var differenceCount = 0
        let threshold = Int(Double(frameData.count) * motionThreshold)
        
        for i in 0..<min(frameData.count, lastFrame.count) {
            if frameData[i] != lastFrame[i] {
                differenceCount += 1
                if differenceCount > threshold {
                    return true
                }
            }
        }
        
        return false
    }
    
    // MARK: - Capture différentielle
    
    private func createDifferentialFrame(current: Data, previous: Data) -> Data? {
        guard current.count == previous.count else { return nil }
        
        var diffData = Data()
        var hasChanges = false
        
        // Algorithme simple de différence
        for i in 0..<current.count {
            let diff = Int(current[i]) - Int(previous[i])
            if abs(diff) > 10 { // Seuil de différence
                diffData.append(current[i])
                hasChanges = true
            } else {
                diffData.append(0) // Pas de changement
            }
        }
        
        return hasChanges ? diffData : nil
    }
    
    // MARK: - FPS adaptatif
    
    private func adjustFrameRateIfNeeded(captureTime: TimeInterval, hasMotion: Bool) {
        let targetFrameTime = 1.0 / settings.frameRate
        
        if captureTime > targetFrameTime * 1.5 {
            // Capture trop lente, réduire le framerate
            reduceFrameRate()
        } else if captureTime < targetFrameTime * 0.5 && hasMotion {
            // Capture rapide avec mouvement, augmenter le framerate
            increaseFrameRate()
        }
    }
    
    private func reduceFrameRate() {
        let newFrameRate = max(10.0, settings.frameRate * 0.8)
        updateFrameRate(newFrameRate)
    }
    
    private func increaseFrameRate() {
        let maxFrameRate = settings.enablePredictiveCapture ? 120.0 : 60.0
        let newFrameRate = min(maxFrameRate, settings.frameRate * 1.2)
        updateFrameRate(newFrameRate)
    }
    
    private func updateFrameRate(_ newFrameRate: Double) {
        guard newFrameRate != settings.frameRate else { return }
        
        settings = CaptureSettings(
            frameRate: newFrameRate,
            adaptiveFrameRate: settings.adaptiveFrameRate,
            enableMotionDetection: settings.enableMotionDetection,
            enableRegionOfInterest: settings.enableRegionOfInterest,
            regionOfInterest: settings.regionOfInterest,
            enableDifferentialCapture: settings.enableDifferentialCapture,
            compressionQuality: settings.compressionQuality,
            enablePredictiveCapture: settings.enablePredictiveCapture
        )
        
        captureStats.frameRateAdjusted()
        
        // Recréer le timer avec la nouvelle fréquence
        captureTimer?.invalidate()
        setupCaptureTimer()
        
        if isCapturing {
            captureTimer?.fireDate = Date()
        }
        
        print("🎛️ FPS ajusté à \(String(format: "%.1f", newFrameRate))")
    }
    
    // MARK: - Gestion des événements de la view
    
    private func handleViewFrameChange() {
        print("📏 Changement de taille de la view: \(sourceView.bounds.size)")
        // Forcer une capture complète après un changement de taille
        if isCapturing {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.captureFrame()
            }
        }
    }
    
    private func handleViewBoundsChange() {
        print("🔄 Changement de bounds de la view: \(sourceView.bounds)")
    }
    
    // MARK: - API publique
    
    /// Retourne les statistiques de capture actuelles
    public func statistics() -> CaptureStats {
        return CaptureStats(
            totalFramesCaptured: captureStats.frameCount,
            averageCaptureTime: captureStats.averageCaptureTime,
            currentFPS: captureStats.currentFPS,
            compressionRatio: captureStats.averageCompressionRatio,
            motionDetected: captureStats.lastMotionDetected,
            lastFrameSize: captureStats.lastFrameSize,
            adaptiveFrameRateAdjustments: captureStats.frameRateAdjustments
        )
    }
    
    /// Met à jour les paramètres de capture
    public func updateSettings(_ newSettings: CaptureSettings) {
        let oldFrameRate = settings.frameRate
        self.settings = newSettings
        
        if oldFrameRate != newSettings.frameRate {
            updateFrameRate(newSettings.frameRate)
        }
        
        print("⚙️ Paramètres de capture mis à jour")
    }
    
    /// Force une capture immédiate
    public func captureNow() {
        captureFrame()
    }
    
    /// Vide le cache des frames précédentes
    public func clearCache() {
        lastCapturedFrame = nil
        print("🗑️ Cache des frames vidé")
    }
    
    deinit {
        stop()
        captureTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Tracking des statistiques

private class CaptureStatsTracker {
    private var captureTimes: [TimeInterval] = []
    private var frameSizes: [Int] = []
    private var startTime: TimeInterval = 0
    
    private(set) var frameCount: UInt64 = 0
    private(set) var frameRateAdjustments: Int = 0
    private(set) var lastMotionDetected: Bool = false
    
    var averageCaptureTime: TimeInterval {
        guard !captureTimes.isEmpty else { return 0 }
        return captureTimes.reduce(0, +) / Double(captureTimes.count)
    }
    
    var currentFPS: Double {
        let elapsed = CACurrentMediaTime() - startTime
        guard elapsed > 0 else { return 0 }
        return Double(frameCount) / elapsed
    }
    
    var averageCompressionRatio: Double {
        // Simulation du ratio de compression
        return 0.3
    }
    
    var lastFrameSize: Int {
        return frameSizes.last ?? 0
    }
    
    func start() {
        startTime = CACurrentMediaTime()
        frameCount = 0
        frameRateAdjustments = 0
    }
    
    func stop() {
        captureTimes.removeAll()
        frameSizes.removeAll()
    }
    
    func recordCapture(time: TimeInterval, dataSize: Int) {
        frameCount += 1
        
        captureTimes.append(time)
        if captureTimes.count > 100 {
            captureTimes.removeFirst()
        }
        
        frameSizes.append(dataSize)
        if frameSizes.count > 10 {
            frameSizes.removeFirst()
        }
    }
    
    func frameRateAdjusted() {
        frameRateAdjustments += 1
    }
}