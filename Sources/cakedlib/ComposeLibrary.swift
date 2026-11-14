//
//  ComposeLibrary.swift
//  CakedLib
//
//  A library of ready-to-use `compose.yml` templates for what developers set up most often (a
//  database, a web stack, a Docker host, ...). Each template is one plain, editable `.yml` file; it
//  follows `VMImageCatalog`'s lifecycle:
//
//  - the library ships inside the binary as the `compose-library` folder (`<id>.yml` files plus an
//    `index.json` listing their ids), so it works offline and before a first sync;
//  - `refreshFromGitHub()` (`cakectl compose library sync`, the library window of Caker.app)
//    downloads the index and the templates published on the `main` branch of the repository into
//    `<CAKE_HOME>/compose-library/`;
//  - once synced, that folder wins over the bundled one and is re-read when a file in it changes, so
//    a template there can be edited by hand (until the next sync overwrites it).
//
//  A template file starts with `# library-<field>: <value>` comment lines (id, name, category,
//  summary, tags): the metadata the library lists. They are not part of the compose text that
//  `clone` writes.
//
//  Until the templates are merged into `main`, the download answers 404: `refreshFromGitHub()` then
//  fails with an explicit message and the bundled copy keeps being used.
//

import CakeAgentLib
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
	/// The `compose.yml` text, comments included but without the `# library-*` metadata lines.
	public let compose: String

	public init(id: String, name: String, category: String, summary: String, tags: [String] = [], compose: String) {
		self.id = id
		self.name = name
		self.category = category
		self.summary = summary
		self.tags = tags
		self.compose = compose
	}

	/// Reads a template file: the leading `# library-<field>: <value>` lines are the metadata, the rest
	/// is the compose text. `expectedID` is the file name without its extension, which the id must match.
	public static func parse(_ text: String, id expectedID: String? = nil) throws -> ComposeLibraryTemplate {
		let prefix = "# library-"
		var meta: [String: String] = [:]
		var body: [Substring] = []

		for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
			if body.isEmpty, line.hasPrefix(prefix), let colon = line.firstIndex(of: ":") {
				let key = String(line[line.index(line.startIndex, offsetBy: prefix.count)..<colon])

				meta[key] = line[line.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines)
			} else {
				body.append(line)
			}
		}

		for field in ["id", "name", "category", "summary", "tags"] where meta[field] == nil {
			throw ServiceError(String(format: String(localized: "Compose library template '%@' has no '# library-%@:' line"), expectedID ?? meta["id"] ?? "?", field))
		}

		if let expectedID, meta["id"] != expectedID {
			throw ServiceError(String(format: String(localized: "Compose library template '%@' declares the id '%@': it must match its file name"), expectedID, meta["id"] ?? ""))
		}

		return ComposeLibraryTemplate(
			id: meta["id"]!,
			name: meta["name"]!,
			category: meta["category"]!,
			summary: meta["summary"]!,
			tags: meta["tags"]!.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { $0.isEmpty == false },
			compose: body.joined(separator: "\n").trimmingCharacters(in: .newlines) + "\n"
		)
	}

	/// A template is only trusted when it is well formed and parses as a compose file.
	public func validate() throws {
		guard self.id.range(of: #"^[a-z0-9]([a-z0-9-]{0,46}[a-z0-9])?$"#, options: .regularExpression) != nil else {
			throw ServiceError(String(format: String(localized: "Compose library template id '%@' is not valid"), self.id))
		}

		guard self.name.isEmpty == false, self.category.isEmpty == false else {
			throw ServiceError(String(format: String(localized: "Compose library template '%@' has no name or category"), self.id))
		}

		let compose: ComposeFile

		do {
			compose = try self.composeFile()
		} catch {
			throw ServiceError(String(format: String(localized: "Compose library template '%@' is not a valid compose file: %@"), self.id, error.reason))
		}

		guard compose.services.isEmpty == false else {
			throw ServiceError(String(format: String(localized: "Compose library template '%@' defines no service"), self.id))
		}

		try ComposeLibrary.validateProjectName(compose.name)
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

	/// The template's text for a clone. Besides `name:`, a template refers to its own project in the
	/// compose DNS names of its services (`db.lamp.compose.internal`) and in VM names
	/// (`compose-lamp-db`), so those follow a new project name. The domain of those DNS names is the
	/// configured one (`ComposeDNS.domainSuffix`), not the `compose.internal` the files are written with,
	/// whether the project is renamed or not.
	public func composeText(projectName newName: String?, domain: String = ComposeDNS.domainSuffix) throws -> String {
		let oldName = self.projectName
		var text = self.compose

		if let newName {
			try ComposeLibrary.validateProjectName(newName)

			if let range = text.range(of: #"(?m)^name:[ \t]*.*$"#, options: .regularExpression) {
				text.replaceSubrange(range, with: "name: \(newName)")
			} else {
				text = "name: \(newName)\n" + text
			}

			if oldName != newName {
				text = text.replacingOccurrences(of: ".\(oldName).", with: ".\(newName).")
				text = text.replacingOccurrences(of: "compose-\(oldName)-", with: "compose-\(newName)-")
			}
		}

		if domain != ComposeDNS.defaultDomainSuffix {
			let project = newName ?? oldName

			text = text.replacingOccurrences(of: ".\(project).\(ComposeDNS.defaultDomainSuffix)", with: ".\(project).\(domain)")
		}

		return text
	}
}

