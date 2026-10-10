#!/usr/bin/env python3
"""Submit an uploaded build to App Store review via the App Store Connect API.

Runs right after .ci/upload-appstore.sh, so it:
  1. waits until App Store Connect has processed the build whose CFBundleVersion is VERSION;
  2. answers export compliance on the build if USES_NON_EXEMPT_ENCRYPTION is set
     (Info.plist has no ITSAppUsesNonExemptEncryption key, so the build otherwise stays
     "Missing Compliance" and cannot be submitted);
  3. finds the macOS App Store version VERSION, or renames the version currently being
     prepared, or creates it (VERSION is computed at build time, it cannot be created by hand
     beforehand);
  4. fills in "What's New in This Version" from WHATS_NEW where it is empty (required for updates);
  5. attaches the build to the version and submits it with the reviewSubmissions API
     (POST /v1/appStoreVersionSubmissions is deprecated).

Required environment variables:
  VERSION                             - build version string (e.g. "1.0.42"), used for both
                                        CFBundleVersion and the App Store version string
  APP_STORE_CONNECT_API_KEY_ID        - App Store Connect API key ID
  APP_STORE_CONNECT_API_KEY_ISSUER_ID - App Store Connect issuer ID

Optional environment variables:
  USES_NON_EXEMPT_ENCRYPTION - "true"/"false": export compliance answer to set on the build
  WHATS_NEW                  - release notes for localizations that have none
  BUILD_PROCESSING_TIMEOUT   - seconds to wait for the build to be processed (default 3600)
  BUILD_POLL_INTERVAL        - seconds between two checks (default 30)

The P8 private key must already be present at:
  ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8
"""

import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

BASE_URL = "https://api.appstoreconnect.apple.com/v1"
BUNDLE_ID = "com.aldunelabs.caker"
PLATFORM = "MAC_OS"

# Versions that can still be edited and submitted.
EDITABLE_STATES = {
    "PREPARE_FOR_SUBMISSION",
    "READY_FOR_REVIEW",
    "DEVELOPER_REJECTED",
    "REJECTED",
    "METADATA_REJECTED",
    "INVALID_BINARY",
}
# Versions already handed to App Review.
SUBMITTED_STATES = {"WAITING_FOR_REVIEW", "IN_REVIEW"}


class APIError(Exception):
    def __init__(self, method: str, url: str, status: int, detail: str):
        super().__init__(f"{method} {url} failed with HTTP {status}: {detail}")
        self.status = status


def _require_pyjwt() -> None:
    try:
        import jwt  # noqa: F401
    except ImportError:
        print(
            "Error: PyJWT is required. Install 'PyJWT[crypto]>=2.0' before running this script.",
            file=sys.stderr,
        )
        sys.exit(1)


class AppStoreConnect:
    # Apple rejects tokens valid for more than 20 minutes; waiting for a build to be processed takes
    # longer than that, so the token is renewed before it expires.
    TOKEN_LIFETIME = 1200
    TOKEN_RENEW_MARGIN = 300

    def __init__(self, key_id: str, issuer_id: str, private_key: str):
        self.key_id = key_id
        self.issuer_id = issuer_id
        self.private_key = private_key
        self._token = ""
        self._token_expiry = 0.0

    def token(self) -> str:
        now = time.time()

        if now > self._token_expiry - self.TOKEN_RENEW_MARGIN:
            import jwt

            self._token_expiry = now + self.TOKEN_LIFETIME
            self._token = jwt.encode(
                {"iss": self.issuer_id, "exp": int(self._token_expiry), "aud": "appstoreconnect-v1"},
                self.private_key,
                algorithm="ES256",
                headers={"kid": self.key_id},
            )

        return self._token

    def request(self, method: str, path: str, params: dict = None, body: dict = None):
        url = f"{BASE_URL}{path}"

        if params:
            url += "?" + urllib.parse.urlencode(params, safe="[],.")

        headers = {"Authorization": f"Bearer {self.token()}"}
        data = None

        if body is not None:
            data = json.dumps(body).encode()
            headers["Content-Type"] = "application/json"

        req = urllib.request.Request(url, data=data, headers=headers, method=method)

        try:
            with urllib.request.urlopen(req) as resp:
                payload = resp.read()
                return json.loads(payload) if payload else None
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode(errors="replace")

            try:
                errors = json.loads(detail).get("errors", [])
                detail = "; ".join(f"{e.get('title', '')}: {e.get('detail', '')}" for e in errors) or detail
            except (ValueError, AttributeError):
                pass

            raise APIError(method, url, exc.code, detail) from None

    def get(self, path: str, params: dict = None):
        return self.request("GET", path, params=params)

    def post(self, path: str, body: dict):
        return self.request("POST", path, body=body)

    def patch(self, path: str, body: dict):
        return self.request("PATCH", path, body=body)


