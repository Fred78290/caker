import XCTest

@testable import CakedLib

/// dhcpcd (Alpine, Gentoo) identifies itself with a DUID, so its lease is keyed by that DUID and a lookup
/// by the VM's MAC address finds nothing: the compose DNS registry then never learned those VMs.
final class DHCPLeaseHostnameTests: XCTestCase {
	private let far = "0x7fffffff"
	private let past = "0x00000001"

	private func lease(name: String, ip: String, hw: String, expires: String) -> String {
		"{\n\tname=\(name)\n\tip_address=\(ip)\n\thw_address=\(hw)\n\tidentifier=\(hw)\n\tlease=\(expires)\n}\n"
	}

	func testDuidLeaseIsFoundByHostnameNotByMac() {
		let content =
			lease(name: "ubuntu", ip: "192.168.32.16", hw: "1,b6:b6:6a:70:57:94", expires: far)
			+ lease(name: "alpine", ip: "192.168.32.44", hw: "ff,c7:6a:f3:46:0:1:0:1:32:78:bc:df:12:cf:c7:6a:f3:46", expires: far)
		let parser = DHCPLeaseParser(content: content)

		XCTAssertEqual(parser["b6:b6:6a:70:57:94"], "192.168.32.16")
		XCTAssertNil(parser["12:cf:c7:6a:f3:46"])
		XCTAssertEqual(parser.address(forHostname: "alpine"), "192.168.32.44")
		XCTAssertEqual(parser.address(forHostname: "ALPINE"), "192.168.32.44")
	}

	func testHostnameLookupPrefersTheNewestUnexpiredLease() {
		let content =
			lease(name: "suse", ip: "192.168.32.38", hw: "1,82:1b:11:c6:48:a3", expires: "0x7ffffff0")
			+ lease(name: "suse", ip: "192.168.32.40", hw: "1,da:7a:28:cb:6f:a7", expires: far)
			+ lease(name: "suse", ip: "192.168.32.39", hw: "1,a6:63:c0:86:b7:a9", expires: "0x7ffffff8")
		let parser = DHCPLeaseParser(content: content)

		XCTAssertEqual(parser.address(forHostname: "suse"), "192.168.32.40")
	}

	func testHostnameLookupIgnoresExpiredLeasesAndUnknownNames() {
		let parser = DHCPLeaseParser(content: lease(name: "gento", ip: "192.168.32.42", hw: "ff,f1:f5:dd:7f:0:2:0:0:ab:11:c3:6e:91:30:65:ee:c0:ff", expires: past))

		XCTAssertNil(parser.address(forHostname: "gento"))
		XCTAssertNil(parser.address(forHostname: "nobody"))
	}
}
