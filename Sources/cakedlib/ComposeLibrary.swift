//
//  ComposeLibrary.swift
//  CakedLib
//
//  A library of ready-to-use `compose.yml` templates for what developers set up most often (a
//  database, a web stack, a Docker host, ...). It follows `VMImageCatalog`'s lifecycle:
//
//  - the library ships inside the binary (`ComposeLibrary.json`, built from `compose-library/*.yml`
//    by `Scripts/build-compose-library.py`), so it works offline and before a first sync;
//  - `refreshFromGitHub()` (`cakectl compose library sync`, the library window of Caker.app)
//    downloads the copy published on the `main` branch of the repository into
//    `<CAKE_HOME>/ComposeLibrary.json`;
//  - a valid copy in `<CAKE_HOME>` wins over the bundled one, and is re-read when it changes.
//
//  Until the templates are merged into `main`, the download answers 404: `refreshFromGitHub()` then
//  fails with an explicit message and the bundled copy keeps being used.
//

import Foundation
import GRPCLib
import Synchronization
import Yams

public struct ComposeLibraryTemplate: Codable, Sendable, Hashable, Identifiable {
	/// Lowercase letters, digits and hyphens: the id is typed on the command line (`library clone <id>`).
	public let id: String
	public let name: String
	public let category: String
	public let summary: String
	public let tags: [String]
	/// The complete `compose.yml` text, comments included.
	public let compose: String

	public init(id: String, name: String, category: String, summary: String, tags: [String] = [], compose: String) {
		self.id = id
		self.name = name
		self.category = category
		self.summary = summary
		self.tags = tags
		self.compose = compose
	}

	/// The parsed definition, as `compose up` would read it (minus the `ssh_authorized_key` file lookup).
	public func composeFile() throws -> ComposeFile {
		try YAMLDecoder().decode(ComposeFile.self, from: self.compose)
	}

	/// The project name declared by the template (`name:`).
	public var projectName: String {
		(try? self.composeFile().name) ?? self.id
	}

	/// The services the template starts, in alphabetical order.
	public var serviceNames: [String] {
		((try? self.composeFile())?.services.keys.sorted()) ?? []
	}

	/// The template's text with the project renamed. Besides `name:`, a template refers to its own
	/// project in the compose DNS names of its services (`db.lamp.compose.internal`) and in VM names
	/// (`compose-lamp-db`), so those follow the new name too.
	public func composeText(projectName newName: String?) throws -> String {
		guard let newName else {
			return self.compose
		}

		try ComposeLibrary.validateProjectName(newName)

		let oldName = self.projectName
		var text = self.compose

		if let range = text.range(of: #"(?m)^name:[ \t]*.*$"#, options: .regularExpression) {
			text.replaceSubrange(range, with: "name: \(newName)")
		} else {
			text = "name: \(newName)\n" + text
		}

		if oldName != newName {
			text = text.replacingOccurrences(of: ".\(oldName).", with: ".\(newName).")
			text = text.replacingOccurrences(of: "compose-\(oldName)-", with: "compose-\(newName)-")
		}

		return text
	}
}

public struct ComposeLibrary: Codable, Sendable {
	/// The format this build understands. A newer library asks for a newer caker.
	public static let supportedVersion = 1
	public static let fileName = "ComposeLibrary.json"

	public let version: Int
	public let templates: [ComposeLibraryTemplate]

	public init(version: Int = ComposeLibrary.supportedVersion, templates: [ComposeLibraryTemplate]) {
		self.version = version
		self.templates = templates
	}

	// MARK: Content

	public var categories: [String] {
		Array(Set(self.templates.map(\.category))).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
	}

	public func template(id: String) -> ComposeLibraryTemplate? {
		let id = id.lowercased()

		return self.templates.first { $0.id == id }
	}

	/// Templates whose id, name, summary, category or tags contain every word of `query`.
	public func search(_ query: String? = nil, category: String? = nil) -> [ComposeLibraryTemplate] {
		let words = (query ?? "").lowercased().split(whereSeparator: \.isWhitespace).map(String.init)

		return self.templates.filter { template in
			if let category, category.isEmpty == false, template.category.caseInsensitiveCompare(category) != .orderedSame {
				return false
			}

			let haystack = ([template.id, template.name, template.summary, template.category] + template.tags).joined(separator: " ").lowercased()

			return words.allSatisfy { haystack.contains($0) }
		}
	}

	// MARK: Validation

	/// Compose project names end up in VM names and DNS labels.
	static func validateProjectName(_ name: String) throws {
		guard name.range(of: #"^[a-z0-9]([a-z0-9-]{0,38}[a-z0-9])?$"#, options: .regularExpression) != nil else {
			throw ServiceError(String(format: String(localized: "'%@' is not a valid project name: use lowercase letters, digits and hyphens"), name))
		}
	}

