//
//  GuestApplications.swift
//  Caker
//
import CakeAgentLib
import Foundation
import GRPCLib

/// An application of a Linux guest, described by one of its `.desktop` files (what `cakeagent seamless apps --json` prints).
public struct GuestApplication: Codable, Hashable, Identifiable, Sendable {
	/// The desktop file name, `org.gnome.gedit.desktop`.
	public let id: String
	public let name: String
	public let comment: String?
	public let exec: String
	public let icon: String?
	public let terminal: Bool?
	public let categories: [String]?

	public init(id: String, name: String, comment: String? = nil, exec: String = "", icon: String? = nil, terminal: Bool? = nil, categories: [String]? = nil) {
		self.id = id
		self.name = name
		self.comment = comment
		self.exec = exec
		self.icon = icon
		self.terminal = terminal
		self.categories = categories
	}

	/// The ID without `.desktop`, the part a user types (`org.gnome.gedit`).
	public var shortID: String {
		self.id.hasSuffix(GuestApplications.desktopSuffix) ? String(self.id.dropLast(GuestApplications.desktopSuffix.count)) : self.id
	}
}

/// The host side of the guest's application launcher: lists the `.desktop` applications of a Linux guest and starts one,
/// so its window shows up through the seamless windows channel. Both go through the cakeagent already in the guest
/// (`cakeagent seamless apps`/`launch`), run by the agent's `Run` call, so it works the same for an embedded VM, a local
/// `caked` and a remote one: the callers only supply how to run a command line (`Runner`).
public enum GuestApplications {
	public static let desktopSuffix = ".desktop"

	/// Where the install scripts put the agent.
	public static let agentPath = "/usr/local/bin/cakeagent"

	/// Runs a command line in the guest and returns what the agent answered.
	public typealias Runner = (_ commandLine: String) throws -> Caked_RunReply

	public enum Failure: Error, LocalizedError {
		case notFound(String)
		case ambiguous(String, [GuestApplication])
		case invalidIdentifier(String)
		case invalidUser(String)
		case listing(String)
		case launching(String)

		public var errorDescription: String? {
			switch self {
			case .notFound(let query):
				return String(format: String(localized: "No application matches '%@' in this VM"), query)
			case .ambiguous(let query, let candidates):
				return String(format: String(localized: "'%@' matches several applications: %@"), query, candidates.map(\.id).joined(separator: ", "))
			case .invalidIdentifier(let id):
				return String(format: String(localized: "'%@' is not a valid application identifier"), id)
			case .invalidUser(let user):
				return String(format: String(localized: "'%@' is not a valid user name"), user)
			case .listing(let reason):
				return String(format: String(localized: "Unable to list the applications of the VM: %@"), reason)
			case .launching(let reason):
				return String(format: String(localized: "Unable to start the application: %@"), reason)
			}
		}
	}

	// MARK: Command lines

	/// A desktop file ID is a file name: letters, digits and a few separators. Anything else is refused rather than quoted.
	public static func isValidIdentifier(_ id: String) -> Bool {
		guard id.isEmpty == false, id.utf8.count <= 255, let first = id.unicodeScalars.first, first != "." else {
			return false
		}

		return id.unicodeScalars.allSatisfy { $0.isASCII && (CharacterSet.alphanumerics.contains($0) || "._+@-".unicodeScalars.contains($0)) }
	}

	/// A Unix account name, as the agent looks it up.
	public static func isValidUser(_ user: String) -> Bool {
		guard user.isEmpty == false, user.utf8.count <= 64, let first = user.unicodeScalars.first, first != "-" else {
			return false
		}

		return user.unicodeScalars.allSatisfy { $0.isASCII && (CharacterSet.alphanumerics.contains($0) || "._-".unicodeScalars.contains($0)) }
	}

	private static func userOption(_ user: String?) throws -> String {
		guard let user, user.isEmpty == false else {
			// The agent's own default: the first regular user.
			return String.empty
		}

		guard self.isValidUser(user) else {
			throw Failure.invalidUser(user)
		}

		return " --seamless-user=\(user)"
	}

	public static func listCommandLine(user: String?) throws -> String {
		"\(self.agentPath) seamless apps --json\(try self.userOption(user))"
	}

	public static func launchCommandLine(id: String, user: String?) throws -> String {
		guard self.isValidIdentifier(id) else {
			throw Failure.invalidIdentifier(id)
		}

		return "\(self.agentPath) seamless launch\(try self.userOption(user)) --desktop \(id)"
	}

