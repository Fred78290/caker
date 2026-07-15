---
layout: default
title: Architecture
nav_order: 3
---

<!-- markdownlint-disable MD033 MD024 -->

<div class="lang-fr" style="display:none" markdown="1">

# Architecture

## Composants

- **outil en ligne de commande caked** (`Sources/caked/`) : démon d'arrière-plan principal
- **outil en ligne de commande cakectl** (`Sources/cakectl/`) : contrôleur en ligne de commande
- **bibliothèque commune CakedLib** (`Sources/cakedlib/`) : code de bibliothèque partagé
- **bibliothèque de communication GRPCLib** (`Sources/grpc/`) : contrats de communication et interfaces de streaming/client
- **Caker.app** (`Sources/caker/`) : source de l'interface graphique
- **API REST LXD** (`Sources/caked/REST/`) : serveur HTTP/HTTPS optionnel compatible LXD intégré à `caked`
- **Interface Web** (`webui/`) : frontend React/Vite servi par `caked` sur `/ui`

## Flux général

1. `cakectl` envoie des commandes à `caked` via gRPC
2. `caked` exécute les opérations de cycle de vie/ressources
3. Les réponses et flux sont transmis via gRPC vers les clients
4. Les journaux/statuts sont renvoyés aux clients

Optionnellement, des outils externes compatibles LXD communiquent avec `caked` via l'API REST :

1. `caked` démarre un listener HTTP(S) en parallèle du serveur gRPC lorsque `--rest` est activé
2. Les clients REST LXD (par ex. `lxc`, l'interface Web, ou tout client HTTP) appellent les points de terminaison `/1.0/...`
3. `caked` traduit les requêtes REST vers les mêmes opérations internes que celles utilisées par gRPC

## Responsabilités du service

`caked` est responsable de :
- la gestion du cycle de vie (construction, lancement, démarrage/arrêt/redémarrage/suspension/suppression)
- l'allocation des ressources
- la surveillance de l'état de santé
- la journalisation et le diagnostic
- l'API REST optionnelle compatible LXD (instances, réseaux, images, certificats, identités, opérations)
- l'hébergement optionnel de l'interface Web

## API REST LXD

Lorsqu'il est démarré avec `--rest`, `caked` expose une API REST compatible LXD :

| Groupe de points de terminaison | Description |
| --- | --- |
| `/1.0` | Informations serveur et capacités |
| `/1.0/instances` | Cycle de vie des VM, état, exec, console, journaux |
| `/1.0/networks` | Gestion réseau |
| `/1.0/images` | Liste et métadonnées des images |
| `/1.0/operations` | Suivi des opérations asynchrones |
| `/1.0/certificates` | Gestion des certificats TLS |
| `/1.0/auth-groups` | Groupes d'autorisation |
| `/1.0/identities` | Gestion des identités |

Ports par défaut : `8443` (HTTPS/mTLS) ou `8080` (HTTP). Modifiable avec `--rest-port`.

## IMDS

`caked` héberge également, par défaut, un service de métadonnées d'instance de style AWS pour les VM Linux (`IMDSCoordinator` + `IMDSServer` dans `Sources/caked/IMDS/`), joignable depuis l'invité via HTTP. Le joindre à l'adresse `169.254.169.254` de style AWS repose sur une redirection `pf` d'alias d'adresse installée automatiquement par un assistant root de courte durée, car `caked` tourne normalement sans privilège ; sans elle, la passerelle IMDS reste pleinement joignable sur son propre port. Voir [IMDS](imds) pour les détails complets.

Voir le [Résumé des commandes](command-summary) pour la référence complète des options de `service listen`.

## Structure du dépôt

```text
Sources/
├── caked/          # Implémentation du démon
│   └── REST/       # Serveur et contrôleurs API REST LXD
├── caker/          # Application graphique (macOS SwiftUI)
├── cakectl/        # Client CLI
├── cakedlib/       # Bibliothèques partagées
└── grpc/           # Définitions gRPC et code généré
scripts/            # Quelques scripts utiles pour la construction et autres
webui/              # Interface Web React/Vite
```

</div>

<div class="lang-en" style="display:block" markdown="1">

# Architecture

## Components

- **caked command line tool** (`Sources/caked/`): core background daemon
- **cakectl command line tool** (`Sources/cakectl/`): command-line controller
- **CakedLib common library** (`Sources/cakedlib/`): shared library code
- **GRPCLib communication libray** (`Sources/grpc/`): communication contracts and streaming/client interfaces
- **Caker.app** (`Sources/caker/`): GUI source
- **LXD REST API** (`Sources/caked/REST/`): optional LXD-compatible HTTP/HTTPS server built into `caked`
- **Web UI** (`webui/`): React/Vite frontend served by `caked` at `/ui`

## High-level flow

1. `cakectl` sends commands to `caked` over gRPC
2. `caked` executes lifecycle/resource operations
3. Responses and streams are transmitted through gRPC back to clients
4. Logs/status are returned to clients

Optionally, external LXD-compatible tooling communicates with `caked` through the REST API:

1. `caked` starts an HTTP(S) listener alongside the gRPC server when `--rest` is set
2. LXD REST clients (e.g. `lxc`, the web UI, or any HTTP client) call `/1.0/...` endpoints
3. `caked` translates REST requests into the same internal operations used by gRPC

## Service responsibilities

`caked` is responsible for:
- lifecycle management (build, launch, start/stop/restart/suspend/delete)
- resource allocation
- health monitoring
- logging and diagnostics
- optional LXD-compatible REST API (instances, networks, images, certificates, identities, operations)
- optional Web UI hosting

## LXD REST API

When started with `--rest`, `caked` exposes an LXD-compatible REST API:

| Endpoint group | Description |
| --- | --- |
| `/1.0` | Server info and capabilities |
| `/1.0/instances` | VM lifecycle, state, exec, console, logs |
| `/1.0/networks` | Network management |
| `/1.0/images` | Image listing and metadata |
| `/1.0/operations` | Async operation tracking |
| `/1.0/certificates` | TLS certificate management |
| `/1.0/auth-groups` | Authorization groups |
| `/1.0/identities` | Identity management |

Default ports: `8443` (HTTPS/mTLS) or `8080` (HTTP). Override with `--rest-port`.

## IMDS

`caked` also hosts, by default, an AWS-style instance metadata service for Linux VMs (`IMDSCoordinator` + `IMDSServer` in `Sources/caked/IMDS/`), reachable from the guest over HTTP. Reaching it at the AWS-style `169.254.169.254` address relies on a `pf` address-alias redirect installed automatically by a short-lived root helper, since `caked` normally runs unprivileged; without it, the IMDS gateway itself stays fully reachable on its own port. See [IMDS](imds) for full details.

See [Command Summary](command-summary) for full `service listen` flag reference.

## Repository Structure

```text
Sources/
├── caked/          # Daemon implementation
│   └── REST/       # LXD REST API server and controllers
├── caker/          # GUI app (macOS SwiftUI)
├── cakectl/        # CLI client
├── cakedlib/       # Shared libraries
└── grpc/           # gRPC definitions and generated code
scripts/            # Some useful scripts to build and other
webui/              # React/Vite web UI
```

</div>

{% include lang-toggle.html %}
