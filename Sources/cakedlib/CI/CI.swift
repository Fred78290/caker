import Foundation

public struct CI {
	private static let rawVersion = "${VERSION}"

	public static var version: String {
		rawVersion.expanded() ? rawVersion : "SNAPSHOT"
	}

	private static var appName: String {
		ProcessInfo.processInfo.processName
	}

	public static var release: String? {
		rawVersion.expanded() ? "\(appName)@\(rawVersion)" : nil
	}
}

extension String {
	fileprivate func expanded() -> Bool {
		!isEmpty && !starts(with: "$")
	}
}
