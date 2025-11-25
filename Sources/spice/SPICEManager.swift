//
//  SPICEManager.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/11/2025.
//

import Foundation
import Virtualization

/// Gestionnaire principal pour l'intégration SPICE avec les machines virtuelles
public class SPICEManager {
	private var spiceServer: SPICEServer?
	private var virtualMachine: VZVirtualMachine?
	private let configuration: SPICEServer.Configuration
	private var isActive = false

	/// État du gestionnaire SPICE
	public enum State {
		case inactive
		case starting
		case active
		case error(Error)
	}

	private var state: State = .inactive {
		didSet {
			DispatchQueue.main.async {
				self.stateChangeHandler?(self.state)
			}
		}
	}

	/// Handler pour les changements d'état
	public var stateChangeHandler: ((State) -> Void)?

	/// URL de connexion actuelle
	public var connectionURL: URL? {
		return spiceServer?.connectionURL()
	}

	/// Mot de passe de connexion
	public var connectionPassword: String {
		return configuration.password ?? ""
	}

	public init(configuration: SPICEServer.Configuration) {
		self.configuration = configuration
	}

	/// Démarre le serveur SPICE pour une machine virtuelle
	public func start(with virtualMachine: VZVirtualMachine) {
		guard !isActive else { return }

		state = .starting
		self.virtualMachine = virtualMachine

		do {
			spiceServer = SPICEServer(configuration: configuration)
			try spiceServer?.start()
			isActive = true
			state = .active

			print("Serveur SPICE démarré sur le port \(configuration.port)")
			if let url = connectionURL {
				print("URL de connexion: \(url.absoluteString)")
			}

		} catch {
			state = .error(error)
			print("Erreur lors du démarrage du serveur SPICE: \(error)")
		}
	}

	/// Arrête le serveur SPICE
	public func stop() {
		guard isActive else { return }

		spiceServer?.stop()
		spiceServer = nil
		virtualMachine = nil
		isActive = false
		state = .inactive

		print("Serveur SPICE arrêté")
	}

	/// Redémarre le serveur SPICE
	public func restart() {
		guard let vm = virtualMachine else { return }
		stop()
		DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
			self.start(with: vm)
		}
	}

	/// Vérifie l'état de santé du serveur
	public var isHealthy: Bool {
		guard isActive,
			let server = spiceServer,
			server.running
		else { return false }

		return true
	}

	/// Génère une configuration SPICE optimisée
	public static func optimizedConfiguration(
		port: Int,
		password: String? = nil,
		quality: Quality = .balanced
	) -> SPICEServer.Configuration {
		switch quality {
		case .performance:
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

		case .quality:
			return SPICEServer.Configuration(
				port: port,
				password: password,
				compressionLevel: 9,
				imageCompressionLevel: 9,
				jpegCompressionLevel: 9,
				zlibCompressionLevel: 9,
				enableAudio: true,
				enableUSBRedirection: true,
				maxClients: 1
			)

		case .balanced:
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

	/// Qualité de l'affichage SPICE
	public enum Quality {
		case performance  // Faible latence, compression minimale
		case quality  // Haute qualité, compression élevée
		case balanced  // Équilibre entre qualité et performance
	}

	deinit {
		stop()
	}
}

// MARK: - Extensions pour l'intégration avec VZVirtualMachine

extension SPICEManager {

	/// Crée et configure une machine virtuelle avec support SPICE
	public static func createVirtualMachine(
		with configuration: VZVirtualMachineConfiguration,
		spiceConfiguration: SPICEServer.Configuration
	) throws -> (VZVirtualMachine, SPICEManager) {

		// Valider la configuration
		try configuration.validate()

		// Créer la machine virtuelle
		let virtualMachine = VZVirtualMachine(configuration: configuration)

		// Créer le gestionnaire SPICE
		let spiceManager = SPICEManager(configuration: spiceConfiguration)

		return (virtualMachine, spiceManager)
	}

	/// Configure automatiquement SPICE pour une machine virtuelle existante
	public func configureForVirtualMachine(
		_ virtualMachine: VZVirtualMachine,
		autoStart: Bool = true
	) {
		self.virtualMachine = virtualMachine

		if autoStart {
			// Attendre que la VM soit prête avant de démarrer SPICE
			DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
				self.start(with: virtualMachine)
			}
		}
	}
}

// MARK: - Utilitaires de diagnostic

extension SPICEManager {

	/// Informations de diagnostic du serveur SPICE
	public struct DiagnosticInfo {
		let isRunning: Bool
		let port: Int
		let hasPassword: Bool
		let connectionURL: String?
		let processID: Int32?
		let uptime: TimeInterval

		public var description: String {
			var info = "=== Diagnostic SPICE ===\n"
			info += "État: \(isRunning ? "Actif" : "Inactif")\n"
			info += "Port: \(port)\n"
			info += "Mot de passe configuré: \(hasPassword ? "Oui" : "Non")\n"
			if let url = connectionURL {
				info += "URL: \(url)\n"
			}
			if let pid = processID {
				info += "Process ID: \(pid)\n"
			}
			info += "Durée de fonctionnement: \(Int(uptime))s\n"
			return info
		}
	}

	/// Retourne les informations de diagnostic
	public func diagnosticInfo() -> DiagnosticInfo {
		return DiagnosticInfo(
			isRunning: isActive && isHealthy,
			port: configuration.port,
			hasPassword: configuration.password != nil,
			connectionURL: connectionURL?.absoluteString,
			processID: nil,  // TODO: Implémenter la récupération du PID
			uptime: 0  // TODO: Implémenter le calcul du temps de fonctionnement
		)
	}

	/// Teste la connectivité du serveur SPICE
	public func testConnectivity(timeout: TimeInterval = 5.0, completion: @escaping (Bool, Error?) -> Void) {
		guard isActive else {
			completion(false, SPICEError.serverNotRunning)
			return
		}

		let client = SPICEClient(
			host: "127.0.0.1",
			port: configuration.port,
			password: connectionPassword)

		var hasCompleted = false

		client.stateChangeHandler = { state in
			guard !hasCompleted else { return }

			switch state {
			case .connected:
				hasCompleted = true
				client.disconnect()
				completion(true, nil)

			case .failed(let error):
				hasCompleted = true
				completion(false, error)

			default:
				break
			}
		}

		// Timeout
		DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
			guard !hasCompleted else { return }
			hasCompleted = true
			client.disconnect()
			completion(false, SPICEError.connectionFailed)
		}

		client.connect()
	}
}
