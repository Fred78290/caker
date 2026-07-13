import Foundation
import CakeAgentLib

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
	public static let anchorName = "com.apple/com.aldunelabs.caker/imds"
	public static let addressAliasAnchorName = "com.apple/com.aldunelabs.caker-imds"

	/// Redirects `proto tcp` traffic addressed to `externalAddress:externalPort` to
	/// `internalAddress:internalPort`. Must be called as root.
	public static func enable(externalAddress: String, externalPort: Int, internalAddress: String, internalPort: Int) throws {
		let rule = "rdr pass proto tcp from any to \(externalAddress) port \(externalPort) -> \(internalAddress) port \(internalPort)"

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
		let rule = "rdr pass proto tcp from any to \(externalAddress) -> \(targetAddress)\n"

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

		try Shell.bash(to: "/sbin/pfctl", arguments: ["-a", name, "-f", "-"], input: rule)
	}

	private static func ensureEnabled() throws {
		// `pfctl -e` fails harmlessly (non-zero exit, "pf already enabled") if pf is
		// already on; only surface a genuine failure to enable it.
		do {
			Logger("PFRedirect").debug("exec: /sbin/pfctl -e")

			try Shell.bash(to: "/sbin/pfctl", arguments: ["-e"])
		} catch {
			Logger("PFRedirect").debug("exec: /sbin/pfctl -s info")

			let status = try Shell.bash(to: "/sbin/pfctl", arguments: ["-s", "info"])

			guard status.contains("Status: Enabled") else {
				throw error
			}
		}
	}
}
