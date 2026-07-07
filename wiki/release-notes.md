<!-- markdownlint-disable MD033 MD024 -->

<div id="content-fr" style="display:none" markdown="1">

# Notes de version

## 2026-06-20 (Résumé du log Git - main)

### Ajouté
- Voir les points marquants des commits ci-dessous.

### Mis à jour
- feat: Enable macOS 27+ guest installation in App Store builds
- feat: Correct conditional compilation for VirtualInstallSPI backend
- feat: Enhance VM creation reliability and error reporting
- feat: Conditionally compile IPSW installer for arm64
- feat: Update DFU restore mode setting label
- feat: Expand tilde in build option file paths
- feat: Propagate build errors via build stream
- feat: enable virtual install backend and DFU mode for App Store builds
- fix: Ensure reliable IPSW installer cancellation in async contexts
- fix: Correct VZMacOSInstaller lifecycle for queued IPSW installs
- Potential fix for pull request finding
- Potential fix for pull request finding
- Discard unneeded import
- refactor: Reset gcdStarted state early during GrandCentral termination
- refactor: Enhance GrandCentral state management and watcher logic
- feat: Set VM status to running on external process detection
- refactor: Make DirWatcher callback non-throwing
- feat: Enhance VM directory watcher for robustness and detailed logging
- feat: Monitor VM directories in app mode
- refactor: Simplify CodableError userInfo key handling

### Notes
- Résumé généré automatiquement à partir des commits Git récents sur la branche `main`.
- Commande utilisée : `git log --no-merges --oneline -n 20 -- Sources wiki .github/workflows`.


## 2026-06-17

### Ajouté
- **Backend d'installation macOS 27 (Golden Gate)** (builds hors App Store, Apple Silicon uniquement) : Caker installe désormais les invités macOS 27 en utilisant le framework privé `AppleMobileDeviceRestore` (AMRestore) au lieu de `VZMacOSInstaller`. Cela contourne la régression de `VZMacOSInstaller` qui se bloque vers 78 % lors de l'installation d'invités macOS 27 sur un hôte macOS 26 ([utmapp/UTM#7746](https://github.com/utmapp/UTM/issues/7746)). Le nouveau chemin est sélectionné automatiquement dès que l'IPSW cible macOS 27 ou une version ultérieure, et peut être forcé sur n'importe quelle version avec la clé UserDefaults `CakerForceVirtualInstallBackend`.

### Notes
- AMRestore communique avec des démons système (`com.apple.mobile.restored`) bloqués par l'App Sandbox ; cette fonctionnalité est donc intentionnellement absente du build App Store.
- Les journaux de restauration sont écrits dans `~/Library/Application Support/Caker/VirtualInstall/Logs/`.
- Voir les pages [FAQ](faq) et [Dépannage](troubleshooting) pour les conseils de diagnostic.

## 2026-05-29

### Ajouté
- **API REST LXD** : `caked service listen --rest` active un serveur API HTTP/HTTPS compatible LXD sur `/1.0/instances`, `/1.0/networks`, `/1.0/images`, `/1.0/operations`, `/1.0/certificates`, `/1.0/identities` et `/1.0/auth-groups`. Ports par défaut : 8443 (HTTPS/mTLS), 8080 (HTTP). Modifiable avec `--rest-port`.
- **Interface Web** : `caked service listen --web-ui <path>` sert le frontend React/Vite fourni sur `/ui`. Accepte un répertoire ou une archive `.zip`.
- **Commande `caked convert`** : convertit des images disque QCOW2 ou VMDK au format raw grâce à une implémentation pure Swift (aucun outil externe requis). Options : `--source-format qcow2` (par défaut) ou `--source-format vmdk`.
- **Commande `cakectl vnc`** : ouvre une fenêtre de client VNC native connectée à l'affichage d'une VM en cours d'exécution. Établit automatiquement un tunnel de connexion VNC via `caked`.
- Support du script de build **Ubuntu 26.04 (Resolute Rhino)** mis à jour.

