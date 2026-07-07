<!-- markdownlint-disable MD033 MD024 -->

<div id="content-fr" style="display:none" markdown="1">

# Développement

## Organisation du code

- `Sources/cakectl/Commands/` – gestionnaires de commandes CLI
- `Sources/caked/Commands/` et `Sources/caked/Handlers/` – gestionnaires de commandes et d'exécution du démon
- `Sources/cakedlib/` – utilitaires partagés, configuration et abstractions principales

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

<div id="content-en" style="display:block" markdown="1">

# Development

## Code organization

- `Sources/cakectl/Commands/` – CLI command handlers
- `Sources/caked/Commands/` and `Sources/caked/Handlers/` – daemon command and runtime handlers
- `Sources/cakedlib/` – shared utilities, config, and core abstractions

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
