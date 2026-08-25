// GENERATED FILE — DO NOT EDIT BY HAND.
//
// Regenerated from Sources/cakedlib/Resources/VMImages.json by:
//
//     python3 Scripts/generate-vm-image-shorthand-flags.py
//
// One `@Flag` per catalog id (e.g. `--macos12`, `--ubuntu2604`), composed into
// `BuildOptions` via `@OptionGroup` — see BuildOptions.swift and the generator
// script's own header comment for why this can't just be a `public extension
// BuildOptions { ... }` declaring the `@Flag` vars directly.
import ArgumentParser

public struct VMImageShorthandFlags: ParsableArguments, Sendable {
	@Flag(name: .customLong("ubuntu2604Desktop"), help: ArgumentHelp("Use the 'ubuntu2604Desktop' catalog image"))
	public var ubuntu2604Desktop: Bool = false

	@Flag(name: .customLong("ubuntu2604Server"), help: ArgumentHelp("Use the 'ubuntu2604Server' catalog image"))
	public var ubuntu2604Server: Bool = false

	@Flag(name: .customLong("ubuntu2404Desktop"), help: ArgumentHelp("Use the 'ubuntu2404Desktop' catalog image"))
	public var ubuntu2404Desktop: Bool = false

	@Flag(name: .customLong("ubuntu2404Server"), help: ArgumentHelp("Use the 'ubuntu2404Server' catalog image"))
	public var ubuntu2404Server: Bool = false

	@Flag(name: .customLong("ubuntu2204Desktop"), help: ArgumentHelp("Use the 'ubuntu2204Desktop' catalog image"))
	public var ubuntu2204Desktop: Bool = false

	@Flag(name: .customLong("ubuntu2204Server"), help: ArgumentHelp("Use the 'ubuntu2204Server' catalog image"))
	public var ubuntu2204Server: Bool = false

	@Flag(name: .customLong("ubuntu2004Desktop"), help: ArgumentHelp("Use the 'ubuntu2004Desktop' catalog image"))
	public var ubuntu2004Desktop: Bool = false

	@Flag(name: .customLong("ubuntu2004Server"), help: ArgumentHelp("Use the 'ubuntu2004Server' catalog image"))
	public var ubuntu2004Server: Bool = false

	@Flag(name: .customLong("ubuntu1804Desktop"), help: ArgumentHelp("Use the 'ubuntu1804Desktop' catalog image"))
	public var ubuntu1804Desktop: Bool = false

	@Flag(name: .customLong("ubuntu1804Server"), help: ArgumentHelp("Use the 'ubuntu1804Server' catalog image"))
	public var ubuntu1804Server: Bool = false

	@Flag(name: .customLong("fedora44Desktop"), help: ArgumentHelp("Use the 'fedora44Desktop' catalog image"))
	public var fedora44Desktop: Bool = false

	@Flag(name: .customLong("fedora44Server"), help: ArgumentHelp("Use the 'fedora44Server' catalog image"))
	public var fedora44Server: Bool = false

	@Flag(name: .customLong("fedora43Desktop"), help: ArgumentHelp("Use the 'fedora43Desktop' catalog image"))
	public var fedora43Desktop: Bool = false

	@Flag(name: .customLong("fedora43Server"), help: ArgumentHelp("Use the 'fedora43Server' catalog image"))
	public var fedora43Server: Bool = false

	@Flag(name: .customLong("fedora42Desktop"), help: ArgumentHelp("Use the 'fedora42Desktop' catalog image"))
	public var fedora42Desktop: Bool = false

	@Flag(name: .customLong("fedora42Server"), help: ArgumentHelp("Use the 'fedora42Server' catalog image"))
	public var fedora42Server: Bool = false

	@Flag(name: .customLong("fedora41Server"), help: ArgumentHelp("Use the 'fedora41Server' catalog image"))
	public var fedora41Server: Bool = false

	@Flag(name: .customLong("fedora40Desktop"), help: ArgumentHelp("Use the 'fedora40Desktop' catalog image"))
	public var fedora40Desktop: Bool = false

	@Flag(name: .customLong("fedora40Server"), help: ArgumentHelp("Use the 'fedora40Server' catalog image"))
	public var fedora40Server: Bool = false

	@Flag(name: .customLong("centos10"), help: ArgumentHelp("Use the 'centos10' catalog image"))
	public var centos10: Bool = false

	@Flag(name: .customLong("centos9"), help: ArgumentHelp("Use the 'centos9' catalog image"))
	public var centos9: Bool = false

	@Flag(name: .customLong("debian1360"), help: ArgumentHelp("Use the 'debian1360' catalog image"))
	public var debian1360: Bool = false

	@Flag(name: .customLong("openSUSELeap161"), help: ArgumentHelp("Use the 'openSUSELeap161' catalog image"))
	public var openSUSELeap161: Bool = false

