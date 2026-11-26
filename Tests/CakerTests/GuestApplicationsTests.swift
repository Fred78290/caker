import Foundation
import GRPCLib
import XCTest

@testable import CakedLib

final class GuestApplicationsTests: XCTestCase {
	private let applications = [
		GuestApplication(id: "org.mozilla.firefox.desktop", name: "Firefox Web Browser"),
		GuestApplication(id: "org.gnome.gedit.desktop", name: "Text Editor"),
		GuestApplication(id: "org.gnome.Nautilus.desktop", name: "Files"),
		GuestApplication(id: "foot.desktop", name: "Foot"),
	]

	private func reply(exit: Int32 = 0, stdout: String = "", stderr: String = "") -> Caked_RunReply {
		Caked_RunReply.with {
			$0.exitCode = exit
			$0.stdout = Data(stdout.utf8)
			$0.stderr = Data(stderr.utf8)
		}
	}

	// MARK: Parsing

	func testParseAgentOutput() throws {
		let json = #"[{"id":"org.gnome.gedit.desktop","name":"Text Editor","comment":"Edit text","exec":"gedit %U","icon":"gedit","terminal":false,"categories":["Utility"]}]"#
		let parsed = try GuestApplications.parse(Data(json.utf8))

		XCTAssertEqual(parsed.count, 1)
		XCTAssertEqual(parsed[0].id, "org.gnome.gedit.desktop")
		XCTAssertEqual(parsed[0].shortID, "org.gnome.gedit")
		XCTAssertEqual(parsed[0].comment, "Edit text")
		XCTAssertEqual(parsed[0].categories, ["Utility"])
	}

	func testParseNullAndEmptyMeanNoApplication() throws {
		XCTAssertEqual(try GuestApplications.parse(Data("null\n".utf8)), [])
		XCTAssertEqual(try GuestApplications.parse(Data("[]".utf8)), [])
		XCTAssertEqual(try GuestApplications.parse(Data("  \n".utf8)), [])
	}

	func testParseRejectsGarbage() {
		XCTAssertThrowsError(try GuestApplications.parse(Data("not json".utf8))) {
			guard case GuestApplications.Failure.listing = $0 else { return XCTFail("\($0)") }
		}
	}

	// MARK: Lookup

	func testResolveByDesktopID() throws {
		XCTAssertEqual(try GuestApplications.resolve("org.gnome.gedit.desktop", in: self.applications).name, "Text Editor")
		XCTAssertEqual(try GuestApplications.resolve("org.gnome.gedit", in: self.applications).name, "Text Editor")
		XCTAssertEqual(try GuestApplications.resolve("ORG.GNOME.GEDIT", in: self.applications).name, "Text Editor")
	}

	func testResolveByNameAndLastWord() throws {
		XCTAssertEqual(try GuestApplications.resolve("text editor", in: self.applications).id, "org.gnome.gedit.desktop")
		XCTAssertEqual(try GuestApplications.resolve("firefox", in: self.applications).id, "org.mozilla.firefox.desktop")
		XCTAssertEqual(try GuestApplications.resolve("nautilus", in: self.applications).id, "org.gnome.Nautilus.desktop")
		XCTAssertEqual(try GuestApplications.resolve("foot", in: self.applications).id, "foot.desktop")
	}

	func testResolveRefusesToGuess() {
		let twins = self.applications + [GuestApplication(id: "com.example.firefox.desktop", name: "Other Firefox")]

		XCTAssertThrowsError(try GuestApplications.resolve("firefox", in: twins)) {
			guard case GuestApplications.Failure.ambiguous(_, let found) = $0 else { return XCTFail("\($0)") }

			XCTAssertEqual(found.count, 2)
		}

		XCTAssertThrowsError(try GuestApplications.resolve("nothing", in: self.applications)) {
			guard case GuestApplications.Failure.notFound = $0 else { return XCTFail("\($0)") }
		}
	}

	func testAnExactIDBeatsALooserMatch() throws {
		let both = [GuestApplication(id: "firefox.desktop", name: "Firefox"), GuestApplication(id: "org.mozilla.firefox.desktop", name: "Firefox ESR")]

		XCTAssertEqual(try GuestApplications.resolve("firefox", in: both).id, "firefox.desktop")
	}

	// MARK: Command lines

	func testCommandLines() throws {
		XCTAssertEqual(try GuestApplications.listCommandLine(user: "admin"), "/usr/local/bin/cakeagent seamless apps --json --seamless-user=admin")
		XCTAssertEqual(try GuestApplications.listCommandLine(user: nil), "/usr/local/bin/cakeagent seamless apps --json")
		XCTAssertEqual(try GuestApplications.launchCommandLine(id: "org.gnome.gedit.desktop", user: "admin"), "/usr/local/bin/cakeagent seamless launch --seamless-user=admin --desktop org.gnome.gedit.desktop")
	}

