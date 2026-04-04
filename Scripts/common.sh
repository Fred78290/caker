PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PATH="${PROJECT_ROOT}/.bin:${PATH}" # Ensure scripts are in PATH for subcommands
KEYS_DIR="${PROJECT_ROOT}/.sparkle"
DIST_DIR="${PROJECT_ROOT}/build"
RELEASES_DIR="${PROJECT_ROOT}/build"
APPCAST_DIR="${PROJECT_ROOT}/docs/appcast"
BRANCH_NAME="$(git -C "${PROJECT_ROOT}" rev-parse --abbrev-ref HEAD)"
APP_NAME="Caker.app"
DATE_VALUE="$(date +%F)"
WIKI_DIR="${PROJECT_ROOT}/wiki"
DOCS_DIR="${PROJECT_ROOT}/docs"
RELEASE_NOTES_FILE="${WIKI_DIR}/release-notes.md"
RELEASE_PATHS="${RELEASE_PATHS:-Sources wiki .github/workflows}"
MAX_COMMITS="${MAX_COMMITS:-20}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
if [ -z "${GITHUB_REPOSITORY:-}" ]; then
  REMOTE_URL="$(git -C "${PROJECT_ROOT}" config --get remote.origin.url || true)"

  if [[ -n "${REMOTE_URL}" ]]; then
    if [[ "${REMOTE_URL}" =~ github.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
      GITHUB_REPOSITORY="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    fi
  fi
fi

GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-Fred78290/caker}"
APPCAST_DIR="${PROJECT_ROOT}/docs/appcast"
APPCAST_FILE="${APPCAST_DIR}/appcast.xml"
MAX_RELEASES=10  # Number of recent releases to include
WIKI_DIR="${PROJECT_ROOT}/wiki"
DOCS_DIR="${PROJECT_ROOT}/docs"