	/// A library is only trusted when every template is well formed and parses as a compose file:
	/// a downloaded copy that fails here is refused as a whole.
	public func validate() throws {
		guard self.version <= Self.supportedVersion else {
			throw ServiceError(String(format: String(localized: "The compose library uses format %d, this version understands up to %d: update Caker"), self.version, Self.supportedVersion))
		}

		var seen = Set<String>()

		for template in self.templates {
			guard template.id.range(of: #"^[a-z0-9]([a-z0-9-]{0,46}[a-z0-9])?$"#, options: .regularExpression) != nil else {
				throw ServiceError(String(format: String(localized: "Compose library template id '%@' is not valid"), template.id))
			}

			guard seen.insert(template.id).inserted else {
				throw ServiceError(String(format: String(localized: "Compose library template id '%@' is used twice"), template.id))
			}

			guard template.name.isEmpty == false, template.category.isEmpty == false else {
				throw ServiceError(String(format: String(localized: "Compose library template '%@' has no name or category"), template.id))
			}

			let compose: ComposeFile

			do {
				compose = try template.composeFile()
			} catch {
				throw ServiceError(String(format: String(localized: "Compose library template '%@' is not a valid compose file: %@"), template.id, error.localizedDescription))
			}

			guard compose.services.isEmpty == false else {
				throw ServiceError(String(format: String(localized: "Compose library template '%@' defines no service"), template.id))
			}

			try Self.validateProjectName(compose.name)
		}
	}

	// MARK: Loading

	/// The loaded library and the modification date of the `<CAKE_HOME>/ComposeLibrary.json` copy it
	/// was read with (nil: none), which `reloadIfChanged()` compares against.
	private struct Loaded: Sendable {
		let library: ComposeLibrary
		let overrideDate: Date?
	}

	private static let storage: Mutex<Loaded> = Mutex(load())

	public static var shared: ComposeLibrary {
		storage.withLock { $0.library }
	}

	/// `shared`, re-read first when the copy in `<CAKE_HOME>` was added, changed or removed since it
	/// was loaded (a long-running caked, or a `sync` run by another process).
	public static func reloadIfChanged() -> ComposeLibrary {
		reloadIfChanged(overrideURL: cakeHomeLibraryURL(createHomeIfNeeded: false))
	}

	/// `internal` so tests can point it at a temporary file instead of the real `<CAKE_HOME>`.
	static func reloadIfChanged(overrideURL: URL?) -> ComposeLibrary {
		let date = modificationDate(overrideURL)

		return storage.withLock { loaded in
			if loaded.overrideDate != date {
				loaded = Loaded(library: load(overrideURL: overrideURL) ?? loadBundled(), overrideDate: date)
			}

			return loaded.library
		}
	}

	/// Raw JSON on the `main` branch — kept in sync with `Sources/cakedlib/Resources/ComposeLibrary.json`.
	public static let githubLibraryURL = URL(string: "https://raw.githubusercontent.com/Fred78290/caker/main/Sources/cakedlib/Resources/ComposeLibrary.json")!

	/// Where the synced copy lives.
	public static func cakeHomeLibraryURL(createHomeIfNeeded: Bool) -> URL? {
		guard let home = try? Utils.getHome(runMode: .app, createItIfNotExists: createHomeIfNeeded) else {
			return nil
		}

		return home.appendingPathComponent(Self.fileName, isDirectory: false)
	}

	/// When the library was last synced from GitHub; nil while the bundled copy is in use.
	public static var syncedDate: Date? {
		modificationDate(cakeHomeLibraryURL(createHomeIfNeeded: false))
	}

	private static func load(overrideURL: URL?) -> ComposeLibrary? {
		guard let url = overrideURL, FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
			return nil
		}

		// A damaged or outdated copy in <CAKE_HOME> is user state, not a packaging invariant: ignore it.
		guard let library = try? JSONDecoder().decode(ComposeLibrary.self, from: Data(contentsOf: url)), (try? library.validate()) != nil else {
			return nil
		}

