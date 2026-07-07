---
layout: default
title: Compose
nav_order: 10
---

<!-- markdownlint-disable MD033 MD024 -->

<div id="content-fr" style="display:none" markdown="1">

# Compose

Caker compose vous permet de définir et gérer des environnements multi-VM à partir d'un fichier `compose.yml`, dans un format compatible avec Docker Compose.

## Démarrage rapide

```bash
# Générer un modèle compose.yml dans le répertoire courant
cakectl compose init

# Éditer compose.yml, puis démarrer tous les services
cakectl compose up

# Vérifier le statut
cakectl compose ps

# Arrêter tous les services
cakectl compose down

# Supprimer toutes les VM de service
cakectl compose rm --stop
```

## Ordre de recherche du fichier

Lorsque `-f` n'est pas spécifié, Caker recherche un fichier compose dans le répertoire courant dans cet ordre :

1. `compose.yml`
2. `compose.yaml`
3. `docker-compose.yml`
4. `docker-compose.yaml`

## Format de compose.yml

```yaml
name: myproject          # nom du projet — également utilisé comme préfixe du nom de VM

services:
  app:
    image: ubuntu:24.04  # image cloud ; même syntaxe que cakectl build
    ports:
      - "3000:3000"      # host:container[/proto] — TCP par défaut
      - "8080:80/tcp"
    sockets:             # extension Caker : redirection de socket unix
      - "/tmp/docker.sock:/var/run/docker.sock"
      - "/tmp/host.sock:/tmp/guest.sock/udp"
    volumes:
      - ".:/workspace"   # montage virtio-FS host:guest
    environment:         # injecté dans /etc/environment via cloud-init
      - NODE_ENV=production
      - DEBUG=1
    networks:
      - default          # réseau nommé défini dans la section networks:
    depends_on:
      - database         # démarrer database avant app (liste ou map de conditions)
    deploy:
      resources:
        limits:
          cpus: "2"      # nombre de vCPU
          memory: 2048M  # RAM : M/MB, G/GB
    hostname: app-host   # nom d'hôte invité
    restart: "no"        # accepté mais informatif seulement (VM, pas conteneurs)

    # Extensions VM Caker (ne font pas partie de la spec Docker Compose) :
    disk: 20             # taille du disque racine en Gio (défaut 10)
    user: ubuntu         # nom d'utilisateur invité pour exec/sh
    password: ubuntu     # mot de passe invité
    nested: false         # activer la virtualisation imbriquée
    autostart: false      # démarrer cette VM au démarrage de caked

  database:
    image: ubuntu:24.04
    environment:
      POSTGRES_PASSWORD: secret
    networks:
      - default
    deploy:
      resources:
        limits:
          cpus: "2"
          memory: 4096M
    disk: 40
    user: ubuntu
    password: ubuntu

networks:
  default:
    driver: bridge       # bridge (NAT partagé) ou none
    # driver_opts:
    #   mode: shared     # shared (défaut) ou host
    #   gateway: 192.168.105.1/24
    #   dhcp_end: 192.168.105.254
```

### Nommage des VM

Chaque service est provisionné en tant que VM nommée `compose-<projectName>-<serviceName>`. Par exemple, un projet nommé `myproject` avec un service nommé `app` crée une VM appelée `compose-myproject-app`. Vous pouvez l'inspecter avec `cakectl infos compose-myproject-app`.

### depends_on

Les formes courte et longue sont toutes deux prises en charge :

```yaml
# Forme courte
depends_on:
  - database

# Forme longue (la condition est acceptée mais non appliquée — Caker démarre dans l'ordre quoi qu'il en soit)
depends_on:
  database:
    condition: service_healthy
```

### Syntaxe de la mémoire

`deploy.resources.limits.memory` accepte :

| Valeur | Signification |
| --- | --- |
| `2048M` / `2048MB` | 2048 Mio |
| `2G` / `2GB` | 2048 Mio |
| `2048` | 2048 Mio (entier brut) |

### Réseaux

