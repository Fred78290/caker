
You are a localization agent for the https://github.com/Fred78290/caker Swift project. Your job is to find all String(localized:) calls that are missing French translations in Resources/Localizable.xcstrings and add accurate ones with take care of duplicate.

## Step 1 — Detect missing keys

Run this Python script from the repo root:

```python
import json, os

SOURCE_DIRS = ["Sources/cakedlib", "Sources/cakectl", "Sources/caked"]
XCSTRINGS = "Resources/Localizable.xcstrings"

with open(XCSTRINGS) as f:
    data = json.load(f)
strings = data["strings"]

def has_french(key):
    return "fr" in strings.get(key, {}).get("localizations", {})

def extract_strings(filepath):
    with open(filepath, encoding="utf-8", errors="replace") as f:
        content = f.read()
    results = []
    i = 0
    while i < len(content):
        idx = content.find('String(localized:', i)
        if idx == -1: break
        j = idx + len('String(localized:')
        while j < len(content) and content[j] in ' \t\n\r': j += 1
        if j >= len(content) or content[j] != '"': i = idx + 1; continue
        j += 1
        s = []
        while j < len(content):
            c = content[j]
            if c == '\\' and j + 1 < len(content):
                nc = content[j+1]
                if nc == '(':
                    k = j + 2; depth = 1
                    while k < len(content) and depth > 0:
                        if content[k] == '(': depth += 1
                        elif content[k] == ')': depth -= 1
                        k += 1
                    s.append('%@'); j = k; continue
                elif nc == '"': s.append('"'); j += 2; continue
                elif nc == 'n': s.append('\n'); j += 2; continue
                else: s.append(nc); j += 2; continue
            elif c == '"': break
            s.append(c); j += 1
        results.append(''.join(s))
        i = j + 1
    return results

missing = {}
for d in SOURCE_DIRS:
    for root, _, files in os.walk(d):
        for fname in files:
            if not fname.endswith('.swift'): continue
            for s in extract_strings(os.path.join(root, fname)):
                if not has_french(s) and s not in missing:
                    missing[s] = True

print(json.dumps(list(missing.keys()), indent=2))
print(f"\nTotal missing: {len(missing)}")
```

If the script prints "Total missing: 0", stop here — no work to do.

## Step 2 — Translate

For each key in the output, produce an accurate French translation. Rules:
- Keep format specifiers (%@, %lld, %1$@, %2$@, etc.) in the correct position; when multiple %@ appear in the French value and order could differ, use numbered positional specifiers (%1$@, %2$@, etc.)
- Keep technical terms untranslated: VM, VNC, TLS, macOS, DHCP, gRPC, caked, cakectl, cakectl, compose, IPSW, UUID, JSON, YAML
- Keep backtick-wrapped commands exactly as-is (e.g. `cakectl up`)
- Translate naturally and idiomatically, not word-for-word
- Use "vous" form for user-facing instructions

## Step 3 — Write translations to file

Use this Python snippet (fill in your translations as the new_entries dict):

```python
import json

XCSTRINGS = "Resources/Localizable.xcstrings"
with open(XCSTRINGS, encoding="utf-8") as f:
    data = json.load(f)
strings = data["strings"]

new_entries = {
    # "english key": "traduction française",
    # ... paste your translations here
}

for key, fr_val in new_entries.items():
    if key not in strings:
        strings[key] = {"extractionState": "manual", "localizations": {
            "fr": {"stringUnit": {"state": "translated", "value": fr_val}}}}
    else:
        locs = strings[key].setdefault("localizations", {})
        if "fr" not in locs:
            locs["fr"] = {"stringUnit": {"state": "translated", "value": fr_val}}

output = json.dumps(data, indent=2, sort_keys=True, ensure_ascii=False,
                    separators=(',', ' : '))
with open(XCSTRINGS, "w", encoding="utf-8") as f:
    f.write(output + "\n")

# Validate
with open(XCSTRINGS) as f: json.load(f)
print(f"Done. Added {len(new_entries)} translations. JSON is valid.")
```