def version_state(version: dict) -> str:
    attributes = version["attributes"]
    # appStoreState is deprecated in favor of appVersionState; accept either.
    return attributes.get("appVersionState") or attributes.get("appStoreState") or ""


def find_app(api: AppStoreConnect) -> str:
    print(f"Looking up app with bundle ID {BUNDLE_ID}...")
    apps = api.get("/apps", {"filter[bundleId]": BUNDLE_ID})

    if not apps["data"]:
        raise SystemExit(f"Error: app {BUNDLE_ID} not found in App Store Connect.")

    app_id = apps["data"][0]["id"]
    print(f"Found app ID: {app_id}")
    return app_id


def wait_for_build(api: AppStoreConnect, app_id: str, version: str, timeout: int, interval: int) -> dict:
    print(f"Waiting for build {version} to be processed (timeout {timeout}s)...")
    deadline = time.time() + timeout
    last_state = None

    while True:
        builds = api.get(
            "/builds",
            {
                "filter[app]": app_id,
                "filter[version]": version,
                "filter[preReleaseVersion.platform]": PLATFORM,
                "limit": "1",
            },
        )

        state = builds["data"][0]["attributes"].get("processingState") if builds["data"] else "NOT_FOUND"

        if state != last_state:
            print(f"  build {version}: {state}")
            last_state = state

        if state == "VALID":
            return builds["data"][0]

        if state in ("FAILED", "INVALID"):
            raise SystemExit(f"Error: build {version} processing ended in state {state}.")

        if time.time() >= deadline:
            raise SystemExit(f"Error: build {version} was not processed after {timeout}s (last state: {state}).")

        time.sleep(interval)


def ensure_export_compliance(api: AppStoreConnect, build: dict) -> None:
    current = build["attributes"].get("usesNonExemptEncryption")
    answer = os.environ.get("USES_NON_EXEMPT_ENCRYPTION", "").strip().lower()

    if current is not None:
        print(f"Export compliance already set on the build (usesNonExemptEncryption={current}).")
        return

    if answer not in ("true", "false"):
        raise SystemExit(
            "Error: the build has no export compliance answer, so it cannot be submitted.\n"
            "Set USES_NON_EXEMPT_ENCRYPTION to 'true' or 'false' (repository variable), or add\n"
            "ITSAppUsesNonExemptEncryption to Resources/Info.plist, or answer it in App Store Connect."
        )

    print(f"Setting export compliance on the build (usesNonExemptEncryption={answer})...")
    api.patch(
        f"/builds/{build['id']}",
        {"data": {"type": "builds", "id": build["id"], "attributes": {"usesNonExemptEncryption": answer == "true"}}},
    )


def find_or_create_version(api: AppStoreConnect, app_id: str, version: str) -> dict:
    print(f"Looking for App Store version {version} ({PLATFORM})...")
    versions = api.get(
        f"/apps/{app_id}/appStoreVersions",
        {"filter[platform]": PLATFORM, "filter[versionString]": version},
    )

    if versions["data"]:
        found = versions["data"][0]
        print(f"Found version ID: {found['id']} (state: {version_state(found)})")
        return found

    # Only one version per platform can be in preparation: reuse it under the new version string.
    candidates = api.get(f"/apps/{app_id}/appStoreVersions", {"filter[platform]": PLATFORM, "limit": "50"})
    editable = [v for v in candidates["data"] if version_state(v) in EDITABLE_STATES]

    if editable:
        current = editable[0]
        print(
            f"Renaming version {current['attributes']['versionString']} (ID {current['id']}, "
            f"state: {version_state(current)}) to {version}..."
        )
        result = api.patch(
            f"/appStoreVersions/{current['id']}",
            {"data": {"type": "appStoreVersions", "id": current["id"], "attributes": {"versionString": version}}},
        )
        return result["data"]

    print(f"Creating App Store version {version}...")
    result = api.post(
        "/appStoreVersions",
        {
            "data": {
                "type": "appStoreVersions",
                "attributes": {"platform": PLATFORM, "versionString": version},
                "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
            }
        },
    )
    return result["data"]


