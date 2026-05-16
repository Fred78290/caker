import Foundation
import XCTest

@testable import caked

final class LXDIdentityStoreTests: XCTestCase {
	func testHasBearerTokenMatchesStoredBearerIdentityID() async throws {
		let id = UUID().uuidString
		let name = "bearer-\(UUID().uuidString)"

		let created = await LXDIdentityStore.shared.create(
			authenticationMethod: "bearer",
			type: "client",
			id: id,
			name: name,
			groups: [],
			tlsCertificate: ""
		)
		XCTAssertNotNil(created)

		let matchesByID = await LXDIdentityStore.shared.hasBearerToken(id)
		XCTAssertTrue(matchesByID)

		let unknownToken = await LXDIdentityStore.shared.hasBearerToken(UUID().uuidString)
		XCTAssertFalse(unknownToken)

		_ = await LXDIdentityStore.shared.delete(authMethod: "bearer", nameOrID: id)
	}

	func testHasBearerTokenIgnoresNonBearerIdentities() async throws {
		let id = UUID().uuidString
		let name = "tls-\(UUID().uuidString)"

		let created = await LXDIdentityStore.shared.create(
			authenticationMethod: "tls",
			type: "client",
			id: id,
			name: name,
			groups: [],
			tlsCertificate: ""
		)
		XCTAssertNotNil(created)

		let matches = await LXDIdentityStore.shared.hasBearerToken(id)
		XCTAssertFalse(matches)

		_ = await LXDIdentityStore.shared.delete(authMethod: "tls", nameOrID: id)
	}
}
