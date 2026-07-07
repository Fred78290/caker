<!-- markdownlint-disable MD033 MD024 -->

<div class="lang-fr" style="display:none" markdown="1">

Bienvenue dans le wiki de documentation de Caker.

**Caker** est une plateforme de virtualisation native Swift pour macOS qui simplifie la gestion du cycle de vie des VM, du développement à l'exploitation.
Elle combine un démon puissant (`caked`) avec une CLI pratique (`cakectl`) permettant aux équipes de construire, exécuter, inspecter et automatiser des machines virtuelles de manière cohérente.
Si vous exécutez `caked` en tant que service, utilisez `cakectl` comme interface principale.

Caker est une chaîne d'outils de virtualisation utilisée pour construire, lancer et gérer des machines virtuelles sur macOS.

Elle est conçue autour de trois composants complémentaires :
- `caked` : le démon/service qui effectue les opérations sur les VM, les images et le réseau
- `cakectl` : le client CLI utilisé pour piloter `caked`
- `Caker.app` : le client graphique utilisé pour piloter `caked`, ou de façon autonome

En usage typique, `cakectl` envoie des commandes à `caked` via gRPC, et `caked` exécute les actions de cycle de vie telles que la construction, le lancement, le démarrage/arrêt, le push/pull d'images et la gestion réseau.

Utilisez ce wiki comme référence centrale pour l'architecture, l'utilisation des commandes, le dépannage et les workflows opérationnels.

Guide du contributeur : [CONTRIBUTING.md](https://github.com/Fred78290/caker/blob/main/CONTRIBUTING.md)

## Liens rapides

- [Démarrage](getting-started)
- [Architecture](architecture)
- [Développement](development)
- [Dépannage](troubleshooting)
- [FAQ](faq)
- [Notes de version](release-notes)
- [Résumé des commandes](command-summary)
- [Pense-bête](cheat-sheet)
- [Politique de confidentialité](privacy-policy)

## Plan du dépôt

- `Sources/caked/` – points d'entrée et commandes du démon
- `Sources/cakectl/` – commandes CLI et logique client
- `Sources/cakedlib/` – bibliothèque partagée
- `Sources/caker/` – application graphique
- `Sources/grpc/` – couche gRPC et interfaces générées
- `Tests/` et `Caker/CakerTests/` – suites de tests

</div>

<div class="lang-en" style="display:block" markdown="1">

Welcome to the Caker documentation wiki.

**Caker** is a Swift-native virtualization platform for macOS that streamlines VM lifecycle management from development to operations.
It combines a powerful daemon (`caked`) with a practical CLI (`cakectl`) so teams can build, run, inspect, and automate virtual machines consistently.
If you run `caked` as a service, use `cakectl` as the primary interface.

Caker is a virtualization toolchain used to build, launch, and manage virtual machines on macOS.

It is designed around three complementary components:
- `caked`: the daemon/service that performs VM, image, and network operations
- `cakectl`: the CLI client used to control `caked`
- `Caker.app`: the GUI client used to control `caked` or standalone

In typical usage, `cakectl` sends commands to `caked` through gRPC, and `caked` executes lifecycle actions such as build, launch, start/stop, image pull/push, and network management.

Use this wiki as the central reference for architecture, command usage, troubleshooting, and operational workflows.

Contributor guide: [CONTRIBUTING.md](https://github.com/Fred78290/caker/blob/main/CONTRIBUTING.md)

## Quick links

- [Getting Started](getting-started)
- [Architecture](architecture)
- [Development](development)
- [Troubleshooting](troubleshooting)
- [FAQ](faq)
- [Release Notes](release-notes)
- [Command Summary](command-summary)
- [Cheat Sheet](cheat-sheet)
- [Private Policy](privacy-policy)

## Repository map

- `Sources/caked/` – daemon entrypoints and commands
- `Sources/cakectl/` – CLI commands and client logic
- `Sources/cakedlib/` – shared core library
- `Sources/caker/` – GUI app
- `Sources/grpc/` – gRPC layer and generated interfaces
- `Tests/` and `Caker/CakerTests/` – test suites

</div>
