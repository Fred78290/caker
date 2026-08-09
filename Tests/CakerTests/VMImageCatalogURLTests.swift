import XCTest

@testable import caker

final class VMImageCatalogURLTests: XCTestCase {
	func testFedora41DesktopIsOnlyPublishedForAmd64() throws {
		let catalog = VMImageCatalog.shared

		XCTAssertNil(catalog.arm64.iso.first(where: { $0.id == "fedora41Desktop" }), "Fedora 41 Workstation has no aarch64 ISO upstream")
		XCTAssertNotNil(catalog.amd64.iso.first(where: { $0.id == "fedora41Desktop" }))
	}

	func testMinimumResourcesMatchDesktopServerConvention() throws {
		for archCatalog in [VMImageCatalog.shared.arm64, VMImageCatalog.shared.amd64] {
			for entry in archCatalog.iso {
				if entry.id.contains("Desktop") {
					XCTAssertEqual(entry.minCPU, 4, "\(entry.id) is a desktop ISO")
					XCTAssertEqual(entry.minMemoryMiB, 4096, "\(entry.id) is a desktop ISO")
				} else {
					XCTAssertEqual(entry.minCPU, 2, "\(entry.id) is a server/installer ISO")
					XCTAssertEqual(entry.minMemoryMiB, 2048, "\(entry.id) is a server/installer ISO")
				}
			}

			for entry in archCatalog.cloud {
				XCTAssertEqual(entry.minCPU, 2, "\(entry.id) is a headless cloud image")
				XCTAssertEqual(entry.minMemoryMiB, 2048, "\(entry.id) is a headless cloud image")
			}

			for entry in archCatalog.ipsw {
				XCTAssertNil(entry.minCPU, "\(entry.id) is a macOS install; it uses its own fixed minimums")
				XCTAssertNil(entry.minMemoryMiB, "\(entry.id) is a macOS install; it uses its own fixed minimums")
			}
		}
	}

	func testAllISOAndCloudImageURLsAreReachable() async throws {
		let catalog = VMImageCatalog.shared
		// Check both architecture nodes, not just `current` — `.shared.availableISOImages`/etc. only
		// expose whichever arch this test happens to run on.
		let entries = catalog.arm64.iso + catalog.arm64.cloud + catalog.amd64.iso + catalog.amd64.cloud

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
					(entry.url, await Self.reachabilityFailureReason(entry.url))
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
