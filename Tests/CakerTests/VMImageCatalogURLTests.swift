import XCTest

@testable import CakedLib

final class VMImageCatalogURLTests: XCTestCase {
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
			#if arch(arm64)
				// A macOS install has its own, higher minimums than the Linux conventions above. Every entry
				// declares them (the fields aren't optional) and `BuildOptions.resolveImageId` raises a build's
				// cpu/memory to them, so what matters is that they are real, not that they are absent.
				for entry in archCatalog.ipsw {
					XCTAssertGreaterThanOrEqual(entry.minCPU, 4, "\(entry.id) is a macOS install")
					XCTAssertGreaterThanOrEqual(entry.minMemoryMiB, 4096, "\(entry.id) is a macOS install")
				}
			#endif
		}
	}

	func testAllISOAndCloudImageURLsAreReachable() async throws {
		// Some cloud images (Gentoo) are republished under a new dated name, so what is built is the URL their
		// manifest names (`latestImageSources`), not the one pinned in VMImages.json. Resolve them first, so
		// the test follows what a build downloads and also reads the real manifests.
		VMImageCatalog.resetLatestImages()
		defer { VMImageCatalog.resetLatestImages() }

		await VMImageCatalog.refreshLatestImages()

		let catalog = VMImageCatalog.shared
		// Only the manifest of this host's architecture is read (the other one isn't offered here), so the
		// pinned URL of the other architecture's manifest-resolved images is a fallback nothing uses, and it
		// goes stale by design: it is not checked.
		#if arch(arm64)
			let otherArch = "amd64"
		#else
			let otherArch = "arm64"
		#endif
		let resolvedIDs = Set(VMImageCatalog.latestImageSources.map(\.id))
		func unresolved(_ archCatalog: VMImageArchCatalog, arch: String) -> [VMImageEntry] {
			archCatalog.iso + archCatalog.cloud.filter { arch != otherArch || resolvedIDs.contains($0.id) == false }
		}

		// Check both architecture nodes, not just `current` — `.shared.availableISOImages`/etc. only
		// expose whichever arch this test happens to run on.
		let entries = unresolved(catalog.arm64, arch: "arm64") + unresolved(catalog.amd64, arch: "amd64")

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
