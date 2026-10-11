//
//  CakerEnvTests.swift
//  CakerTests
//

import XCTest
import Foundation
import GRPCLib

@testable import CakedLib

final class CakerEnvTests: XCTestCase {

	// MARK: - Helpers

	private func load(_ content: String) throws -> CakerEnv {
		let tmp = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString + ".cakerenv")
		try content.write(to: tmp, atomically: true, encoding: .utf8)
		defer { try? FileManager.default.removeItem(at: tmp) }
		return try CakerEnv.load(fromFile: tmp.path)
	}

	/// Build options for every VM, through `startOrder` — the same path `caked up`/`cakectl up` take.
	private func buildOptions(_ env: CakerEnv) throws -> [String: BuildOptions] {
		var result: [String: BuildOptions] = [:]

		for (name, vm) in try env.startOrder() {
			result[name] = try vm.toBuildOptions(name: name)
		}

		return result
	}

	// MARK: - user / password

	func testMultiVMUserAndPasswordReachBuildOptions() throws {
		let env = try load("""
		vms:
		  app:
		    image: ubuntu:24.04
		    user: ubuntu
		    password: secret
		  db:
		    image: ubuntu:24.04
		    user: postgres
		    password: other
		""")
		let opts = try buildOptions(env)

		XCTAssertEqual(opts["app"]?.user, "ubuntu")
		XCTAssertEqual(opts["app"]?.password, "secret")
		XCTAssertEqual(opts["db"]?.user, "postgres")
		XCTAssertEqual(opts["db"]?.password, "other")
	}

	func testSingleVMUserAndPasswordReachBuildOptions() throws {
		let env = try load("""
		name: myapp
		image: ubuntu:24.04
		user: ubuntu
		password: secret
		""")
		let opts = try buildOptions(env)

		XCTAssertEqual(opts.count, 1)
		XCTAssertEqual(opts["myapp"]?.user, "ubuntu")
		XCTAssertEqual(opts["myapp"]?.password, "secret")

		let direct = try env.toBuildOptions(name: "myapp")
		XCTAssertEqual(direct.user, "ubuntu")
		XCTAssertEqual(direct.password, "secret")
	}

	func testUserAndPasswordDefaultToAdmin() throws {
		let env = try load("""
		vms:
		  app:
		    image: ubuntu:24.04
		""")
		let opts = try buildOptions(env)

		XCTAssertEqual(opts["app"]?.user, "admin")
		XCTAssertEqual(opts["app"]?.password, "admin")
	}

	func testUserWithoutPasswordKeepsDefaultPassword() throws {
		let env = try load("""
		vms:
		  app:
		    image: ubuntu:24.04
		    user: ubuntu
		""")
		let opts = try buildOptions(env)

		XCTAssertEqual(opts["app"]?.user, "ubuntu")
		XCTAssertEqual(opts["app"]?.password, "admin")
	}

	/// The template written by `init` sets `user: ubuntu` / `password: ubuntu` on every VM; they must be applied.
	func testTemplateUserAndPasswordReachBuildOptions() throws {
		let opts = try buildOptions(load(CakerEnv.template))

		XCTAssertEqual(Set(opts.keys), ["app", "database"])

		for (name, options) in opts {
			XCTAssertEqual(options.user, "ubuntu", name)
			XCTAssertEqual(options.password, "ubuntu", name)
		}
	}
}
