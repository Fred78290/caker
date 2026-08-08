import XCTest

@testable import caker

final class VMImageCatalogURLTests: XCTestCase {
	func testAllISOAndCloudImageURLsAreReachable() async throws {
		let catalog = VMImageCatalog.shared
		let entries = catalog.availableISOImages + catalog.availableCloudImages

		XCTAssertFalse(entries.isEmpty)

		var failures: [String] = []
		let maxConcurrentRequests = 8

		await withTaskGroup(of: (String, String?).self) { group in
			var pendingEntries = entries.makeIterator()

			func addNextTask() {
				guard let entry = pendingEntries.next() else {
					return
				}

				group.addTask {
					(entry.resolvedURL, await Self.reachabilityFailureReason(entry.resolvedURL))
				}
			}

			for _ in 0..<maxConcurrentRequests {
				addNextTask()
			}

			while let (url, failureReason) = await group.next() {
				if let failureReason {
					failures.append("\(url): \(failureReason)")
				}

				addNextTask()
			}
		}

		XCTAssertTrue(failures.isEmpty, "Unreachable image URLs:\n\(failures.sorted().joined(separator: "\n"))")
	}

	private static func reachabilityFailureReason(_ urlString: String) async -> String? {
		guard let url = URL(string: urlString) else {
			return "not a valid URL"
		}

		var request = URLRequest(url: url, timeoutInterval: 30)
		request.httpMethod = "HEAD"

		do {
			let (_, response) = try await URLSession.shared.data(for: request)

			guard let http = response as? HTTPURLResponse else {
				return "response is not an HTTP response"
			}

			return (200..<400).contains(http.statusCode) ? nil : "unexpected status code \(http.statusCode)"
		} catch {
			return "request failed: \(error.localizedDescription)"
		}
	}
}
