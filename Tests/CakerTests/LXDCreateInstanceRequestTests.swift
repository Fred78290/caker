import XCTest

@testable import caked

final class LXDCreateInstanceRequestTests: XCTestCase {
	func testDecodesDevicesAndBuildsEffectiveNetworkConfig() throws {
		let json = """
		{
		  "name": "vm-test",
		  "source": { "type": "image", "alias": "ubuntu/26.04" },
		  "user": "admin",
		  "password": "admin",
		  "clearPassword": false,
		  "mainGroup": "adm",
		  "other_groups": ["sudo"],
		  "net_ifnames": true,
		  "autostart": false,
		  "bridged_network": false,
		  "nested": false,
		  "dynamic_port_forwarding": false,
		  "devices": {
		    "eth0": { "type": "nic", "name": "eth0", "network": "br0" },
		    "eth1": { "type": "nic", "network": "br1" }
		  }
		}
		"""

		let decoder = JSONDecoder()
		let request = try decoder.decode(LXDCreateInstanceRequest.self, from: Data(json.utf8))

		XCTAssertEqual(request.devices?["eth0"]?["network"], "br0")
		XCTAssertEqual(request.devices?["eth1"]?["network"], "br1")
		XCTAssertNil(request.effectiveNetworkConfig)
	}

	func testNetworkConfigTakesPrecedenceOverDevices() throws {
		let provided = "#cloud-config\nnetwork:\n  version: 2\n  ethernets:\n    custom0:\n      dhcp4: true"
		let json = """
		{
		  "name": "vm-test",
		  "source": { "type": "image", "alias": "ubuntu/26.04" },
		  "user": "admin",
		  "password": "admin",
		  "clearPassword": false,
		  "mainGroup": "adm",
		  "other_groups": ["sudo"],
		  "net_ifnames": true,
		  "autostart": false,
		  "bridged_network": false,
		  "nested": false,
		  "dynamic_port_forwarding": false,
		  "network_config": "#cloud-config\\nnetwork:\\n  version: 2\\n  ethernets:\\n    custom0:\\n      dhcp4: true",
		  "devices": {
		    "eth0": { "type": "nic", "name": "eth0", "network": "br0" }
		  }
		}
		"""

		let decoder = JSONDecoder()
		let request = try decoder.decode(LXDCreateInstanceRequest.self, from: Data(json.utf8))

		XCTAssertEqual(request.effectiveNetworkConfig, provided)
	}

	func testConfigCloudInitKeysAreUsedWhenTopLevelFieldsAreMissing() throws {
		let expectedNetworkConfig = "#cloud-config\nnetwork:\n  version: 2\n  ethernets:\n    enp5s0:\n      dhcp4: true"
		let expectedUserData = "#cloud-config\npackages:\n  - curl"
		let expectedSSHKey = "ssh-ed25519 AAAATEST user@host"
		let json = """
		{
		  "name": "vm-test",
		  "source": { "type": "image", "alias": "ubuntu/26.04" },
		  "user": "admin",
		  "password": "admin",
		  "clearPassword": false,
		  "mainGroup": "adm",
		  "other_groups": ["sudo"],
		  "net_ifnames": true,
		  "autostart": false,
		  "bridged_network": false,
		  "nested": false,
		  "dynamic_port_forwarding": false,
		  "config": {
		    "limits.cpu": "2",
		    "limits.memory": "2048MB",
		    "limits.disk": "20GB",
		    "boot.autostart": "true",
		    "cloud-init.network-config": "#cloud-config\\nnetwork:\\n  version: 2\\n  ethernets:\\n    enp5s0:\\n      dhcp4: true",
		    "cloud-init.user-data": "#cloud-config\\npackages:\\n  - curl",
		    "cloud-init.ssh-keys.admin": "ssh-ed25519 AAAATEST user@host"
		  }
		}
		"""

		let decoder = JSONDecoder()
		let request = try decoder.decode(LXDCreateInstanceRequest.self, from: Data(json.utf8))

		XCTAssertEqual(request.effectiveNetworkConfig, expectedNetworkConfig)
		XCTAssertEqual(request.effectiveUserData, expectedUserData)
		XCTAssertEqual(request.effectiveSSHAuthorizedKey, expectedSSHKey)
		XCTAssertEqual(request.effectiveAutostart, true)
	}

