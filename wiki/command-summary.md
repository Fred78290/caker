<!-- markdownlint-disable MD033 MD024 -->

<div class="lang-fr" style="display:none" markdown="1">

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
    - `--imds-port <port>` — port non privilégié sur lequel IMDS écoute, joignable directement par les invités sans root (par défaut `28080`). Voir [IMDS](imds).
  - `status` — rapporte le statut du démon.
  - `stop` — arrête le démon en cours d'exécution.
- `vmrun` — commande interne d'exécution de VM (masquée/interne).
- `import` — importe une VM externe (Multipass ou VMware Fusion) depuis un fichier/URL.
- sous-commandes internes/admin supplémentaires de `networks` :
  - `nat-infos`
  - `set-dhcp-lease`
  - `restart`
  - `run` (interne)
  - `imds-redirect` (interne, root requis) — installe/retire la redirection `pf` d'alias d'adresse pour `169.254.169.254`, voir [IMDS](imds).

## Commandes spécifiques à `cakectl`

- `certificate` — Gère les certificats pour authentifier l'API REST.

## Installation IPSW macOS

`build` accepte un fichier `.ipsw` comme source d'image sur les hôtes Apple Silicon. Le backend d'installation est choisi automatiquement selon le contenu de l'IPSW.

### Sélection du backend

| Version macOS invitée | Backend utilisé | Disponibilité |
| --- | --- | --- |
| macOS 26 ou antérieur | `VZMacOSInstaller` (framework système) | Tous les builds |
| macOS 27 (Golden Gate) ou plus récent | AMRestore (SPI `AppleMobileDeviceRestore`) | Tous les builds |

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
- Nécessite macOS 26 ou ultérieur sur l'**hôte**.

<a name="packerlite-fr"></a>
### PackerLite : provisioning automatisé (macOS et Linux)

Quand `build`/`create` est lancé avec `--autoinstall`, une fois l'installation terminée, `caked` pilote automatiquement le premier démarrage de la VM (création du compte, activation du partage d'écran/Remote Login, désactivation de Gatekeeper pour macOS ; script d'installation piloté par clavier pour Linux) via **PackerLite** — un mini-moteur intégré inspiré de Packer (`boot_command`) et de son plugin `packer-plugin-tart`, mais sans dépendre d'aucun binaire ou plugin externe. Sans `--autoinstall`, aucun provisioning automatique n'a lieu.

La résolution du template diffère selon la source :

**Depuis un `.ipsw` (macOS)** — résolu dans cet ordre, le build échoue si rien n'aboutit :

1. **`--template <chemin>`** — chemin explicite vers un fichier YAML personnalisé ; prioritaire sur tout le reste.
2. **Détection automatique** de la version macOS à partir du nom de fichier de l'IPSW (convention Apple `UniversalMac_<version>_<build>_Restore.ipsw`), puis chargement du template intégré correspondant.
3. **`--macos-version <version>`** — si la détection échoue, utilise la version indiquée explicitement (`monterey`, `ventura`, `sonoma`, `sequoia`, `tahoe` ou `goldengate`) pour choisir le template intégré.

La version macOS détectée (nom de code + numéro, ex. `sequoia` / `15.6`) est toujours enregistrée dans la configuration de la VM (`osName`/`osRelease`), que `--autoinstall` soit utilisé ou non — ce qui permet à un `caked provision` ultérieur de retrouver la bonne version sans l'IPSW d'origine.

**Depuis un `.iso` (Linux)** — aucun template n'est fourni par défaut. PackerLite ne se déclenche que si `--template <chemin>` est fourni explicitement **en plus** de `--autoinstall`. Les distributions gérant déjà leur propre autoinstall (Ubuntu, via cloud-init/subiquity) n'ont pas besoin de PackerLite et continuent d'utiliser ce mécanisme existant ; PackerLite couvre les ISO qui n'ont pas d'autoinstall natif. Dans l'assistant graphique de Caker.app, le sélecteur de fichier « Provisioning yaml » n'apparaît que pour les sources ISO non-Ubuntu et bloque la création tant qu'aucun template n'est choisi si l'auto-configuration est activée.