Lorsque `driver: bridge` est défini et que `external` n'est pas `true`, Caker crée un nouveau réseau NAT partagé. Un sous-réseau `/24` déterministe est dérivé du nom du réseau (dans la plage `192.168.100.x`–`192.168.199.x`) à moins que vous ne spécifiiez une `gateway` dans `driver_opts`.

Lorsque `external: true`, Caker attache la VM de service à un réseau nommé existant au lieu d'en créer un.

## Sous-commandes

> Si `caked` s'exécute en tant que service, utilisez `cakectl compose`. Si vous exécutez `caked` directement (sans service), utilisez `caked compose`.

### `compose up`

Démarre (et crée si nécessaire) les services dans l'ordre de `depends_on`.

```
cakectl compose up [-f <file>] [--wait-ip-timeout <seconds>] [services...]
caked    compose up [-f <file>] [--wait-ip-timeout <seconds>] [services...]
```

| Option | Défaut | Description |
| --- | --- | --- |
| `-f, --file <path>` | détection auto | Chemin du fichier compose |
| `--wait-ip-timeout <seconds>` | `180` | Durée d'attente de l'IP de chaque VM avant abandon |
| `[services...]` | tous | Limiter à des services nommés spécifiques |

Si `up` est interrompu ou échoue partiellement, les VM démarrées avec succès sont enregistrées. Relancer `compose up` ne tentera pas de recréer les VM déjà existantes.

### `compose down`

Arrête les services dans l'ordre inverse de `depends_on`.

```
cakectl compose down [-f <file>] [--force] [services...]
caked    compose down [-f <file>] [--force] [services...]
```

| Option | Défaut | Description |
| --- | --- | --- |
| `-f, --file <path>` | détection auto | Chemin du fichier compose |
| `--force` | désactivé | Forcer l'arrêt sans arrêt gracieux |
| `[services...]` | tous | Limiter à des services nommés spécifiques |

### `compose ps`

Affiche le statut des services enregistrés sous ce projet compose.

```
cakectl compose ps [-f <file>] [services...]
caked    compose ps [-f <file>] [services...]
```

| Option | Défaut | Description |
| --- | --- | --- |
| `-f, --file <path>` | détection auto | Chemin du fichier compose |
| `[services...]` | tous | Limiter à des services nommés spécifiques |

### `compose rm`

Supprime les VM de service et désenregistre le projet.

```
cakectl compose rm [-f <file>] [-s] [--force] [services...]
caked    compose rm [-f <file>] [-s] [--force] [services...]
```

| Option | Défaut | Description |
| --- | --- | --- |
| `-f, --file <path>` | détection auto | Chemin du fichier compose |
| `-s, --stop` | désactivé | Arrêter les services en cours avant suppression |
| `--force` | désactivé | Ne pas renvoyer d'erreur si une VM de service est introuvable |
| `[services...]` | tous | Limiter à des services nommés spécifiques |

### `compose ls`

Liste tous les projets compose enregistrés et le statut de leurs services.

```
cakectl compose ls
```

Cette commande ne nécessite pas de fichier compose — elle lit le registre global des projets.

### `compose init`

Écrit un modèle `compose.yml` commenté dans le répertoire courant.

```
cakectl compose init [--force]
caked    compose init [--force]
```

| Option | Défaut | Description |
| --- | --- | --- |
| `-f, --force` | désactivé | Écraser un `compose.yml` existant |

## Différences avec Docker Compose

| Fonctionnalité | Docker Compose | Caker compose |
| --- | --- | --- |
| Runtime | Démon de conteneurs | VM Apple Virtualization.framework |
| Extensions VM | Non | `disk`, `user`, `password`, `nested`, `autostart`, `sockets` |
| `restart` | Politique appliquée | Accepté, non appliqué |
| Conditions `depends_on` | Appliquées | Ordre uniquement — les conditions sont acceptées mais non vérifiées |
| Clé `build:` | Build depuis un Dockerfile | Non pris en charge — utilisez `image:` avec une URL d'image cloud ou un alias simplestream |
| Volumes nommés | Gérés par Docker | Non pris en charge — utilisez des montages liés dans `volumes:` |
| `--detach` | Arrière-plan | Toujours en arrière-plan (les VM sont durables) |
| `ls` | Liste les conteneurs | Liste les projets compose enregistrés |

