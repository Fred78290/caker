//
//  SPICEProtocol.swift
//  Caker
//
//  Created by Frederic BOLTZ on 23/11/2025.
//

import Foundation

/// Constantes et structures du protocole SPICE RedHat
public struct SPICEProtocol {
    
    // MARK: - Constantes du protocole
    
    /// Version du protocole SPICE
    public static let protocolVersion: UInt32 = 2
    
    /// Magic number pour l'identification SPICE
    public static let magicNumber: [UInt8] = [0x52, 0x45, 0x44, 0x51] // "REDQ"
    
    /// Taille maximale des paquets
    public static let maxPacketSize: Int = 1024 * 1024 // 1MB
    
    // MARK: - Types de messages
    
    public enum MessageType: UInt16 {
        case link = 1
        case data = 2
        case ping = 3
        case setAck = 4
        case migrate = 5
        case migrateData = 6
        case migrateEnd = 7
        case inval = 8
        case waitForChannels = 9
        case disconnecting = 10
        case notify = 11
    }
    
    // MARK: - Types de canaux
    
    public enum ChannelType: UInt8 {
        case main = 1
        case display = 2
        case inputs = 3
        case cursor = 4
        case playback = 5
        case record = 6
        case tunnel = 7
        case smartcard = 8
        case usbredir = 9
        case port = 10
    }
    
    // MARK: - Messages d'entrée
    
    public enum InputsMessage: UInt16 {
        case keyDown = 101
        case keyUp = 102
        case keyModifiers = 103
        case mouseMotion = 111
        case mousePosition = 112
        case mousePress = 113
        case mouseRelease = 114
    }
    
    // MARK: - Messages d'affichage
    
    public enum DisplayMessage: UInt16 {
        case mode = 201
        case mark = 202
        case reset = 203
        case copyBits = 204
        case inval = 205
        case invalAll = 206
        case invalPalette = 207
        case invalList = 208
        case streamCreate = 209
        case streamData = 210
        case streamClip = 211
        case streamDestroy = 212
        case streamActivateReport = 213
    }
    
    // MARK: - Structures de messages
    
    /// En-tête de message SPICE
    public struct MessageHeader {
        let type: MessageType
        let size: UInt32
        
        public init(type: MessageType, size: UInt32) {
            self.type = type
            self.size = size
        }
        
        public var data: Data {
            var data = Data()
            withUnsafeBytes(of: type.rawValue.littleEndian) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: size.littleEndian) { data.append(contentsOf: $0) }
            return data
        }
        
        public static func from(data: Data) -> MessageHeader? {
            guard data.count >= 6 else { return nil }
            
            let typeValue = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt16.self) }
            let size = data.withUnsafeBytes { $0.load(fromByteOffset: 2, as: UInt32.self) }
            
            guard let type = MessageType(rawValue: UInt16(littleEndian: typeValue)) else { return nil }
            
            return MessageHeader(type: type, size: UInt32(littleEndian: size))
        }
    }
    
    /// Message de liaison SPICE
    public struct LinkMessage {
        let magic: [UInt8]
        let majorVersion: UInt32
        let minorVersion: UInt32
        let size: UInt32
        
        public init() {
            self.magic = SPICEProtocol.magicNumber
            self.majorVersion = SPICEProtocol.protocolVersion
            self.minorVersion = 0
            self.size = 16 // Taille de base du message de liaison
        }
        
        public var data: Data {
            var data = Data()
            data.append(contentsOf: magic)
            withUnsafeBytes(of: majorVersion.littleEndian) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: minorVersion.littleEndian) { data.append(contentsOf: $0) }
            withUnsafeBytes(of: size.littleEndian) { data.append(contentsOf: $0) }
            return data
        }
    }
    
    /// Message d'authentification
    public struct AuthMessage {
        let method: AuthMethod
        let data: Data
        
        public enum AuthMethod: UInt32 {
            case none = 0
            case spice = 1
            case sasl = 2
        }
        
        public init(method: AuthMethod, data: Data = Data()) {
            self.method = method
            self.data = data
        }
        
        public var messageData: Data {
            var result = Data()
            withUnsafeBytes(of: method.rawValue.littleEndian) { result.append(contentsOf: $0) }
            result.append(data)
            return result
        }
    }
    
    /// Informations sur le canal
    public struct ChannelInfo {
        let type: ChannelType
        let id: UInt8
        let flags: UInt8
        
        public init(type: ChannelType, id: UInt8 = 0, flags: UInt8 = 0) {
            self.type = type
            self.id = id
            self.flags = flags
        }
        
        public var data: Data {
            var data = Data()
            data.append(type.rawValue)
            data.append(id)
            data.append(flags)
            return data
        }
    }
}

// MARK: - Extensions utilitaires

extension Data {
    /// Lit un entier de taille spécifiée à partir de l'offset donné
    func readInteger<T: FixedWidthInteger>(at offset: Int, as type: T.Type) -> T? {
        guard offset + MemoryLayout<T>.size <= count else { return nil }
        return withUnsafeBytes { $0.load(fromByteOffset: offset, as: T.self) }
    }
    
    /// Ajoute un entier au Data en little-endian
    mutating func appendInteger<T: FixedWidthInteger>(_ value: T) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }
}

// MARK: - Gestionnaire de protocole

/// Gestionnaire pour le parsing et la création de messages SPICE
public class SPICEProtocolHandler {
    private var buffer = Data()
    
    /// Ajoute des données reçues au buffer et traite les messages complets
    public func processReceivedData(_ data: Data) -> [SPICEMessage] {
        buffer.append(data)
        var messages: [SPICEMessage] = []
        
        while buffer.count >= 6 { // Taille minimale d'un en-tête
            guard let header = SPICEProtocol.MessageHeader.from(data: buffer) else { break }
            
            let totalSize = 6 + Int(header.size)
            guard buffer.count >= totalSize else { break }
            
            let messageData = buffer.subdata(in: 6..<totalSize)
            let message = SPICEMessage(header: header, payload: messageData)
            messages.append(message)
            
            buffer.removeFirst(totalSize)
        }
        
        return messages
    }
    
    /// Crée un message SPICE avec l'en-tête approprié
    public func createMessage(type: SPICEProtocol.MessageType, payload: Data) -> Data {
        let header = SPICEProtocol.MessageHeader(type: type, size: UInt32(payload.count))
        var message = header.data
        message.append(payload)
        return message
    }
}

/// Représente un message SPICE complet
public struct SPICEMessage {
    let header: SPICEProtocol.MessageHeader
    let payload: Data
    
    public init(header: SPICEProtocol.MessageHeader, payload: Data) {
        self.header = header
        self.payload = payload
    }
}
