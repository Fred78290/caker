import Foundation

/// One `<item>` of a Sparkle appcast, reduced to what a release check needs.
///
/// Caker's feeds put the version on the enclosure (`Scripts/sparkle-sign-release.sh`) or as
/// `<sparkle:version>` elements (`Scripts/sparkle-generate-appcast-xml.sh`); both are read, as Sparkle does.
public struct AppcastItem: Equatable, Sendable {
	/// `sparkle:version`, the release's `CFBundleVersion` — what `CI.version` is compared against.
	public var version: String
	public var shortVersion: String?
	public var title: String?
	public var link: String?
	public var publishedAt: String?
	public var downloadURL: String?
	public var minimumSystemVersion: String?
	public var os: String?

	public init(version: String, shortVersion: String? = nil, title: String? = nil, link: String? = nil, publishedAt: String? = nil, downloadURL: String? = nil, minimumSystemVersion: String? = nil, os: String? = nil) {
		self.version = version
		self.shortVersion = shortVersion
		self.title = title
		self.link = link
		self.publishedAt = publishedAt
		self.downloadURL = downloadURL
		self.minimumSystemVersion = minimumSystemVersion
		self.os = os
	}

	public var displayVersion: String {
		self.shortVersion ?? self.version
	}
}

public enum Appcast {
	/// Items without a version are dropped, as Sparkle drops them.
	public static func parse(_ data: Data) throws -> [AppcastItem] {
		let delegate = AppcastParserDelegate()
		let parser = XMLParser(data: data)

		parser.delegate = delegate

		guard parser.parse() else {
			throw parser.parserError ?? ServiceError(String(localized: "Unable to parse the release feed"))
		}

		return delegate.items
	}
}

private final class AppcastParserDelegate: NSObject, XMLParserDelegate {
	var items: [AppcastItem] = []

	// Element texts and enclosure attributes of the <item> being read, nil outside an item.
	// Element and attribute names keep their `sparkle:` prefix, like Sparkle's own parser.
	private var fields: [String: String]? = nil
	private var enclosure: [String: String] = [:]
	private var text = ""

	func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
		if elementName == "item" {
			self.fields = [:]
			self.enclosure = [:]
		} else if self.fields != nil && elementName == "enclosure" {
			self.enclosure = attributeDict
		}

		self.text = ""
	}

	func parser(_ parser: XMLParser, foundCharacters string: String) {
		self.text += string
	}

	func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
		self.text += String(decoding: CDATABlock, as: UTF8.self)
	}

	func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
		guard var fields = self.fields else {
			return
		}

		if elementName == "item" {
			if let item = self.makeItem(fields) {
				self.items.append(item)
			}

			self.fields = nil
		} else {
			let value = self.text.trimmingCharacters(in: .whitespacesAndNewlines)

			if value.isEmpty == false && fields[elementName] == nil {
				fields[elementName] = value
			}

			self.fields = fields
		}

		self.text = ""
	}

	private func makeItem(_ fields: [String: String]) -> AppcastItem? {
		guard let version = self.enclosure["sparkle:version"] ?? fields["sparkle:version"], version.isEmpty == false else {
			return nil
		}

		return AppcastItem(
			version: version,
			shortVersion: self.enclosure["sparkle:shortVersionString"] ?? fields["sparkle:shortVersionString"],
			title: fields["title"],
			link: fields["link"],
			publishedAt: fields["pubDate"],
			downloadURL: self.enclosure["url"],
			minimumSystemVersion: fields["sparkle:minimumSystemVersion"],
			os: self.enclosure["sparkle:os"])
	}
}

/// Port of Sparkle's `SUStandardVersionComparator`, so a release check orders versions exactly as
/// Caker.app's updater does: numbers compare numerically, a trailing string part makes a version
/// older (`1.0b1` < `1.0`) and a trailing number part makes it newer (`1.0` < `1.0.1`).
public enum SparkleVersionComparator {
	private enum Kind {
		case number
		case string
		case separator
	}

	private static func kind(of character: Character) -> Kind {
		if character.isASCII && character.isNumber {
			return .number
		} else if character.isWhitespace || character.isPunctuation {
			return .separator
		}

		return .string
	}

	static func split(_ version: String) -> [String] {
		var parts: [String] = []
		var current = ""
		var currentKind: Kind? = nil

		for character in version {
			let kind = Self.kind(of: character)

			if let currentKind, kind != currentKind || kind == .separator {
				parts.append(current)
				current = ""
			}

			current.append(character)
			currentKind = kind
		}

		if current.isEmpty == false {
			parts.append(current)
		}

		return parts
	}

	// Digit strings are compared without converting them, so no length overflows.
	private static func compareNumbers(_ lhs: Substring, _ rhs: Substring) -> ComparisonResult {
		let lhs = lhs.drop { $0 == "0" }
		let rhs = rhs.drop { $0 == "0" }

		if lhs.count != rhs.count {
			return lhs.count < rhs.count ? .orderedAscending : .orderedDescending
		} else if lhs != rhs {
			return lhs < rhs ? .orderedAscending : .orderedDescending
		}

		return .orderedSame
	}

	public static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
		let partsA = Self.split(lhs)
		let partsB = Self.split(rhs)