## Exemples

### Démarrer une stack à deux VM

```bash
# Initialiser
cd myproject
cakectl compose init
# Éditer compose.yml…
cakectl compose up
```

### Démarrer un seul service

```bash
cakectl compose up app
```

### Reconstruire depuis un chemin de fichier personnalisé

```bash
cakectl compose up -f ./infra/staging.yml
```

### Inspecter une VM de service directement

```bash
cakectl infos compose-myproject-app
cakectl exec compose-myproject-app -- uname -a
```

### Tout arrêter et nettoyer

```bash
# Arrêter les services (conserver les VM)
cakectl compose down

# Arrêter et supprimer les VM, retirer le projet du registre
cakectl compose rm --stop
```

### Lister tous les projets compose

```bash
cakectl compose ls
```

</div>

<div id="content-en" style="display:block" markdown="1">

# Compose

Caker compose lets you define and manage multi-VM environments from a `compose.yml` file, using a format compatible with Docker Compose.

## Quick start

```bash
# Generate a template compose.yml in the current directory
cakectl compose init

# Edit compose.yml, then start all services
cakectl compose up

# Check status
cakectl compose ps

# Stop all services
cakectl compose down

# Remove all service VMs
cakectl compose rm --stop
```

## File lookup order

When `-f` is not specified, Caker looks for a compose file in the current directory in this order:

1. `compose.yml`
2. `compose.yaml`
3. `docker-compose.yml`
4. `docker-compose.yaml`

## compose.yml format

```yaml
name: myproject          # project name — also used as VM name prefix

services:
  app:
    image: ubuntu:24.04  # cloud image; same syntax as cakectl build
    ports:
      - "3000:3000"      # host:container[/proto] — TCP by default
      - "8080:80/tcp"
    sockets:             # Caker extension: unix socket forwarding
      - "/tmp/docker.sock:/var/run/docker.sock"
      - "/tmp/host.sock:/tmp/guest.sock/udp"
    volumes:
      - ".:/workspace"   # host:guest virtio-FS mount
    environment:         # injected into /etc/environment via cloud-init
      - NODE_ENV=production
      - DEBUG=1
    networks:
      - default          # named network defined in the networks: section
    depends_on:
      - database         # start database before app (list or condition map)
    deploy:
      resources:
        limits:
          cpus: "2"      # vCPU count
          memory: 2048M  # RAM: M/MB, G/GB
    hostname: app-host   # guest hostname
    restart: "no"        # accepted but informational only (VMs, not containers)

    # Caker VM extensions (not part of Docker Compose spec):
    disk: 20             # root disk size in GiB (default 10)
    user: ubuntu         # guest username for exec/sh
    password: ubuntu     # guest password
    nested: false        # enable nested virtualisation
    autostart: false     # start this VM when caked starts

  database:
    image: ubuntu:24.04
    environment:
      POSTGRES_PASSWORD: secret
    networks:
      - default
    deploy:
      resources:
        limits:
          cpus: "2"
          memory: 4096M
    disk: 40
    user: ubuntu
    password: ubuntu

networks:
  default:
    driver: bridge       # bridge (shared NAT) or none
    # driver_opts:
    #   mode: shared     # shared (default) or host
    #   gateway: 192.168.105.1/24
    #   dhcp_end: 192.168.105.254
```

### VM naming

Each service is provisioned as a VM named `compose-<projectName>-<serviceName>`. For example, a project named `myproject` with a service named `app` creates a VM called `compose-myproject-app`. You can inspect it with `cakectl infos compose-myproject-app`.

### depends_on

Both short and long forms are supported:

```yaml
# Short form
depends_on:
  - database

# Long form (condition is accepted but not enforced — Caker starts in order regardless)
depends_on:
  database:
    condition: service_healthy
```

### Memory syntax

`deploy.resources.limits.memory` accepts:

| Value | Meaning |
| --- | --- |
| `2048M` / `2048MB` | 2048 MiB |
| `2G` / `2GB` | 2048 MiB |
| `2048` | 2048 MiB (bare integer) |

### Networks

