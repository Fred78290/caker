import Foundation

/// Installs/removes a `pf` (packet filter) port-redirect rule so a privileged port (e.g. 80)
/// on a given address can be served by an unprivileged process listening on a different,
/// unprivileged port. Used by IMDS: `caked service listen` runs unprivileged and can't
/// `bind()` port 80 itself, so a short-lived, separately-privileged helper (see
/// `Networks.ImdsRedirect` in `caked`) installs a redirect instead — no long-running
/// privileged process is needed once the rule is in place, `pf` handles the forwarding in
/// the kernel.
///
/// Rules are loaded into a dedicated anchor nested under `com.apple/`. macOS's default
/// `/etc/pf.conf` wires a wildcard `nat-anchor "com.apple/*"` / `rdr-anchor "com.apple/*"`
/// into the main ruleset specifically so first- and third-party tools (VPN clients, Internet
/// Sharing, etc.) can load anchors via `pfctl -a com.apple/... -f -` without the user having
/// to edit `/etc/pf.conf` themselves — an anchor name outside that namespace would silently
/// load but never actually be evaluated against traffic.
public enum PFRedirect {
	public static let anchorName = "com.apple/com.aldunelabs.caker/imds"

	/// Redirects `proto tcp` traffic addressed to `externalAddress:externalPort` to
	/// `internalAddress:internalPort`. Must be called as root.
	public static func enable(externalAddress: String, externalPort: Int, internalAddress: String, internalPort: Int) throws {
		guard geteuid() == 0 else {
			throw ServiceError(String(localized: "PFRedirect.enable must be run as root"))
		}

		let rule = "rdr pass proto tcp from any to \(externalAddress) port \(externalPort) -> \(internalAddress) port \(internalPort)\n"

		try Self.loadAnchor(rule: rule)
		try Self.ensureEnabled()
	}

	/// Removes any redirect previously installed by `enable`. Must be called as root.
	public static func disable() throws {
		guard geteuid() == 0 else {
			throw ServiceError(String(localized: "PFRedirect.disable must be run as root"))
		}

		// Loading an empty ruleset into the anchor clears it; pf itself (and any other
		// anchor) is left untouched.
		try Self.loadAnchor(rule: "")
	}

	private static func loadAnchor(rule: String) throws {
		try Shell.bash(to: "/sbin/pfctl", arguments: ["-a", Self.anchorName, "-f", "-"], input: rule)
	}

	private static func ensureEnabled() throws {
		// `pfctl -e` fails harmlessly (non-zero exit, "pf already enabled") if pf is
		// already on; only surface a genuine failure to enable it.
		do {
			try Shell.bash(to: "/sbin/pfctl", arguments: ["-e"])
		} catch {
			let status = try Shell.bash(to: "/sbin/pfctl", arguments: ["-s", "info"])

			guard status.contains("Status: Enabled") else {
				throw error
			}
		}
	}
}