def fill_whats_new(api: AppStoreConnect, version_id: str) -> None:
    whats_new = os.environ.get("WHATS_NEW", "").strip()

    if not whats_new:
        return

    localizations = api.get(f"/appStoreVersions/{version_id}/appStoreVersionLocalizations")

    for localization in localizations["data"]:
        attributes = localization["attributes"]

        if attributes.get("whatsNew"):
            continue

        locale = attributes.get("locale", localization["id"])

        try:
            api.patch(
                f"/appStoreVersionLocalizations/{localization['id']}",
                {
                    "data": {
                        "type": "appStoreVersionLocalizations",
                        "id": localization["id"],
                        "attributes": {"whatsNew": whats_new},
                    }
                },
            )
            print(f"Set \"What's New\" for {locale}.")
        except APIError as exc:
            # The first version of an app has no "What's New" field; App Review reports anything else.
            print(f"Warning: could not set \"What's New\" for {locale}: {exc}", file=sys.stderr)


def attach_build(api: AppStoreConnect, version_id: str, build_id: str) -> None:
    print(f"Attaching build {build_id} to version {version_id}...")
    api.patch(f"/appStoreVersions/{version_id}/relationships/build", {"data": {"type": "builds", "id": build_id}})


def submit_for_review(api: AppStoreConnect, app_id: str, version_id: str) -> None:
    # Reuse a submission that was created but not sent yet (e.g. by an earlier failed run).
    pending = api.get(
        "/reviewSubmissions",
        {"filter[app]": app_id, "filter[platform]": PLATFORM, "filter[state]": "READY_FOR_REVIEW"},
    )

    if pending["data"]:
        submission_id = pending["data"][0]["id"]
        print(f"Reusing review submission {submission_id}.")
    else:
        result = api.post(
            "/reviewSubmissions",
            {
                "data": {
                    "type": "reviewSubmissions",
                    "attributes": {"platform": PLATFORM},
                    "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
                }
            },
        )
        submission_id = result["data"]["id"]
        print(f"Created review submission {submission_id}.")

    items = api.get(f"/reviewSubmissions/{submission_id}/items", {"include": "appStoreVersion"})
    already_added = any(
        ((item.get("relationships") or {}).get("appStoreVersion") or {}).get("data", {}) == {"type": "appStoreVersions", "id": version_id}
        for item in items["data"]
    )

    if not already_added:
        api.post(
            "/reviewSubmissionItems",
            {
                "data": {
                    "type": "reviewSubmissionItems",
                    "relationships": {
                        "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": submission_id}},
                        "appStoreVersion": {"data": {"type": "appStoreVersions", "id": version_id}},
                    },
                }
            },
        )

    api.patch(
        f"/reviewSubmissions/{submission_id}",
        {"data": {"type": "reviewSubmissions", "id": submission_id, "attributes": {"submitted": True}}},
    )
    print(f"Review submission {submission_id} sent.")


def main() -> None:
    _require_pyjwt()

    version = os.environ.get("VERSION", "").strip()
    key_id = os.environ.get("APP_STORE_CONNECT_API_KEY_ID", "").strip()
    issuer_id = os.environ.get("APP_STORE_CONNECT_API_KEY_ISSUER_ID", "").strip()
    timeout = int(os.environ.get("BUILD_PROCESSING_TIMEOUT", "3600"))
    interval = int(os.environ.get("BUILD_POLL_INTERVAL", "30"))

    if not version:
        raise SystemExit("Error: VERSION environment variable is required.")

    if not key_id or not issuer_id:
        raise SystemExit("Error: APP_STORE_CONNECT_API_KEY_ID and APP_STORE_CONNECT_API_KEY_ISSUER_ID are required.")

    key_path = os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{key_id}.p8")

    if not os.path.exists(key_path):
        raise SystemExit(f"Error: API key not found at {key_path}")

    with open(key_path) as f:
        api = AppStoreConnect(key_id, issuer_id, f.read())

    try:
        app_id = find_app(api)
        build = wait_for_build(api, app_id, version, timeout, interval)
        ensure_export_compliance(api, build)

        app_version = find_or_create_version(api, app_id, version)
        state = version_state(app_version)

        if state in SUBMITTED_STATES:
            print(f"Version {version} is already submitted (state: {state}), nothing to do.")
            return

        if state and state not in EDITABLE_STATES:
            raise SystemExit(f"Error: version {version} is in state {state} and cannot be submitted.")

        fill_whats_new(api, app_version["id"])
        attach_build(api, app_version["id"], build["id"])
        submit_for_review(api, app_id, app_version["id"])
    except APIError as exc:
        raise SystemExit(f"Error: {exc}")

    print(f"Version {version} submitted for App Store review successfully.")


if __name__ == "__main__":
    main()
