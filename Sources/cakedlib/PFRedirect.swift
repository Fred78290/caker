import Foundation
import CakeAgentLib
import Subprocess

/// Installs/removes `pf` (packet filter) redirect rules, used by IMDS since
/// `caked service listen` runs unprivileged and can't `bind()` privileged addresses/ports
/// itself. A short-lived, separately-privileged helper (see `Networks.ImdsRedirect` in
/// `caked`) installs a redirect instead — no long-running privileged process is needed once
/// the rule is in place, `pf` handles the forwarding in the kernel.
///
/// Rules are loaded into dedicated anchors nested under `com.apple/`. macOS's default
/// `/etc/pf.conf` wires a wildcard `nat-anchor "com.apple/*"` / `rdr-anchor "com.apple/*"`
/// into the main ruleset specifically so first- and third-party tools (VPN clients, Internet
/// Sharing, etc.) can load anchors via `pfctl -a com.apple/... -f -` without the user having
/// to edit `/etc/pf.conf` themselves — an anchor name outside that namespace would silently
/// load but never actually be evaluated against traffic.
public enum PFRedirect {
	public static let anchorName = "com.apple/caker-imds"
	public static let addressAliasAnchorName = "com.apple/caker-alias"

	/// Redirects `proto tcp` traffic addressed to `externalAddress:externalPort` to
	/// `internalAddress:internalPort`. Must be called as root.
	public static func enable(externalAddress: String, externalPort: Int, internalAddress: String, internalPort: Int) throws {
		let rule = "rdr pass inet proto tcp from any to \(externalAddress) port \(externalPort) -> \(internalAddress) port \(internalPort)"

		try Self.loadAnchor(name: Self.anchorName, rule: rule)
		try Self.ensureEnabled()
	}

	/// Removes any redirect previously installed by `enable`. Must be called as root.
	public static func disable() throws {
		// Loading an empty ruleset into the anchor clears it; pf itself (and any other
		// anchor) is left untouched.
		try Self.loadAnchor(name: Self.anchorName, rule: "")
	}

	/// Redirects *all* `proto tcp` traffic addressed to `externalAddress` (any port) to
	/// `targetAddress`, preserving the original destination port — a pure address rewrite,
	/// not a port forward. Used to make the AWS-style `169.254.169.254` address transparently
	/// reach the real IMDS gateway, regardless of which port IMDS actually bound (80 as
	/// root, or the unprivileged `--imds-port` otherwise) — one rule covers both, since the
	/// port is never rewritten. Must be called as root.
	public static func enableAddressAlias(externalAddress: String, targetAddress: String) throws {
		let rule = "rdr pass inet proto tcp from any to \(externalAddress) -> \(targetAddress)\n"

		try Self.loadAnchor(name: Self.addressAliasAnchorName, rule: rule)
		try Self.ensureEnabled()
	}

	/// Removes any redirect previously installed by `enableAddressAlias`. Must be called as
	/// root.
	public static func disableAddressAlias() throws {
		try Self.loadAnchor(name: Self.addressAliasAnchorName, rule: "")
	}

	private static func loadAnchor(name: String, rule: String) throws {
		guard geteuid() == 0 else {
			throw ServiceError(String(localized: "PFRedirect must be run as root"))
		}

		Logger("PFRedirect").debug("/sbin/pfctl -a \(name) -f - <<<'\(rule)'")

		try pfctl("-a", name, "-f", "-", input: rule)
	}

	private static func ensureEnabled() throws {
		// `pfctl -e` fails harmlessly (non-zero exit, "pf already enabled") if pf is
		// already on; only surface a genuine failure to enable it.
		do {
			Logger("PFRedirect").debug("exec: /sbin/pfctl -e")

			try pfctl("-e")
		} catch {
			Logger("PFRedirect").debug("exec: /sbin/pfctl -s info")

			let status = try pfctl("-s", "info")

			guard status.contains("Status: Enabled") else {
				throw error
			}
		}
	}
	
	@discardableResult
	private static func pfctl(_ arguments: String..., input: String? = nil) throws -> String {
		return try Task.sync {
			let maxSubprocessOutputSize = 100 * 1024 * 1024
			let input: InputProtocol = input != nil ? .string(input!) : .none
			let result = try await Subprocess.run(
				.path("/sbin/pfctl"),
				arguments: .init(arguments),
				input: input,
				output: .string(limit: maxSubprocessOutputSize),
				error: .string(limit: maxSubprocessOutputSize)
			)

			// Extract numeric exit code from TerminationStatus enum
			let exitCode: TerminationStatus.Code
			
			switch result.terminationStatus {
			case .exited(let code):
				exitCode = code
			case .signaled:
				// Use a conventional negative code for signalled termination
				exitCode = -1
			}

			if exitCode != 0 {
				let stdout = result.standardOutput?.trimmingCharacters(in: .whitespacesAndNewlines) ?? String.empty
				let stderr = result.standardError?.trimmingCharacters(in: .whitespacesAndNewlines) ?? String.empty
				
				throw ShellError(terminationStatus: exitCode, error: stderr, message: stdout)
			}

			if let out: String = result.standardOutput {
				return out.trimmingCharacters(in: .whitespacesAndNewlines)
			}
			
			return String.empty
		}
	}
}