```bash
# macOS : version détectée automatiquement depuis le nom du fichier IPSW
cakectl build my-vm https://updates.cdn-apple.com/.../UniversalMac_26.6_25G72_Restore.ipsw --autoinstall

# macOS : nom de fichier non standard, version précisée explicitement
cakectl build my-vm ./restore.ipsw --autoinstall --macos-version tahoe

# macOS : template personnalisé, ignore toute détection
cakectl build my-vm ./restore.ipsw --autoinstall --template ./mon-template.packerlite.yaml

# Linux : template obligatoire pour une ISO non-Ubuntu
cakectl build my-vm ./debian-13.iso --autoinstall --template ./debian.packerlite.yaml

# Variables de template supplémentaires (répétable)
cakectl build my-vm ./restore.ipsw --autoinstall --var greeting=hello
```

| Option | Description |
| --- | --- |
| `--autoinstall` | Active le provisioning automatique (requis dans tous les cas, macOS comme Linux). |
| `--template <chemin>` | Template YAML PackerLite personnalisé ; contourne la détection automatique pour macOS, **obligatoire** pour une ISO Linux non-Ubuntu. |
| `--macos-version <monterey\|ventura\|sonoma\|sequoia\|tahoe\|goldengate>` | Version macOS à utiliser pour choisir le template intégré quand elle ne peut pas être déduite du nom de fichier IPSW. Sans effet pour Linux. |
| `--var <clé=valeur>` | Définit une variable de template (`${var.clé}`), répétable. |

**Identifiants du compte** : le compte créé pendant le provisioning utilise toujours `--user`/`--password` (ou l'équivalent dans l'UI) — jamais une valeur propre au template. À l'intérieur d'un template, ces valeurs sont accessibles via `${var.username}` / `${var.password}`.

**Templates macOS intégrés** : cinq templates sont fournis en ressources embarquées (`Sources/cakedlib/PackerLite/Resources/`) : `monterey` (macOS 12.x), `ventura` (macOS 13.x), `sonoma` (macOS 14.x), `sequoia` (macOS 15.x, transcrit depuis `templates/macos/vanilla-sequoia.pkr.hcl`) et `tahoe` (macOS 26.x, transcrit depuis `vanilla-tahoe.pkr.hcl`). `goldengate` (macOS 27.x) est une version reconnue (détection automatique et `--macos-version` fonctionnent) mais sans template intégré pour l'instant — fournissez le vôtre avec `--template` pour cette version. **Aucun template Linux n'est fourni** — écrivez le vôtre pour la distribution ciblée.

**Format du template** — un YAML minimal avec une liste `boot_command` d'entrées `title`/`command` reprenant le vocabulaire de tokens de Packer (`<wait10s>`, `<enter>`, `<tab>`, `<leftShiftOn>`/`<leftShiftOff>`, `<fnOn>`/`<fnOff>`, `<f1>`–`<f20>`, `<click 'Texte affiché'>` — repéré par OCR via Vision —, `<keyboard 'com.apple.keylayout.XXX'>` ou `<keyboard 'current'>` pour changer la disposition clavier utilisée pour traduire les caractères tapés, etc.), plus `variables:`, `create_grace_time` et `boot_timeout`. Le `title` de chaque entrée est affiché comme sous-étape de progression et dans les logs — utile pour repérer où un provisioning s'est arrêté. `${var.username}`/`${var.password}` sont toujours injectées par `caked` (voir ci-dessus) ; les autres `${var.*}` viennent de `variables:` ou d'un `--var` correspondant.

```yaml
# mon-template.packerlite.yaml — extrait illustratif
create_grace_time: 30s   # délai après le démarrage avant la première frappe
boot_timeout: 45m        # échec si le provisioning n'est pas terminé dans ce délai

variables:
  greeting: hello         # valeur par défaut, surchageable via --var greeting=...

boot_command:
  - title: Écran de bienvenue
    command: "<wait60s><spacebar>"
  - title: Sélection de la langue
    command: "<wait30s>italiano<esc>english<enter>"
  - title: Sélection du pays ou de la région
    command: "<wait30s><click 'Select Your Country or Region'><wait5s>united states<leftShiftOn><tab><leftShiftOff><spacebar>"
  - title: Création du compte
    command: "<wait10s>${var.username}<tab>${var.password}<tab>${var.password}<tab><tab><spacebar>"
  - title: Désactivation de Gatekeeper
    command: "<wait10s>sudo spctl --global-disable<enter>"
  - title: Confirmation du mot de passe
    command: "<wait10s>${var.password}<enter>"
```