public struct ComposeLibrary: Sendable {
	/// The format of `index.json` this build understands. A newer library asks for a newer caker.
	public static let supportedVersion = 1
	/// The folder holding the templates, in the app bundle and in `<CAKE_HOME>`, and on GitHub.
	public static let directoryName = "compose-library"
	/// Lists the ids of the templates of a folder; GitHub offers no cheap way to list a directory.
	public static let indexFileName = "index.json"
	public static let templateExtension = "yml"

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
			try template.validate()

			guard seen.insert(template.id).inserted else {
				throw ServiceError(String(format: String(localized: "Compose library template id '%@' is used twice"), template.id))
			}
		}
	}

	// MARK: Index

	/// `index.json`: the format version and the ids of the templates (`<id>.yml`) of a folder.
	struct Index: Codable {
		let version: Int
		let templates: [String]
	}

	/// The ids listed by an `index.json`. Every id becomes a file name, so each one is checked against
	/// the template id format before anything touches the file system — an index from the network
	/// can't name `../something`.
	static func parseIndex(_ data: Data) throws -> [String] {
		let index: Index

		do {
			index = try JSONDecoder().decode(Index.self, from: data)
		} catch {
			throw ServiceError(String(format: String(localized: "The compose library index is not valid: %@"), error.reason))
		}

		guard index.version <= supportedVersion else {
			throw ServiceError(String(format: String(localized: "The compose library uses format %d, this version understands up to %d: update Caker"), index.version, supportedVersion))
		}

		guard index.templates.isEmpty == false else {
			throw ServiceError(String(localized: "The compose library index lists no template"))
		}

		var seen = Set<String>()

		for id in index.templates {
			guard id.range(of: #"^[a-z0-9]([a-z0-9-]{0,46}[a-z0-9])?$"#, options: .regularExpression) != nil else {
				throw ServiceError(String(format: String(localized: "Compose library template id '%@' is not valid"), id))
			}

			guard seen.insert(id).inserted else {
				throw ServiceError(String(format: String(localized: "Compose library template id '%@' is used twice"), id))
			}
		}

		return index.templates
	}

	// MARK: Loading

	/// The loaded library and the signature of the `<CAKE_HOME>/compose-library` folder it was read
	/// with (nil: none), which `reloadIfChanged()` compares against.
	private struct Loaded: Sendable {
		let library: ComposeLibrary
		let signature: Signature?
	}

	/// What `reloadIfChanged()` compares: the folder's own modification date and, for every entry in it,
	/// its name, modification date and size. Keeping each entry (instead of only the latest date) means
	/// that editing or removing a file changes the signature even when another one is newer.
	private struct Signature: Equatable, Sendable {
		struct Entry: Equatable, Sendable {
			let name: String
			let date: Date?
			let size: UInt64?
		}

		let directory: Date
		let entries: [Entry]
	}

	private static let storage: Mutex<Loaded> = Mutex(load())

	public static var shared: ComposeLibrary {
		storage.withLock { $0.library }
	}

	/// `shared`, re-read first when the folder in `<CAKE_HOME>` or a template in it was added, changed
	/// or removed since it was loaded (a long-running caked, a `sync` run by another process, a hand edit).
	public static func reloadIfChanged() -> ComposeLibrary {
		reloadIfChanged(overrideURL: cakeHomeLibraryDirectory(createHomeIfNeeded: false))
	}

	/// `internal` so tests can point it at a temporary folder instead of the real `<CAKE_HOME>`.
	static func reloadIfChanged(overrideURL: URL?) -> ComposeLibrary {
		let date = signature(overrideURL)

		return storage.withLock { loaded in
			if loaded.signature != date {
				loaded = Loaded(library: load(overrideURL: overrideURL) ?? loadBundled(), signature: date)
			}

			return loaded.library
		}
	}

	/// Raw files on the `main` branch — kept in sync with `Sources/cakedlib/Resources/compose-library`.
	public static let githubLibraryBaseURL = URL(string: "https://raw.githubusercontent.com/Fred78290/caker/main/Sources/cakedlib/Resources/compose-library/")!

	/// Where the synced copy lives.
	public static func cakeHomeLibraryDirectory(createHomeIfNeeded: Bool) -> URL? {
		guard let home = try? Utils.getHome(runMode: .app, createItIfNotExists: createHomeIfNeeded) else {
			return nil
		}

		return home.appendingPathComponent(Self.directoryName, isDirectory: true)
	}

	/// When the library was last synced from GitHub; nil while the bundled copy is in use.
	public static var syncedDate: Date? {
		cakeHomeLibraryDirectory(createHomeIfNeeded: false).flatMap { modificationDate($0.appendingPathComponent(Self.indexFileName)) }
	}

	/// The templates of a folder, sorted by category then id, and what could not be read: a file whose
	/// metadata is missing, whose id isn't its name, or that isn't a valid compose file.
	static func templates(in directory: URL) -> (templates: [ComposeLibraryTemplate], errors: [String: Error]) {
		var templates: [ComposeLibraryTemplate] = []
		var errors: [String: Error] = [:]
		let files = ((try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []).filter { $0.pathExtension == templateExtension }

		for file in files {
			do {
				let template = try ComposeLibraryTemplate.parse(String(contentsOf: file, encoding: .utf8), id: file.deletingPathExtension().lastPathComponent)

				try template.validate()
				templates.append(template)
			} catch {
				errors[file.lastPathComponent] = error
			}
		}

		templates.sort {
			let order = $0.category.localizedCaseInsensitiveCompare($1.category)

			return order == .orderedSame ? $0.id < $1.id : order == .orderedAscending
		}

		return (templates, errors)
	}

	/// The synced folder, or nil when there is none, it wasn't written by a sync (no `index.json`) or
	/// nothing in it is usable. A template that can't be read is skipped (and logged) rather than
	/// discarding the others: a file edited by hand is user state, not a packaging invariant.
	private static func load(overrideURL: URL?) -> ComposeLibrary? {
		guard let directory = overrideURL, let indexData = try? Data(contentsOf: directory.appendingPathComponent(indexFileName)) else {
			return nil
		}

		// A synced folder is only used when its index is readable and of a format this build understands
		// (a newer library asks for a newer caker): otherwise the bundled copy is used.
		do {
			_ = try parseIndex(indexData)
		} catch {
			Logger("ComposeLibrary").warn("Ignoring \(directory.path(percentEncoded: false)): \(error.reason)")

			return nil
		}

		let loaded = templates(in: directory)

		for (file, error) in loaded.errors.sorted(by: { $0.key < $1.key }) {
			Logger("ComposeLibrary").warn("Ignoring \(file) in \(directory.path(percentEncoded: false)): \(error.reason)")
		}

		return loaded.templates.isEmpty ? nil : ComposeLibrary(templates: loaded.templates)
	}

	/// The folder's modification date plus the name, modification date and size of each entry, sorted
	/// by name: an added, removed or edited file changes it, whatever the other files' dates are.
	private static func signature(_ directory: URL?) -> Signature? {
		guard let directory, let date = modificationDate(directory) else {
			return nil
		}

		let entries = ((try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []).map { entry in
			let attributes = try? FileManager.default.attributesOfItem(atPath: entry.path(percentEncoded: false))

			return Signature.Entry(
				name: entry.lastPathComponent,
				date: attributes?[.modificationDate] as? Date,
				size: (attributes?[.size] as? NSNumber)?.uint64Value
			)
		}.sorted { $0.name < $1.name }

		return Signature(directory: date, entries: entries)
	}

	private static func modificationDate(_ url: URL?) -> Date? {
		guard let url else {
			return nil
		}

		return (try? FileManager.default.attributesOfItem(atPath: url.path(percentEncoded: false)))?[.modificationDate] as? Date
	}

	/// The bundled `compose-library` folder: flat in an app's `Resources`, in the SPM resource bundle
	/// otherwise (see `ComposeFile.template` for the same lookup).
	static func bundledDirectory() -> URL {
		if let url = Bundle.main.url(forResource: directoryName, withExtension: nil) {
			return url
		}

		guard let url = composeResourceBundle.url(forResource: directoryName, withExtension: nil) else {
			fatalError("\(directoryName) resource not found in the app bundle — add the folder to the target's \"Copy Bundle Resources\" build phase in Xcode")
		}

		return url
	}

	/// `internal` so tests can load the bundled folder directly: `shared` prefers a synced copy, which
	/// would hide a bundled-file failure. A bundled template that can't be read is a packaging bug.
	static func loadBundled() -> ComposeLibrary {
		let loaded = templates(in: bundledDirectory())

		if let failure = loaded.errors.first {
			fatalError("Failed to load the bundled compose template \(failure.key): \(failure.value)")
		}

		guard loaded.templates.isEmpty == false else {
			fatalError("The bundled \(directoryName) folder holds no template")
		}

		return ComposeLibrary(templates: loaded.templates)
	}

	private static func load() -> Loaded {
		let overrideURL = cakeHomeLibraryDirectory(createHomeIfNeeded: false)

		return Loaded(library: load(overrideURL: overrideURL) ?? loadBundled(), signature: signature(overrideURL))
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

	/// Downloads the index and the templates published on GitHub, keeps them in
	/// `<CAKE_HOME>/compose-library/` and makes `shared` use them.
	///
	/// This trusts `main` as a live source for `compose.yml` text, like `VMImageCatalog` does for its
	/// download links — and a template is not run by being downloaded: it only becomes a project when
	/// the user clones it and runs `compose up`, after having had it in front of them. Every template
	/// must still validate, otherwise the whole download is refused.
	@discardableResult
	public static func refreshFromGitHub(session: URLSession = .shared) async throws -> SyncResult {
		let index = try await download(indexFileName, session: session)
		var files: [String: String] = [:]

		for id in try parseIndex(index) {
			guard let text = String(data: try await download("\(id).\(templateExtension)", session: session, listedID: id), encoding: .utf8) else {
				throw ServiceError(String(format: String(localized: "The compose library template '%@' is not valid UTF-8 text"), id))
			}

			files[id] = text
		}

		return try install(index: index, files: files)
	}

	private static func download(_ name: String, session: URLSession, listedID: String? = nil) async throws -> Data {
		let (data, response) = try await session.data(from: githubLibraryBaseURL.appendingPathComponent(name))

		guard let http = response as? HTTPURLResponse else {
			throw ServiceError(String(localized: "Failed to download the compose library from GitHub"))
		}

		guard (200..<300).contains(http.statusCode) else {
			if http.statusCode == 404 {
				if let listedID {
					throw ServiceError(String(format: String(localized: "The compose library template '%@' is listed on GitHub but missing there"), listedID))
				}

				throw ServiceError(String(localized: "The compose library is not published on GitHub yet: the copy bundled with this version is used"))
			}

			throw ServiceError(String(format: String(localized: "Failed to download the compose library from GitHub (HTTP %d)"), http.statusCode))
		}

		return data
	}

	/// Validates the downloaded `files` (id -> file text) against `index` and installs them as the
	/// synced copy: each template is written as `<id>.yml`, the ones the previous sync listed and this
	/// one doesn't are removed (a file the user added by hand is left alone), and `index.json` is
	/// written last. Separate from the download so tests can cover it without the network.
	static func install(index: Data, files: [String: String], destination: URL? = nil) throws -> SyncResult {
		let ids = try parseIndex(index)
		var templates: [ComposeLibraryTemplate] = []

		for id in ids {
			guard let text = files[id] else {
				throw ServiceError(String(format: String(localized: "The compose library template '%@' is listed on GitHub but missing there"), id))
			}

			templates.append(try ComposeLibraryTemplate.parse(text, id: id))
		}

		try ComposeLibrary(templates: templates).validate()

		guard let destination = destination ?? cakeHomeLibraryDirectory(createHomeIfNeeded: true) else {
			throw ServiceError(String(localized: "Unable to find the cake home to store the compose library"))
		}

		// `Utils.getHome` only creates the directory on its first call, see `VMImageCatalog.refreshFromGitHub`.
		try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

		let previous = reloadIfChanged(overrideURL: destination)
		let indexURL = destination.appendingPathComponent(indexFileName)
		let previousIDs = (try? parseIndex(Data(contentsOf: indexURL))) ?? []

		for id in ids {
			try files[id]?.write(to: destination.appendingPathComponent("\(id).\(templateExtension)"), atomically: true, encoding: .utf8)
		}

		// A retired template that can't be removed would stay in the folder, and be loaded, while the new
		// index no longer lists it: fail before the index is written. A file that is already gone (deleted
		// by hand) is not an error, otherwise every later sync would fail on it.
		for id in previousIDs where ids.contains(id) == false {
			let retired = destination.appendingPathComponent("\(id).\(templateExtension)")

			if FileManager.default.fileExists(atPath: retired.path(percentEncoded: false)) {
				try FileManager.default.removeItem(at: retired)
			}
		}

		try index.write(to: indexURL, options: .atomic)

		let library = load(overrideURL: destination) ?? ComposeLibrary(templates: templates)

		storage.withLock { $0 = Loaded(library: library, signature: signature(destination)) }

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