	func testProgramWordsAreQuoted() throws {
		XCTAssertEqual(try GuestApplications.launchCommandLine(program: ["foot", "-e", "it's; rm -rf /"], user: "admin"), #"/usr/local/bin/cakeagent seamless launch --seamless-user=admin -- 'foot' '-e' 'it'\''s; rm -rf /'"#)
	}

	func testUntrustedIdentifiersAndUsersAreRefused() {
		for id in ["", ".hidden", "a b", "a;b", "a$(b)", "a\nb", "../x", "é.desktop", "a'b"] {
			XCTAssertFalse(GuestApplications.isValidIdentifier(id), id)
			XCTAssertThrowsError(try GuestApplications.launchCommandLine(id: id, user: "admin"), id)
		}

		for user in ["-r", "a b", "a;b", "root$(x)", "x\ny"] {
			XCTAssertFalse(GuestApplications.isValidUser(user), user)
			XCTAssertThrowsError(try GuestApplications.listCommandLine(user: user), user)
		}

		XCTAssertTrue(GuestApplications.isValidIdentifier("org.gnome.gedit.desktop"))
		XCTAssertTrue(GuestApplications.isValidIdentifier("kde-org.kate_2.desktop"))
		XCTAssertTrue(GuestApplications.isValidUser("fred.b-1_x"))
	}

	// MARK: Running

	func testListAndLaunchThroughARunner() throws {
		var lines: [String] = []
		let run: GuestApplications.Runner = { line in
			lines.append(line)

			return line.contains(" apps ") ? self.reply(stdout: #"[{"id":"foot.desktop","name":"Foot","exec":"foot"}]"#) : self.reply(stdout: "4242\n")
		}

		let found = try GuestApplications.list(user: "admin", run: run)

		XCTAssertEqual(found.map(\.id), ["foot.desktop"])
		XCTAssertEqual(try GuestApplications.launch(found[0], user: "admin", run: run), 4242)
		XCTAssertEqual(try GuestApplications.launch(program: ["foot"], user: "admin", run: run), 4242)
		XCTAssertEqual(lines.count, 3)
	}

	func testAgentFailuresCarryItsMessage() {
		let failing: GuestApplications.Runner = { _ in self.reply(exit: 1, stderr: "application \"x\" not found\n") }

		XCTAssertThrowsError(try GuestApplications.list(user: nil, run: failing)) {
			XCTAssertTrue($0.localizedDescription.contains("not found"), $0.localizedDescription)
		}

		XCTAssertThrowsError(try GuestApplications.launch(self.applications[0], user: nil, run: failing)) {
			guard case GuestApplications.Failure.launching(let reason) = $0 else { return XCTFail("\($0)") }

			XCTAssertEqual(reason, "application \"x\" not found")
		}
	}

	// MARK: Launcher

	private func temporaryDirectory() throws -> URL {
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent("guestapp-\(UUID().uuidString)", isDirectory: true)

		try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
		addTeardownBlock { try? FileManager.default.removeItem(at: directory) }

		return directory
	}

	func testLauncherBundle() throws {
		let directory = try self.temporaryDirectory()
		let cakectl = URL(fileURLWithPath: "/Applications/Caker.app/Contents/PlugIns/cakectl.app/Contents/MacOS/cakectl")
		let bundle = try GuestApplicationLauncher.create(vm: "dev vm", application: self.applications[1], tool: cakectl, extraArguments: ["--system"], in: directory)

		XCTAssertEqual(bundle.lastPathComponent, "Text Editor (dev vm).app")

		let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: bundle.appendingPathComponent("Contents/Info.plist")), format: nil) as? [String: Any])

		XCTAssertEqual(plist["CFBundleExecutable"] as? String, "launcher")
		XCTAssertEqual(plist["CFBundleIdentifier"] as? String, "com.aldunelabs.caker.guestapp.dev-vm.org.gnome.gedit")
		XCTAssertEqual(plist["LSUIElement"] as? Bool, true)

		let executable = bundle.appendingPathComponent("Contents/MacOS/launcher")
		let script = try String(contentsOf: executable, encoding: .utf8)

