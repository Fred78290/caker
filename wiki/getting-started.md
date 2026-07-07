<!-- markdownlint-disable MD033 MD024 -->

<div class="lang-fr" style="display:none" markdown="1">

# Démarrage

## Prérequis

- macOS
- Xcode + toolchain Swift
- Accès aux ressources de signature du projet (pour les scripts de build signés)

## Compilation

Exécutez l'un des scripts du projet depuis la racine du dépôt :

- `./Scripts/build-signed-debug.sh`
- `./Scripts/build-signed-release.sh`

Si les scripts de build échouent, vérifiez :
- la disponibilité du profil de provisioning
- les entitlements de signature dans `Resources/`
- la configuration de signature locale d'Xcode

## Commandes principales

Le projet contient deux binaires principaux :

- `caked` (démon)
- `cakectl` (CLI)

Utilisez les scripts d'exécution si besoin :

- `./Scripts/run-signed-caked.sh`
- `./Scripts/run-signed-cakectl.sh`

## Prochaines étapes

- Explorez l'[Architecture](architecture) pour comprendre comment les composants fonctionnent ensemble
- Consultez le [Résumé des commandes](command-summary) pour une référence détaillée des commandes
- Visitez [Développement](development) pour les consignes de contribution

</div>

<div class="lang-en" style="display:block" markdown="1">

# Getting Started

## Prerequisites

- macOS
- Xcode + Swift toolchain
- Access to project signing assets (for signed build scripts)

## Build

Run one of the project scripts from the repository root:

- `./Scripts/build-signed-debug.sh`
- `./Scripts/build-signed-release.sh`

If build scripts fail, verify:
- provisioning profile availability
- signing entitlements in `Resources/`
- local Xcode signing configuration

## Core commands

The project contains two principal binaries:

- `caked` (daemon)
- `cakectl` (CLI)

Use the run helpers when needed:

- `./Scripts/run-signed-caked.sh`
- `./Scripts/run-signed-cakectl.sh`

## Next Steps

- Explore the [Architecture](architecture) to understand how components work together
- Check the [Command Summary](command-summary) for detailed command references
- Visit [Development](development) for contribution guidelines

</div>