		return library
	}

	private static func modificationDate(_ url: URL?) -> Date? {
		guard let url else {
			return nil
		}

		return (try? FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false)))?[.modificationDate] as? Date
	}

	/// `internal` so tests can load the bundled file directly: `shared` prefers a synced copy, which
	/// would hide a bundled-file decoding failure.
	static func loadBundled() -> ComposeLibrary {
		func load(_ url: URL) -> ComposeLibrary {
			do {
				return try JSONDecoder().decode(ComposeLibrary.self, from: Data(contentsOf: url))
			} catch {
				fatalError("Failed to load ComposeLibrary.json: \(error)")
			}
		}

		if let url = Bundle.main.url(forResource: "ComposeLibrary", withExtension: "json") {
			return load(url)
		}

		guard let url = composeResourceBundle.url(forResource: "ComposeLibrary", withExtension: "json") else {
			fatalError("ComposeLibrary.json resource not found in the app bundle — add it to the target's \"Copy Bundle Resources\" build phase in Xcode")
		}

		return load(url)
	}

	private static func load() -> Loaded {
		let overrideURL = cakeHomeLibraryURL(createHomeIfNeeded: false)

		return Loaded(library: load(overrideURL: overrideURL) ?? loadBundled(), overrideDate: modificationDate(overrideURL))
	}

	// MARK: Sync

	/// What a `refreshFromGitHub()` changed compared with the library that was in use before.
	public struct SyncResult: Codable, Sendable {
		public let templates: Int
		public let added: [String]
		public let updated: [String]
		public let removed: [String]

		public var changed: Bool {
			self.added.isEmpty == false || self.updated.isEmpty == false || self.removed.isEmpty == false
		}
	}

	/// Downloads the library published on GitHub, keeps it in `<CAKE_HOME>/ComposeLibrary.json` and
	/// makes `shared` use it.
	///
	/// This trusts `main` as a live source for `compose.yml` text, like `VMImageCatalog` does for its
	/// download links — and a template is not run by being downloaded: it only becomes a project when
	/// the user clones it and runs `compose up`, after having had it in front of them. Every template
	/// must still validate (`validate()`), otherwise the whole download is refused.
	@discardableResult
	public static func refreshFromGitHub(session: URLSession = .shared) async throws -> SyncResult {
		let (data, response) = try await session.data(from: githubLibraryURL)

		guard let http = response as? HTTPURLResponse else {
			throw ServiceError(String(localized: "Failed to download the compose library from GitHub"))
		}

		guard (200..<300).contains(http.statusCode) else {
			if http.statusCode == 404 {
				throw ServiceError(String(localized: "The compose library is not published on GitHub yet: the copy bundled with this version is used"))
			}

			throw ServiceError(String(format: String(localized: "Failed to download the compose library from GitHub (HTTP %d)"), http.statusCode))
		}

		return try install(data)
	}

	/// Validates `data` as a library and installs it as the synced copy. Separate from the download
	/// so tests can cover it without the network.
	static func install(_ data: Data, destination: URL? = nil) throws -> SyncResult {
		let library: ComposeLibrary

		do {
			library = try JSONDecoder().decode(ComposeLibrary.self, from: data)
		} catch {
			throw ServiceError(String(format: String(localized: "The downloaded compose library is not valid: %@"), error.localizedDescription))
		}

		try library.validate()

		guard let destination = destination ?? cakeHomeLibraryURL(createHomeIfNeeded: true) else {
			throw ServiceError(String(localized: "Unable to find the cake home to store the compose library"))
		}

		// `Utils.getHome` only creates the directory on its first call, see `VMImageCatalog.refreshFromGitHub`.
		try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)

		let previous = reloadIfChanged(overrideURL: destination)

		try data.write(to: destination, options: .atomic)

		storage.withLock { $0 = Loaded(library: library, overrideDate: modificationDate(destination)) }

		let before = Dictionary(uniqueKeysWithValues: previous.templates.map { ($0.id, $0) })
		let after = Dictionary(uniqueKeysWithValues: library.templates.map { ($0.id, $0) })

		return SyncResult(
			templates: library.templates.count,
			added: after.keys.filter { before[$0] == nil }.sorted(),
			updated: after.keys.filter { before[$0] != nil && before[$0] != after[$0] }.sorted(),
			removed: before.keys.filter { after[$0] == nil }.sorted()
		)
	}

	// MARK: Clone

	/// Where `clone` writes: `output` when it names a file, `<output>/compose.yml` when it names a
	/// directory (existing, or written with a trailing slash), `./compose.yml` without `output`.
	public static func destination(output: String?, currentDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)) -> URL {
		guard let output, output.isEmpty == false else {
			return currentDirectory.appendingPathComponent(ComposeFile.filename)
		}

		let url = URL(fileURLWithPath: output.expandingTildeInPath, relativeTo: currentDirectory).standardizedFileURL
		var isDirectory: ObjCBool = false

		if output.hasSuffix("/") || (FileManager.default.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory) && isDirectory.boolValue) {
			return url.appendingPathComponent(ComposeFile.filename)
		}

		return url
	}

	/// Writes the template as a `compose.yml` the user can edit and start with `compose up`.
	@discardableResult
	public static func clone(_ template: ComposeLibraryTemplate, projectName: String? = nil, to destination: URL, force: Bool = false) throws -> URL {
		let text = try template.composeText(projectName: projectName)

		if FileManager.default.fileExists(atPath: destination.path(percentEncoded: false)) && force == false {
			throw ServiceError(String(format: String(localized: "%@ already exists — use --force to overwrite."), destination.path(percentEncoded: false)))
		}

		try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
		try text.write(to: destination, atomically: true, encoding: .utf8)

		return destination
	}
}
