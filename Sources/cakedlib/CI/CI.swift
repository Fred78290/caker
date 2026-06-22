import Foundation

public struct CI {
	public static var version: String {
		Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "SNAPSHOT"
	}

	private static var appName: String {
		ProcessInfo.processInfo.processName
	}

	public static var release: String {
		"\(appName)@\(version)"
	}
}

extension String {
	fileprivate func expanded() -> Bool {
		!isEmpty && !starts(with: "$")
	}
}