		for (partA, partB) in zip(partsA, partsB) {
			let kindA = Self.kind(of: partA.first!)
			let kindB = Self.kind(of: partB.first!)

			if kindA == kindB {
				switch kindA {
				case .number:
					let result = Self.compareNumbers(partA[...], partB[...])

					if result != .orderedSame {
						return result
					}
				case .string:
					if partA != partB {
						return partA < partB ? .orderedAscending : .orderedDescending
					}
				case .separator:
					continue
				}
			} else if kindA != .string && kindB == .string {
				return .orderedDescending
			} else if kindA == .string && kindB != .string {
				return .orderedAscending
			} else {
				// A number against a separator: the separator is invalid.
				return kindA == .number ? .orderedDescending : .orderedAscending
			}
		}

		if partsA.count != partsB.count {
			let aIsLonger = partsA.count > partsB.count
			let extraPart = aIsLonger ? partsA[partsB.count] : partsB[partsA.count]
			let longerWins = Self.kind(of: extraPart.first!) != .string

			return aIsLonger == longerWins ? .orderedDescending : .orderedAscending
		}

		return .orderedSame
	}
}

public struct ReleaseUpdateStatus: Codable, Equatable, Sendable, CustomStringConvertible {
	public let currentVersion: String
	public let latestVersion: String?
	public let updateAvailable: Bool
	public let downloadURL: String?
	public let releaseNotesURL: String?
	public let publishedAt: String?
	public let feedURL: String

	public var description: String {
		guard let latestVersion = self.latestVersion else {
			return String(format: String(localized: "No release for this Mac was found in %@."), self.feedURL)
		}

		guard ReleaseUpdateChecker.isKnownVersion(self.currentVersion) else {
			return String(format: String(localized: "The latest release is Caker %1$@. This build has no version (%2$@), so it can't be compared."), latestVersion, self.currentVersion)
		}

		guard self.updateAvailable else {
			return String(format: String(localized: "Caker %@ is up to date."), self.currentVersion)
		}

		var lines = [String(format: String(localized: "Caker %1$@ is available (installed: %2$@)."), latestVersion, self.currentVersion)]

		if let releaseNotesURL = self.releaseNotesURL {
			lines.append(String(format: String(localized: "Release notes: %@"), releaseNotesURL))
		}

		if let downloadURL = self.downloadURL {
			lines.append(String(format: String(localized: "Download: %@"), downloadURL))
		}

		return lines.joined(separator: "\n")
	}
}

/// The command-line counterpart of Caker.app's Sparkle "Check for Updates…": reads the same appcast
/// and reports whether it lists a newer release than this binary. It only reports — installing is
/// left to Caker.app or to downloading the release, since caked and cakectl ship inside Caker.app.
public enum ReleaseUpdateChecker {
	public static let defaultFeedURL = URL(string: "https://caker.aldunelabs.com/appcast/appcast.xml")!

	/// `SUFeedURL` from the running bundle's Info.plist. `Scripts/build.inc.sh` writes the same
	/// channel-dependent feed there for caked and cakectl as for Caker.app; a build without it
	/// (plain `swift build`, Xcode) falls back to the release channel, like Caker.app's own Info.plist.
	public static var feedURL: URL {
		if let value = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String, let url = URL(string: value), url.scheme != nil {
			return url
		}

		return Self.defaultFeedURL
	}

	/// `false` for a binary without a stamped bundle version: no Info.plist (`CI.version` is
	/// "SNAPSHOT") or an Info.plist whose `${VERSION}` placeholder was never substituted.
	public static func isKnownVersion(_ version: String) -> Bool {
		version.isEmpty == false && version != "SNAPSHOT" && version.hasPrefix("$") == false
	}

	static var systemVersion: String {
		let version = ProcessInfo.processInfo.operatingSystemVersion

		return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
	}

	/// The newest item this Mac can install. Like Sparkle, items for another OS or that need a
	/// newer macOS are skipped.
	public static func latestItem(in items: [AppcastItem], systemVersion: String) -> AppcastItem? {
		items.filter { item in
			if let os = item.os, os.lowercased() != "macos" {
				return false
			}

			if let minimum = item.minimumSystemVersion, SparkleVersionComparator.compare(minimum, systemVersion) == .orderedDescending {
				return false
			}

			return true
		}.max {
			SparkleVersionComparator.compare($0.version, $1.version) == .orderedAscending
		}
	}

	public static func status(currentVersion: String, items: [AppcastItem], systemVersion: String, feedURL: URL) -> ReleaseUpdateStatus {
		let latest = Self.latestItem(in: items, systemVersion: systemVersion)
		let updateAvailable: Bool

		if let latest, Self.isKnownVersion(currentVersion) {
			updateAvailable = SparkleVersionComparator.compare(currentVersion, latest.version) == .orderedAscending
		} else {
			updateAvailable = false
		}

		return ReleaseUpdateStatus(
			currentVersion: currentVersion,
			latestVersion: latest?.displayVersion,
			updateAvailable: updateAvailable,
			downloadURL: latest?.downloadURL,
			releaseNotesURL: latest?.link,
			publishedAt: latest?.publishedAt,
			feedURL: feedURL.absoluteString)
	}

	public static func check(feedURL: URL = Self.feedURL, currentVersion: String = CI.version, timeout: TimeInterval = 30) async throws -> ReleaseUpdateStatus {
		let request = URLRequest(url: feedURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
		let (data, response) = try await URLSession.shared.data(for: request)

		if let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) == false {
			throw ServiceError(String(format: String(localized: "Unable to read the release feed %1$@: HTTP status %2$d"), feedURL.absoluteString, response.statusCode))
		}

		return Self.status(currentVersion: currentVersion, items: try Appcast.parse(data), systemVersion: Self.systemVersion, feedURL: feedURL)
	}
}