When `driver: bridge` is set and `external` is not `true`, Caker creates a new shared NAT network. A deterministic `/24` subnet is derived from the network name (in the range `192.168.100.x`–`192.168.199.x`) unless you specify a `gateway` in `driver_opts`.

When `external: true`, Caker attaches the service VM to an existing named network instead of creating one.

## Subcommands

> If `caked` is running as a service, use `cakectl compose`. If running `caked` directly (no service), use `caked compose`.

### `compose up`

Start (and create if needed) services in `depends_on` order.

```
cakectl compose up [-f <file>] [--wait-ip-timeout <seconds>] [services...]
caked    compose up [-f <file>] [--wait-ip-timeout <seconds>] [services...]
```

| Flag | Default | Description |
| --- | --- | --- |
| `-f, --file <path>` | auto-detect | Path to compose file |
| `--wait-ip-timeout <seconds>` | `180` | How long to wait for each VM's IP before giving up |
| `[services...]` | all | Limit to specific named services |

If `up` is interrupted or partially fails, the successfully started VMs are recorded. Re-running `compose up` will not attempt to re-create VMs that already exist.

### `compose down`

Stop services in reverse `depends_on` order.

```
cakectl compose down [-f <file>] [--force] [services...]
caked    compose down [-f <file>] [--force] [services...]
```

| Flag | Default | Description |
| --- | --- | --- |
| `-f, --file <path>` | auto-detect | Path to compose file |
| `--force` | off | Force stop without graceful shutdown |
| `[services...]` | all | Limit to specific named services |

### `compose ps`

Show status of services registered under this compose project.

```
cakectl compose ps [-f <file>] [services...]
caked    compose ps [-f <file>] [services...]
```

| Flag | Default | Description |
| --- | --- | --- |
| `-f, --file <path>` | auto-detect | Path to compose file |
| `[services...]` | all | Limit to specific named services |

### `compose rm`

Remove (delete) service VMs and unregister the project.

```
cakectl compose rm [-f <file>] [-s] [--force] [services...]
caked    compose rm [-f <file>] [-s] [--force] [services...]
```

| Flag | Default | Description |
| --- | --- | --- |
| `-f, --file <path>` | auto-detect | Path to compose file |
| `-s, --stop` | off | Stop running services before removing |
| `--force` | off | Do not error if a service VM is not found |
| `[services...]` | all | Limit to specific named services |

### `compose ls`

List all registered compose projects and their service status.

```
cakectl compose ls
```

This command does not need a compose file — it reads the global project registry.

### `compose init`

Write a commented `compose.yml` template in the current directory.

```
cakectl compose init [--force]
caked    compose init [--force]
```

| Flag | Default | Description |
| --- | --- | --- |
| `-f, --force` | off | Overwrite an existing `compose.yml` |

## Differences from Docker Compose

| Feature | Docker Compose | Caker compose |
| --- | --- | --- |
| Runtime | Container daemon | Apple Virtualization.framework VMs |
| VM extensions | No | `disk`, `user`, `password`, `nested`, `autostart`, `sockets` |
| `restart` | Enforced policy | Accepted, not enforced |
| `depends_on` conditions | Enforced | Order only — conditions are accepted but not checked |
| `build:` key | Build from Dockerfile | Not supported — use `image:` with a cloud image URL or simplestream alias |
| Named volumes | Managed by Docker | Not supported — use bind mounts in `volumes:` |
| `--detach` | Background | Always in background (VMs are long-lived) |
| `ls` | Lists containers | Lists registered compose projects |

## Examples

### Start a two-VM stack

```bash
# Initialise
cd myproject
cakectl compose init
# Edit compose.yml…
cakectl compose up
```

### Start only one service

```bash
cakectl compose up app
```

### Rebuild from a custom file path

```bash
cakectl compose up -f ./infra/staging.yml
```

### Inspect a service VM directly

```bash
cakectl infos compose-myproject-app
cakectl exec compose-myproject-app -- uname -a
```

### Tear down and clean up

```bash
# Stop services (keep VMs)
cakectl compose down

# Stop and delete VMs, remove project from registry
cakectl compose rm --stop
```

### List all compose projects

```bash
cakectl compose ls
```

</div>

{% include lang-toggle.html %}