Voir `Sources/cakedlib/PackerLite/Resources/*.packerlite.yaml` (templates macOS embarqués, avec les titres) et `templates/linux/*.packerlite.yaml` (templates Linux de référence, non embarqués : `fedora-workstation`, `centos-stream`, `rhel` — famille Anaconda —, `opensuse-leap` — YaST — et `debian` — debian-installer) pour des exemples complets et entièrement commentés.

<a name="provision-fr"></a>
### `caked provision` : relancer le provisioning de façon autonome

`caked build`/`create` ne pilote PackerLite automatiquement que si `--autoinstall` a été utilisé. Pour une VM (macOS ou Linux) dont le provisioning a été sauté au moment du build — ou construite avant que `--autoinstall` n'existe — `caked provision <vm>` relance la même automatisation directement sur une VM déjà construite. C'est une commande propre à `caked` (pas encore exposée via `cakectl`/gRPC) ; elle doit être exécutée sur l'hôte où résident les fichiers de la VM. Elle démarre elle-même la VM avec une fenêtre visible (comme `vmrun`) plutôt que de supposer qu'elle tourne déjà, afin que vous puissiez suivre le provisioning à l'écran, puis l'arrête une fois terminé.

Elle s'appuie sur l'état déjà stocké de la VM plutôt que sur l'`.ipsw`/`.iso` d'origine :

- **VM macOS** : la version provient de `CakeConfig.osName` — enregistrée automatiquement à chaque build `.ipsw` — sauf si `--macos-version` la surcharge ; `--template` reste disponible pour ignorer complètement cette résolution.
- **VM non-macOS (Linux)** : `--template <chemin>` est **obligatoire** — sans détection possible depuis une VM déjà installée, la commande échoue immédiatement si le fichier n'est pas fourni ou n'existe pas.
- Dans tous les cas, les identifiants du compte proviennent du `--user`/`--password` propre à la VM (`configuredUser`/`configuredPassword`), exactement comme au moment du build. Une fois le `boot_command` terminé et une IP obtenue, `caked provision` installe aussi le cakeagent si besoin — utile pour une VM Linux qui a sauté cloud-init.

```bash
# Reprovisionner une VM macOS avec sa version et ses identifiants stockés
caked provision my-vm

# Forcer la version macOS résolue
caked provision my-vm --macos-version tahoe

# Reprovisionner une VM Linux (template obligatoire)
caked provision my-linux-vm --template ./debian.packerlite.yaml
```

| Option | Description |
| --- | --- |
| `--template <chemin>` | Template YAML PackerLite personnalisé ; contourne la version macOS stockée par la VM, **obligatoire** pour une VM non-macOS. |
| `--macos-version <monterey\|ventura\|sonoma\|sequoia\|tahoe\|goldengate>` | Version macOS à utiliser pour choisir le template intégré, à la place de l'`osName` stocké par la VM. Sans effet pour Linux. |
| `--var <clé=valeur>` | Définit une variable de template (`${var.clé}`), répétable. |

`caked provision` refuse de s'exécuter si la VM tourne actuellement ou si elle a déjà été provisionnée — le premier démarrage ne se produit qu'une fois, donc relancer PackerLite sur une VM déjà provisionnée resterait bloqué à attendre des écrans qui n'apparaissent plus.

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

<a name="disk-formats-raw-and-asif-fr"></a>
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

<div class="lang-en" style="display:block" markdown="1">

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
    - `--imds-port <port>` — unprivileged port IMDS listens on, directly reachable by guests with no root needed (default `28080`). See [IMDS](imds).
  - `status` — report daemon status.
  - `stop` — stop the running daemon.
- `vmrun` — internal VM runtime command (hidden/internal).
- `import` — import external VM (Multipass or VMware Fusion) from file/URL.
- `networks` extra internal/admin subcommands:
  - `nat-infos`
  - `set-dhcp-lease`
  - `restart`
  - `run` (internal)
  - `imds-redirect` (internal, requires root) — installs/removes the `pf` address-alias redirect for `169.254.169.254`, see [IMDS](imds).

## `cakectl`-specific commands

- `certificate` — Manage certificate to authenticate API rest.

## macOS IPSW installation

`build` accepts an `.ipsw` file as the image source on Apple Silicon hosts. The installer back-end is chosen automatically based on the IPSW content.

### Back-end selection

