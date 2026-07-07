<!-- markdownlint-disable MD033 MD024 -->

<div id="content-fr" style="display:none" markdown="1">

# Résumé des commandes

Cette page résume les commandes `ArgumentParser` implémentées dans :
- `Sources/caked/Commands`
- `Sources/cakectl/Commands`

## Modèle de commandes

- `caked` est la surface de commandes du démon/hyperviseur local.
- `cakectl` est la surface de commandes du client gRPC.
- La plupart des opérations VM/image/réseau existent des deux côtés, sous des noms similaires.

## Groupes de commandes communs (`caked` et `cakectl`)

### Cycle de vie et exécution des VM

- `build` — crée une VM à partir d'une image cloud, en la téléchargeant et en la convertissant si nécessaire ; cloud-init s'exécute au premier démarrage.
- `launch` — construit et démarre une VM.
- `spawn` (alias : `create-from-disk`) — crée une VM à partir d'un disque racine **existant** (fichier image raw ou périphérique bloc physique) sans cloud-init. Voir [Créer une VM à partir d'un disque existant](#spawning-from-an-existing-disk).
- `spawn-start` — identique à `spawn`, puis démarre immédiatement la VM.
- `start` / `stop` / `restart` / `suspend` — contrôlent l'état d'exécution de la VM.
- `delete` / `duplicate` / `rename` / `configure` — gèrent le cycle de vie et la configuration de la VM.
- `list` / `infos` / `waitip` — inspectent l'inventaire des VM, leurs détails et la disponibilité de l'IP.
- `exec` / `sh` — exécutent des commandes dans le contexte de la VM invitée.
- `mount` / `umount` — gèrent les montages de la VM.
- `vnc` — ouvre une fenêtre de client VNC native connectée à l'affichage d'une VM en cours d'exécution.

### Images et registres

- groupe `image` : `list`, `info`, `pull`.
- `pull` / `push` — transfèrent des images de VM.
- `login` / `logout` — authentification au registre.
- groupe `remote` : `add`, `delete`, `list`.
- groupe `template` : `create`, `delete`, `list`.
- `purge` — nettoie les caches/images selon les options de rétention/budget.

### Réseaux

- groupe `networks` : `infos`, `list`, `create`, `configure`, `delete`, `start`, `stop`.

### Compose

- groupe `compose` : `up`, `down`, `ps`, `rm`, `ls`, `init`. Gère des stacks multi-VM définies dans un fichier `compose.yml`. Voir [Compose](compose) pour la référence complète.
  - `up [-f file] [--wait-ip-timeout N] [services...]` — crée et démarre les services dans l'ordre de `depends_on`.
  - `down [-f file] [--force] [services...]` — arrête les services dans l'ordre inverse.
  - `ps [-f file] [services...]` — affiche le statut des services.
  - `rm [-f file] [-s/--stop] [--force] [services...]` — supprime les VM de service et désenregistre le projet.
  - `ls` — liste tous les projets compose enregistrés (`cakectl` uniquement).
  - `init [-f/--force]` — écrit un modèle `compose.yml` commenté dans le répertoire courant.

## Commandes spécifiques à `caked`

- groupe `certificates` :
  - `get` — affiche les chemins des certificats
  - `generate` — génère des certificats TLS
  - `agent` — génère des certificats d'agent
- `convert` — convertit une image disque VMDK ou QCOW2 au format raw (pur Swift, aucun outil externe requis).
  - `--source-format` / `-f` — format source : `qcow2` (par défaut) ou `vmdk`.
- `service` — point d'entrée de gestion du service/démon.
  - `install` — installe `caked` en tant qu'agent launchctl.
  - `listen` — démarre l'écouteur du démon avec les options notables suivantes :
    - `--rest` — active le serveur API REST compatible LXD (port par défaut 8443 pour HTTPS, 8080 pour HTTP).
    - `--rest-port <port>` — modifie le port d'écoute de l'API REST.
    - `--web-ui <path>` — sert l'interface Web fournie depuis un répertoire ou une archive `.zip` sur `/ui`.
    - `--address` / `-l` — modifie l'adresse d'écoute gRPC.
    - `--insecure` — désactive TLS.
  - `status` — rapporte le statut du démon.
  - `stop` — arrête le démon en cours d'exécution.
- `vmrun` — commande interne d'exécution de VM (masquée/interne).
- `import` — importe une VM externe (Multipass ou VMware Fusion) depuis un fichier/URL.
- sous-commandes internes/admin supplémentaires de `networks` :
  - `nat-infos`
  - `set-dhcp-lease`
  - `restart`
  - `run` (interne)

## Commandes spécifiques à `cakectl`

- `certificate` — Gère les certificats pour authentifier l'API REST.

## Installation IPSW macOS

`build` accepte un fichier `.ipsw` comme source d'image sur les hôtes Apple Silicon. Le backend d'installation est choisi automatiquement selon le contenu de l'IPSW.

### Sélection du backend

| Version macOS invitée | Backend utilisé | Disponibilité |
| --- | --- | --- |
| macOS 26 ou antérieur | `VZMacOSInstaller` (framework système) | Tous les builds |
| macOS 27 (Golden Gate) ou plus récent | AMRestore (SPI `AppleMobileDeviceRestore`) | Builds hors App Store uniquement |

Le chemin AMRestore peut être forcé pour n'importe quel IPSW en définissant la clé UserDefaults `CakerForceVirtualInstallBackend` (utile pour les tests) :

```bash
defaults write com.aldunelabs.Caker CakerForceVirtualInstallBackend -bool true
```

Supprimez la surcharge une fois terminé :

```bash
defaults delete com.aldunelabs.Caker CakerForceVirtualInstallBackend
```

### Fonctionnement du chemin AMRestore

1. La VM est démarrée en **mode DFU** en utilisant la propriété privée `_forceDFU` sur `VZMacOSVirtualMachineStartOptions`.
2. Caker attend que la VM apparaisse comme un appareil AMRestore restaurable (identifié par son ECID — l'identifiant de puce unique intégré à l'identifiant machine).
3. L'IPSW est transmis à `AMRestorableDeviceRestore`, qui effectue la personnalisation auprès de `gs.apple.com` et flashe l'image. La VM s'arrête une fois l'opération terminée.

Les journaux de restauration sont écrits dans `~/Library/Application Support/Caker/VirtualInstall/Logs/` (quatre fichiers : `global.log`, `host.log`, `device.log`, `serial.log`).

### Limitations

- **Apple Silicon uniquement** — le SPI AMRestore n'existe pas sur les Mac Intel.
- **Builds hors App Store uniquement** — AMRestore communique avec `com.apple.mobile.restored` et d'autres démons système bloqués par l'App Sandbox.
- Nécessite macOS 26 ou ultérieur sur l'**hôte**.

## Notes

- Certaines commandes sont internes ou masquées dans la sortie d'aide de `caked` (`vmrun`, certaines sous-commandes `networks`).
- Les options/indicateurs exacts sont définis dans les types `*Options` et fichiers de commande correspondants.
- Si le service `caked` est déjà actif, n'exécutez pas les commandes `caked` directement ; utilisez `cakectl` pour interagir avec le service en cours d'exécution.

## Exemples

### Opérations de base sur les VM
```bash
# Créer et démarrer une VM
cakectl launch myvm --image ubuntu:22.04

# Lister les VM en cours d'exécution
cakectl list

# Exécuter une commande dans la VM
cakectl exec myvm -- ls -la

# Arrêter la VM
cakectl stop myvm
```

### Gestion des images
```bash
# Récupérer une image
cakectl pull ubuntu:22.04

# Lister les images locales
cakectl image list

# Pousser une image personnalisée
cakectl push myregistry.com/myimage:latest
```

## Formats de disque : raw et ASIF

Caker prend en charge deux formats d'image de disque racine, sélectionnés avec `--disk-format` / `-f` sur `build` et `launch` :

| Format | Valeur | Exigence hôte | Description |
| --- | --- | --- | --- |
| Raw | `raw` | Tout macOS supporté | Image disque plate redimensionnée en étendant le fichier. Par défaut sur les hôtes antérieurs à macOS 26. |
| ASIF | `asif` | macOS 26 (Tahoe) ou ultérieur | Apple Sparse Image Format, créé et géré avec `diskutil image`. Efficace en espace — le fichier n'occupe que les blocs réellement écrits par l'invité. **Par défaut sur macOS 26+.** |

```bash
# Créer une VM avec un disque racine ASIF (macOS 26+, par défaut là-bas)
cakectl build myvm --disk-size 40 --disk-format asif ubuntu:noble

# Forcer le format raw
cakectl build myvm --disk-size 40 --disk-format raw ubuntu:noble
```

Notes :

- ASIF nécessite macOS 26 ou ultérieur sur l'**hôte**. Sur les hôtes plus anciens, le format n'est pas disponible et `raw` est utilisé.
- Caker reconnaît un disque ASIF grâce à son extension `.asif` **ou** à son en-tête magique `shdw` ; une image ASIF existante est donc détectée quel que soit son nom de fichier.
- L'agrandissement d'un disque avec `configure --disk-size <GiB>` utilise `diskutil image resize` pour les disques ASIF et la troncature de fichier pour les disques raw. La VM doit d'abord être arrêtée. La réduction n'est pas prise en charge.

### ⚠️ Le redimensionnement de disque ASIF n'est pas disponible en ligne de commande dans la version App Store (sandboxée)

La version App Store de Caker s'exécute dans le App Sandbox de macOS, ce qui empêche l'interface en ligne de commande `caked`/`cakectl` et le service en arrière-plan d'invoquer `diskutil image resize`. Toute tentative de redimensionner un disque ASIF depuis la CLI échoue avec :

```text
Resize disk is not available in sandboxed mode with command line interface, ...
```

Pour redimensionner un disque ASIF dans la version sandboxée, vous pouvez soit :

1. **Utiliser l'application Caker** — le redimensionnement depuis l'interface des paramètres de la VM fonctionne normalement, ou
2. **Exécuter la commande `diskutil` manuellement** dans Terminal (avec la VM arrêtée) :

```bash
diskutil image resize --size=<new-size>G "$(caked home)/vms/<vm-name>.cakedvm/disk.img"
```

Lorsque le redimensionnement est refusé, l'application Caker affiche la commande exacte à exécuter pour votre VM. Les disques raw et le build en téléchargement direct ne sont pas concernés — `configure --disk-size` y fonctionne normalement.

## Créer une VM à partir d'un disque existant

`spawn` et `spawn-start` enregistrent une nouvelle VM qui démarre directement depuis un disque **existant** — un fichier image raw que vous possédez déjà, ou un périphérique bloc physique (`/dev/diskN`). Aucune image n'est téléchargée ou convertie, et cloud-init ne s'exécute pas par défaut.

### Quand utiliser `spawn` plutôt que `build`

| | `build` / `launch` | `spawn` / `spawn-start` |
| --- | --- | --- |
| Disque racine | Téléchargé / converti depuis une URL | Fourni par vous (image ou périphérique bloc) |
| cloud-init | S'exécute au premier démarrage | Désactivé par défaut ; activable avec `--use-cloud-init` |
| Usage typique | VM Linux/macOS fraîches à partir d'images cloud | Images préconfigurées, disques physiques, VM migrées |

### Syntaxe

```text
caked spawn [options] <name> <root-disk>
caked spawn-start [options] <name> <root-disk>
```

`<root-disk>` peut être :

- Un chemin absolu ou avec expansion `~` vers une image disque raw (`/path/to/disk.img`)
- Un périphérique bloc physique (`/dev/disk4`) — nécessite macOS 14 ou ultérieur

### Options

| Option | Défaut | Description |
| --- | --- | --- |
| `-c, --cpus <num>` | `1` | Nombre de vCPU |
| `-m, --memory <MB>` | `512` | RAM en mégaoctets |
| `--os <linux\|darwin>` | `linux` | Type d'OS invité |
| `--disk <path>` | — | Disque supplémentaire attaché (répétable) |
| `-u, --user <name>` | `admin` | Nom d'utilisateur utilisé par caked pour se connecter à l'invité (exec/sh) |
| `-w, --password <pass>` | — | Mot de passe pour l'utilisateur invité |
| `--nvram <path>` | — | Fichier NVRAM / stockage auxiliaire existant à copier (requis pour macOS sur Apple Silicon lorsqu'il n'est pas récupéré automatiquement) |
| `-a, --autostart` | désactivé | Démarrer la VM automatiquement au démarrage |
| `-t, --nested` | désactivé | Activer la virtualisation imbriquée |
| `--suspendable` | désactivé | Optimiser pour la suspension de VM (invités macOS) |
| `-p, --publish <spec>` | — | Redirection de port, syntaxe docker (répétable) |
| `-v, --mount <spec>` | — | Partage de répertoire Virtio-FS (répétable) |
| `-n, --network <spec>` | — | Interface réseau (répétable) |
| `--bridged` | désactivé | Ajouter une interface réseau en pont |
| `--net.ifnames <bool>` | `true` | Utiliser des noms d'interface prévisibles (eth0 → enp…) |
| `--display <WxH>` | `1024x768` | Résolution d'écran de l'invité |
| `--socket <url>` | — | Socket Virtio (répétable) |
| `--console <url>` | — | URL de la console série |
| `--use-cloud-init` | désactivé | Exécuter cloud-init au premier démarrage (Linux uniquement) |

`spawn-start` accepte aussi `--wait-ip-timeout <seconds>` (défaut `180`).

#### Comportement NVRAM

| Plateforme | `--nvram` fourni | `--nvram` omis |
| --- | --- | --- |
| Linux (toute architecture) | ignoré — un nouvel espace de variables EFI est toujours créé | nouvel espace de variables EFI créé |
| macOS (Apple Silicon) | le fichier fourni est copié comme stockage auxiliaire de la VM | le modèle matériel est récupéré depuis les métadonnées Apple ; un nouveau stockage auxiliaire est créé automatiquement |

#### cloud-init avec `--use-cloud-init`

Lorsque `--use-cloud-init` est passé (Linux uniquement), les options supplémentaires suivantes deviennent pertinentes :

| Option | Description |
| --- | --- |
| `-i, --ssh-authorized-key <path>` | Fichier de clé SSH autorisée à injecter |
| `-g, --main-group <name>` | Groupe principal de l'utilisateur (défaut `adm`) |
| `-o, --other-group <name>` | Groupes supplémentaires (défaut `sudo`, répétable) |
| `-k, --clear-password` | Autoriser la connexion SSH par mot de passe |
| `--cloud-init <path\|url\|->`| Fichier user-data personnalisé ou URL (`-` pour stdin) |
| `--network-config <path>` | Fichier network-config cloud-init personnalisé |

Sans `--use-cloud-init`, aucune de ces options n'a d'effet — elles sont acceptées mais ignorées.

### Exemples de spawn

```bash
# Enregistrer une VM à partir d'une image raw, 2 vCPU, 2 Gio de RAM
caked spawn myvm ~/images/ubuntu-24.04.raw -c 2 -m 2048

# Enregistrer et démarrer immédiatement, avec réseau NAT et redirection de port
caked spawn-start myvm ~/images/ubuntu-24.04.raw \
  -c 4 -m 4096 \
  --network nat \
  -p 2222:22/tcp

# Démarrer depuis un disque physique, en spécifiant les identifiants invités pour exec/sh
caked spawn diskvm /dev/disk4 --os linux -c 2 -m 4096 -u ubuntu -w secret

# Invité macOS à partir d'un disque existant — copier son NVRAM (Apple Silicon)
caked spawn macosvm ~/vms/macos.img --os darwin -c 4 -m 8192 \
  --nvram ~/vms/macos.nvram

# Invité macOS — laisser caked récupérer le modèle matériel et créer le NVRAM automatiquement
caked spawn macosvm ~/vms/macos.img --os darwin -c 4 -m 8192

# Spawn avec cloud-init activé et une clé SSH personnalisée
caked spawn webvm ~/images/ubuntu-24.04.raw \
  -c 2 -m 2048 -u ubuntu -w secret \
  --use-cloud-init -i ~/.ssh/id_ed25519.pub
```

### Périphérique bloc physique (`/dev/diskN`)

Lorsque `<root-disk>` pointe vers un périphérique bloc plutôt qu'un fichier image, caked :

1. Vérifie si des volumes du disque sont actuellement montés.
2. S'ils sont montés, propose de les démonter automatiquement (GUI) ou abandonne avec un message d'erreur (mode démon/headless) — vous devez alors exécuter manuellement `diskutil unmountDisk /dev/diskN`.
3. Ouvre le périphérique avec un **verrou exclusif** (`O_EXLOCK`) en mode lecture-écriture.
4. Transmet le descripteur de fichier ouvert au `Virtualization.framework` d'Apple en tant que `VZDiskBlockDeviceStorageDeviceAttachment`.

Le verrou est maintenu pendant toute la durée de vie de la VM, empêchant macOS de remonter le disque tant que la VM est en cours d'exécution.

> **Remarque :** L'attachement de périphériques bloc physiques nécessite macOS 14 (Sonoma) ou ultérieur et n'est **pas pris en charge dans la version App Store**. L'App Sandbox ne peut pas acquérir le verrou exclusif (`O_EXLOCK`) requis pour ouvrir un périphérique bloc en toute sécurité. Utilisez le build en téléchargement direct si vous avez besoin d'un accès disque raw.

### Prendre possession d'un périphérique physique

Les périphériques bloc macOS (`/dev/diskN`) appartiennent à `root:operator` avec le mode `0660`. Les utilisateurs ordinaires ne peuvent pas les ouvrir en lecture-écriture sans privilèges supplémentaires.

Si caked signale une erreur de **permission refusée** pour un périphérique bloc, vous avez deux options :

#### Option A — rejoindre le groupe `operator` (persistant, recommandé)

```bash
sudo dseditgroup -o edit -a "$USER" -t user operator
```

Déconnectez-vous et reconnectez-vous (ou démarrez une nouvelle session shell) pour que l'appartenance au groupe prenne effet. Ensuite, chaque périphérique `/dev/diskN` vous est accessible sans `sudo`, et vous n'avez plus jamais besoin de répéter cette étape.

#### Option B — changer le propriétaire du périphérique (par session, réinitialisé au redémarrage)

```bash
sudo chown "$USER" /dev/disk4
```

Cela modifie la propriété du nœud spécifique pour votre utilisateur. Le changement n'est **pas persistant** — macOS réinitialise la propriété des périphériques au redémarrage ou lors de la reconnexion du disque.

#### Quelle option choisir

| | Option A (groupe operator) | Option B (chown) |
| --- | --- | --- |
| Persistant | Oui | Non (réinitialisé au redémarrage / à la reconnexion) |
| Portée | Tous les périphériques bloc | Un périphérique à la fois |
| Effort | Une fois par compte utilisateur | À chaque reconnexion du disque |
| Recommandé | Oui | Tests ponctuels rapides |

Après avoir accordé l'accès avec l'une ou l'autre option, relancez la commande `spawn` ou `spawn-start` — aucun autre changement n'est nécessaire.

</div>

<div id="content-en" style="display:block" markdown="1">

# Command Summary

This page summarizes the `ArgumentParser` commands implemented in:
- `Sources/caked/Commands`
- `Sources/cakectl/Commands`

## Command model

- `caked` is the local daemon/hypervisor command surface.
- `cakectl` is the gRPC client command surface.
- Most VM/image/network operations exist on both sides with similar names.

## Common command groups (`caked` and `cakectl`)

### VM lifecycle and execution

- `build` — create a VM from a cloud image, downloading and converting it as needed; cloud-init runs on first boot.
- `launch` — build and start a VM.
- `spawn` (alias: `create-from-disk`) — create a VM from an **existing** root disk (raw image file or physical block device) without cloud-init. See [Spawning from an existing disk](#spawning-from-an-existing-disk).
- `spawn-start` — same as `spawn`, then immediately start the VM.
- `start` / `stop` / `restart` / `suspend` — control VM runtime state.
- `delete` / `duplicate` / `rename` / `configure` — manage VM lifecycle and configuration.
- `list` / `infos` / `waitip` — inspect VM inventory, details, and IP readiness.
- `exec` / `sh` — execute commands in guest VM context.
- `mount` / `umount` — manage VM mounts.
- `vnc` — open a native VNC client window connected to a running VM's display.

### Images and registries

- `image` group: `list`, `info`, `pull`.
- `pull` / `push` — transfer VM images.
- `login` / `logout` — registry authentication.
- `remote` group: `add`, `delete`, `list`.
- `template` group: `create`, `delete`, `list`.
- `purge` — cleanup caches/images according to retention/budget options.

### Networks

- `networks` group: `infos`, `list`, `create`, `configure`, `delete`, `start`, `stop`.

### Compose

- `compose` group: `up`, `down`, `ps`, `rm`, `ls`, `init`. Manage multi-VM stacks defined in a `compose.yml` file. See [Compose](compose) for full reference.
  - `up [-f file] [--wait-ip-timeout N] [services...]` — create and start services in `depends_on` order.
  - `down [-f file] [--force] [services...]` — stop services in reverse order.
  - `ps [-f file] [services...]` — show service status.
  - `rm [-f file] [-s/--stop] [--force] [services...]` — remove service VMs and unregister the project.
  - `ls` — list all registered compose projects (`cakectl` only).
  - `init [-f/--force]` — write a commented `compose.yml` template in the current directory.

## `caked`-specific commands

- `certificates` group:
  - `get` — show certificate paths
  - `generate` — generate TLS certs
  - `agent` — generate agent certs
- `convert` — convert a VMDK or QCOW2 disk image to raw format (pure Swift, no external tools required).
  - `--source-format` / `-f` — source format: `qcow2` (default) or `vmdk`.
- `service` — service/daemon management entry point.
  - `install` — install `caked` as a launchctl agent.
  - `listen` — start the daemon listener with the following notable flags:
    - `--rest` — enable the LXD-compatible REST API server (default port 8443 for HTTPS, 8080 for HTTP).
    - `--rest-port <port>` — override the REST API listen port.
    - `--web-ui <path>` — serve the bundled web UI from a directory or `.zip` archive at `/ui`.
    - `--address` / `-l` — override the gRPC listen address.
    - `--insecure` — disable TLS.
  - `status` — report daemon status.
  - `stop` — stop the running daemon.
- `vmrun` — internal VM runtime command (hidden/internal).
- `import` — import external VM (Multipass or VMware Fusion) from file/URL.
- `networks` extra internal/admin subcommands:
  - `nat-infos`
  - `set-dhcp-lease`
  - `restart`
  - `run` (internal)

## `cakectl`-specific commands

- `certificate` — Manage certificate to authenticate API rest.

## macOS IPSW installation

`build` accepts an `.ipsw` file as the image source on Apple Silicon hosts. The installer back-end is chosen automatically based on the IPSW content.

### Back-end selection

| Guest macOS version | Back-end used | Availability |
| --- | --- | --- |
| macOS 26 or older | `VZMacOSInstaller` (system framework) | All builds |
| macOS 27 (Golden Gate) or newer | AMRestore (`AppleMobileDeviceRestore` SPI) | Non-App Store builds only |

The AMRestore path can be force-enabled for any IPSW by setting the `CakerForceVirtualInstallBackend` UserDefaults key (useful for testing):

```bash
defaults write com.aldunelabs.Caker CakerForceVirtualInstallBackend -bool true
```

Remove the override when you are done:

```bash
defaults delete com.aldunelabs.Caker CakerForceVirtualInstallBackend
```

### How the AMRestore path works

1. The VM is booted in **DFU mode** using the private `_forceDFU` property on `VZMacOSVirtualMachineStartOptions`.
2. Caker waits for the VM to appear as a restorable AMRestore device (matched by its ECID — the unique chip identifier embedded in the machine identifier).
3. The IPSW is handed to `AMRestorableDeviceRestore` which performs personalization against `gs.apple.com` and flashes the image. The VM shuts down on completion.

Restore logs are written to `~/Library/Application Support/Caker/VirtualInstall/Logs/` (four files: `global.log`, `host.log`, `device.log`, `serial.log`).

### Limitations

- **Apple Silicon only** — AMRestore SPI does not exist on Intel Macs.
- **Non-App Store builds only** — AMRestore communicates with `com.apple.mobile.restored` and other system daemons that are blocked by the App Sandbox.
- Requires macOS 26 or later on the **host**.

## Notes

- Some commands are internal or hidden in help output on `caked` (`vmrun`, some `networks` subcommands).
- Exact flags/options are defined in the corresponding `*Options` types and command files.
- If the `caked` service is already active, do not run `caked` commands directly; use `cakectl` to interact with the running service.

## Examples

### Basic VM Operations
```bash
# Create and start a VM
cakectl launch myvm --image ubuntu:22.04

# List running VMs
cakectl list

# Execute command in VM
cakectl exec myvm -- ls -la

# Stop VM
cakectl stop myvm
```

### Image Management
```bash
# Pull an image
cakectl pull ubuntu:22.04

# List local images
cakectl image list

# Push custom image
cakectl push myregistry.com/myimage:latest
```

## Disk formats: raw and ASIF

Caker supports two root-disk image formats, selected with `--disk-format` / `-f` on `build` and `launch`:

| Format | Value | Host requirement | Description |
| --- | --- | --- | --- |
| Raw | `raw` | Any supported macOS | Flat disk image resized by extending the file. Default on hosts older than macOS 26. |
| ASIF | `asif` | macOS 26 (Tahoe) or later | Apple Sparse Image Format, created and managed with `diskutil image`. Space-efficient — the file only occupies the blocks actually written by the guest. **Default on macOS 26+.** |

```bash
# Create a VM with an ASIF root disk (macOS 26+, default there)
cakectl build myvm --disk-size 40 --disk-format asif ubuntu:noble

# Force the raw format
cakectl build myvm --disk-size 40 --disk-format raw ubuntu:noble
```

Notes:

- ASIF requires macOS 26 or later on the **host**. On older hosts the format is unavailable and `raw` is used.
- Caker recognizes an ASIF disk by its `.asif` extension **or** its `shdw` magic header, so an existing ASIF image is detected regardless of its file name.
- Growing a disk with `configure --disk-size <GiB>` uses `diskutil image resize` for ASIF disks and file truncation for raw disks. The VM must be stopped first. Shrinking is not supported.

### ⚠️ ASIF disk resize is not available from the command line in the App Store (sandboxed) version

The App Store version of Caker runs inside the macOS App Sandbox, which prevents the `caked`/`cakectl` command-line interface and the background service from invoking `diskutil image resize`. Attempting to resize an ASIF disk from the CLI fails with:

```text
Resize disk is not available in sandboxed mode with command line interface, ...
```

To resize an ASIF disk in the sandboxed version you can either:

1. **Use the Caker application** — resizing from the VM settings UI works normally, or
2. **Run the `diskutil` command manually** in Terminal (with the VM stopped):

```bash
diskutil image resize --size=<new-size>G "$(caked home)/vms/<vm-name>.cakedvm/disk.img"
```

When the resize is refused, the Caker application displays the exact command to run for your VM. Raw disks and the direct-download build are not affected — `configure --disk-size` works normally there.

## Spawning from an existing disk

`spawn` and `spawn-start` register a new VM that boots directly from an **existing** disk — a raw image file you already have, or a physical block device (`/dev/diskN`). No image is downloaded or converted, and cloud-init does not run by default.

### When to use `spawn` vs `build`

| | `build` / `launch` | `spawn` / `spawn-start` |
| --- | --- | --- |
| Root disk | Downloaded / converted from URL | Provided by you (image or block device) |
| cloud-init | Runs on first boot | Off by default; opt in with `--use-cloud-init` |
| Typical use | Fresh Linux/macOS VMs from cloud images | Pre-configured images, physical disks, migrated VMs |

### Syntax

```text
caked spawn [options] <name> <root-disk>
caked spawn-start [options] <name> <root-disk>
```

`<root-disk>` can be:

- An absolute or `~`-expanded path to a raw disk image (`/path/to/disk.img`)
- A physical block device (`/dev/disk4`) — requires macOS 14 or later

### Options

| Flag | Default | Description |
| --- | --- | --- |
| `-c, --cpus <num>` | `1` | Number of vCPUs |
| `-m, --memory <MB>` | `512` | RAM in megabytes |
| `--os <linux\|darwin>` | `linux` | Guest OS type |
| `--disk <path>` | — | Additional attached disk (repeatable) |
| `-u, --user <name>` | `admin` | Username caked uses to connect to the guest (exec/sh) |
| `-w, --password <pass>` | — | Password for the guest user |
| `--nvram <path>` | — | Existing NVRAM / auxiliary-storage file to copy (required for macOS on Apple Silicon when not auto-fetched) |
| `-a, --autostart` | off | Start VM automatically at boot |
| `-t, --nested` | off | Enable nested virtualisation |
| `--suspendable` | off | Optimise for VM suspension (macOS guests) |
| `-p, --publish <spec>` | — | Port forwarding, docker syntax (repeatable) |
| `-v, --mount <spec>` | — | Virtio-FS directory share (repeatable) |
| `-n, --network <spec>` | — | Network interface (repeatable) |
| `--bridged` | off | Add one bridged network interface |
| `--net.ifnames <bool>` | `true` | Use predictable interface names (eth0 → enp…) |
| `--display <WxH>` | `1024x768` | Guest screen resolution |
| `--socket <url>` | — | Virtio socket (repeatable) |
| `--console <url>` | — | Serial console URL |
| `--use-cloud-init` | off | Run cloud-init on first boot (Linux only) |

`spawn-start` also accepts `--wait-ip-timeout <seconds>` (default `180`).

#### NVRAM behaviour

| Platform | `--nvram` provided | `--nvram` omitted |
| --- | --- | --- |
| Linux (any arch) | ignored — fresh EFI variable store is always created | fresh EFI variable store created |
| macOS (Apple Silicon) | provided file is copied as the VM's auxiliary storage | hardware model fetched from Apple metadata; fresh auxiliary storage created automatically |

#### cloud-init when using `--use-cloud-init`

When `--use-cloud-init` is passed (Linux only), the following additional options become meaningful:

| Flag | Description |
| --- | --- |
| `-i, --ssh-authorized-key <path>` | SSH authorized-key file to inject |
| `-g, --main-group <name>` | Primary group for the user (default `adm`) |
| `-o, --other-group <name>` | Additional groups (default `sudo`, repeatable) |
| `-k, --clear-password` | Allow password-based SSH login |
| `--cloud-init <path\|url\|->`| Custom user-data file or URL (`-` for stdin) |
| `--network-config <path>` | Custom cloud-init network-config file |

Without `--use-cloud-init`, none of these options have any effect — they are accepted but ignored.

### Spawn examples

```bash
# Register a VM from a raw image, 2 vCPUs, 2 GiB RAM
caked spawn myvm ~/images/ubuntu-24.04.raw -c 2 -m 2048

# Register and immediately start, with NAT network and port forwarding
caked spawn-start myvm ~/images/ubuntu-24.04.raw \
  -c 4 -m 4096 \
  --network nat \
  -p 2222:22/tcp

# Boot from a physical disk, specifying the guest credentials for exec/sh
caked spawn diskvm /dev/disk4 --os linux -c 2 -m 4096 -u ubuntu -w secret

# macOS guest from an existing disk — copy its NVRAM (Apple Silicon)
caked spawn macosvm ~/vms/macos.img --os darwin -c 4 -m 8192 \
  --nvram ~/vms/macos.nvram

# macOS guest — let caked fetch the hardware model and create NVRAM automatically
caked spawn macosvm ~/vms/macos.img --os darwin -c 4 -m 8192

# Spawn with cloud-init enabled and a custom SSH key
caked spawn webvm ~/images/ubuntu-24.04.raw \
  -c 2 -m 2048 -u ubuntu -w secret \
  --use-cloud-init -i ~/.ssh/id_ed25519.pub
```

### Physical block device (`/dev/diskN`)

When `<root-disk>` points to a block device rather than an image file, caked:

1. Checks whether any volumes on the disk are currently mounted.
2. If mounted, prompts to unmount them automatically (GUI) or aborts with an error message (daemon/headless mode) — you must run `diskutil unmountDisk /dev/diskN` manually first.
3. Opens the device with an **exclusive lock** (`O_EXLOCK`) in read-write mode.
4. Passes the open file descriptor to Apple's `Virtualization.framework` as a `VZDiskBlockDeviceStorageDeviceAttachment`.

The lock is held for the entire lifetime of the VM, preventing macOS from re-mounting the disk while the VM is running.

> **Note:** Attaching physical block devices requires macOS 14 (Sonoma) or later and is **not supported in the App Store version**. The App Sandbox cannot acquire the exclusive lock (`O_EXLOCK`) required to open a block device safely. Use the direct-download build if you need raw disk access.

### Taking ownership of a physical device

macOS block devices (`/dev/diskN`) are owned by `root:operator` with mode `0660`. Ordinary users cannot open them read-write without additional privileges.

If caked reports a **permission denied** error for a block device, you have two options:

#### Option A — join the `operator` group (persistent, recommended)

```bash
sudo dseditgroup -o edit -a "$USER" -t user operator
```

Log out and back in (or start a new shell session) for the group membership to take effect. After that, every `/dev/diskN` device is accessible to you without `sudo`, and you never need to repeat this step.

#### Option B — change the device owner (per-session, resets on reboot)

```bash
sudo chown "$USER" /dev/disk4
```

This changes ownership of the specific node to your user. The change is **not persistent** — macOS resets device ownership on reboot or when the disk is reconnected.

#### Which option to choose

| | Option A (operator group) | Option B (chown) |
| --- | --- | --- |
| Persistent | Yes | No (resets on reboot / reconnect) |
| Scope | All block devices | One device at a time |
| Effort | Once per user account | Every time the disk is reconnected |
| Recommended | Yes | Quick one-off testing |

After granting access with either option, retry the `spawn` or `spawn-start` command — no other changes are needed.

</div>
