//
//  PrivilegedImportArgumentsTests.swift
//  CakerTests
//

import XCTest

@testable import CakedLib

final class PrivilegedImportArgumentsTests: XCTestCase {
	private let valid = ["instance-1", "my-vm", "--from=multipass", "--user=admin", "--password=admin", "--json"]

	private func assertRefused(_ arguments: [String], file: StaticString = #filePath, line: UInt = #line) {
		XCTAssertThrowsError(try ImportHandler.validatePrivilegedImportArguments(arguments), "\(arguments)", file: file, line: line)
	}

	func testAcceptsWhatTheClientSends() throws {
		try ImportHandler.validatePrivilegedImportArguments(self.valid)
		try ImportHandler.validatePrivilegedImportArguments(self.valid + ["--clear-password", "--ssh-key=id_rsa", "--ssh-passphrase=secret", "--importer-arg=driver=applevz", "--log-level=debug"])
	}

	func testRefusesWhatSelectsAnotherOwnerOrHome() {
		for option in ["--uid=0", "--gid=0", "--home=/var/root", "--system", "-s"] {
			self.assertRefused(self.valid + [option])
		}

		self.assertRefused(self.valid + ["--uid", "0"])
	}

	func testRefusesOptionsThatWereNotWrittenForRoot() {
		self.assertRefused(self.valid + ["--no-copy-disk"])
		self.assertRefused(self.valid + ["--format=json"])
		self.assertRefused(self.valid + ["--importer-arg=path=/var/root"])
		self.assertRefused(self.valid + ["--importer-arg=driver=../../tmp"])
		self.assertRefused(self.valid + ["--user"])
	}

	func testOnlyMultipassRunsAsRoot() {
		self.assertRefused(["instance-1", "my-vm", "--from=vmdk", "--json"])
		self.assertRefused(["instance-1", "my-vm", "--json"])
		self.assertRefused(self.valid + ["--from=multipass"])
	}

	func testRefusesPathsAndOddNames() {
		self.assertRefused(["/etc", "my-vm", "--from=multipass"])
		self.assertRefused(["instance-1", "../escape", "--from=multipass"])
		self.assertRefused(["instance-1", ".hidden", "--from=multipass"])
		self.assertRefused(["instance-1", "--from=multipass"])
		self.assertRefused(["a", "b", "c", "--from=multipass"])
		self.assertRefused(["", "my-vm", "--from=multipass"])
	}
}
