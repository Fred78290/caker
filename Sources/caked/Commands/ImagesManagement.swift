import ArgumentParser
import Foundation
import GRPCLib
import Logging
import TextTable

struct ImagesManagement: ParsableCommand {
	static var configuration = CommandConfiguration(commandName: "image", abstract: "Manage simplestream images",
	                                                subcommands: [ListImage.self, InfoImage.self, PullImage.self])

	struct ListImage : AsyncParsableCommand {
		static var configuration: CommandConfiguration = CommandConfiguration(commandName: "list", abstract: "List images")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Option(name: .shortAndLong, help: "Output format: text or json")
		var format: Format = .text

		@Argument(help: "Remote name")
		var name: String

		mutating func validate() throws {
			Logger.setLevel(self.logLevel)
		}

		struct ShortImageInfo: Codable {
			let alias: String
			let fingerprint: String
			let pub: String
			let description: String
			let architecture: String
			let type: String
			let size: String
			let uploaded: String

			enum CodingKeys: String, CodingKey {
			case alias = "ALIAS"
			case fingerprint = "FINGERPRINT"
			case pub = "PUBLIC"
			case description = "DESCRIPTION"
			case architecture = "ARCHITECTURE"
			case type = "TYPE"
			case size = "SIZE"
			case uploaded = "UPLOADED"
			}

			init(imageInfo: ImageInfo) {
				if imageInfo.aliases.isEmpty {
					self.alias = ""
				} else if imageInfo.aliases.count == 1 {
					self.alias = imageInfo.aliases[0]
				} else {
					self.alias = imageInfo.aliases[0] + " (" + String(imageInfo.aliases.count - 1) + " more)"
				}

				let endIndex = imageInfo.fingerprint.index(imageInfo.fingerprint.startIndex, offsetBy: 12)

				self.fingerprint = String(imageInfo.fingerprint[..<endIndex])
				self.pub = imageInfo.pub ? "yes" : "no"
				self.description = imageInfo.properties["description"] ?? ""
				self.architecture = imageInfo.architecture
				self.type = imageInfo.type
				self.size = ByteCountFormatter.string(fromByteCount: Int64(imageInfo.size), countStyle: .file)
				self.uploaded = imageInfo.uploaded ?? ""
			}
		}

		mutating func run() async throws {
			let result: [ImageInfo] = try await ImageHandler.listImage(remote: self.name, asSystem: false)

			if format == .json {
				Logger.appendNewLine(format.renderList(style: Style.grid, uppercased: true, result))
			} else {
				Logger.appendNewLine(format.renderList(style: Style.grid, uppercased: true, result.map{ ShortImageInfo(imageInfo: $0)}))
			}
		}
	}

	struct InfoImage : AsyncParsableCommand {
		static var configuration: CommandConfiguration = CommandConfiguration(commandName: "info", abstract: "Show useful information about images")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Option(name: .shortAndLong, help: "Output format: text or json")
		var format: Format = .text

		@Argument(help: "Image name")
		var name: String

		mutating func validate() throws {
			Logger.setLevel(self.logLevel)
		}

		mutating func run() async throws {
			let result = try await ImageHandler.info(name: self.name, asSystem: false)

			if format == .json {
				Logger.appendNewLine(format.renderSingle(result))
			} else {
				Logger.appendNewLine(result.toText())
			}
		}
	}

	struct PullImage : AsyncParsableCommand {
		static var configuration: CommandConfiguration = CommandConfiguration(commandName: "pull", abstract: "Pull image")

		@Option(name: [.customLong("log-level")], help: "Log level")
		var logLevel: Logging.Logger.Level = .info

		@Option(name: .shortAndLong, help: "Output format: text or json")
		var format: Format = .json

		@Argument(help: "Image name")
		var name: String

		mutating func validate() throws {
			Logger.setLevel(self.logLevel)
		}

		mutating func run() async throws {
			let result = try await ImageHandler.pull(name: self.name, asSystem: false)

			Logger.appendNewLine(format.renderSingle(style: Style.psql, uppercased: true, result))
		}
	}
}