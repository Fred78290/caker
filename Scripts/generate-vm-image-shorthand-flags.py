#!/usr/bin/env python3
"""Regenerates Sources/Grpc/options/VMImageShorthandFlags.swift from
Sources/cakedlib/Resources/VMImages.json — the same catalog webui/scripts/sync-vm-images.mjs
reads to generate webui/src/data/vmImages.ts.

Run manually whenever VMImages.json changes (adding/renaming/removing a catalog id):

    python3 Scripts/generate-vm-image-shorthand-flags.py

This is a deliberately manual step (like sync-vm-images.mjs, minus the npm pre-script hook) —
it's not wired into `swift build` as a plugin, since the generated file is checked into the repo
and only needs regenerating when the catalog's set of ids actually changes.

Emits one `@Flag(name: .customLong("<id>"))` boolean per unique catalog id (e.g. `--macos12`,
`--ubuntu2604Desktop`) on a small `VMImageShorthandFlags: ParsableArguments` type, composed into
`BuildOptions` via `@OptionGroup` (see BuildOptions.swift). This can't be a `public extension
BuildOptions { ... }` adding the `@Flag` vars directly onto `BuildOptions` itself, because Swift
does not allow stored properties — and a property-wrapper-backed property is a stored property
under the hood — to be declared in an extension of a struct. Composing a separate
`ParsableArguments` type via `@OptionGroup` is the standard ArgumentParser workaround and keeps
`BuildOptions` itself hand-written apart from that one `@OptionGroup` line plus the `imageId`
storage it feeds (see BuildOptions.swift and CLAUDE.md's "Catalog-driven shorthand CLI flags"
notes for the full wiring).
"""
import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
CATALOG_PATH = REPO_ROOT / "Sources" / "cakedlib" / "Resources" / "VMImages.json"
OUTPUT_PATH = REPO_ROOT / "Sources" / "Grpc" / "options" / "VMImageShorthandFlags.swift"

SWIFT_IDENTIFIER_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def collect_ids(catalog: dict) -> list[str]:
    """Every unique catalog id across both architectures and all three categories, in the
    order first seen (arm64 iso, then ipsw, then cloud; amd64 only contributes ids arm64
    doesn't already have, e.g. fedora41Desktop, which is amd64-only)."""
    seen: dict[str, None] = {}

    for arch in ("arm64", "amd64"):
        if arch not in catalog:
            raise SystemExit(f"VMImages.json is missing the \"{arch}\" architecture")
        for category in ("iso", "ipsw", "cloud"):
            if category not in catalog[arch]:
                raise SystemExit(f"VMImages.json is missing \"{arch}.{category}\"")
            for entry in catalog[arch][category]:
                seen.setdefault(entry["id"], None)

    return list(seen.keys())


def swift_property_name(image_id: str) -> str:
    """The catalog ids are already valid, unescaped Swift identifiers (checked below) — this
    just documents that assumption rather than performing any real sanitization. If a future id
    needs escaping (a leading digit, a Swift keyword, ...), this raises instead of silently
    emitting invalid Swift; extend it then rather than guessing at a scheme now."""
    if not SWIFT_IDENTIFIER_RE.match(image_id):
        raise SystemExit(
            f"Catalog id {image_id!r} is not a plain Swift identifier — "
            "extend generate-vm-image-shorthand-flags.py to escape/rename it before regenerating."
        )
    return image_id


def render(ids: list[str]) -> str:
    lines = []
    lines.append("// GENERATED FILE — DO NOT EDIT BY HAND.")
    lines.append("//")
    lines.append("// Regenerated from Sources/cakedlib/Resources/VMImages.json by:")
    lines.append("//")
    lines.append("//     python3 Scripts/generate-vm-image-shorthand-flags.py")
    lines.append("//")
    lines.append("// One `@Flag` per catalog id (e.g. `--macos12`, `--ubuntu2604`), composed into")
    lines.append("// `BuildOptions` via `@OptionGroup` — see BuildOptions.swift and the generator")
    lines.append("// script's own header comment for why this can't just be a `public extension")
    lines.append("// BuildOptions { ... }` declaring the `@Flag` vars directly.")
    lines.append("import ArgumentParser")
    lines.append("")
    lines.append("public struct VMImageShorthandFlags: ParsableArguments, Sendable {")

    for image_id in ids:
        prop = swift_property_name(image_id)
        lines.append(f'\t@Flag(name: .customLong("{image_id}"), help: ArgumentHelp("Use the \'{image_id}\' catalog image"))')
        lines.append(f"\tpublic var {prop}: Bool = false")
        lines.append("")

    lines.append("\t// MUST stay empty. ArgumentParser's own internal validators (UniqueNamesValidator,")
    lines.append("\t// NonsenseFlagsValidator, CodingKeyValidator, ...) call `Mirror(reflecting: Type.init())`")
    lines.append("\t// on every `ParsableArguments` type reachable from a command — including this one, via")
    lines.append("\t// `BuildOptions`'s `@OptionGroup var imageShorthand` — to extract each `@Flag`'s pending")
    lines.append("\t// \"definition\" closure and build `--help` output / do misconfiguration checks. Assigning")
    lines.append("\t// any of these properties here (even to their own `false` default) resolves them early")
    lines.append("\t// and crashes that walk with \"Trying to get the argument set from a resolved/parsed")
    lines.append("\t// property.\" The corollary: a `VMImageShorthandFlags()` built this way is *not* safe to")
    lines.append("\t// read from — only a real, fully-parsed instance (`BuildOptions.parse([...])`, or")
    lines.append("\t// whatever ArgumentParser hands back after a real `caked build --macos12 ...` parse) is.")
    lines.append("\tpublic init() {}")
    lines.append("")
    lines.append("\t/// Every generated flag's catalog id, in declaration order, paired with whether the")
    lines.append("\t/// user set it — used by `BuildOptions.selectedImageIDs` to detect \"none\" / \"exactly")
    lines.append("\t/// one\" / \"more than one\" without hand-maintaining a second list of ids here.")
    lines.append("\tvar setIDs: [String] {")
    lines.append("\t\tvar result: [String] = []")
    lines.append("")

    for image_id in ids:
        prop = swift_property_name(image_id)
        lines.append(f'\t\tif {prop} {{ result.append("{image_id}") }}')

    lines.append("")
    lines.append("\t\treturn result")
    lines.append("\t}")
    lines.append("}")
    lines.append("")
    lines.append("extension BuildOptions {")
    lines.append("\t/// The catalog id from whichever single `imageShorthand` flag is set (e.g. \"macos12\" for")
    lines.append("\t/// `--macos12`), without the ambiguity check `validate(remote:)` performs — returns the")
    lines.append("\t/// first match if, hypothetically, more than one flag were set. Most code should read")
    lines.append("\t/// `imageId` instead: it's populated from this by `validate(remote:)`, and it's the only")
    lines.append("\t/// one of the two that round-trips over gRPC (see `imageId`'s doc comment).")
    lines.append("\tpublic var selectedImageID: String? {")
    lines.append("\t\timageShorthand.setIDs.first")
    lines.append("\t}")
    lines.append("}")
    lines.append("")

    return "\n".join(lines)


def main() -> None:
    catalog = json.loads(CATALOG_PATH.read_text())
    ids = collect_ids(catalog)

    if not ids:
        raise SystemExit("VMImages.json yielded no catalog ids — refusing to emit an empty flags file")

    OUTPUT_PATH.write_text(render(ids))
    print(f"Wrote {OUTPUT_PATH.relative_to(REPO_ROOT)} with {len(ids)} shorthand flags")


if __name__ == "__main__":
    sys.exit(main())
