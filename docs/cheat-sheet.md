---
layout: default
title: Cheat Sheet
nav_order: 9
---

<!-- markdownlint-disable MD033 MD024 -->

<div class="lang-fr" style="display:none" markdown="1">

# Pense-bête

Référence rapide des commandes pour les opérations quotidiennes courantes.

> ⚠️ Si le service `caked` est actif, n'utilisez pas `caked` directement. Utilisez les commandes `cakectl` contre le service en cours d'exécution.

## Cycle de vie des VM (`cakectl`)

- Lister les VM :
  - `cakectl list`
- Obtenir les détails d'une VM :
  - `cakectl infos <vm-name>`
- Démarrer / arrêter / redémarrer :
  - `cakectl start <vm-name>`
  - `cakectl stop <vm-name>`
  - `cakectl restart <vm-name>`
- Lancer une nouvelle VM :
  - `cakectl launch ...`

## Authentification pour la webui (`cakectl certificate`)

- Lister les certificats enregistrés :
  - `cakectl certificate list`
- Ajouter un certificat (depuis un fichier ou stdin) :
  - `cakectl certificate add --name <name> <cert.pem>`
  - `cat cert.pem | cakectl certificate add --name <name>`
- Obtenir un certificat (affiche le PEM) :
  - `cakectl certificate get <fingerprint-or-name>`
- Supprimer un certificat :
  - `cakectl certificate delete <fingerprint-or-name>`

## Accès invité (`cakectl`)

- Exécuter une commande dans l'invité :
  - `cakectl exec <vm-name> -- <command> [args...]`
- Ouvrir un shell invité :
  - `cakectl sh <vm-name>`
- Attendre l'IP :
  - `cakectl waitip <vm-name>`
- Ouvrir l'affichage VNC :
  - `cakectl vnc <vm-name>`

## Images et registre (`cakectl`)

- Liste/info/pull d'image :
  - `cakectl image list <remote>`
  - `cakectl image info <image>`
  - `cakectl image pull <image>`
- Authentification au registre :
  - `cakectl login <host>`
  - `cakectl logout <host>`
- Push/pull d'images de VM :
  - `cakectl pull <name> <image>`
  - `cakectl push <local-name> <remote-name>`

## Réseaux (`cakectl`)

- Lister les réseaux :
  - `cakectl networks list`
- Inspecter un réseau :
  - `cakectl networks infos <network>`
- Créer/démarrer/arrêter :
  - `cakectl networks create ...`
  - `cakectl networks start <network>`
  - `cakectl networks stop <network>`

## Compose (`cakectl compose`)

- Initialiser un projet :
  - `cakectl compose init`
- Démarrer tous les services :
  - `cakectl compose up`
- Démarrer des services spécifiques :
  - `cakectl compose up app database`
- Arrêter tous les services :
  - `cakectl compose down`
- Afficher le statut des services :
  - `cakectl compose ps`
