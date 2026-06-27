//
//  ComposeTest.swift
//  CakerTests
//

import XCTest
import Foundation
import Yams

@testable import CakedLib
@testable import cakectl

final class ComposeTest: XCTestCase {

	// MARK: - Helpers

	private func yaml(_ content: String) -> String { content }

	private func load(_ content: String) throws -> ComposeFile {
		let tmp = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString + ".yml")
		try content.write(to: tmp, atomically: true, encoding: .utf8)
		defer { try? FileManager.default.removeItem(at: tmp) }
		return try ComposeFile.load(fromFile: tmp.path)
	}

	// MARK: - Parsing

	func testLoadMinimalCompose() throws {
		let f = try load(yaml("""
		name: my-project
		services:
		  web:
		    image: ubuntu:24.04
		"""))
		XCTAssertEqual(f.name, "my-project")
		XCTAssertNotNil(f.services["web"])
		XCTAssertEqual(f.services["web"]?.image, "ubuntu:24.04")
	}

	func testLoadWithVersion() throws {
		let f = try load(yaml("""
		name: versioned
		version: "3.8"
		services:
		  app:
		    image: ubuntu:22.04
		"""))
		XCTAssertEqual(f.version, "3.8")
	}

	func testMissingFileThrows() {
		XCTAssertThrowsError(try ComposeFile.load(fromFile: "/nonexistent/path/compose.yml"))
	}

	// MARK: - DependsOn decoding

	func testDependsOnList() throws {
		let f = try load(yaml("""
		name: p
		services:
		  a:
		    image: ubuntu:24.04
		  b:
		    image: ubuntu:24.04
		    depends_on:
		      - a
		"""))
		let deps = f.services["b"]?.dependsOn?.serviceNames ?? []
		XCTAssertEqual(deps, ["a"])
	}

	func testDependsOnConditionMap() throws {
		let f = try load(yaml("""
		name: p
		services:
		  a:
		    image: ubuntu:24.04
		  b:
		    image: ubuntu:24.04
		    depends_on:
		      a:
		        condition: service_healthy
		"""))
		let deps = f.services["b"]?.dependsOn?.serviceNames ?? []
		XCTAssertEqual(deps, ["a"])
	}

	// MARK: - Environment decoding

	func testEnvironmentList() throws {
		let f = try load(yaml("""
		name: p
		services:
		  app:
		    image: ubuntu:24.04
		    environment:
		      - FOO=bar
		      - BAZ=qux
		"""))
		let lines = f.services["app"]?.environment?.lines ?? []
		XCTAssertTrue(lines.contains("FOO=bar"))
		XCTAssertTrue(lines.contains("BAZ=qux"))
	}

	func testEnvironmentMap() throws {
		let f = try load(yaml("""
		name: p
		services:
		  app:
		    image: ubuntu:24.04
		    environment:
		      KEY: value
		      EMPTY:
		"""))
		let lines = f.services["app"]?.environment?.lines ?? []
		XCTAssertTrue(lines.contains("KEY=value"))
		XCTAssertTrue(lines.contains("EMPTY="))
	}

	// MARK: - Port decoding

	func testPortShortString() throws {
		let f = try load(yaml("""
		name: p
		services:
		  app:
		    image: ubuntu:24.04
		    ports:
		      - "8080:80"
		      - "443:443/tcp"
		"""))
		let ports = f.services["app"]?.ports?.compactMap { $0.portString } ?? []
		XCTAssertTrue(ports.contains("8080:80"))
		XCTAssertTrue(ports.contains("443:443/tcp"))
	}

	func testPortLongForm() throws {
		let f = try load(yaml("""
		name: p
		services:
		  app:
		    image: ubuntu:24.04
		    ports:
		      - target: 80
		        published: 8080
		        protocol: tcp
		"""))
		let ports = f.services["app"]?.ports?.compactMap { $0.portString } ?? []
		XCTAssertEqual(ports, ["8080:80/tcp"])
	}

	// MARK: - Volume decoding

	func testVolumeShortString() throws {
		let f = try load(yaml("""
		name: p
		services:
		  app:
		    image: ubuntu:24.04
		    volumes:
		      - ".:/workspace"
		"""))
		let mounts = f.services["app"]?.volumes?.compactMap { $0.mountString } ?? []
		XCTAssertEqual(mounts, [".:/workspace"])
	}

	func testVolumeLongForm() throws {
		let f = try load(yaml("""
		name: p
		services:
		  app:
		    image: ubuntu:24.04
		    volumes:
		      - type: bind
		        source: /host/path
		        target: /container/path
		"""))
		let mounts = f.services["app"]?.volumes?.compactMap { $0.mountString } ?? []
		XCTAssertEqual(mounts, ["/host/path:/container/path"])
	}

	// MARK: - Deploy / Resources decoding

	func testDeployResources() throws {
		let f = try load(yaml("""
		name: p
		services:
		  app:
		    image: ubuntu:24.04
		    deploy:
		      resources:
		        limits:
		          cpus: "4"
		          memory: 4096M
		"""))
		XCTAssertEqual(f.services["app"]?.deploy?.resources?.limits?.cpus, "4")
		XCTAssertEqual(f.services["app"]?.deploy?.resources?.limits?.memory, "4096M")
	}

	// MARK: - startOrder (topological sort)

	func testStartOrderNoDeps() throws {
		let f = try load(yaml("""
		name: p
		services:
		  a:
		    image: ubuntu:24.04
		  b:
		    image: ubuntu:24.04
		"""))
		let order = try f.startOrder()
		XCTAssertEqual(Set(order.map { $0.name }), Set(["a", "b"]))
	}

	func testStartOrderRespectsDependsOn() throws {
		let f = try load(yaml("""
		name: p
		services:
		  app:
		    image: ubuntu:24.04
		    depends_on:
		      - db
		  db:
		    image: ubuntu:24.04
		"""))
		let names = try f.startOrder().map { $0.name }
		let dbIndex = try XCTUnwrap(names.firstIndex(of: "db"))
		let appIndex = try XCTUnwrap(names.firstIndex(of: "app"))
		XCTAssertLessThan(dbIndex, appIndex)
	}

	func testStartOrderLinearChain() throws {
		let f = try load(yaml("""
		name: p
		services:
		  c:
		    image: ubuntu:24.04
		    depends_on: [b]
		  b:
		    image: ubuntu:24.04
		    depends_on: [a]
		  a:
		    image: ubuntu:24.04
		"""))
		let names = try f.startOrder().map { $0.name }
		XCTAssertEqual(names, ["a", "b", "c"])
	}

	func testStartOrderThrowsOnCycle() throws {
		let f = try load(yaml("""
		name: p
		services:
		  a:
		    image: ubuntu:24.04
		    depends_on: [b]
		  b:
		    image: ubuntu:24.04
		    depends_on: [a]
		"""))
		XCTAssertThrowsError(try f.startOrder())
	}

	func testStartOrderThrowsOnMissingDep() throws {
		let f = try load(yaml("""
		name: p
		services:
		  app:
		    image: ubuntu:24.04
		    depends_on: [missing]
		"""))
		XCTAssertThrowsError(try f.startOrder())
	}

	// MARK: - downOrder

	func testDownOrderIsReversedStartOrder() throws {
		let f = try load(yaml("""
		name: p
		services:
		  app:
		    image: ubuntu:24.04
		    depends_on: [db]
		  db:
		    image: ubuntu:24.04
		"""))
		let start = try f.startOrder().map { $0.name }
		let down = try f.downOrder().map { $0.name }
		XCTAssertEqual(down, start.reversed())
	}

	// MARK: - resolvedServices / filter

	func testResolvedServicesFilterByName() throws {
		let f = try load(yaml("""
		name: p
		services:
		  a:
		    image: ubuntu:24.04
		  b:
		    image: ubuntu:24.04
		  c:
		    image: ubuntu:24.04
		"""))
		let names = try f.resolvedServices(filter: ["a", "c"]).map { $0.name }
		XCTAssertEqual(Set(names), Set(["a", "c"]))
	}

	func testResolvedServicesThrowsOnUnknownService() throws {
		let f = try load(yaml("""
		name: p
		services:
		  a:
		    image: ubuntu:24.04
		"""))
		XCTAssertThrowsError(try f.resolvedServices(filter: ["a", "unknown"]))
	}

	// MARK: - Caker VM extensions

	func testVMExtensionFields() throws {
		let f = try load(yaml("""
		name: p
		services:
		  app:
		    image: ubuntu:24.04
		    disk: 20
		    user: admin
		    password: secret
		    nested: true
		    autostart: false
		"""))
		let svc = try XCTUnwrap(f.services["app"])
		XCTAssertEqual(svc.disk, 20)
		XCTAssertEqual(svc.user, "admin")
		XCTAssertEqual(svc.password, "secret")
		XCTAssertEqual(svc.nested, true)
		XCTAssertEqual(svc.autostart, false)
	}

	// MARK: - Template round-trip

	func testTemplateParsesWithoutError() throws {
		let tmp = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString + ".yml")
		try ComposeFile.template.write(to: tmp, atomically: true, encoding: .utf8)
		defer { try? FileManager.default.removeItem(at: tmp) }

		XCTAssertNoThrow(try ComposeFile.load(fromFile: tmp.path))
	}

	func testTemplateHasExpectedServices() throws {
		let tmp = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString + ".yml")
		try ComposeFile.template.write(to: tmp, atomically: true, encoding: .utf8)
		defer { try? FileManager.default.removeItem(at: tmp) }

		let f = try ComposeFile.load(fromFile: tmp.path)
		XCTAssertTrue(f.services.keys.contains("app"))
		XCTAssertTrue(f.services.keys.contains("database"))
	}

	// MARK: - ComposeInit command

	func testComposeInitCreatesFile() throws {
		let tempDir = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: tempDir) }

		let saved = FileManager.default.currentDirectoryPath
		FileManager.default.changeCurrentDirectoryPath(tempDir.path)
		defer { FileManager.default.changeCurrentDirectoryPath(saved) }

		var cmd = ComposeInit()
		cmd.force = false
		XCTAssertNoThrow(try cmd.run())

		let dest = tempDir.appendingPathComponent(ComposeFile.filename)
		XCTAssertTrue(FileManager.default.fileExists(atPath: dest.path))
	}

	func testComposeInitWritesValidYAML() throws {
		let tempDir = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: tempDir) }

		let saved = FileManager.default.currentDirectoryPath
		FileManager.default.changeCurrentDirectoryPath(tempDir.path)
		defer { FileManager.default.changeCurrentDirectoryPath(saved) }

		var cmd = ComposeInit()
		cmd.force = false
		try cmd.run()

		let dest = tempDir.appendingPathComponent(ComposeFile.filename)
		XCTAssertNoThrow(try ComposeFile.load(fromFile: dest.path))
	}

	func testComposeInitFailsIfFileExists() throws {
		let tempDir = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: tempDir) }

		let dest = tempDir.appendingPathComponent(ComposeFile.filename)
		try "existing".write(to: dest, atomically: true, encoding: .utf8)

		let saved = FileManager.default.currentDirectoryPath
		FileManager.default.changeCurrentDirectoryPath(tempDir.path)
		defer { FileManager.default.changeCurrentDirectoryPath(saved) }

		var cmd = ComposeInit()
		cmd.force = false
		XCTAssertThrowsError(try cmd.run())
	}

	func testComposeInitForceOverwritesExistingFile() throws {
		let tempDir = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
		defer { try? FileManager.default.removeItem(at: tempDir) }

		let dest = tempDir.appendingPathComponent(ComposeFile.filename)
		try "existing".write(to: dest, atomically: true, encoding: .utf8)

		let saved = FileManager.default.currentDirectoryPath
		FileManager.default.changeCurrentDirectoryPath(tempDir.path)
		defer { FileManager.default.changeCurrentDirectoryPath(saved) }

		var cmd = ComposeInit()
		cmd.force = true
		XCTAssertNoThrow(try cmd.run())

		let content = try String(contentsOf: dest, encoding: .utf8)
		XCTAssertNotEqual(content, "existing")
	}

	// MARK: - ComposeHandler — ps (no VMs provisioned)

	func testHandlerPsReturnsNotFoundForUnprovisionedServices() throws {
		var svc = ComposeService()
		svc.image = "ubuntu:24.04"
		let compose = ComposeFile(name: "test-ps", services: ["web": svc])

		let reply = ComposeHandler.ps(compose: compose, services: [], runMode: .user)

		XCTAssertTrue(reply.success)
		XCTAssertEqual(reply.name, "test-ps")
		let info = try XCTUnwrap(reply.services.first { $0.name == "web" })
		XCTAssertEqual(info.status, "not found")
		XCTAssertFalse(info.running)
	}

	func testHandlerPsReportsImageFromSpec() throws {
		var svc = ComposeService()
		svc.image = "ubuntu:22.04"
		let compose = ComposeFile(name: "test-ps-image", services: ["db": svc])

		let reply = ComposeHandler.ps(compose: compose, services: [], runMode: .user)

		XCTAssertTrue(reply.success)
		let info = try XCTUnwrap(reply.services.first { $0.name == "db" })
		XCTAssertEqual(info.image, "ubuntu:22.04")
	}

	func testHandlerPsFiltersToRequestedServices() throws {
		var a = ComposeService(); a.image = "ubuntu:24.04"
		var b = ComposeService(); b.image = "ubuntu:24.04"
		let compose = ComposeFile(name: "test-ps-filter", services: ["a": a, "b": b])

		let reply = ComposeHandler.ps(compose: compose, services: ["a"], runMode: .user)

		XCTAssertTrue(reply.success)
		XCTAssertEqual(reply.services.count, 1)
		XCTAssertEqual(reply.services.first?.name, "a")
	}

	func testHandlerPsFailsOnUnknownServiceFilter() throws {
		var svc = ComposeService(); svc.image = "ubuntu:24.04"
		let compose = ComposeFile(name: "test-ps-unknown", services: ["web": svc])

		let reply = ComposeHandler.ps(compose: compose, services: ["missing"], runMode: .user)

		XCTAssertFalse(reply.success)
		XCTAssertFalse(reply.reason.isEmpty)
	}

	// MARK: - ComposeHandler — down (no VMs provisioned)

	func testHandlerDownSucceedsWithUnprovisionedServices() throws {
		var svc = ComposeService(); svc.image = "ubuntu:24.04"
		let compose = ComposeFile(name: "test-down", services: ["web": svc])

		let reply = ComposeHandler.down(compose: compose, services: [], force: false, runMode: .user)

		XCTAssertTrue(reply.success)
		XCTAssertEqual(reply.name, "test-down")
	}

	func testHandlerDownRespectsDownOrder() throws {
		var db = ComposeService(); db.image = "ubuntu:24.04"
		var app = ComposeService(); app.image = "ubuntu:24.04"
		app.dependsOn = .list(["db"])
		let compose = ComposeFile(name: "test-down-order", services: ["app": app, "db": db])

		// downOrder is the reverse of startOrder — must not throw a cycle or missing-dep error
		let reply = ComposeHandler.down(compose: compose, services: [], force: false, runMode: .user)

		XCTAssertTrue(reply.success)
	}

	func testHandlerDownWithCycleReturnsFail() throws {
		var a = ComposeService(); a.image = "ubuntu:24.04"; a.dependsOn = .list(["b"])
		var b = ComposeService(); b.image = "ubuntu:24.04"; b.dependsOn = .list(["a"])
		let compose = ComposeFile(name: "test-down-cycle", services: ["a": a, "b": b])

		let reply = ComposeHandler.down(compose: compose, services: [], force: false, runMode: .user)

		XCTAssertFalse(reply.success)
		XCTAssertFalse(reply.reason.isEmpty)
	}

	func testHandlerDownFilteredSubset() throws {
		var a = ComposeService(); a.image = "ubuntu:24.04"
		var b = ComposeService(); b.image = "ubuntu:24.04"
		let compose = ComposeFile(name: "test-down-filter", services: ["a": a, "b": b])

		let reply = ComposeHandler.down(compose: compose, services: ["a"], force: false, runMode: .user)

		XCTAssertTrue(reply.success)
	}
}