	/// Starts a program that has no desktop file. The agent runs the line with `/bin/sh -c`, so each word is quoted.
	public static func launchCommandLine(program: [String], user: String?) throws -> String {
		guard program.isEmpty == false else {
			throw Failure.invalidIdentifier(String.empty)
		}

		return "\(self.agentPath) seamless launch\(try self.userOption(user)) -- " + program.map(self.shellQuoted).joined(separator: " ")
	}

	static func shellQuoted(_ value: String) -> String {
		"'" + value.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
	}

	// MARK: Parsing and lookup

	/// The agent prints `null` for no application at all (a Go nil slice) and an empty list otherwise.
	public static func parse(_ output: Data) throws -> [GuestApplication] {
		let text = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

		if text.isEmpty || text == "null" {
			return []
		}

		do {
			return try JSONDecoder().decode([GuestApplication].self, from: Data(text.utf8))
		} catch {
			throw Failure.listing(error.localizedDescription)
		}
	}

	/// Finds the application a user meant: the desktop file ID (with or without `.desktop`), else its name, else the
	/// last word of a reverse-DNS ID (`firefox` for `org.mozilla.firefox`). A step that finds several applications is an
	/// error rather than a guess.
	public static func resolve(_ query: String, in applications: [GuestApplication]) throws -> GuestApplication {
		let wanted = query.trimmingCharacters(in: .whitespacesAndNewlines)
		let lowered = wanted.lowercased()
		let wantedID = wanted.hasSuffix(self.desktopSuffix) ? wanted : wanted + self.desktopSuffix

		let steps: [(GuestApplication) -> Bool] = [
			{ $0.id == wantedID },
			{ $0.id.lowercased() == wantedID.lowercased() },
			{ $0.name.lowercased() == lowered },
			{ $0.shortID.split(separator: ".").last.map { $0.lowercased() == lowered } ?? false },
		]

		for matches in steps {
			let found = applications.filter(matches)

			if found.count == 1 {
				return found[0]
			}

			if found.count > 1 {
				throw Failure.ambiguous(wanted, found)
			}
		}

		throw Failure.notFound(wanted)
	}

	// MARK: Icons

	/// Where a guest keeps the icons a desktop file names by name: the icon themes of the system, of snapd and of Flatpak.
	static let iconDirectories = ["/usr/share/icons", "/usr/share/pixmaps", "/usr/local/share/icons", "/var/lib/snapd/desktop/icons", "/var/lib/flatpak/exports/share/icons"]

	/// Where a desktop file may point at an icon by path: the same folders, and the snaps (`/snap/firefox/current/default256.png`).
	static let iconPathRoots = iconDirectories + ["/snap", "/var/lib/snapd", "/var/lib/flatpak"]

	/// An icon name from a desktop file (`foot`) or a path under the icon directories. It comes from the guest and ends in a
	/// command line, so only plain file names and paths are accepted.
	public static func isValidIconName(_ icon: String) -> Bool {
		let plain = "._+@-"

		func plainName(_ name: String) -> Bool {
			name.isEmpty == false && name.utf8.count <= 200 && name.unicodeScalars.allSatisfy { $0.isASCII && (CharacterSet.alphanumerics.contains($0) || plain.unicodeScalars.contains($0)) }
		}

		if icon.hasPrefix("/") {
			return self.iconPathRoots.contains { icon.hasPrefix($0 + "/") } && icon.split(separator: "/").allSatisfy { $0 != ".." && plainName(String($0)) }
		}

		return plainName(icon)
	}

	static func iconSearchCommandLine(icon: String) throws -> String {
		guard self.isValidIconName(icon) else {
			throw Failure.invalidIdentifier(icon)
		}

		if icon.hasPrefix("/") {
			return "echo " + self.shellQuoted(icon)
		}

		let directories = self.iconDirectories.map(self.shellQuoted).joined(separator: " ")

		return "find \(directories) \\( -name \(self.shellQuoted(icon + ".png")) -o -name \(self.shellQuoted(icon + ".svg")) \\) 2>/dev/null | head -100"
	}

	/// The side of a themed icon in its path (`.../48x48/apps/x.png`, `.../128x128@2/...` is twice that), 0 when it has none.
	static func iconSide(of path: String) -> Int {
		for component in path.split(separator: "/") {
			let parts = component.split(separator: "x", maxSplits: 1)

			guard parts.count == 2, let side = Int(parts[0]) else {
				continue
			}

			let scale = parts[1].split(separator: "@").dropFirst().first.flatMap { Int($0) } ?? 1

			return side * scale
		}

		return 0
	}

	/// The icon to use among the candidates: a PNG of at least 128 points, else a scalable one (SVG), else the largest PNG.
	public static func bestIcon(among paths: [String]) -> String? {
		let candidates = paths.filter { ($0.hasSuffix(".png") || $0.hasSuffix(".svg")) && $0.hasPrefix("/") }
		let png = candidates.filter { $0.hasSuffix(".png") }.max { self.iconSide(of: $0) < self.iconSide(of: $1) }

		if let png, self.iconSide(of: png) >= 128 {
			return png
		}

		return candidates.first { $0.hasSuffix(".svg") } ?? png
	}