	@Flag(name: .customLong("openSUSELeap160"), help: ArgumentHelp("Use the 'openSUSELeap160' catalog image"))
	public var openSUSELeap160: Bool = false

	@Flag(name: .customLong("openSUSELeap156"), help: ArgumentHelp("Use the 'openSUSELeap156' catalog image"))
	public var openSUSELeap156: Bool = false

	@Flag(name: .customLong("openSUSELeap155"), help: ArgumentHelp("Use the 'openSUSELeap155' catalog image"))
	public var openSUSELeap155: Bool = false

	@Flag(name: .customLong("macos27"), help: ArgumentHelp("Use the 'macos27' catalog image"))
	public var macos27: Bool = false

	@Flag(name: .customLong("macos26"), help: ArgumentHelp("Use the 'macos26' catalog image"))
	public var macos26: Bool = false

	@Flag(name: .customLong("macos15"), help: ArgumentHelp("Use the 'macos15' catalog image"))
	public var macos15: Bool = false

	@Flag(name: .customLong("macos14"), help: ArgumentHelp("Use the 'macos14' catalog image"))
	public var macos14: Bool = false

	@Flag(name: .customLong("macos13"), help: ArgumentHelp("Use the 'macos13' catalog image"))
	public var macos13: Bool = false

	@Flag(name: .customLong("macos12"), help: ArgumentHelp("Use the 'macos12' catalog image"))
	public var macos12: Bool = false

	@Flag(name: .customLong("ubuntu2604"), help: ArgumentHelp("Use the 'ubuntu2604' catalog image"))
	public var ubuntu2604: Bool = false

	@Flag(name: .customLong("ubuntu2504"), help: ArgumentHelp("Use the 'ubuntu2504' catalog image"))
	public var ubuntu2504: Bool = false

	@Flag(name: .customLong("ubuntu2404"), help: ArgumentHelp("Use the 'ubuntu2404' catalog image"))
	public var ubuntu2404: Bool = false

	@Flag(name: .customLong("ubuntu2204"), help: ArgumentHelp("Use the 'ubuntu2204' catalog image"))
	public var ubuntu2204: Bool = false

	@Flag(name: .customLong("ubuntu2004"), help: ArgumentHelp("Use the 'ubuntu2004' catalog image"))
	public var ubuntu2004: Bool = false

	@Flag(name: .customLong("debian14"), help: ArgumentHelp("Use the 'debian14' catalog image"))
	public var debian14: Bool = false

	@Flag(name: .customLong("debian13"), help: ArgumentHelp("Use the 'debian13' catalog image"))
	public var debian13: Bool = false

	@Flag(name: .customLong("debian12"), help: ArgumentHelp("Use the 'debian12' catalog image"))
	public var debian12: Bool = false

	@Flag(name: .customLong("debian11"), help: ArgumentHelp("Use the 'debian11' catalog image"))
	public var debian11: Bool = false

	@Flag(name: .customLong("fedora44"), help: ArgumentHelp("Use the 'fedora44' catalog image"))
	public var fedora44: Bool = false

	@Flag(name: .customLong("fedora43"), help: ArgumentHelp("Use the 'fedora43' catalog image"))
	public var fedora43: Bool = false

	@Flag(name: .customLong("fedora42"), help: ArgumentHelp("Use the 'fedora42' catalog image"))
	public var fedora42: Bool = false

	@Flag(name: .customLong("fedora41"), help: ArgumentHelp("Use the 'fedora41' catalog image"))
	public var fedora41: Bool = false

	@Flag(name: .customLong("fedora40"), help: ArgumentHelp("Use the 'fedora40' catalog image"))
	public var fedora40: Bool = false

	@Flag(name: .customLong("openSUSE156"), help: ArgumentHelp("Use the 'openSUSE156' catalog image"))
	public var openSUSE156: Bool = false

	@Flag(name: .customLong("openSUSE155"), help: ArgumentHelp("Use the 'openSUSE155' catalog image"))
	public var openSUSE155: Bool = false

	@Flag(name: .customLong("openSUSE154"), help: ArgumentHelp("Use the 'openSUSE154' catalog image"))
	public var openSUSE154: Bool = false

	@Flag(name: .customLong("alpine322"), help: ArgumentHelp("Use the 'alpine322' catalog image"))
	public var alpine322: Bool = false

	@Flag(name: .customLong("alpine321"), help: ArgumentHelp("Use the 'alpine321' catalog image"))
	public var alpine321: Bool = false

	@Flag(name: .customLong("alpine320"), help: ArgumentHelp("Use the 'alpine320' catalog image"))
	public var alpine320: Bool = false

	@Flag(name: .customLong("fedora41Desktop"), help: ArgumentHelp("Use the 'fedora41Desktop' catalog image"))
	public var fedora41Desktop: Bool = false

