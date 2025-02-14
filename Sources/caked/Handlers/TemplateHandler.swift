import ArgumentParser
import Foundation
import GRPCLib
import NIO
import TextTable

struct TemplateHandler: CakedCommand {
	let request: Caked_TemplateRequest

	struct TemplateEntry: Codable {
		let name: String
		let fqn: String
		let diskSize: String
		let totalSize: String
	}

	struct CreateTemplateReply: Codable {
		let name: String
		let created: Bool
	}

	struct DeleteTemplateReply: Codable {
		let name: String
		let deleted: Bool
	}

	static func createTemplate(sourceName: String, templateName: String, asSystem: Bool) throws -> CreateTemplateReply {
		let storage = StorageLocation(asSystem: asSystem, template: true)
		let location: VMLocation = try StorageLocation(asSystem: asSystem).find(sourceName)
		let lock: FileLock = try FileLock(lockURL: storage.rootURL)

		try lock.lock()

		defer {
			try? lock.unlock()
		}

		if storage.exists(templateName) {
			throw ServiceError("template \(templateName) already exists")
		}

		if location.status != .running {
			let templateLocation = storage.location(templateName)

			try FileManager.default.createDirectory(at: templateLocation.rootURL, withIntermediateDirectories: true)
			try FileManager.default.copyItem(at: location.diskURL, to: templateLocation.diskURL)

			return .init(name: templateName, created: true)
		}

		return .init(name: templateName, created: false)
	}

	static func deleteTemplate(templateName: String, asSystem: Bool) throws -> DeleteTemplateReply {
		let storage = StorageLocation(asSystem: asSystem, template: true)
		let lock = try FileLock(lockURL: storage.rootURL)
		var vmLocation: VMLocation? = nil

		try lock.lock()

		defer {
			try? lock.unlock()
		}

		if let location: VMLocation = try? storage.find(templateName) {
			vmLocation = location
		} else if let u = URL(string: templateName), u.scheme == "template" {
			vmLocation = try? StorageLocation(asSystem: false).find(u.host()!)
		}

		if let location = vmLocation, location.status != .running {
			if location.status != .running {
				try? FileManager.default.removeItem(at: location.rootURL)
				return .init(name: location.name, deleted: true)
			} else {
				return .init(name: location.name, deleted: false)
			}
		}


		return .init(name: templateName, deleted: false)
	}

	static func listTemplate(asSystem: Bool) throws -> [TemplateEntry] {
		let storage = StorageLocation(asSystem: asSystem, template: true)

		return try storage.list().map { (key: String, value: VMLocation) in
			return TemplateEntry(
				name: key,
				fqn: "template://\(key)",
				diskSize: try ByteCountFormatter.string(fromByteCount: Int64(value.diskSize()), countStyle: .file),
				totalSize: try ByteCountFormatter.string(fromByteCount: Int64(value.allocatedSize()), countStyle: .file)
			)
		}
	}

	func run(on: EventLoop, asSystem: Bool) throws -> EventLoopFuture<String> {
		let format: Format = request.format == .text ? Format.text : Format.json

		return on.submit {
			switch request.command {
			case .add:
				return format.renderSingle(style: Style.grid, uppercased: true, try Self.createTemplate(sourceName: request.create.sourceName, templateName: request.create.templateName, asSystem: runAsSystem))
			case .delete:
				return format.renderSingle(style: Style.grid, uppercased: true, try Self.deleteTemplate(templateName: request.delete, asSystem: runAsSystem))
			case .list:
				return format.renderList(style: Style.grid, uppercased: true, try Self.listTemplate(asSystem: runAsSystem))
			default:
				throw ServiceError("Unknown command \(request.command)")
			}
		}
	}
}