### Mis à jour
- Renforcement de la gestion des certificats TLS : suppression du force-unwrap, certificat CA mTLS requis pour le contournement par mot de passe.
- Les identifiants d'authentification de base sont désormais stockés en mémoire (plus écrits dans `sessionStorage`).
- Vue « À propos » mise à jour pour refléter les capacités de contrôle à distance (CLI, GUI et API Web).

### Notes
- L'API REST est compatible LXD ; les clients et outils LXD existants peuvent se connecter directement à `caked`.
- Le proxy de développement de l'interface Web (`VITE_API_TARGET`) pointe par défaut vers `http://127.0.0.1:8080`.

## 2026-03-26 (Résumé du log Git - main)

### Ajouté
- Voir les points marquants des commits ci-dessous.

### Mis à jour
- Refactor ensurePrivilegedBootstrapFiles call
- Update Sources/caker/Model/AppState.swift
- Terminate app and alert user on privileged bootstrap failure
- Use singleton pattern for AppState and automate bootstrap file check
- Clarify error message for IPSW usage on non-ARM architectures
- Use shared constant for the caked command name
- Improve error feedback for virtual machine loading failures
- Adjust daemon launch priority to background
- Refactor service management and introduce manual daemon control
- Refactor AppState service loading and mode switching logic
- Configure window title and toolbar style for HomeView
- Add run mode status indicator to the HomeView toolbar
- Group navigation toolbar items
- Finish shell stream when closing the interactive shell
- Hide background visibility for VM status toolbar items
- Update Sources/caker/MainApp.swift
- Update Sources/caker/Helpers/Authorization.swift
- Update Sources/caker/Helpers/Authorization.swift
- Update Sources/caker/Helpers/Authorization.swift
- Refactor privileged operations to use native Authorization Services

### Notes
- Résumé généré automatiquement à partir des commits Git récents sur la branche `main`.
- Commande utilisée : `git log --no-merges --oneline -n 20 -- Sources wiki`.


## 2026-03-03 (Résumé du log Git - main)

### Ajouté
- Voir les points marquants des commits ci-dessous.

### Mis à jour
- Adds helper for consistent virtual machine document creation
- Adds handler for retrieving VM infos and configuration
- Refactors agent helper creation for consistency
- Refactors command handlers to use provider instead of client
- Adds utility to instantiate agent helpers with varied inputs
- Simplifies init call syntax for data conversion
- Refactors info retrieval to support VMLocation input
- Removes runMode check when selecting gRPC client usage
- Adds option to include VM config in list output
- Adds option to include VM config in list commands
- Use display.cgSize for document view sizing
- Add Codable conformance to SupportedPlatform
- Make enum codable and remove unused conformances
- Simplifies console config to use String instead of struct
- Standardizes display size types across the application
- Refactors `InfosHandler` file structure
- Adds optional VM configuration to list requests
- Refactor config mapping and introduce public model
- Refactors VM hardware identifier storage
- Centralizes VM configuration and image source types

### Notes
- Résumé généré automatiquement à partir des commits Git récents sur la branche `main`.
- Commande utilisée : `git log --no-merges --oneline -n 20 -- Sources wiki`.


## 2026-02-26 (Résumé du log Git - main)

### Ajouté
- Capacités Grand Central Dispatch pour le streaming en direct de l'état des VM/du système (incluant la commande `gcd` et le flux de mise à jour).
- Méthodes gRPC pour le dispatcher Grand Central/les chemins de mise à jour et la gestion associée des flux de statut.
- Dépendances de projet supplémentaires et échafaudage de plan de tests.

### Mis à jour
- Comportement de démarrage/arrêt du service affiné.
- Aide/descriptions de la commande de démarrage de VM améliorées.
- Gestion des demandes d'aide CLI et des erreurs améliorée.
- Fiabilité d'exécution des VM/réseau améliorée (mises à jour de statut, stabilité gRPC, logique de démarrage réseau).
- Gestion des commandes shell améliorée (y compris un échappement plus sûr des arguments).

### Notes
- Résumé généré à partir des commits récents sur la branche `main`.
- Voir l'historique Git pour tous les détails : `git log --oneline`.

