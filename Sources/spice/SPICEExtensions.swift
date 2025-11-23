//
//  SPICEExtensions.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/11/2025.
//

import Foundation
import Virtualization

// MARK: - Extensions pour l'intégration SPICE avec Virtualization.framework

extension VZVirtualMachineConfiguration {
    
    /// Configure les périphériques d'entrée pour SPICE
    public func configureSPICEInputDevices() {
        // Configuration du clavier
        let keyboardConfiguration = VZUSBKeyboardConfiguration()
        
        // Configuration de la souris
        let pointingDeviceConfiguration = VZUSBScreenCoordinatePointingDeviceConfiguration()
        
        // Ajouter les périphériques d'entrée
        var keyboards = self.keyboards
        keyboards.append(keyboardConfiguration)
        self.keyboards = keyboards
        
        var pointingDevices = self.pointingDevices  
        pointingDevices.append(pointingDeviceConfiguration)
        self.pointingDevices = pointingDevices
    }
    
    /// Configure l'affichage pour une utilisation optimale avec SPICE
    public func configureSPICEGraphics(width: Int = 1920, height: Int = 1080) {
        let graphicsConfiguration = VZVirtioGraphicsDeviceConfiguration()
        graphicsConfiguration.scanouts = [
            VZVirtioGraphicsScanoutConfiguration(widthInPixels: width, heightInPixels: height)
        ]
        
        self.graphicsDevices = [graphicsConfiguration]
    }
    
    /// Configure l'audio pour SPICE
    public func configureSPICEAudio() {
        let audioInputConfiguration = VZVirtioSoundDeviceConfiguration()
        let audioOutputConfiguration = VZVirtioSoundDeviceConfiguration()
        
        // Configuration des flux audio
        audioInputConfiguration.streams = [
            VZVirtioSoundDeviceInputStreamConfiguration()
        ]
        
        audioOutputConfiguration.streams = [
            VZVirtioSoundDeviceOutputStreamConfiguration()
        ]
        
        self.audioDevices = [audioInputConfiguration, audioOutputConfiguration]
    }
    
    /// Configure la redirection USB pour SPICE
    public func configureSPICEUSBRedirection() {
        // Configuration pour permettre la redirection des périphériques USB
        // Note: Ceci nécessiterait une implémentation spécifique selon les capacités du framework
        
        // Ajouter les contrôleurs USB nécessaires
        let usbController = VZVirtioConsoleDeviceConfiguration()
        
        var consoleDevices = self.consoleDevices
        consoleDevices.append(usbController)
        self.consoleDevices = consoleDevices
    }
    
    /// Configuration complète pour SPICE
    public func configureForSPICE(displayWidth: Int = 1920, 
                                displayHeight: Int = 1080,
                                enableAudio: Bool = true,
                                enableUSB: Bool = true) {
        
        // Configuration de base pour SPICE
        configureSPICEInputDevices()
        configureSPICEGraphics(width: displayWidth, height: displayHeight)
        
        if enableAudio {
            configureSPICEAudio()
        }
        
        if enableUSB {
            configureSPICEUSBRedirection()
        }
    }
}

// MARK: - Extensions pour VZVirtualMachine

extension VZVirtualMachine {
    
