<!-- markdownlint-disable MD033 MD024 -->

<div class="lang-fr" style="display:none" markdown="1">

# Développement

## Organisation du code

- `Sources/cakectl/Commands/` – gestionnaires de commandes CLI
- `Sources/caked/Commands/` et `Sources/caked/Handlers/` – gestionnaires de commandes et d'exécution du démon
- `Sources/cakedlib/` – utilitaires partagés, configuration et abstractions principales

## Catalogue d'images de VM (assistant Caker.app, et raccourcis `build`/`launch --<id>`)

L'assistant de création de VM de Caker.app (`Sources/caker/Views/VirtualMachineWizard.swift`) propose des images ISO, IPSW et cloud (qcow2) préconfigurées. Cette liste n'est plus codée en dur dans des enums Swift : elle provient d'une ressource JSON embarquée, chargée au runtime. Le catalogue vit désormais dans `CakedLib` (il était auparavant réservé à `caker`), ce qui permet à `caked build`/`cakectl build` (et `launch`) de résoudre eux aussi un id du catalogue via des drapeaux `--<id>` générés (`--macos12`, `--ubuntu2604`, …) — voir `Sources/Grpc/options/VMImageShorthandFlags.swift` et la section « VM image catalog and `--<id>` shorthand flags » du CLAUDE.md pour cette seconde moitié du mécanisme.

- `Sources/cakedlib/Resources/VMImages.json` – le catalogue, organisé par architecture au premier niveau : `{"arm64": {...}, "amd64": {...}}`, chaque nœud contenant trois tableaux `iso`, `ipsw` et `cloud` d'entrées `{id, label, url}` déjà résolues (pas de gabarit `{arch}` à substituer au runtime). Une image qui n'existe pas pour une architecture donnée est simplement absente de son tableau — par exemple l'ISO Fedora 41 Workstation, qui n'a jamais été publiée en `aarch64`, n'apparaît que sous `amd64`.
- `Sources/cakedlib/VMImageCatalog.swift` – `VMImageCatalog`/`VMImageArchCatalog`/`VMImageEntry` (tous `public`), le modèle `Codable` correspondant. `VMImageCatalog.current` (et les raccourcis `availableISOImages`/`availableIPSWImages`/`availableCloudImages`) sélectionne le nœud `arm64` ou `amd64` selon l'architecture d'exécution via `#if arch(arm64)`.

Les entrées `iso` et `cloud` portent aussi des champs optionnels `minCPU`/`minMemoryMiB`, absents des entrées `ipsw` (les installations macOS appliquent leur propre plancher fixe, indépendamment de ce catalogue). Convention actuelle : 2 CPU / 2048 MiB pour les ISO « Server » et les images cloud (headless par nature), 4 CPU / 4096 MiB pour les ISO « Desktop ». `VMImageEntry.applyMinimumResources(to:)` (`VirtualMachineWizard.swift`) applique ce plancher via `max(...)` chaque fois qu'une image est sélectionnée ou que la source d'image change vers `.iso`/`.qcow2` — il ne fait jamais redescendre une valeur que l'utilisateur a déjà augmentée au-delà du minimum.

Pour ajouter ou modifier une entrée, il suffit d'éditer `VMImages.json` — aucune modification Swift n'est nécessaire. `Tests/CakerTests/VMImageCatalogURLTests.swift` envoie une requête HEAD à chaque URL ISO/cloud des **deux** architectures (limitée à 8 requêtes concurrentes) afin que les liens obsolètes soient détectés par `swift test` plutôt que de casser silencieusement l'assistant ; des tests dédiés vérifient aussi que Fedora 41 Workstation reste absent du nœud `arm64`, et que chaque entrée respecte la convention `minCPU`/`minMemoryMiB` ci-dessus.

### Sources de chargement

`VMImageCatalog.shared` résout le catalogue dans cet ordre, à la première utilisation :

