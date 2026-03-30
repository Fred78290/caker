# 🌐 Custom Sparkle Appcast for Caker

This directory contains the custom XML appcast for Sparkle automatic updates, instead of using the GitHub releases feed.

## 📁 Structure

```
docs/appcast/
├── appcast.xml          # Main appcast file (generated)
└── README.md           # This documentation
```

## 🚀 Quick Start

### Generate Appcast
```bash
# Generate appcast from GitHub releases
./sparkle.sh appcast generate

# Or use the script directly
./Scripts/sparkle-generate-appcast-xml.sh
```

### Deploy to GitHub Pages
```bash
# Deploy appcast to GitHub Pages
./sparkle.sh appcast deploy

# Or use the script directly
./Scripts/sparkle-deploy-appcast.sh
```

### Check Status
```bash
# Check appcast status
./sparkle.sh appcast status
```

## 🔧 Configuration

The appcast is configured in `Caker/Caker/Info.plist`:
```xml
<key>SUFeedURL</key>
<string>https://caker.aldunelabs.com/appcast/appcast.xml</string>
```

## 📄 Appcast Format

The generated XML follows the Sparkle RSS 2.0 format:

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>Caker Updates</title>
        <description>Automatic updates for Caker</description>
        <item>
            <title>Caker 1.2.3</title>
            <description><![CDATA[Release notes...]]></description>
            <pubDate>Sat, 29 Mar 2026 12:00:00 +0000</pubDate>
            <sparkle:version>1.2.3</sparkle:version>
            <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
            <enclosure url="https://github.com/Fred78290/caker/releases/download/v1.2.3/Caker-1.2.3.dmg"
                       length="12345678"
                       type="application/x-apple-diskimage"
                       sparkle:edSignature="[ED25519_SIGNATURE]"
                       sparkle:os="macos" />
        </item>
    </channel>
</rss>
```

## 🔒 Security

- **Ed25519 Signatures**: Each release is signed with Ed25519 for security
- **HTTPS Only**: All downloads and appcast access use HTTPS
- **Signature Verification**: Sparkle verifies signatures before installing updates

## 🌐 Deployment

The appcast is automatically deployed to GitHub Pages at:
- **Production URL**: https://caker.aldunelabs.com/appcast/appcast.xml
- **GitHub Source**: https://github.com/Fred78290/caker/blob/main/docs/appcast/appcast.xml

## 🔄 Automatic Updates

The GitHub Actions workflow automatically:
1. Generates the appcast after each release
2. Deploys it to GitHub Pages
3. Updates the appcast with the latest releases

## 🛠️ Manual Operations

### Generate appcast for specific version
```bash
./Scripts/sparkle-generate-appcast-xml.sh --version 1.2.3
```

### Include more releases
```bash
./Scripts/sparkle-generate-appcast-xml.sh --releases 20
```

### Deploy with force
```bash
./Scripts/sparkle-deploy-appcast.sh --force
```

### Dry run deployment
```bash
./Scripts/sparkle-deploy-appcast.sh --dry-run
```

## 🔍 Troubleshooting

### Appcast not updating
1. Check if appcast.xml has recent changes
2. Verify GitHub Pages deployment
3. Check for any XML validation errors

### Sparkle not finding updates
1. Verify appcast URL in Info.plist
2. Check if appcast is accessible via HTTPS
3. Ensure DMG files have valid signatures

### Debug appcast generation
```bash
# Verbose output
./Scripts/sparkle-generate-appcast-xml.sh --help

# Check dependencies
./sparkle.sh status
```

## 📊 Monitoring

- **GitHub Pages status**: Check repository settings → Pages
- **Appcast accessibility**: https://caker.aldunelabs.com/appcast/appcast.xml
- **XML validation**: Use browser or XML validator

## 🆚 vs GitHub Feed

### Custom XML Appcast Advantages:
- ✅ **Full control** over release metadata
- ✅ **Better performance** with optimized XML
- ✅ **Enhanced security** with Ed25519 signatures
- ✅ **Custom release notes** formatting
- ✅ **Selective release** inclusion
- ✅ **Better caching** control

### GitHub Feed Limitations:
- ❌ Limited metadata control
- ❌ No signature integration
- ❌ Basic release notes formatting
- ❌ All releases included by default

## 📚 Resources

- [Sparkle Documentation](https://sparkle-project.org/documentation/)
- [RSS 2.0 Specification](https://www.rssboard.org/rss-specification)
- [GitHub Pages Documentation](https://docs.github.com/en/pages)

---

🎉 **Your custom appcast system is ready!**