    /// Démarre la machine virtuelle avec support SPICE
    public func startWithSPICE(spiceConfiguration: SPICEServer.Configuration,
                             completion: @escaping (Result<SPICEManager, Error>) -> Void) {
        
        // Démarrer la VM d'abord
        start { result in
            switch result {
            case .success:
                // Créer et démarrer le gestionnaire SPICE
                let spiceManager = SPICEManager(configuration: spiceConfiguration)
                spiceManager.start(with: self)
                completion(.success(spiceManager))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Vérifie si la machine virtuelle est compatible avec SPICE
    public var isSPICECompatible: Bool {
        // Vérifier les capacités nécessaires pour SPICE
        guard state == .running || state == .paused else { return false }
        
        // Vérifier la présence des périphériques nécessaires
        // Cette logique dépendrait de l'implémentation spécifique
        
        return true
    }
}

// MARK: - Utilitaires pour la configuration réseau SPICE

public struct SPICENetworkUtils {
    
    /// Trouve un port disponible pour SPICE
    public static func findAvailablePort(startingFrom basePort: Int = 5900) -> Int {
        for port in basePort..<(basePort + 100) {
            if isPortAvailable(port) {
                return port
            }
        }
        return basePort // Fallback
    }
    
    /// Vérifie si un port est disponible
    public static func isPortAvailable(_ port: Int) -> Bool {
        let socketFD = socket(AF_INET, SOCK_STREAM, 0)
        guard socketFD != -1 else { return false }
        
        defer { close(socketFD) }
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(port).bigEndian
        addr.sin_addr.s_addr = INADDR_ANY
        
        let result = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(socketFD, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        return result == 0
    }
    
    /// Génère une configuration SPICE avec des ports automatiquement assignés
    public static func autoConfiguration(password: String? = nil) -> SPICEServer.Configuration {
        let port = findAvailablePort()
        return SPICEServer.Configuration(port: port, password: password)
    }
}

// MARK: - Extensions pour la surveillance et les métriques

extension SPICEManager {
    
    /// Métriques de performance SPICE
    public struct PerformanceMetrics {
        let bytesTransferred: UInt64
        let frameRate: Double
        let compressionRatio: Double
        let latency: TimeInterval
        let connectedClients: Int
        
        public var summary: String {
            return """
            === Métriques SPICE ===
            Données transférées: \(bytesTransferred / 1024 / 1024) MB
            Images/seconde: \(String(format: "%.1f", frameRate))
            Compression: \(String(format: "%.1f%%", compressionRatio * 100))
            Latence: \(String(format: "%.1f ms", latency * 1000))
            Clients connectés: \(connectedClients)
            """
        }
    }
    
    /// Collecte les métriques de performance (implémentation simulée)
    public func collectMetrics() -> PerformanceMetrics {
        // Dans une implémentation réelle, ces données seraient collectées
        // depuis le serveur SPICE via des APIs ou des logs
        return PerformanceMetrics(
            bytesTransferred: 0, // TODO: Implémenter la collecte réelle
            frameRate: 30.0,
            compressionRatio: 0.7,
            latency: 0.016,
            connectedClients: 1
        )
    }
}

// MARK: - Support pour les codecs vidéo

public enum SPICEVideoCodec: String, CaseIterable {
    case mjpeg = "mjpeg"
    case vp8 = "vp8"
    case vp9 = "vp9" 
    case h264 = "h264"
    case h265 = "h265"
    
    public var description: String {
        switch self {
        case .mjpeg: return "Motion JPEG"
        case .vp8: return "VP8"
        case .vp9: return "VP9"
        case .h264: return "H.264"
        case .h265: return "H.265/HEVC"
        }
    }
    
    /// Retourne les codecs supportés sur la plateforme actuelle
    public static var supportedCodecs: [SPICEVideoCodec] {
        // Dans une implémentation réelle, ceci serait déterminé dynamiquement
        return [.mjpeg, .vp8, .h264]
    }
}

// MARK: - Gestion des profils de qualité prédéfinis

extension SPICEServer.Configuration {
    
    /// Profile haute performance pour gaming/CAO
    public static func highPerformanceProfile(port: Int, password: String? = nil) -> SPICEServer.Configuration {
        return SPICEServer.Configuration(
            port: port,
            password: password,
            compressionLevel: 1,
            imageCompressionLevel: 1,
            jpegCompressionLevel: 1,
            zlibCompressionLevel: 1,
            enableAudio: true,
            enableUSBRedirection: true,
            maxClients: 1
        )
    }
    
    /// Profile économie de bande passante
    public static func lowBandwidthProfile(port: Int, password: String? = nil) -> SPICEServer.Configuration {
        return SPICEServer.Configuration(
            port: port,
            password: password,
            compressionLevel: 9,
            imageCompressionLevel: 9,
            jpegCompressionLevel: 9,
            zlibCompressionLevel: 9,
            enableAudio: false,
            enableUSBRedirection: false,
            maxClients: 1
        )
    }
    
    /// Profile pour utilisation bureautique standard
    public static func officeProfile(port: Int, password: String? = nil) -> SPICEServer.Configuration {
        return SPICEServer.Configuration(
            port: port,
            password: password,
            compressionLevel: 6,
            imageCompressionLevel: 7,
            jpegCompressionLevel: 8,
            zlibCompressionLevel: 6,
            enableAudio: true,
            enableUSBRedirection: true,
            maxClients: 1
        )
    }
}