## 2026-02-26

### Ajouté
- Structure initiale du wiki publiée.
- Pages Démarrage, Architecture, Développement, Dépannage et FAQ.
- Script de publication du wiki : `Scripts/publish-wiki.sh`.

### Mis à jour
- Consignes de contribution alignées sur la branche de base `main`.
- Formulation et structure améliorées sur les principales pages du wiki.

### Notes
- La publication du wiki nécessite l'accès au wiki GitHub sur le dépôt cible.
- Pour les dépôts privés, utilisez `GH_TOKEN`/`GITHUB_TOKEN` ou `USE_SSH=1`.

## Comment mettre à jour ce wiki

1. Modifiez les pages dans le répertoire local `wiki/`.
2. Passez en revue les modifications et gardez la navigation synchronisée (`Home.md` et `_Sidebar.md`).
3. (Optionnel) Créez automatiquement une entrée de notes de version datée avec :
	- `./Scripts/new-wiki-release-entry.sh`
	- ou `./Scripts/new-wiki-release-entry.sh YYYY-MM-DD`
4. Publiez avec :
	- `GH_TOKEN="${GITHUB_TOKEN}" ./Scripts/publish-wiki.sh Fred78290 caker`
	- ou `USE_SSH=1 ./Scripts/publish-wiki.sh Fred78290 caker`
5. Ajoutez les mises à jour de documentation notables dans la nouvelle entrée datée.

## Modèle d'entrée

Copiez/collez ce bloc pour la prochaine mise à jour :

```markdown
## YYYY-MM-DD

### Ajouté
- ...

### Mis à jour
- ...

### Notes
- ...
```

</div>

<div id="content-en" style="display:block" markdown="1">

# Release Notes

## 2026-06-20 (Git log summary - main)

### Added
- See commit highlights below.

### Updated
- feat: Enable macOS 27+ guest installation in App Store builds
- feat: Correct conditional compilation for VirtualInstallSPI backend
- feat: Enhance VM creation reliability and error reporting
- feat: Conditionally compile IPSW installer for arm64
- feat: Update DFU restore mode setting label
- feat: Expand tilde in build option file paths
- feat: Propagate build errors via build stream
- feat: enable virtual install backend and DFU mode for App Store builds
- fix: Ensure reliable IPSW installer cancellation in async contexts
- fix: Correct VZMacOSInstaller lifecycle for queued IPSW installs
- Potential fix for pull request finding
- Potential fix for pull request finding
- Discard uneeded import
- refactor: Reset gcdStarted state early during GrandCentral termination
- refactor: Enhance GrandCentral state management and watcher logic
- feat: Set VM status to running on external process detection
- refactor: Make DirWatcher callback non-throwing
- feat: Enhance VM directory watcher for robustness and detailed logging
- feat: Monitor VM directories in app mode
- refactor: Simplify CodableError userInfo key handling

### Notes
- Summary generated automatically from recent git commits on branch `main`.
- Command used: `git log --no-merges --oneline -n 20 -- Sources wiki .github/workflows`.


## 2026-06-17