		XCTAssertTrue(script.hasPrefix("#!/bin/sh\n"))
		XCTAssertTrue(script.contains("exec '/Applications/Caker.app/Contents/PlugIns/cakectl.app/Contents/MacOS/cakectl' 'app' 'run' 'dev vm' 'org.gnome.gedit.desktop' '--start' '--wait' '120' '--system'\n"), script)
		XCTAssertTrue(FileManager.default.isExecutableFile(atPath: executable.path(percentEncoded: false)))
	}

	/// Runs the generated script against a stand-in for cakectl that prints its arguments one per line.
	func testLauncherPassesWhatTheUserTypedAsPlainArguments() throws {
		let directory = try self.temporaryDirectory()
		let fake = directory.appendingPathComponent("fake cakectl")

		try Data("#!/bin/sh\nfor argument in \"$@\"; do printf '%s\\n' \"$argument\"; done\n".utf8).write(to: fake)
		try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fake.path(percentEncoded: false))

		let vm = "it's $(touch pwned) `x`; vm"
		let launcher = directory.appendingPathComponent("launcher")

		try Data(GuestApplicationLauncher.script(tool: fake.path(percentEncoded: false), vm: vm, application: self.applications[3], extraArguments: ["--connect=unix:///tmp/a b"]).utf8).write(to: launcher)

		let process = Process()
		let output = Pipe()

		process.executableURL = URL(fileURLWithPath: "/bin/sh")
		process.arguments = [launcher.path(percentEncoded: false)]
		process.currentDirectoryURL = directory
		process.standardOutput = output
		try process.run()
		process.waitUntilExit()

		let arguments = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self).split(separator: "\n", omittingEmptySubsequences: false).dropLast()

		XCTAssertEqual(arguments.map(String.init), ["app", "run", vm, "foot.desktop", "--start", "--wait", "120", "--connect=unix:///tmp/a b"])
		XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("pwned").path(percentEncoded: false)))
	}

	func testLauncherRefusesToOverwriteUnlessAsked() throws {
		let directory = try self.temporaryDirectory()
		let cakectl = URL(fileURLWithPath: "/x/cakectl")

		try GuestApplicationLauncher.create(vm: "vm", application: self.applications[3], tool: cakectl, in: directory)

		XCTAssertThrowsError(try GuestApplicationLauncher.create(vm: "vm", application: self.applications[3], tool: cakectl, in: directory))
		XCTAssertNoThrow(try GuestApplicationLauncher.create(vm: "vm", application: self.applications[3], tool: cakectl, in: directory, overwrite: true))
	}

	func testLauncherRefusesAHostileIdentifier() throws {
		let directory = try self.temporaryDirectory()
		let hostile = GuestApplication(id: "x.desktop\nrm -rf ~", name: "Evil")

		XCTAssertThrowsError(try GuestApplicationLauncher.create(vm: "vm", application: hostile, tool: URL(fileURLWithPath: "/x/cakectl"), in: directory))
		XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false)), [])
	}

	func testLauncherNameCannotLeaveItsDirectory() throws {
		let directory = try self.temporaryDirectory()
		let sneaky = GuestApplication(id: "x.desktop", name: "../../Evil: App")
		let bundle = try GuestApplicationLauncher.create(vm: "a/b", application: sneaky, tool: URL(fileURLWithPath: "/x/cakectl"), in: directory)

		XCTAssertEqual(bundle.deletingLastPathComponent().standardizedFileURL.path, directory.standardizedFileURL.path)
	}

	// MARK: Terminal applications

	private let terminalGuest = [
		GuestApplication(id: "foot-server.desktop", name: "Foot Server", exec: "foot --server", categories: ["TerminalEmulator"]),
		GuestApplication(id: "foot.desktop", name: "Foot", exec: "foot", categories: ["System", "TerminalEmulator"]),
		GuestApplication(id: "htop.desktop", name: "Htop", exec: "htop", terminal: true, categories: ["System", "Monitor"]),
		GuestApplication(id: "vim.desktop", name: "Vim", exec: "vim %F", terminal: true),
	]

	func testTerminalApplicationRunsInTheGuestsTerminalEmulator() {
		XCTAssertEqual(GuestApplications.terminalCommand(for: self.terminalGuest[2], in: self.terminalGuest), ["foot", "-e", "htop"])
		// Field codes stand for files that aren't passed
		XCTAssertEqual(GuestApplications.terminalCommand(for: self.terminalGuest[3], in: self.terminalGuest), ["foot", "-e", "vim"])
	}

	func testTerminalCommandIsNilWhenNotNeeded() {
		XCTAssertNil(GuestApplications.terminalCommand(for: self.terminalGuest[1], in: self.terminalGuest), "a graphical application runs as it is")
		XCTAssertNil(GuestApplications.terminalCommand(for: self.terminalGuest[2], in: [self.terminalGuest[2]]), "no emulator in the guest")
	}

	func testLaunchWrapsATerminalApplication() throws {
		var lines: [String] = []

		let pid = try GuestApplications.launch(self.terminalGuest[2], among: self.terminalGuest, user: "admin") { line in
			lines.append(line)
			return self.reply(stdout: "77\n")
		}

		XCTAssertEqual(pid, 77)
		XCTAssertEqual(lines, ["/usr/local/bin/cakeagent seamless launch --seamless-user=admin -- 'foot' '-e' 'htop'"])
	}

	// MARK: Icons

	func testIconNamesFromTheGuestAreChecked() {
		XCTAssertTrue(GuestApplications.isValidIconName("foot"))
		XCTAssertTrue(GuestApplications.isValidIconName("org.gnome.gedit"))
		XCTAssertTrue(GuestApplications.isValidIconName("/usr/share/pixmaps/htop.png"))
		// Snap and Flatpak applications name their icon by path
		XCTAssertTrue(GuestApplications.isValidIconName("/snap/firefox/current/default256.png"))
		XCTAssertTrue(GuestApplications.isValidIconName("/var/lib/flatpak/exports/share/icons/hicolor/128x128/apps/org.gimp.GIMP.png"))
		XCTAssertFalse(GuestApplications.isValidIconName("/snap/../etc/shadow"))
		XCTAssertFalse(GuestApplications.isValidIconName("/snapshot/x.png"))
		XCTAssertFalse(GuestApplications.isValidIconName("a b"))
		XCTAssertFalse(GuestApplications.isValidIconName("x;rm -rf /"))
		XCTAssertFalse(GuestApplications.isValidIconName("$(id)"))
		XCTAssertFalse(GuestApplications.isValidIconName("/etc/shadow"))
		XCTAssertFalse(GuestApplications.isValidIconName("/usr/share/icons/../../etc/shadow"))
		XCTAssertFalse(GuestApplications.isValidIconName(String.empty))
	}

	func testBestIconPrefersALargePNGThenSVGThenTheLargestPNG() {
		let big = "/usr/share/icons/hicolor/256x256/apps/x.png"
		let retina = "/usr/share/icons/hicolor/128x128@2/apps/x.png"
		let small = "/usr/share/icons/hicolor/48x48/apps/x.png"
		let svg = "/usr/share/icons/hicolor/scalable/apps/x.svg"

		XCTAssertEqual(GuestApplications.iconSide(of: retina), 256)
		XCTAssertEqual(GuestApplications.bestIcon(among: [small, svg, big]), big)
		XCTAssertEqual(GuestApplications.bestIcon(among: [small, svg]), svg)
		XCTAssertEqual(GuestApplications.bestIcon(among: [small, "/usr/share/pixmaps/x.png"]), small)
		XCTAssertNil(GuestApplications.bestIcon(among: ["/usr/share/icons/x.txt", "relative.png"]))
	}

	func testIconIsReadThroughTwoCommandsAndDecoded() throws {
		let png = Data([0x89, 0x50, 0x4E, 0x47])
		var lines: [String] = []
		let application = GuestApplication(id: "foot.desktop", name: "Foot", icon: "foot")

		let icon = try GuestApplications.icon(for: application) { line in
			lines.append(line)

			return lines.count == 1 ? self.reply(stdout: "/usr/share/icons/hicolor/48x48/apps/foot.png\n/usr/share/icons/hicolor/scalable/apps/foot.svg\n/etc/shadow\n") : self.reply(stdout: png.base64EncodedString(options: .lineLength64Characters))
		}

		XCTAssertEqual(icon, png)
		XCTAssertEqual(lines.count, 2)
		XCTAssertTrue(lines[0].contains("'foot.png'") && lines[0].contains("'foot.svg'"))
		XCTAssertTrue(lines[1].contains("base64 < '/usr/share/icons/hicolor/scalable/apps/foot.svg'"), lines[1])
	}

	func testNoIconIsNotAnError() throws {
		XCTAssertNil(try GuestApplications.icon(for: GuestApplication(id: "a.desktop", name: "A")) { _ in XCTFail("nothing to ask"); return self.reply() })
		XCTAssertNil(try GuestApplications.icon(for: GuestApplication(id: "a.desktop", name: "A", icon: "$(id)")) { _ in XCTFail("nothing to ask"); return self.reply() })
		XCTAssertNil(try GuestApplications.icon(for: GuestApplication(id: "a.desktop", name: "A", icon: "none")) { _ in self.reply() })
	}

	func testLauncherGetsAnIcnsFromTheGuestsIcon() throws {
		let svg = #"<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64"><circle cx="32" cy="32" r="30" fill="red"/></svg>"#
		let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)

		defer { try? FileManager.default.removeItem(at: directory) }

		let bundle = try GuestApplicationLauncher.create(vm: "vm", application: self.applications[3], tool: URL(fileURLWithPath: "/x/caked"), in: directory, icon: Data(svg.utf8))
		let plist = try XCTUnwrap(NSDictionary(contentsOf: bundle.appendingPathComponent("Contents/Info.plist")))

		XCTAssertEqual(plist["CFBundleIconFile"] as? String, "launcher")
		XCTAssertTrue(FileManager.default.fileExists(atPath: bundle.appendingPathComponent("Contents/Resources/launcher.icns").path(percentEncoded: false)))

		let without = try GuestApplicationLauncher.create(vm: "vm2", application: self.applications[3], tool: URL(fileURLWithPath: "/x/caked"), in: directory, icon: Data("not an image".utf8))
		let plain = try XCTUnwrap(NSDictionary(contentsOf: without.appendingPathComponent("Contents/Info.plist")))

		XCTAssertNil(plain["CFBundleIconFile"], "an unreadable icon leaves the generic one")
	}

	func testIconGivenAsAPathIsFetchedWithoutASearch() throws {
		var lines: [String] = []
		let application = GuestApplication(id: "firefox_firefox.desktop", name: "Firefox", icon: "/snap/firefox/current/default256.png")
		let png = Data([1, 2, 3])

		let icon = try GuestApplications.icon(for: application) { line in
			lines.append(line)

			return lines.count == 1 ? self.reply(stdout: "/snap/firefox/current/default256.png\n") : self.reply(stdout: png.base64EncodedString())
		}

		XCTAssertEqual(icon, png)
		XCTAssertEqual(lines.first, "echo '/snap/firefox/current/default256.png'")
	}

	// MARK: Watching a launched process

	func testProcessIdentityIsTheStartTimeOfARunningProcess() {
		XCTAssertEqual(GuestApplications.processIdentity(from: "S 214862\n"), "214862")
		XCTAssertEqual(GuestApplications.processIdentity(from: "R 7"), "7")
	}

	func testProcessIdentityIsNilWhenTheProcessIsGoneOrAZombie() {
		XCTAssertNil(GuestApplications.processIdentity(from: ""))
		XCTAssertNil(GuestApplications.processIdentity(from: "\n"))
		XCTAssertNil(GuestApplications.processIdentity(from: "Z 214862"))
		XCTAssertNil(GuestApplications.processIdentity(from: "X 214862"))
	}

	func testProcessIdentityRejectsAnythingElse() {
		XCTAssertNil(GuestApplications.processIdentity(from: "S"))
		XCTAssertNil(GuestApplications.processIdentity(from: "S 12a"))
		XCTAssertNil(GuestApplications.processIdentity(from: "S 12 34"))
	}

	func testProcessIdentityAsksTheGuestForThatProcess() throws {
		var lines: [String] = []

		let identity = try GuestApplications.processIdentity(pid: 4321) { line in
			lines.append(line)

			return self.reply(stdout: "S 99\n")
		}

		XCTAssertEqual(identity, "99")
		XCTAssertEqual(lines.count, 1)
		XCTAssertTrue(lines[0].contains("/proc/4321/stat"))
	}

	/// A gone process must be an empty answer with exit status 0, or the watch would take it for a failed poll and never
	/// see the process end.
	func testProcessStatusCommandSucceedsWithNoOutputForAGoneProcess() throws {
		let shell = Process()
		let output = Pipe()

		shell.executableURL = URL(fileURLWithPath: "/bin/sh")
		// No PID this high exists, and the host has no /proc at all: the file is missing either way.
		shell.arguments = ["-c", GuestApplications.processStatusCommandLine(pid: 999_999_999)]
		shell.standardOutput = output
		try shell.run()
		shell.waitUntilExit()

		XCTAssertEqual(shell.terminationStatus, 0)
		XCTAssertTrue(output.fileHandleForReading.readDataToEndOfFile().isEmpty)
	}

	func testProcessIdentityIsNilForAnEmptyAnswer() throws {
		XCTAssertNil(try GuestApplications.processIdentity(pid: 4321) { _ in self.reply(stdout: "") })
	}

	func testProcessIdentityThrowsWhenTheGuestCannotRunTheCommand() {
		XCTAssertThrowsError(try GuestApplications.processIdentity(pid: 4321) { _ in self.reply(exit: 127, stderr: "sh: not found") })
	}
}
