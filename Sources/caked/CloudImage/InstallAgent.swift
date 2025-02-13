import Foundation
import Shout

let install_agent = """
#!/bin/bash
set -e

OSDISTRO=$([[ "$(uname -s)" =~ Darwin ]] && echo -n darwin || echo -n linux)
ARCH=$([[ "$(uname -m)" =~ arm64|aarch64 ]] && echo -n arm64 || echo -n amd64)
AGENT_URL="https://github.com/Fred78290/cakeagent/releases/download/SNAPSHOT-b69570d8/cakeagent-${OSDISTRO}-${ARCH}"

curl -L $AGENT_URL -o /usr/local/bin/cake-agent
chmod +x /usr/local/bin/cakeagent
/usr/local/bin/cakeagent --install \\
	--listen=vsock://any:5000 \\
	--ca-cert=/etc/cakeagent/ssl/ca.pem \\
	--tls-cert=/etc/cakeagent/ssl/server.pem \\
	--tls-key=/etc/cakeagent/ssl/server.key

"""

struct AgentInstaller {
	static func installAgent(config: CakeConfig, runningIP: String, asSystem: Bool) throws -> Bool {
		let certificates: CertificatesLocation = try CertificatesLocation(certHome: URL(fileURLWithPath: "agent", isDirectory: true, relativeTo: try Utils.getHome(asSystem: runAsSystem))).createCertificats()
		let home = try Home(asSystem: asSystem)
		let ssh = try SSH(host: runningIP, timeout: 120)
		let tempFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("install-agent.sh")
		
		try install_agent.write(to: tempFileURL, atomically: true, encoding: .utf8)
		
		try ssh.authenticate(username: config.configuredUser, password: config.configuredPassword)
		try ssh.execute("sudo mkdir -p /tmp/cakeagent/ssl")

		for file in certificates.files {
			_ = try ssh.sendFile(localURL: file, remotePath: "/tmp/cakeagent/ssl/\(file.lastPathComponent)")
		}

		_ = try ssh.sendFile(localURL: tempFileURL, remotePath: "/tmp/install-agent.sh", permissions: .init(rawValue: 0o755))

		try ssh.execute("sh -c 'mv /tmp/install-agent.sh /usr/local/bin; /usr/local/bin/install-agent.sh'")

		return false
	}
}