//
//  SPICEClient.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/11/2025.
//

import Compression
import Foundation
import Network

/// Client SPICE pour la connexion aux serveurs SPICE
public class SPICEClient {
	private var connection: NWConnection?
	private let endpoint: NWEndpoint
	private let password: String
	private var isConnected = false
	private let queue: DispatchQueue

	/// État de la connexion
	public enum ConnectionState: Equatable {
		case disconnected
		case connecting
		case connected
		case failed(Error)

		public static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
			switch (lhs, rhs) {
			case (.disconnected, .disconnected),
				(.connecting, .connecting),
				(.connected, .connected):
				return true
			case (.failed, .failed):
				// Consider all failures equal for state comparison
				return true
			default:
				return false
			}
		}
	}

	private var connectionState: ConnectionState = .disconnected {
		didSet {
			DispatchQueue.main.async {
				self.stateChangeHandler?(self.connectionState)
			}
		}
	}

	/// Handler pour les changements d'état de connexion
	public var stateChangeHandler: ((ConnectionState) -> Void)?

	/// Handler pour la réception de données
	public var dataHandler: ((Data) -> Void)?

	public init(host: String, port: Int, password: String) {
		self.endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: UInt16(port)))
		self.password = password
		self.queue = DispatchQueue(label: "com.caker.spice.client", qos: .userInteractive)
	}

	/// Établit la connexion au serveur SPICE
	public func connect() {
		guard connectionState == .disconnected else { return }

		connectionState = .connecting

		let parameters = NWParameters.tcp
		connection = NWConnection(to: endpoint, using: parameters)

		connection?.stateUpdateHandler = { [weak self] state in
			self?.handleConnectionStateChange(state)
		}

		connection?.start(queue: queue)
	}

	/// Ferme la connexion
	public func disconnect() {
		connection?.cancel()
		connection = nil
		isConnected = false
		connectionState = .disconnected
	}

	/// Envoie des données au serveur SPICE
	public func send(data: Data) {
		guard isConnected, let connection = connection else { return }

		connection.send(
			content: data,
			completion: .contentProcessed { error in
				if let error = error {
					print("Erreur envoi SPICE: \(error)")
				}
			})
	}

	/// Envoie un événement clavier
	public func sendKeyEvent(keycode: UInt32, pressed: Bool, modifiers: UInt32) {
		let event = ClientKeyboardEvent(keyCode: keycode, pressed: pressed, modifiers: modifiers)
		send(data: event.data)
	}

	/// Envoie un événement souris
	public func sendMouseEvent(x: Int32, y: Int32, buttonMask: UInt8, wheelDelta: Int8) {
		let event = ClientMouseEvent(x: x, y: y, buttonMask: buttonMask, wheelDelta: wheelDelta)
		send(data: event.data)
	}

	private func handleConnectionStateChange(_ state: NWConnection.State) {
		switch state {
		case .ready:
			isConnected = true
			connectionState = .connected
			startReceiving()
			performSpiceHandshake()

		case .failed(let error):
			isConnected = false
			connectionState = .failed(error)

		case .cancelled:
			isConnected = false
			connectionState = .disconnected

		default:
			break
		}
	}

	private func startReceiving() {
		connection?.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
			if let data = data, !data.isEmpty {
				self?.dataHandler?(data)
			}

			if let error = error {
				print("Erreur réception SPICE: \(error)")
				return
			}

			if !isComplete {
				self?.startReceiving()
			}
		}
	}

	private func performSpiceHandshake() {
		// Implémentation simplifiée du handshake SPICE
		let handshake = SPICEHandshake(password: password)
		send(data: handshake.data)
	}

	deinit {
		disconnect()
	}
}

// MARK: - Structures des messages SPICE

/// Événement clavier pour le client SPICE
private struct ClientKeyboardEvent {
	let keyCode: UInt32
	let pressed: Bool
	let modifiers: UInt32

	var data: Data {
		var data = Data()
		data.appendInteger(keyCode)
		data.append(pressed ? 1 : 0)
		data.appendInteger(modifiers)
		return data
	}
}

/// Événement souris pour le client SPICE
private struct ClientMouseEvent {
	let x: Int32
	let y: Int32
	let buttonMask: UInt8
	let wheelDelta: Int8

	var data: Data {
		var data = Data()
		data.appendInteger(x)
		data.appendInteger(y)
		data.append(buttonMask)
		data.append(UInt8(bitPattern: wheelDelta))
		return data
	}
}

/// Message d'authentification SPICE
private struct SPICEHandshake {
	let password: String

	var data: Data {
		var data = Data()
		// Magic number SPICE
		data.append(contentsOf: [0x52, 0x45, 0x44, 0x51])  // "REDQ"
		// Version majeure/mineure
		data.append(contentsOf: [0x02, 0x00, 0x00, 0x00])
		data.append(contentsOf: [0x02, 0x00, 0x00, 0x00])
		// Ticket (password)
		let passwordData = password.data(using: .utf8) ?? Data()
		data.append(passwordData)
		return data
	}
}