	static func iconFetchCommandLine(path: String) -> String {
		"test \"$(wc -c < \(self.shellQuoted(path)))\" -le 2000000 && base64 < \(self.shellQuoted(path))"
	}

	/// The icon of an application (PNG or SVG data), read from the guest's icon theme; nil when it names none or none is found.
	public static func icon(for application: GuestApplication, run: Runner) throws -> Data? {
		guard let name = application.icon, name.isEmpty == false, self.isValidIconName(name) else {
			return nil
		}

		let search = try run(try self.iconSearchCommandLine(icon: name))

		guard search.exitCode == 0 else {
			return nil
		}

		let paths = String(decoding: search.stdout, as: UTF8.self).split(whereSeparator: \.isNewline).map(String.init).filter(self.isValidIconName)

		guard let path = self.bestIcon(among: paths) else {
			return nil
		}

		let fetch = try run(self.iconFetchCommandLine(path: path))

		guard fetch.exitCode == 0 else {
			return nil
		}

		return Data(base64Encoded: String(decoding: fetch.stdout, as: UTF8.self).filter { $0.isWhitespace == false })
	}

	// MARK: Running

	public static func list(user: String?, run: Runner) throws -> [GuestApplication] {
		let reply = try run(try self.listCommandLine(user: user))

		guard reply.exitCode == 0 else {
			throw Failure.listing(self.reason(reply))
		}

		return try self.parse(reply.stdout)
	}

	/// The words of a `.desktop` `Exec` line without its field codes (`%U`, `%f`...), which stand for files this launcher doesn't pass.
	static func execWords(_ exec: String) -> [String] {
		exec.split(whereSeparator: \.isWhitespace).map(String.init).filter { $0.count != 2 || $0.hasPrefix("%") == false }
	}

	/// What starts a `Terminal=true` application: it has no window of its own, so it runs inside one of the guest's terminal
	/// emulators (`foot -e htop`). nil when the application isn't one, or the guest has no emulator to run it in.
	public static func terminalCommand(for application: GuestApplication, in applications: [GuestApplication]) -> [String]? {
		guard application.terminal == true else {
			return nil
		}

		let program = self.execWords(application.exec)
		let emulators = applications.filter { $0.categories?.contains("TerminalEmulator") == true && $0.terminal != true }
		// `foot-server` and `footclient` need a server: prefer the plain emulator, the one whose name is the shortest.
		let emulator = emulators.min { $0.id.count < $1.id.count }.map { self.execWords($0.exec) }

		guard program.isEmpty == false, let emulator, emulator.isEmpty == false else {
			return nil
		}

		return emulator + ["-e"] + program
	}

	/// Starts an application and returns the guest process ID. The agent starts it detached and returns at once.
	/// `applications` is the guest's list, to find a terminal emulator for an application that needs one.
	@discardableResult
	public static func launch(_ application: GuestApplication, among applications: [GuestApplication] = [], user: String?, run: Runner) throws -> Int {
		if let command = self.terminalCommand(for: application, in: applications) {
			return try self.launch(program: command, user: user, run: run)
		}

		return try self.pid(from: try run(try self.launchCommandLine(id: application.id, user: user)))
	}

	@discardableResult
	public static func launch(program: [String], user: String?, run: Runner) throws -> Int {
		try self.pid(from: try run(try self.launchCommandLine(program: program, user: user)))
	}

	private static func pid(from reply: Caked_RunReply) throws -> Int {
		guard reply.exitCode == 0 else {
			throw Failure.launching(self.reason(reply))
		}

		return Int(String(decoding: reply.stdout, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
	}

	private static func reason(_ reply: Caked_RunReply) -> String {
		let message = String(decoding: reply.stderr, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)

		return message.isEmpty ? String(format: String(localized: "exit code %d"), Int(reply.exitCode)) : message
	}
}

extension CakeAgentLib.Format {
	/// One row of the text table: the identifier to give to `app run`, the name, and what the application says it is.
	private struct GuestApplicationRow: Encodable {
		let id: String
		let name: String
		let comment: String

		init(_ application: GuestApplication) {
			self.id = application.shortID
			self.name = application.name
			self.comment = application.comment ?? String.empty
		}
	}

	public func render(_ data: [GuestApplication]) -> String {
		switch self {
		case .text:
			return self.renderList(data.map { GuestApplicationRow($0) })
		case .json:
			return self.renderList(data)
		}
	}
}
