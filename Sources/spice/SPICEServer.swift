//
//  SPICEServer.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/11/2025.
//

import Foundation
import Virtualization

/// Serveur SPICE RedHat pour l'accès distant aux machines virtuelles
public class SPICEServer {
    private var spiceProcess: Process?
    private let port: Int
    private let password: String
    private let socketPath: String
    private var isRunning = false
    private let queue: DispatchQueue
    
    /// Configuration du serveur SPICE
    public struct Configuration {
        public let port: Int
        public let password: String?
        public let compressionLevel: Int
        public let imageCompressionLevel: Int
        public let jpegCompressionLevel: Int
        public let zlibCompressionLevel: Int
        public let enableAudio: Bool
        public let enableUSBRedirection: Bool
        public let maxClients: Int
        
        public init(port: Int,
                   password: String? = nil,
                   compressionLevel: Int = 6,
                   imageCompressionLevel: Int = 7,
                   jpegCompressionLevel: Int = 8,
                   zlibCompressionLevel: Int = 6,
                   enableAudio: Bool = true,
                   enableUSBRedirection: Bool = true,
                   maxClients: Int = 1) {
            self.port = port
            self.password = password
            self.compressionLevel = compressionLevel
            self.imageCompressionLevel = imageCompressionLevel
            self.jpegCompressionLevel = jpegCompressionLevel
            self.zlibCompressionLevel = zlibCompressionLevel
            self.enableAudio = enableAudio
            self.enableUSBRedirection = enableUSBRedirection
            self.maxClients = maxClients
        }
    }
    
    public init(configuration: Configuration) {
        self.port = configuration.port
        self.password = configuration.password ?? UUID().uuidString.prefix(8).lowercased()
        self.socketPath = "/tmp/spice-\(UUID().uuidString).sock"
        self.queue = DispatchQueue(label: "com.caker.spice", qos: .userInitiated)
    }
    
    /// Démarre le serveur SPICE
    public func start() throws {
        guard !isRunning else {
            throw SPICEError.serverAlreadyRunning
        }
        
        try startSpiceProcess()
        isRunning = true
    }
    
    /// Arrête le serveur SPICE
    public func stop() {
        guard isRunning else { return }
        
        spiceProcess?.terminate()
        spiceProcess?.waitUntilExit()
        spiceProcess = nil
        isRunning = false
        
        // Nettoyer le socket
        try? FileManager.default.removeItem(atPath: socketPath)
    }
    
    /// Retourne l'URL de connexion SPICE
    public func connectionURL() -> URL? {
        guard isRunning else { return nil }
        return URL(string: "spice://:\(password)@127.0.0.1:\(port)")
    }
    
    /// Vérifie si le serveur est en cours d'exécution
    public var running: Bool {
        return isRunning && (spiceProcess?.isRunning ?? false)
    }
    
    private func startSpiceProcess() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/spice-server")
        
        var arguments = [
            "--port=\(port)",
            "--password=\(password)",
            "--socket=\(socketPath)",
            "--disable-ticketing=false",
            "--compression=auto_glz",
            "--streaming-video=filter"
        ]
        
        // Ajouter les arguments de compression
        arguments.append("--image-compression=auto_glz")
        arguments.append("--jpeg-wan-compression=auto")
        arguments.append("--zlib-glz-wan-compression=auto")
        
        process.arguments = arguments
        process.qualityOfService = .userInitiated
        
        // Configuration des pipes pour la sortie
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Handler pour la terminaison du processus
        process.terminationHandler = { [weak self] process in
            self?.queue.async {
                if process.terminationStatus != 0 {
                    print("SPICE server terminated with status: \(process.terminationStatus)")
                }
                self?.isRunning = false
            }
        }
        
        try process.run()
        self.spiceProcess = process
    }
    
    deinit {
        stop()
    }
}

/// Erreurs du serveur SPICE
public enum SPICEError: Error, LocalizedError {
    case serverAlreadyRunning
    case serverNotRunning
    case failedToStart(String)
    case connectionFailed
    case invalidConfiguration
    
    public var errorDescription: String? {
        switch self {
        case .serverAlreadyRunning:
            return "Le serveur SPICE est déjà en cours d'exécution"
        case .serverNotRunning:
            return "Le serveur SPICE n'est pas en cours d'exécution"
        case .failedToStart(let reason):
            return "Échec du démarrage du serveur SPICE: \(reason)"
        case .connectionFailed:
            return "Échec de la connexion au serveur SPICE"
        case .invalidConfiguration:
            return "Configuration du serveur SPICE invalide"
        }
    }
}