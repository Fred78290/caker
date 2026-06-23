#!/usr/bin/env python3
"""Submit a build to App Store review via App Store Connect API.

Required environment variables:
  VERSION                          - build version string (e.g. "1.0.42")
  APP_STORE_CONNECT_API_KEY_ID     - App Store Connect API key ID
  APP_STORE_CONNECT_API_KEY_ISSUER_ID - App Store Connect issuer ID

The P8 private key must already be present at:
  ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8
"""

import json
import os
import sys
import time
import urllib.error
import urllib.request


def _require_pyjwt() -> None:
    try:
        import jwt  # noqa: F401
    except ImportError:
        print(
            "Error: PyJWT is required. Install 'PyJWT[crypto]>=2.0' before running this script.",
            file=sys.stderr,
        )
        sys.exit(1)


def generate_token(key_id: str, issuer_id: str, private_key_path: str) -> str:
    import jwt

    with open(private_key_path) as f:
        private_key = f.read()

    payload = {
        "iss": issuer_id,
        "exp": int(time.time()) + 1200,
        "aud": "appstoreconnect-v1",
    }
    return jwt.encode(
        payload, private_key, algorithm="ES256", headers={"kid": key_id}
    )


def api_get(url: str, token: str) -> dict:
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())


def api_post(url: str, token: str, body: dict) -> dict:
    data = json.dumps(body).encode()
    req = urllib.request.Request(
        url,
        data=data,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode()
        print(f"HTTP {exc.code}: {detail}", file=sys.stderr)
        raise


BASE_URL = "https://api.appstoreconnect.apple.com/v1"
BUNDLE_ID = "com.aldunelabs.caker"


def main() -> None:
    _require_pyjwt()

    version = os.environ.get("VERSION", "").strip()
    key_id = os.environ.get("APP_STORE_CONNECT_API_KEY_ID", "").strip()
    issuer_id = os.environ.get("APP_STORE_CONNECT_API_KEY_ISSUER_ID", "").strip()

    if not version:
        print("Error: VERSION environment variable is required.", file=sys.stderr)
        sys.exit(1)

    if not key_id or not issuer_id:
        print(
            "Error: APP_STORE_CONNECT_API_KEY_ID and APP_STORE_CONNECT_API_KEY_ISSUER_ID are required.",
            file=sys.stderr,
        )
        sys.exit(1)

    key_path = os.path.expanduser(f"~/.appstoreconnect/private_keys/AuthKey_{key_id}.p8")

    if not os.path.exists(key_path):
        print(f"Error: API key not found at {key_path}", file=sys.stderr)
        sys.exit(1)

    print("Generating App Store Connect API token...")
    token = generate_token(key_id, issuer_id, key_path)

    print(f"Looking up app with bundle ID {BUNDLE_ID}...")
    apps = api_get(f"{BASE_URL}/apps?filter[bundleId]={BUNDLE_ID}", token)
    if not apps["data"]:
        print(f"Error: app {BUNDLE_ID} not found in App Store Connect.", file=sys.stderr)
        sys.exit(1)
    app_id = apps["data"][0]["id"]
    print(f"Found app ID: {app_id}")

    print(f"Looking for App Store version {version} (MAC_OS)...")
    versions = api_get(
        f"{BASE_URL}/appStoreVersions"
        f"?filter[app]={app_id}"
        f"&filter[versionString]={version}"
        f"&filter[platform]=MAC_OS",
        token,
    )

    if not versions["data"]:
        print(
            f"Error: no App Store version found for {version}.\n"
            "Create the version in App Store Connect before running this step.",
            file=sys.stderr,
        )
        sys.exit(1)

    version_id = versions["data"][0]["id"]
    version_state = versions["data"][0]["attributes"]["appStoreState"]
    print(f"Found version ID: {version_id} (state: {version_state})")

    print(f"Submitting version {version} for App Store review...")
    result = api_post(
        f"{BASE_URL}/appStoreVersionSubmissions",
        token,
        {
            "data": {
                "type": "appStoreVersionSubmissions",
                "relationships": {
                    "appStoreVersion": {
                        "data": {"type": "appStoreVersions", "id": version_id}
                    }
                },
            }
        },
    )
    print(f"Submission created: {result['data']['id']}")
    print("Version submitted for App Store review successfully.")


if __name__ == "__main__":
    main()