1. **`<CAKE_HOME>/VMImages.json`**, si présent et valide — un fichier déposé à la main (pour personnaliser ou figer la liste) ou déjà mis en cache par un rafraîchissement GitHub précédent. Un fichier invalide à cet endroit est simplement ignoré (repli sur l'étape suivante) plutôt que de faire planter l'application, puisqu'il s'agit d'un état fourni par l'utilisateur et non d'un invariant de packaging.
2. **La ressource embarquée** `VMImages.json`, avec la même bascule `Bundle.module`/cible-native déjà utilisée par `PackerLiteTemplateResolver` pour les autres ressources embarquées de `CakedLib` : `Bundle.module` pour les builds `swift build`/`swift test`, repli sur une recherche `Bundle(for:)` + `.bundle` pour `Caker.xcodeproj`/`CakerAppStore.xcodeproj`, qui hébergent `CakedLib` comme cible native sans accesseur `Bundle.module` généré. Tout nouveau fichier ajouté sous `Sources/cakedlib/Resources/` doit donc aussi être ajouté manuellement aux deux fichiers `.xcodeproj` (référence de fichier + phases de build Resources des cibles `CakedLib`/`Caker`/`caked.app`, selon le cas) pour rester disponible dans les builds construits via Xcode.

Séparément, `VMImageCatalog.refreshFromGitHub()` télécharge la version courante de `VMImages.json` depuis la branche `main` sur GitHub, la met en cache dans `<CAKE_HOME>/VMImages.json`, et met à jour `VMImageCatalog.shared` en place. `MainApp.init()` déclenche cet appel en tâche de fond (best-effort, erreurs ignorées) au lancement de l'application — comme les vues de l'assistant relisent `VMImageCatalog.shared` à chaque rendu plutôt que de le mettre en cache dans un `@State`, une session déjà lancée profite du catalogue rafraîchi dès que le téléchargement aboutit, sans redémarrage.

## Tests

Emplacements principaux des tests :

- `Tests/CakerTests/`
- `Caker/CakerTests/`
- `integration/tests/`

## Workflow de contribution

1. Créez une branche depuis `main`.
2. Implémentez des modifications ciblées.
3. Exécutez les tests pertinents et les vérifications de build.
4. Ouvrez une pull request avec un contexte clair.

Guide du contributeur :

- [CONTRIBUTING.md](https://github.com/Fred78290/caker/blob/main/CONTRIBUTING.md)

## Interface Web

Caker inclut une interface Web basée sur React, située dans le répertoire `webui/`. Elle est construite avec Vite, TypeScript et Bootstrap 5.

### Prérequis

- Node.js ≥ 18
- npm ≥ 9

### Installer les dépendances

```bash
cd webui
npm install
```

### Mode développement

Démarrez le serveur de développement Vite avec un proxy vers un `caked` exécuté localement :

```bash
cd webui
npm run dev
```

Le serveur de développement écoute sur `http://localhost:5173`. Les appels API vers `/1.0` sont redirigés par défaut vers `http://127.0.0.1:8080`. Modifiez la cible avec la variable d'environnement `VITE_API_TARGET` :

```bash
VITE_API_TARGET=http://127.0.0.1:9090 npm run dev
```

### Build de production

```bash
cd webui
npm run build
```

Le résultat est écrit dans `webui/dist/`. Passez ce répertoire à `caked` avec l'option `--web-ui` :

```bash
caked service --rest --web-ui /path/to/caker/webui/dist
```

L'interface est alors servie sur `http://<host>:<port>/ui`.

### Déploiement depuis une archive zip

`--web-ui` accepte également une archive `.zip`. `caked` l'extrait automatiquement au démarrage dans un répertoire temporaire :

```bash
cd webui && npm run build && zip -r ../webui-dist.zip dist/
caked service --rest --web-ui /path/to/webui-dist.zip
```

Si l'archive contient un unique répertoire de premier niveau (par ex. `dist/`), `caked` y descend automatiquement pour résoudre correctement le fichier index.

### Structure du projet

```
webui/
  index.html            # Point d'entrée HTML
  vite.config.ts        # Configuration Vite (base /ui/, proxy /1.0)
  tsconfig.json         # Configuration TypeScript
  src/
    main.tsx            # Point d'entrée React (CSS/JS Bootstrap importés ici)
    App.tsx             # HashRouter + routes
    types/lxd.ts         # Interfaces TypeScript correspondant à l'API REST
    api/                # Modules du client API axios
    components/         # Composants UI partagés (Layout, StatusBadge, …)
    pages/              # Un composant par page
  dist/                 # Sortie de production (après npm run build)
```

## Scripts utiles

- `Scripts/build-signed-debug.sh` - Compile la version debug avec signature
- `Scripts/build-signed-release.sh` - Compile la version release avec signature
- `Scripts/build-signed-snapshot.sh` - Compile le package et le dmg avec signature
- `Scripts/act.sh` - Test local des GitHub Actions
- `Scripts/run-signed-caked.sh` - Exécute le démon signé
- `Scripts/run-signed-cakectl.sh` - Exécute la CLI signée

## Environnement de développement

### Prérequis
- macOS (requis pour le framework Virtualization)
- Xcode avec toolchain Swift
- Certificats de signature et profils de provisioning
- Optionnel : GitHub CLI pour la gestion des pull requests

### Démarrage
1. Clonez le dépôt
2. Exécutez `./Scripts/build-signed-debug.sh` pour compiler
3. Utilisez les scripts d'exécution pour tester les composants
4. Exécutez les tests via Xcode ou en ligne de commande

### Style de code
- Suivez les conventions Swift
- Utilisez des noms clairs et descriptifs
- Documentez les API publiques
- Incluez des tests pour les nouvelles fonctionnalités

</div>

<div class="lang-en" style="display:block" markdown="1">

# Development

## Code organization

- `Sources/cakectl/Commands/` – CLI command handlers
- `Sources/caked/Commands/` and `Sources/caked/Handlers/` – daemon command and runtime handlers
- `Sources/cakedlib/` – shared utilities, config, and core abstractions

## VM image catalog (Caker.app wizard, and `build`/`launch --<id>` shorthand flags)

Caker.app's VM creation wizard (`Sources/caker/Views/VirtualMachineWizard.swift`) offers preconfigured ISO, IPSW, and cloud (qcow2) image choices. That list is no longer hardcoded in Swift enums — it's driven by a bundled JSON resource, decoded at runtime. The catalog now lives in `CakedLib` (it used to be `caker`-only), so `caked build`/`cakectl build` (and `launch`) can also resolve a catalog id via generated `--<id>` shorthand flags (`--macos12`, `--ubuntu2604`, ...) — see `Sources/Grpc/options/VMImageShorthandFlags.swift` and CLAUDE.md's "VM image catalog and `--<id>` shorthand flags" section for that half of the picture.

- `Sources/cakedlib/Resources/VMImages.json` – the catalog, keyed by architecture at the top level: `{"arm64": {...}, "amd64": {...}}`, each node holding three arrays — `iso`, `ipsw`, `cloud` — of already-resolved `{id, label, url}` entries (no `{arch}` template to substitute at runtime). An image that doesn't exist for a given architecture is simply absent from that array — e.g. the Fedora 41 Workstation ISO, never published for `aarch64`, only appears under `amd64`.
- `Sources/cakedlib/VMImageCatalog.swift` – `VMImageCatalog`/`VMImageArchCatalog`/`VMImageEntry` (all `public`), the matching `Codable` model. `VMImageCatalog.current` (and the `availableISOImages`/`availableIPSWImages`/`availableCloudImages` shortcuts) picks the `arm64` or `amd64` node based on the running architecture via `#if arch(arm64)`.

`iso` and `cloud` entries also carry optional `minCPU`/`minMemoryMiB` fields, absent from `ipsw` entries (macOS installs apply their own fixed floor independently of this catalog). Current convention: 2 CPU / 2048 MiB for "Server" ISOs and cloud images (headless by nature), 4 CPU / 4096 MiB for "Desktop" ISOs. `VMImageEntry.applyMinimumResources(to:)` (`VirtualMachineWizard.swift`) applies this floor via `max(...)` whenever an image is selected or the image source switches to `.iso`/`.qcow2` — it never lowers a value the user already raised above the minimum.

To add or update an entry, edit `VMImages.json` — no Swift changes needed. `Tests/CakerTests/VMImageCatalogURLTests.swift` HEAD-requests every ISO/cloud URL from **both** architectures (bounded to 8 concurrent requests) so stale links get caught by `swift test` instead of silently breaking the wizard; dedicated tests also assert Fedora 41 Workstation stays absent from the `arm64` node, and that every entry follows the `minCPU`/`minMemoryMiB` convention above.

### Loading sources

`VMImageCatalog.shared` resolves the catalog in this order, on first use:

1. **`<CAKE_HOME>/VMImages.json`**, if present and valid — either dropped there by hand (to pin or customize the list) or already cached by a previous GitHub refresh. An invalid file here is skipped (falls through to the next step) rather than crashing the app, since unlike the bundled resource it's user-supplied state, not a packaging invariant.
2. **The bundled `VMImages.json` resource**, following the same `Bundle.module`/native-target fallback already used by `PackerLiteTemplateResolver` for `CakedLib`'s other bundled resources: `Bundle.module` for `swift build`/`swift test` builds, falling back to a `Bundle(for:)`-plus-`.bundle`-lookup dance for `Caker.xcodeproj`/`CakerAppStore.xcodeproj`, which mirror `CakedLib` as a native Xcode target with no generated `Bundle.module` accessor. Any new file added under `Sources/cakedlib/Resources/` therefore also needs to be added by hand to both `.xcodeproj` files (file reference + the `CakedLib`/`Caker`/`caked.app` targets' Resources build phases, as applicable) to stay available in Xcode-built binaries.

Separately, `VMImageCatalog.refreshFromGitHub()` downloads the current `VMImages.json` from the `main` branch on GitHub, caches it to `<CAKE_HOME>/VMImages.json`, and updates `VMImageCatalog.shared` in place. `MainApp.init()` fires this in a background task (best-effort, errors ignored) at app launch — since the wizard's views re-read `VMImageCatalog.shared` on every render rather than caching it in `@State`, an already-running session picks up the refreshed catalog as soon as the download completes, no restart needed.

## Tests

Primary test locations:

- `Tests/CakerTests/`
- `Caker/CakerTests/`
- `integration/tests/`

## Contribution workflow

1. Create a branch from `main`.
2. Implement focused changes.
3. Run relevant tests and build checks.
4. Open a pull request with clear context.

Contributor guide:

- [CONTRIBUTING.md](https://github.com/Fred78290/caker/blob/main/CONTRIBUTING.md)

## Web UI

Caker includes a React-based web UI located in the `webui/` directory. It is built with Vite, TypeScript, and Bootstrap 5.

### Requirements

- Node.js ≥ 18
- npm ≥ 9

### Install dependencies

```bash
cd webui
npm install
```

### Development mode

Start the Vite dev server with a proxy to a locally running `caked`:

```bash
cd webui
npm run dev
```

The dev server listens on `http://localhost:5173`. API calls to `/1.0` are proxied to `http://127.0.0.1:8080` by default. Override the target with the `VITE_API_TARGET` environment variable:

```bash
VITE_API_TARGET=http://127.0.0.1:9090 npm run dev
```

### Production build

```bash
cd webui
npm run build
```

The output is written to `webui/dist/`. Pass this directory to `caked` with the `--web-ui` flag:

```bash
caked service --rest --web-ui /path/to/caker/webui/dist
```

The UI is then served at `http://<host>:<port>/ui`.

### Deploying from a zip archive

`--web-ui` also accepts a `.zip` archive. `caked` extracts it automatically at startup to a temporary directory:

```bash
cd webui && npm run build && zip -r ../webui-dist.zip dist/
caked service --rest --web-ui /path/to/webui-dist.zip
```

If the archive contains a single top-level directory (e.g. `dist/`), `caked` descends into it automatically so the index file is resolved correctly.

### Project structure

```
webui/
  index.html            # HTML entry point
  vite.config.ts        # Vite configuration (base /ui/, proxy /1.0)
  tsconfig.json         # TypeScript configuration
  src/
    main.tsx            # React entry point (Bootstrap CSS/JS imported here)
    App.tsx             # HashRouter + routes
    types/lxd.ts        # TypeScript interfaces matching the REST API
    api/                # axios API client modules
    components/         # Shared UI components (Layout, StatusBadge, …)
    pages/              # One component per page
  dist/                 # Production output (after npm run build)
```

## Useful scripts

- `Scripts/build-signed-debug.sh` - Build debug version with signing
- `Scripts/build-signed-release.sh` - Build release version with signing
- `Scripts/build-signed-snapshot.sh` - Build package and dmg with signing
- `Scripts/act.sh` - Local GitHub Actions testing
- `Scripts/run-signed-caked.sh` - Run signed daemon
- `Scripts/run-signed-cakectl.sh` - Run signed CLI

## Development Environment

### Requirements
- macOS (required for Virtualization framework)
- Xcode with Swift toolchain
- Signing certificates and provisioning profiles
- Optional: GitHub CLI for pull request management

### Getting Started
1. Clone the repository
2. Run `./Scripts/build-signed-debug.sh` to build
3. Use the run scripts to test components
4. Run tests via Xcode or command line

### Code Style
- Follow Swift conventions
- Use clear, descriptive naming
- Add documentation for public APIs
- Include tests for new functionality

</div>