| Guest macOS version | Back-end used | Availability |
| --- | --- | --- |
| macOS 26 or older | `VZMacOSInstaller` (system framework) | All builds |
| macOS 27 (Golden Gate) or newer | AMRestore (`AppleMobileDeviceRestore` SPI) | All builds |

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
- Requires macOS 26 or later on the **host**.

<a name="packerlite"></a>
### PackerLite: unattended provisioning (macOS and Linux)

When `build`/`create` runs with `--autoinstall`, once installation finishes, `caked` automatically drives the VM's first boot (account creation, enabling Screen Sharing/Remote Login, disabling Gatekeeper for macOS; a keystroke-driven installer for Linux) via **PackerLite** — a small built-in engine inspired by Packer's `boot_command` and its `packer-plugin-tart` plugin, with no external binary or plugin required. Without `--autoinstall`, no automatic provisioning happens.

Template resolution differs by source:

**From an `.ipsw` (macOS)** — resolved in this order, the build fails if nothing resolves:

1. **`--template <path>`** — an explicit path to a custom YAML template; wins over everything else.
2. **Automatic detection** of the macOS version from the IPSW's filename (Apple's `UniversalMac_<version>_<build>_Restore.ipsw` convention), loading the matching built-in template.
3. **`--macos-version <version>`** — if detection fails, uses the explicitly given version (`monterey`, `ventura`, `sonoma`, `sequoia`, `tahoe`, or `goldengate`) to pick the built-in template.

The detected macOS version (codename + dotted version, e.g. `sequoia` / `15.6`) is always recorded on the VM's config (`osName`/`osRelease`), whether or not `--autoinstall` was used — so a later `caked provision` run can find the right version without the original IPSW.

**From an `.iso` (Linux)** — no template ships built in. PackerLite only runs for an ISO build when `--template <path>` is given explicitly **in addition to** `--autoinstall`. Distros with their own autoinstall (Ubuntu, via cloud-init/subiquity) don't need PackerLite and keep using that existing path; PackerLite covers ISOs without native autoinstall support. In Caker.app's VM creation wizard, the "Provisioning yaml" file picker only appears for non-Ubuntu ISO sources, and blocks VM creation until a template is chosen if autoinstall is enabled.

```bash
# macOS: version auto-detected from the IPSW filename
cakectl build my-vm https://updates.cdn-apple.com/.../UniversalMac_26.6_25G72_Restore.ipsw --autoinstall

# macOS: non-standard filename, version given explicitly
cakectl build my-vm ./restore.ipsw --autoinstall --macos-version tahoe

# macOS: custom template, bypasses auto-detection entirely
cakectl build my-vm ./restore.ipsw --autoinstall --template ./my-template.packerlite.yaml

# Linux: template required for a non-Ubuntu ISO
cakectl build my-vm ./debian-13.iso --autoinstall --template ./debian.packerlite.yaml

# Extra template variables (repeatable)
cakectl build my-vm ./restore.ipsw --autoinstall --var greeting=hello
```

| Option | Description |
| --- | --- |
| `--autoinstall` | Enables automatic provisioning (required in all cases, macOS and Linux alike). |
| `--template <path>` | Custom PackerLite YAML template; bypasses auto-detection for macOS, **required** for a non-Ubuntu Linux ISO. |
| `--macos-version <monterey\|ventura\|sonoma\|sequoia\|tahoe\|goldengate>` | macOS version to use for picking the built-in template when it can't be inferred from the IPSW filename. No effect for Linux. |
| `--var <key=value>` | Sets a template variable (`${var.key}`), repeatable. |

**Account credentials**: the account provisioning creates always uses `--user`/`--password` (or the UI equivalent) — never a template-declared value. Inside a template, these are available as `${var.username}` / `${var.password}`.

**Built-in macOS templates**: five templates ship as embedded resources (`Sources/cakedlib/PackerLite/Resources/`): `monterey` (macOS 12.x), `ventura` (macOS 13.x), `sonoma` (macOS 14.x), `sequoia` (macOS 15.x, transcribed from `templates/macos/vanilla-sequoia.pkr.hcl`), and `tahoe` (macOS 26.x, transcribed from `vanilla-tahoe.pkr.hcl`). `goldengate` (macOS 27.x) is a recognized version (auto-detection and `--macos-version` both work) with no built-in template yet — provide your own with `--template` for that version. **No Linux template ships built in** — write your own for the target distro.

