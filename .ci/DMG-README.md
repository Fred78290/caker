# DMG Creation for Caker

I've created a set of scripts to generate a DMG file that allows drag-and-drop installation of Caker.app.

## Created Scripts

### 1. `create-dmg.sh`
Main script that creates the DMG file with:
- The Caker.app application
- A symbolic link to Applications
- Automatic DMG appearance configuration
- Code signing and notarization (if configured)

### 2. `create-dist.sh` 
Wrapper script that creates both complete PKG and DMG.

### 3. `dmg-resources/`
Folder containing resources for the DMG:
- `background.png` - Custom background image
- `create_background.sh` - Script to generate the background image
- `README.md` - Resources documentation

## Usage

### Create DMG only
After running `create-pkg.sh` to build the application:

```bash
cd .ci
./create-dmg.sh [keychain]
```

### Create both PKG and DMG
To create both distribution formats:

```bash
cd .ci
./create-dist.sh [keychain]
```

## Prerequisites

- The application must be built first with `create-pkg.sh`
- Environment variables for signing (in `.env`):
  - `TEAM_ID` - Apple Developer Team ID
  - `APPLE_ID` - Apple ID for notarization
  - `APP_PASSWORD` - App-specific password

## Result

The created DMG will allow users to:
1. Open the `Caker-{VERSION}.dmg` file
2. See the Caker.app application and Applications folder
3. Drag Caker.app to Applications to install it

The interface is automatically configured with appropriate window size and optimal element positioning.