	func testDecodesBuildOptionsPassthroughFields() throws {
		let json = """
		{
		  "name": "vm-test",
		  "source": { "type": "image", "alias": "ubuntu/26.04" },
		  "user": "ubuntu",
		  "password": "secret",
		  "clearPassword": true,
		  "mainGroup": "wheel",
		  "other_groups": ["sudo", "docker"],
		  "ssh_authorized_key": "ssh-ed25519 AAAATEST user@host",
		  "forwarded_ports": ["2022:22/tcp", "8080:80/tcp"],
		  "net_ifnames": false,
		  "autostart": true,
		  "bridged_network": true,
		  "nested": true,
		  "dynamic_port_forwarding": true
		}
		"""

		let decoder = JSONDecoder()
		let request = try decoder.decode(LXDCreateInstanceRequest.self, from: Data(json.utf8))

		XCTAssertEqual(request.user, "ubuntu")
		XCTAssertEqual(request.password, "secret")
		XCTAssertEqual(request.mainGroup, "wheel")
		XCTAssertEqual(request.otherGroups, ["sudo", "docker"])
		XCTAssertEqual(request.sshAuthorizedKey, "ssh-ed25519 AAAATEST user@host")
		XCTAssertEqual(request.netIfnames, false)
		XCTAssertEqual(request.autostart, true)
		XCTAssertEqual(request.bridgedNetwork, true)
		XCTAssertEqual(request.nested, true)
		XCTAssertEqual(request.dynamicPortForwarding, true)

		let forwarded = request.forwardedPortAttachments.map(\.description)
		XCTAssertTrue(forwarded.contains("2022:22/tcp"))
		XCTAssertTrue(forwarded.contains("8080:80/tcp"))
	}

	func testEffectiveNetworkConfigIsNilWhenNoUsableNicDevices() throws {
		let json = """
		{
		  "name": "vm-test",
		  "source": { "type": "image", "alias": "ubuntu/26.04" },
		  "user": "admin",
		  "password": "admin",
		  "clearPassword": false,
		  "mainGroup": "adm",
		  "other_groups": ["sudo"],
		  "net_ifnames": true,
		  "autostart": false,
		  "bridged_network": false,
		  "nested": false,
		  "dynamic_port_forwarding": false,
		  "devices": {
		    "root": { "type": "disk", "path": "/" },
		    "eth0": { "type": "nic", "name": "eth0" }
		  }
		}
		"""

		let decoder = JSONDecoder()
		let request = try decoder.decode(LXDCreateInstanceRequest.self, from: Data(json.utf8))

		XCTAssertNil(request.effectiveNetworkConfig)
	}

	func testNetworkAttachmentsFromDevicesMapsOnlyNICDevices() throws {
		let json = """
		{
		  "name": "vm-test",
		  "source": { "type": "image", "alias": "ubuntu/26.04" },
		  "user": "admin",
		  "password": "admin",
		  "clearPassword": false,
		  "mainGroup": "adm",
		  "other_groups": ["sudo"],
		  "net_ifnames": true,
		  "autostart": false,
		  "bridged_network": false,
		  "nested": false,
		  "dynamic_port_forwarding": false,
		  "devices": {
		    "root": { "type": "disk", "path": "/" },
		    "eth0": { "type": "nic", "name": "eth0", "network": "br0", "mode": "auto" },
		    "eth1": { "type": "nic", "network": "nat", "mac": "aa:bb:cc:dd:ee:ff" }
		  }
		}
		"""

		let decoder = JSONDecoder()
		let request = try decoder.decode(LXDCreateInstanceRequest.self, from: Data(json.utf8))
		let attachments = request.networkAttachments

		XCTAssertEqual(attachments.count, 2)
		XCTAssertEqual(attachments[0].network, "br0")
		XCTAssertEqual(attachments[0].mode, .auto)
		XCTAssertEqual(attachments[1].network, "nat")
		XCTAssertEqual(attachments[1].macAddress, "aa:bb:cc:dd:ee:ff")
	}
}