- Supprimer et désenregistrer (arrêter d'abord) :
  - `cakectl compose rm --stop`
- Lister tous les projets compose :
  - `cakectl compose ls`
- Utiliser un fichier personnalisé :
  - `cakectl compose up -f ./infra/staging.yml`

## Démon local/admin (`caked`)

- Exécuter une commande du démon directement :
  - `caked <command> ...`
- Certificats :
  - `caked certificates get`
  - `caked certificates generate`
- Mode service :
  - `caked service listen --disable-tls` *(activer le trafic sans TLS)*
  - `caked service listen --tcp`  *(activer l'écoute sur tcp)*
  - `caked service listen --rest` *(activer l'API REST LXD)*
  - `caked service listen --rest --web-ui /path/to/webui/dist` *(avec interface Web)*
  - `caked service status`
  - `caked service stop`
- Convertir des images disque :
  - `caked convert source.qcow2 destination.raw`
  - `caked convert --source-format vmdk source.vmdk destination.raw`

## Options globales utiles

- `cakectl --connect <address>`
- `cakectl --disable-tls`
- `cakectl --system`
- `caked --log-level <level>`
- `caked --format json`

## Liens vers la documentation

- Groupes de commandes détaillés : [Résumé des commandes](command-summary)
- Dépannage : [Dépannage](troubleshooting)

## Workflows réels

### 1) Créer et démarrer une VM

depuis un registre OCI

```bash
cakectl build --name demo-vm --cpu 4 --memory 8192 --disk-size 40G oci://ghcr.io/example/image:latest
```

depuis https

```bash
cakectl build --name demo-vm --cpu 4 --memory 8192 --disk-size 40G https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-arm64.img
```

depuis un remote simplestream

```bash
cakectl build --name demo-vm --cpu 4 --memory 8192 --disk-size 40G ubuntu:noble
```

en choisissant le format du disque racine (`asif` est le défaut sur macOS 26+, `raw` sur les hôtes plus anciens — voir [Formats de disque](command-summary#disk-formats-raw-and-asif-fr))

```bash
cakectl build --name demo-vm --cpu 4 --memory 8192 --disk-size 40G --disk-format asif ubuntu:noble
```

> ⚠️ Dans la version App Store (sandboxée), le redimensionnement d'un disque **ASIF** avec `configure --disk-size` n'est pas disponible en ligne de commande — utilisez l'application Caker ou exécutez la commande `diskutil image resize` affichée dans le message d'erreur.

### 2) Démarrer une VM existante, attendre l'IP, inspecter le statut

```bash
cakectl start demo-vm
cakectl waitip demo-vm
cakectl infos demo-vm
```

### 3) Ouvrir un shell et exécuter une commande dans l'invité

```bash
cakectl shell demo-vm
cakectl exec demo-vm -- uname -a
```

### 6) Se connecter à l'affichage de la VM via VNC

```bash
cakectl start demo-vm
cakectl vnc demo-vm
```

### 7) Convertir une image QCOW2 ou VMDK en raw

```bash
# QCOW2 (par défaut)
caked convert ubuntu-cloud.qcow2 ubuntu.raw

# VMDK
caked convert --source-format vmdk disk.vmdk disk.raw
```

### 4) Pousser une image de VM locale vers un registre distant

```bash
cakectl login ghcr.io --username <username> --password <password>
cakectl push demo-vm ghcr.io/<owner>/demo-vm:latest
cakectl logout ghcr.io
```

### 5) Créer et gérer un réseau partagé

```bash
cakectl networks create --name shared-dev --mode shared --gateway 192.168.105.1 --dhcp-end 192.168.105.254 --netmask 255.255.255.0
cakectl networks start shared-dev
cakectl networks infos shared-dev
cakectl networks stop shared-dev
```

</div>

<div class="lang-en" style="display:block" markdown="1">

# Cheat Sheet

Quick command reference for common daily operations.

> ⚠️ If the `caked` service is active, do not use `caked` directly. Use `cakectl` commands against the running service.

## VM lifecycle (`cakectl`)

- List VMs:
  - `cakectl list`
- Get VM details:
  - `cakectl infos <vm-name>`
- Start / stop / restart:
  - `cakectl start <vm-name>`
  - `cakectl stop <vm-name>`
  - `cakectl restart <vm-name>`
- Launch a new VM:
  - `cakectl launch ...`

## Authentication for webui (`cakectl certificate`)

- List registered certificates:
  - `cakectl certificate list`
- Add a certificate (from file or stdin):
  - `cakectl certificate add --name <name> <cert.pem>`
  - `cat cert.pem | cakectl certificate add --name <name>`
- Get a certificate (outputs PEM):
  - `cakectl certificate get <fingerprint-or-name>`
- Remove a certificate:
  - `cakectl certificate delete <fingerprint-or-name>`

## Guest access (`cakectl`)

- Run one command in guest:
  - `cakectl exec <vm-name> -- <command> [args...]`
- Open guest shell:
  - `cakectl sh <vm-name>`
- Wait for IP:
  - `cakectl waitip <vm-name>`
- Open VNC display:
  - `cakectl vnc <vm-name>`

## Images and registry (`cakectl`)

- Image list/info/pull:
  - `cakectl image list <remote>`
  - `cakectl image info <image>`
  - `cakectl image pull <image>`
- Registry auth:
  - `cakectl login <host>`
  - `cakectl logout <host>`
- Push/pull VM images:
  - `cakectl pull <name> <image>`
  - `cakectl push <local-name> <remote-name>`

## Networks (`cakectl`)

- List networks:
  - `cakectl networks list`
- Inspect one network:
  - `cakectl networks infos <network>`
- Create/start/stop:
  - `cakectl networks create ...`
  - `cakectl networks start <network>`
  - `cakectl networks stop <network>`

## Compose (`cakectl compose`)

- Initialise a project:
  - `cakectl compose init`
- Start all services:
  - `cakectl compose up`
- Start specific services:
  - `cakectl compose up app database`
- Stop all services:
  - `cakectl compose down`
- Show service status:
  - `cakectl compose ps`
- Remove and unregister (stop first):
  - `cakectl compose rm --stop`
- List all compose projects:
  - `cakectl compose ls`
- Use a custom file:
  - `cakectl compose up -f ./infra/staging.yml`

## Local daemon/admin (`caked`)

- Run daemon command directly:
  - `caked <command> ...`
- Certificates:
  - `caked certificates get`
  - `caked certificates generate`
- Service mode:
  - `caked service listen --disable-tls` *(enable traffic without TLS)*
  - `caked service listen --tcp`  *(enable listen on tcp)*
  - `caked service listen --rest` *(enable LXD REST API)*
  - `caked service listen --rest --web-ui /path/to/webui/dist` *(with web UI)*
  - `caked service status`
  - `caked service stop`
- Convert disk images:
  - `caked convert source.qcow2 destination.raw`
  - `caked convert --source-format vmdk source.vmdk destination.raw`

## Useful global options

- `cakectl --connect <address>`
- `cakectl --disable-tls`
- `cakectl --system`
- `caked --log-level <level>`
- `caked --format json`

## Docs links

- Detailed command groups: [Command Summary](command-summary)
- Troubleshooting: [Troubleshooting](troubleshooting)

## Real workflows

### 1) Create and start a VM

from OCI registry

```bash
cakectl build --name demo-vm --cpu 4 --memory 8192 --disk-size 40G oci://ghcr.io/example/image:latest
```

from https

```bash
cakectl build --name demo-vm --cpu 4 --memory 8192 --disk-size 40G https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-arm64.img
```

from simplestream remote

```bash
cakectl build --name demo-vm --cpu 4 --memory 8192 --disk-size 40G ubuntu:noble
```

choosing the root-disk format (`asif` is the default on macOS 26+, `raw` on older hosts — see [Disk formats](command-summary#disk-formats-raw-and-asif))

```bash
cakectl build --name demo-vm --cpu 4 --memory 8192 --disk-size 40G --disk-format asif ubuntu:noble
```

> ⚠️ In the App Store (sandboxed) version, resizing an **ASIF** disk with `configure --disk-size` is not available from the command line — use the Caker application or run the `diskutil image resize` command shown in the error message.

### 2) Start an existing VM, wait for IP, inspect status

```bash
cakectl start demo-vm
cakectl waitip demo-vm
cakectl infos demo-vm
```

### 3) Open shell and run one command in guest

```bash
cakectl shell demo-vm
cakectl exec demo-vm -- uname -a
```

### 6) Connect to VM display via VNC

```bash
cakectl start demo-vm
cakectl vnc demo-vm
```

### 7) Convert a QCOW2 or VMDK image to raw

```bash
# QCOW2 (default)
caked convert ubuntu-cloud.qcow2 ubuntu.raw

# VMDK
caked convert --source-format vmdk disk.vmdk disk.raw
```

### 4) Push a local VM image to remote registry

```bash
cakectl login ghcr.io --username <username> --password <password>
cakectl push demo-vm ghcr.io/<owner>/demo-vm:latest
cakectl logout ghcr.io
```

### 5) Create and manage a shared network

```bash
cakectl networks create --name shared-dev --mode shared --gateway 192.168.105.1 --dhcp-end 192.168.105.254 --netmask 255.255.255.0
cakectl networks start shared-dev
cakectl networks infos shared-dev
cakectl networks stop shared-dev
```

</div>

{% include lang-toggle.html %}
