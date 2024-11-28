struct CI {
	private static let rawVersion = "${VERSION_TAG}"

	static var version: String {
		rawVersion.expanded() ? rawVersion : "SNAPSHOT"
	}

	static var release: String? {
		rawVersion.expanded() ? "caker@\(rawVersion)" : nil
	}
}

private extension String {
	func expanded() -> Bool {
		!isEmpty && !starts(with: "$")
	}
}
