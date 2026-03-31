# 🚀 Sparkle Configuration for Caker - Production Guide

This document describes the complete integration of [Sparkle](https://sparkle-project.org/) into the Caker project for automatic update management in production.

## 🎯 Overview

Sparkle is now fully integrated into Caker with:
- ✅ Complete automation scripts
- ✅ GitHub Actions workflow
- ✅ Security configuration
- ✅ SwiftUI user interface
- ✅ Automated build pipeline

## 🚀 Quick Start

### 1. Initial setup (one time only)

```bash
# Complete automatic configuration
./sparkle.sh setup
```

This command:
- Installs dependencies (Sparkle via Homebrew)
- Generates Ed25519 signing keys
- Automatically updates Info.plist
- Checks complete configuration

### 2. First test build

```bash
# Debug build for testing
./sparkle.sh build debug

# Check status
./sparkle.sh status
```

### 3. First release

```bash
# Complete build and publication
./sparkle.sh release 1.0.0
```

## 📁 Created file structure

```
caker/
├── sparkle.sh                    # Main automation script
├── sparkle.conf                  # Centralized configuration
├── .sparkle/                     # Signing keys (ignored by git)
├── Scripts/
│   ├── sparkle-generate-keys.sh  # Ed25519 key generation
│   ├── sparkle-sign-release.sh   # Release signing
│   ├── sparkle-build-integration.sh  # Integrated build
│   └── sparkle-github-release.sh # Automatic GitHub publication
├── .github/workflows/
│   └── sparkle-release.yml       # GitHub Actions workflow
├── Sources/caker/Helpers/
│   └── CheckForUpdatesView.swift # SwiftUI interface
└── docs/
    └── sparkle-integration.md    # This documentation
```

## 🔧 Detailed configuration

### Automatic modifications made

#### Package.swift
```swift
.package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.1")
//...
.product(name: "Sparkle", package: "Sparkle")
```

#### MainApp.swift
```swift
import Sparkle

struct MainApp: App {
    private let updaterController: SPUStandardUpdaterController
    
    init() {
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }
    
    // "Check for Updates..." menu added automatically
}
```

#### Info.plist
```xml
<key>SUFeedURL</key>
<string>https://caker.aldunelabs.com/appcast/appcast.xml</string>
<key>SUEnableAutomaticChecks</key>
<true/>
<key>SUScheduledCheckInterval</key>
<integer>86400</integer>
<key>SUPublicEDKey</key>
<string>[AUTOMATICALLY_GENERATED_KEY]</string>
```

## ⚡ Using the scripts

### Main script `./sparkle.sh`

```bash
# Configuration commands
./sparkle.sh setup      # Complete initial configuration
./sparkle.sh keys       # Regenerate keys
./sparkle.sh config     # Show configuration
./sparkle.sh status     # Check status

# Build commands
./sparkle.sh build debug    # Debug build
./sparkle.sh build release  # Release build
./sparkle.sh clean          # Clean

# Release commands
./sparkle.sh release 1.2.3                    # Complete release
./sparkle.sh sign 1.2.3 path/to/Caker.dmg     # Sign only
./sparkle.sh github 1.2.3 build/Caker.dmg     # Publish on GitHub
```

### Individual scripts

```bash
# Key configuration (included in setup)
./Scripts/sparkle-generate-keys.sh

# Integrated build with Sparkle
./Scripts/sparkle-build-integration.sh 1.2.3

# Signing an existing release  
./Scripts/sparkle-sign-release.sh 1.2.3 /path/to/Caker.dmg

# Automatic GitHub publication
./Scripts/sparkle-github-release.sh 1.2.3 /path/to/Caker.dmg "Description"
```

## 🔐 GitHub Actions configuration (automatic)

### Required secrets

In the GitHub repository settings, add these secrets:

```bash
# Generate once with ./sparkle.sh keys, then copy the values
SPARKLE_PRIVATE_KEY  # Content of .sparkle/sparkle_private_key.pem
SPARKLE_PUBLIC_KEY   # Content of .sparkle/sparkle_public_key.pem
```

### Automatic triggering

The workflow triggers:
- ✅ On push of a tag `v*.*.*` (ex: `v1.2.3`)
- ✅ Manually via GitHub Actions UI
- ✅ Build, signing and automatic publication

### Trigger example

```bash
# Create and push a tag to trigger the release
git tag v1.2.3
git push origin v1.2.3

# The release happens automatically:
# 1. Build the app
# 2. Create DMG
# 3. Sparkle signing
# 4. Publish GitHub Release
# 5. Update appcast
```

## 🔄 Production release process

### Manual release

```bash
# 1. Configuration (one time only)
./sparkle.sh setup

# 2. Build and publication
./sparkle.sh release 1.2.3

# 3. Publish on GitHub (optional if not automatic)
./sparkle.sh github 1.2.3 build/Caker-1.2.3.dmg
```

### Automatic release (recommended)

```bash
# Simple tag push
git tag v1.2.3 -m "Release version 1.2.3"
git push origin v1.2.3

# GitHub Actions automatically does:
# - Signed build
# - DMG creation
# - Sparkle signing  
# - Release publication
# - User notifications
```

## 🌐 Appcast configuration

### Custom XML Appcast (current setup)

Caker now uses a **custom XML appcast** instead of GitHub releases feed for enhanced control:

```
https://caker.aldunelabs.com/appcast/appcast.xml
```

**Advantages of custom appcast:**
- ✅ **Full control** over release metadata  
- ✅ **Better performance** with optimized XML
- ✅ **Enhanced security** with integrated Ed25519 signatures
- ✅ **Custom release notes** formatting
- ✅ **Selective release** inclusion

### Quick appcast management

```bash
# Generate appcast from GitHub releases  
./sparkle.sh appcast generate

# Deploy to GitHub Pages
./sparkle.sh appcast deploy

# Check status
./sparkle.sh appcast status
```

### GitHub Releases (legacy)

The previous URL used the GitHub feed:
```
https://github.com/Fred78290/caker/releases.atom
```

### Alternative hosting options

For different hosting needs:

1. **GitHub Pages** (current setup):
   ```
   https://caker.aldunelabs.com/appcast/appcast.xml
   ```

2. **Custom server**:
   ```xml
   <!-- Update Info.plist -->
   <key>SUFeedURL</key>
   <string>https://your-site.com/appcast.xml</string>
   ```

### Generated appcast structure

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>Caker Updates</title>
        <description>Automatic updates for Caker</description>
        <language>en</language>
        <item>
            <title>Caker 1.2.3</title>
            <description><![CDATA[...]]></description>
            <pubDate>Mon, 29 Mar 2026 12:00:00 +0000</pubDate>
            <enclosure url="https://github.com/Fred78290/caker/releases/download/v1.2.3/Caker-1.2.3.dmg"
                       sparkle:version="1.2.3"
                       sparkle:edSignature="[ED25519_SIGNATURE]" />
        </item>
    </channel>
</rss>
```

## 🛡️ Security and best practices

### Key protection

- ✅ `.sparkle/` automatically ignored by git
- ✅ Keys stored in GitHub Secrets for CI/CD
- ✅ Private key never leaves build environment
- ✅ Ed25519 signature (recommended by Apple)

### Release validation

```bash
# Verify signature of a release
./Scripts/sparkle-verify-signature.sh Caker-1.2.3.dmg

# Test appcast
curl -s https://github.com/Fred78290/caker/releases.atom | head -20
```

### Rollback in case of issues

1. **Remove defective release**:
   ```bash
   gh release delete v1.2.3
   git tag -d v1.2.3
   git push origin :refs/tags/v1.2.3
   ```

2. **Republish previous version**:
   ```bash
   ./sparkle.sh release 1.2.2
   ```

## 📊 Testing and validation

### Automated tests

The `./sparkle.sh status` script checks:
- ✅ Signature keys present
- ✅ Info.plist configured correctly
- ✅ Sparkle dependency in Package.swift
- ✅ Required tools installed

### Manual tests

1. **Test build**:
   ```bash
   ./sparkle.sh build debug
   ```

2. **Interface test**:
   - Launch the app
   - Menu → "Check for Updates…"
   - Verify Sparkle dialog appears

3. **Update test**:
   - Publish a new version
   - Test from an older version
   - Verify automatic installation

## 🚨 Troubleshooting

### Common issues

#### "Sparkle not found" error
```bash
# Install Sparkle
brew install sparkle

# Or force reinstallation
./sparkle.sh setup
```

#### Signature error
```bash
# Regenerate keys
rm -rf .sparkle
./sparkle.sh keys
```

#### GitHub Actions fail
1. Check secrets `SPARKLE_PRIVATE_KEY` and `SPARKLE_PUBLIC_KEY`
2. Verify repository permissions
3. Check detailed logs

### Verbose debugging

```bash
# Verbose mode for diagnostics
SPARKLE_VERBOSE=true ./sparkle.sh status
```

### Contacts and support

- 📖 Sparkle documentation: https://sparkle-project.org/documentation/
- 🐛 Sparkle issues: https://github.com/sparkle-project/Sparkle/issues
- 💬 Caker configuration: See this file and the scripts

## 📈 Next steps and evolution

### Possible improvements

1. **Delta updates**: Differential updates to reduce size
2. **Staged rollout**: Progressive deployment by user percentage
3. **Telemetry**: Usage and update statistics
4. **Notifications**: Integration with notification services
5. **Multi-channel**: Beta, stable, nightly channels

### Monitoring

- GitHub Releases analytics
- Sparkle logs in Console.app
- User feedback via GitHub issues

---

## ✅ Production checklist

- [ ] Initial configuration: `./sparkle.sh setup`
- [ ] Build tests: `./sparkle.sh build debug`
- [ ] User interface tests
- [ ] GitHub Secrets configuration
- [ ] GitHub Actions tests
- [ ] Draft test release
- [ ] Complete update validation
- [ ] User documentation updated
- [ ] New feature communication

🎉 **Sparkle is now fully configured and ready for production!**