**Template format** — a minimal YAML file with a `boot_command` list of `title`/`command` entries using Packer's token vocabulary (`<wait10s>`, `<enter>`, `<tab>`, `<leftShiftOn>`/`<leftShiftOff>`, `<fnOn>`/`<fnOff>`, `<f1>`–`<f20>`, `<click 'On-screen text'>` — located via Vision OCR —, `<keyboard 'com.apple.keylayout.XXX'>` or `<keyboard 'current'>` to switch the keyboard layout used to translate typed characters at runtime, etc.), plus `variables:`, `create_grace_time`, and `boot_timeout`. Each entry's `title` is surfaced as a progress substep and in the logs — handy for spotting exactly where a provisioning run stalled. `${var.username}`/`${var.password}` are always injected by `caked` (see above); any other `${var.*}` comes from `variables:` or a matching `--var`.

```yaml
# my-template.packerlite.yaml — illustrative excerpt
create_grace_time: 30s   # delay after boot before the first keystroke
boot_timeout: 45m        # fail if provisioning isn't done within this long

variables:
  greeting: hello         # default value, overridable via --var greeting=...

boot_command:
  - title: Welcome screen
    command: "<wait60s><spacebar>"
  - title: Select Language
    command: "<wait30s>italiano<esc>english<enter>"
  - title: Select Your Country or Region
    command: "<wait30s><click 'Select Your Country or Region'><wait5s>united states<leftShiftOn><tab><leftShiftOff><spacebar>"
  - title: Create Account
    command: "<wait10s>${var.username}<tab>${var.password}<tab>${var.password}<tab><tab><spacebar>"
  - title: Disable Gatekeeper
    command: "<wait10s>sudo spctl --global-disable<enter>"
  - title: Confirm password
    command: "<wait10s>${var.password}<enter>"
```

See `Sources/cakedlib/PackerLite/Resources/*.packerlite.yaml` (the embedded macOS templates, with titles) and `templates/linux/*.packerlite.yaml` (reference Linux templates, not bundled: `fedora-workstation`, `centos-stream`, `rhel` — Anaconda-family installers —, `opensuse-leap` — YaST — and `debian` — debian-installer) for full, fully-commented examples.

<a name="provision"></a>
### `caked provision`: re-running provisioning standalone

`caked build`/`create` only drives PackerLite automatically when `--autoinstall` was used. For a VM (macOS or Linux) that skipped provisioning at build time — or was built before `--autoinstall` existed — `caked provision <vm>` re-runs the same automation directly against an already-built VM. It is a `caked`-only command (not currently wired through `cakectl`/gRPC) and must be run on the host where the VM's files live. It boots the VM itself with a visible window (like `vmrun`) rather than assuming it's already running, so you can watch provisioning happen, then stops it once done.

It uses the VM's own stored state instead of the original `.ipsw`/`.iso`:

- **macOS VM**: the version comes from `CakeConfig.osName` — recorded automatically on every `.ipsw` build — unless overridden with `--macos-version`; `--template` is still available to bypass this resolution entirely.
- **Non-macOS (Linux) VM**: `--template <path>` is **required** — there's no way to detect a version from an already-installed VM, so the command fails immediately if the file isn't given or doesn't exist.
- Either way, account credentials come from the VM's own `--user`/`--password` (`configuredUser`/`configuredPassword`), exactly as at build time. Once the `boot_command` finishes and an IP is obtained, `caked provision` also installs the cakeagent if needed — useful for a Linux VM that skipped cloud-init.

```bash
# Re-provision a macOS VM using its stored version and credentials
caked provision my-vm

# Override the resolved macOS version
caked provision my-vm --macos-version tahoe

# Re-provision a Linux VM (template required)
caked provision my-linux-vm --template ./debian.packerlite.yaml
```

| Option | Description |
| --- | --- |
| `--template <path>` | Custom PackerLite YAML template; overrides the VM's stored macOS version, **required** for a non-macOS VM. |
| `--macos-version <monterey\|ventura\|sonoma\|sequoia\|tahoe\|goldengate>` | macOS version to use for picking the built-in template, overriding the VM's stored `osName`. No effect for Linux. |
| `--var <key=value>` | Sets a template variable (`${var.key}`), repeatable. |

`caked provision` refuses to run if the VM is currently running or has already been provisioned — first boot only happens once, so re-running against an already-provisioned VM would just hang waiting for screens that no longer appear.

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