### Added
- **macOS 27 (Golden Gate) installation backend** (non-App Store builds, Apple Silicon only): Caker now installs macOS 27 guests using the private `AppleMobileDeviceRestore` (AMRestore) framework instead of `VZMacOSInstaller`. This works around the `VZMacOSInstaller` regression that stalls at ~78% when installing macOS 27 guests on a macOS 26 host ([utmapp/UTM#7746](https://github.com/utmapp/UTM/issues/7746)). The new path is selected automatically whenever the IPSW targets macOS 27 or later, and can be force-enabled on any version with the `CakerForceVirtualInstallBackend` UserDefaults key.

### Notes
- AMRestore talks to system daemons (`com.apple.mobile.restored`) that are blocked by the App Sandbox, so this feature is intentionally absent from the App Store build.
- Restore logs are written to `~/Library/Application Support/Caker/VirtualInstall/Logs/`.
- See the [FAQ](faq) and [Troubleshooting](troubleshooting) pages for diagnosis guidance.

## 2026-05-29

### Added
- **LXD REST API**: `caked service listen --rest` enables an LXD-compatible HTTP/HTTPS API server at `/1.0/instances`, `/1.0/networks`, `/1.0/images`, `/1.0/operations`, `/1.0/certificates`, `/1.0/identities`, and `/1.0/auth-groups`. Default ports: 8443 (HTTPS/mTLS), 8080 (HTTP). Override with `--rest-port`.
- **Web UI**: `caked service listen --web-ui <path>` serves the bundled React/Vite frontend at `/ui`. Accepts a directory or a `.zip` archive.
- **`caked convert` command**: converts QCOW2 or VMDK disk images to raw format using a pure-Swift implementation (no external tools required). Flags: `--source-format qcow2` (default) or `--source-format vmdk`.
- **`cakectl vnc` command**: opens a native VNC client window connected to a running VM's display. Automatically tunnels the VNC connection through `caked`.
- **Ubuntu 26.04 (Resolute Rhino)** build script support updated.

### Updated
- TLS certificate handling hardened: force-unwrap removed, mTLS CA certificate required for password bypass.
- Basic Auth credential moved to in-memory storage (no longer written to `sessionStorage`).
- `About` view updated to reflect remote control (CLI, GUI, and Web API) capabilities.

### Notes
- The REST API is LXD-compatible; existing LXD clients and tooling can connect directly to `caked`.
- The Web UI development proxy (`VITE_API_TARGET`) defaults to `http://127.0.0.1:8080`.

## 2026-03-26 (Git log summary - main)

### Added
- See commit highlights below.

### Updated
- Refactor ensurePrivilegedBootstrapFiles call
- Update Sources/caker/Model/AppState.swift
- Terminate app and alert user on privileged bootstrap failure
- Use singleton pattern for AppState and automate bootstrap file check
- Clarify error message for IPSW usage on non-ARM architectures
- Use shared constant for the caked command name
- Improve error feedback for virtual machine loading failures
- Adjust daemon launch priority to background
- Refactor service management and introduce manual daemon control
- Refactor AppState service loading and mode switching logic
- Configure window title and toolbar style for HomeView
- Add run mode status indicator to the HomeView toolbar
- Group navigation toolbar items
- Finish shell stream when closing the interactive shell
- Hide background visibility for VM status toolbar items
- Update Sources/caker/MainApp.swift
- Update Sources/caker/Helpers/Authorization.swift
- Update Sources/caker/Helpers/Authorization.swift
- Update Sources/caker/Helpers/Authorization.swift
- Refactor privileged operations to use native Authorization Services

### Notes
- Summary generated automatically from recent git commits on branch `main`.
- Command used: `git log --no-merges --oneline -n 20 -- Sources wiki`.


## 2026-03-03 (Git log summary - main)

### Added
- See commit highlights below.

### Updated
- Adds helper for consistent virtual machine document creation
- Adds handler for retrieving VM infos and configuration
- Refactors agent helper creation for consistency
- Refactors command handlers to use provider instead of client
- Adds utility to instantiate agent helpers with varied inputs
- Simplifies init call syntax for data conversion
- Refactors info retrieval to support VMLocation input
- Removes runMode check when selecting gRPC client usage
- Adds option to include VM config in list output
- Adds option to include VM config in list commands
- Use display.cgSize for document view sizing
- Add Codable conformance to SupportedPlatform
- Make enum codable and remove unused conformances
- Simplifies console config to use String instead of struct
- Standardizes display size types across the application
- Refactors `InfosHandler` file structure
- Adds optional VM configuration to list requests
- Refactor config mapping and introduce public model
- Refactors VM hardware identifier storage
- Centralizes VM configuration and image source types

### Notes
- Summary generated automatically from recent git commits on branch `main`.
- Command used: `git log --no-merges --oneline -n 20 -- Sources wiki`.


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
	- `GH_TOKEN="${GITHUB_TOKEN}" ./Scripts/publish-wiki.sh Fred78290 caker`
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

</div>
