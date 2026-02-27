# Release Notes

## 2026-02-26 (Git log summary - main)

### Added
- Grand Central Dispatch capabilities for live VM/system status streaming (including `gcd` command and updater flow).
- gRPC methods for Grand Central dispatcher/update paths and related status stream handling.
- Additional project dependencies and test plan scaffolding.

### Updated
- Service startup/shutdown behavior refined.
- VM start command help/descriptions improved.
- CLI help request and error handling improved.
- VM/network runtime reliability improved (status updates, gRPC stability, network startup logic).
- Shell command handling improved (including safer argument quoting).

### Notes
- Summary generated from recent commits on branch `main`.
- See git history for full details: `git log --oneline`.

## 2026-02-26

### Added
- Initial wiki structure published.
- Getting Started, Architecture, Development, Troubleshooting, and FAQ pages.
- Wiki publishing script: `Scripts/publish-wiki.sh`.

### Updated
- Contribution guidance aligned to base branch `main`.
- Wording and structure polished across core wiki pages.

### Notes
- Wiki publication requires GitHub Wiki access on the target repository.
- For private repositories, use `GH_TOKEN`/`GITHUB_TOKEN` or `USE_SSH=1`.

## How to update this wiki

1. Edit pages in the local `wiki/` directory.
2. Review changes and keep navigation in sync (`Home.md` and `_Sidebar.md`).
3. (Optional) Create a dated release note entry automatically with:
	- `./Scripts/new-wiki-release-entry.sh`
	- or `./Scripts/new-wiki-release-entry.sh YYYY-MM-DD`
4. Publish with:
	- `GH_TOKEN="$GITHUB_TOKEN" ./Scripts/publish-wiki.sh Fred78290 caker`
	- or `USE_SSH=1 ./Scripts/publish-wiki.sh Fred78290 caker`
5. Add notable documentation updates in the new dated entry.

## Entry template

Copy/paste this block for the next update:

```markdown
## YYYY-MM-DD

### Added
- ...

### Updated
- ...

### Notes
- ...
```
