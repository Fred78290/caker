struct CI {
	private static let rawVersion = "${VERSION_TAG}"

	static var version: String {
		rawVersion.expanded() ? rawVersion : "SNAPSHOT"
	}

	static var release: String? {
		rawVersion.expanded() ? "tartctl@\(rawVersion)" : nil
	}
}

extension String {
	fileprivate func expanded() -> Bool {
		!isEmpty && !starts(with: "$")
	}
}