	// MUST stay empty. ArgumentParser's own internal validators (UniqueNamesValidator,
	// NonsenseFlagsValidator, CodingKeyValidator, ...) call `Mirror(reflecting: Type.init())`
	// on every `ParsableArguments` type reachable from a command — including this one, via
	// `BuildOptions`'s `@OptionGroup var imageShorthand` — to extract each `@Flag`'s pending
	// "definition" closure and build `--help` output / do misconfiguration checks. Assigning
	// any of these properties here (even to their own `false` default) resolves them early
	// and crashes that walk with "Trying to get the argument set from a resolved/parsed
	// property." The corollary: a `VMImageShorthandFlags()` built this way is *not* safe to
	// read from — only a real, fully-parsed instance (`BuildOptions.parse([...])`, or
	// whatever ArgumentParser hands back after a real `caked build --macos12 ...` parse) is.
	public init() {}

	/// Every generated flag's catalog id, in declaration order, paired with whether the
	/// user set it — used by `BuildOptions.selectedImageIDs` to detect "none" / "exactly
	/// one" / "more than one" without hand-maintaining a second list of ids here.
	var setIDs: [String] {
		var result: [String] = []

		if ubuntu2604Desktop { result.append("ubuntu2604Desktop") }
		if ubuntu2604Server { result.append("ubuntu2604Server") }
		if ubuntu2404Desktop { result.append("ubuntu2404Desktop") }
		if ubuntu2404Server { result.append("ubuntu2404Server") }
		if ubuntu2204Desktop { result.append("ubuntu2204Desktop") }
		if ubuntu2204Server { result.append("ubuntu2204Server") }
		if ubuntu2004Desktop { result.append("ubuntu2004Desktop") }
		if ubuntu2004Server { result.append("ubuntu2004Server") }
		if ubuntu1804Desktop { result.append("ubuntu1804Desktop") }
		if ubuntu1804Server { result.append("ubuntu1804Server") }
		if fedora44Desktop { result.append("fedora44Desktop") }
		if fedora44Server { result.append("fedora44Server") }
		if fedora43Desktop { result.append("fedora43Desktop") }
		if fedora43Server { result.append("fedora43Server") }
		if fedora42Desktop { result.append("fedora42Desktop") }
		if fedora42Server { result.append("fedora42Server") }
		if fedora41Server { result.append("fedora41Server") }
		if fedora40Desktop { result.append("fedora40Desktop") }
		if fedora40Server { result.append("fedora40Server") }
		if centos10 { result.append("centos10") }
		if centos9 { result.append("centos9") }
		if debian1360 { result.append("debian1360") }
		if openSUSELeap161 { result.append("openSUSELeap161") }
		if openSUSELeap160 { result.append("openSUSELeap160") }
		if openSUSELeap156 { result.append("openSUSELeap156") }
		if openSUSELeap155 { result.append("openSUSELeap155") }
		if macos27 { result.append("macos27") }
		if macos26 { result.append("macos26") }
		if macos15 { result.append("macos15") }
		if macos14 { result.append("macos14") }
		if macos13 { result.append("macos13") }
		if macos12 { result.append("macos12") }
		if ubuntu2604 { result.append("ubuntu2604") }
		if ubuntu2504 { result.append("ubuntu2504") }
		if ubuntu2404 { result.append("ubuntu2404") }
		if ubuntu2204 { result.append("ubuntu2204") }
		if ubuntu2004 { result.append("ubuntu2004") }
		if debian14 { result.append("debian14") }
		if debian13 { result.append("debian13") }
		if debian12 { result.append("debian12") }
		if debian11 { result.append("debian11") }
		if fedora44 { result.append("fedora44") }
		if fedora43 { result.append("fedora43") }
		if fedora42 { result.append("fedora42") }
		if fedora41 { result.append("fedora41") }
		if fedora40 { result.append("fedora40") }
		if openSUSE156 { result.append("openSUSE156") }
		if openSUSE155 { result.append("openSUSE155") }
		if openSUSE154 { result.append("openSUSE154") }
		if alpine322 { result.append("alpine322") }
		if alpine321 { result.append("alpine321") }
		if alpine320 { result.append("alpine320") }
		if fedora41Desktop { result.append("fedora41Desktop") }

		return result
	}
}

extension BuildOptions {
	/// The catalog id from whichever single `imageShorthand` flag is set (e.g. "macos12" for
	/// `--macos12`), without the ambiguity check `validate(remote:)` performs — returns the
	/// first match if, hypothetically, more than one flag were set. Most code should read
	/// `imageId` instead: it's populated from this by `validate(remote:)`, and it's the only
	/// one of the two that round-trips over gRPC (see `imageId`'s doc comment).
	public var selectedImageID: String? {
		imageShorthand.setIDs.first
	}
}
