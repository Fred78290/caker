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

Quand `build`/`create` est lancé avec `--autoinstall`, une fois l'installation terminée, `caked` pilote automatiquement le premier démarrage de la VM (création du compte, activation du partage d'écran/Remote Login pour macOS ; script d'installation piloté par clavier pour Linux) via **PackerLite** — un mini-moteur intégré inspiré de Packer (`boot_command`) et de son plugin `packer-plugin-tart`, mais sans dépendre d'aucun binaire ou plugin externe. Sans `--autoinstall`, aucun provisioning automatique n'a lieu.

La résolution du template diffère selon la source :

**Depuis un `.ipsw` (macOS)** — résolu dans cet ordre, le build échoue si rien n'aboutit :

1. **`--template <chemin>`** — chemin explicite vers un fichier YAML personnalisé ; prioritaire sur tout le reste.
2. **Détection automatique** de la version macOS à partir du nom de fichier de l'IPSW (convention Apple `UniversalMac_<version>_<build>_Restore.ipsw`), puis chargement du template intégré correspondant.
3. **`--macos-version <version>`** — si la détection échoue, utilise la version indiquée explicitement (`macos12`, `macos13`, `macos14`, `macos15`, `macos26` ou `macos27` ; les anciens noms marketing `monterey`/`ventura`/`sonoma`/`sequoia`/`tahoe`/`goldengate` restent acceptés en entrée par compatibilité) pour choisir le template intégré.

La version macOS détectée (identifiant + numéro, ex. `macos15` / `15.6`) est toujours enregistrée dans la configuration de la VM (`osName`/`osRelease`), que `--autoinstall` soit utilisé ou non — ce qui permet à un `caked provision` ultérieur de retrouver la bonne version sans l'IPSW d'origine.

**Depuis un `.iso` (Linux)** — résolu dans cet ordre :

1. **`--template <chemin>`** — chemin explicite vers un fichier YAML personnalisé ; prioritaire sur tout le reste.
2. **Détection automatique** de la distribution à partir du nom de fichier/URL de l'ISO, puis chargement du template intégré correspondant : `fedora`, `centos`, `redhat` (ou `rhel`), `openSUSE`, `debian`.
3. Sinon, **aucun provisioning n'a lieu** — silencieusement, ce n'est pas une erreur. C'est le comportement attendu pour Ubuntu (qui gère déjà son propre autoinstall via cloud-init/subiquity) ou toute distribution non reconnue ; fournissez votre propre `--template` pour cette dernière.

Dans l'assistant graphique de Caker.app, le sélecteur de fichier « Provisioning yaml » n'apparaît que pour les sources ISO non-Ubuntu ; il reste facultatif quand un template intégré existe pour la plateforme détectée, et devient obligatoire sinon si l'auto-configuration est activée.

```bash
# macOS : version détectée automatiquement depuis le nom du fichier IPSW
cakectl build my-vm https://updates.cdn-apple.com/.../UniversalMac_26.6_25G72_Restore.ipsw --autoinstall

# macOS : nom de fichier non standard, version précisée explicitement
cakectl build my-vm ./restore.ipsw --autoinstall --macos-version macos26

# macOS : template personnalisé, ignore toute détection
cakectl build my-vm ./restore.ipsw --autoinstall --template ./mon-template.packerlite.yaml

# Linux : distribution détectée automatiquement depuis le nom du fichier ISO (Fedora ici)
cakectl build my-vm ./Fedora-Workstation-Live-x86_64-42.iso --autoinstall

# Linux : template personnalisé, pour une distribution sans template intégré
cakectl build my-vm ./my-distro.iso --autoinstall --template ./ma-distro.packerlite.yaml

# Variables de template supplémentaires (répétable)
cakectl build my-vm ./restore.ipsw --autoinstall --var greeting=hello
```

| Option | Description |
| --- | --- |
| `--autoinstall` | Active le provisioning automatique (requis dans tous les cas, macOS comme Linux). |
| `--template <chemin>` | Template YAML PackerLite personnalisé ; contourne la détection automatique pour macOS comme pour Linux. Obligatoire uniquement si la plateforme détectée n'a pas de template intégré. |
| `--macos-version <macos12\|macos13\|macos14\|macos15\|macos26\|macos27>` | Version macOS à utiliser pour choisir le template intégré quand elle ne peut pas être déduite du nom de fichier IPSW. Les anciens noms marketing (`monterey`, `ventura`, `sonoma`, `sequoia`, `tahoe`, `goldengate`) sont toujours acceptés en entrée. Sans effet pour Linux. |
| `--var <clé=valeur>` | Définit une variable de template (`${var.clé}`), répétable. |

**Identifiants du compte** : le compte créé pendant le provisioning utilise toujours `--user`/`--password` (ou l'équivalent dans l'UI) — jamais une valeur propre au template. À l'intérieur d'un template, ces valeurs sont accessibles via `${var.username}` / `${var.password}`.

**Templates macOS intégrés** : six templates sont fournis en ressources embarquées (`Sources/cakedlib/PackerLite/Resources/`), un par version — `macos12`, `macos13`, `macos14`, `macos15` (à l'origine transcrit depuis un template Packer `vanilla-sequoia.pkr.hcl`), `macos26` (à l'origine transcrit depuis `vanilla-tahoe.pkr.hcl`) et `macos27`. Ces anciens templates Packer/Tart de référence ont depuis été retirés du dépôt — PackerLite ne dépend plus d'eux. Toutes les six versions macOS reconnues ont désormais un template intégré — `macos27` (l'ancien `goldengate`) était la dernière version encore sans template. Les identifiants de version ont été renommés depuis les noms marketing d'origine (`monterey`→`macos12`, `ventura`→`macos13`, `sonoma`→`macos14`, `sequoia`→`macos15`, `tahoe`→`macos26`, `goldengate`→`macos27`) ; les anciens noms restent acceptés comme valeur de `--macos-version` par compatibilité.

**Templates Linux intégrés** : six templates sont également fournis en ressources embarquées, sous les mêmes noms de fichiers `linux-*.packerlite.yaml` : `linux-fedora` (Fedora Workstation, Anaconda — ISO Live, sélectionné quand l'URL/nom de fichier contient « workstation » ou « desktop »), `linux-fedora-server` (Fedora Server, Anaconda — même flux qu'un ISO CentOS/RHEL, boot direct sans session live ; sélectionné par défaut sinon), `linux-centos` (CentOS Stream, Anaconda), `linux-redhat` (RHEL, Anaconda — `redhat` **et** `rhel` sont tous deux reconnus dans le nom de fichier), `linux-opensuse` (openSUSE Leap, installeur YaST) et `linux-debian` (Debian, debian-installer). **Aucun de ces six n'a été validé sur un vrai démarrage** — contrairement aux templates macOS transcrits depuis des recettes Packer fonctionnelles, ceux-ci ont seulement été relus pour leur plausibilité et testés unitairement pour leur analyse syntaxique ; attendez-vous à devoir ajuster les cibles de clic. Le template `linux-opensuse` cible l'installeur YaST (openSUSE Leap ≤ 15.6) — les ISO Leap 16.0/16.1 récemment ajoutées à `VMImages.json` utilisent le nouvel installeur Agama, non couvert par ce template ; fournissez votre propre `--template` pour ces versions en attendant. Ubuntu n'a pas de template PackerLite (utilise cloud-init/subiquity) ; toute autre distribution nécessite un `--template` personnalisé.

Certains templates Linux (`linux-{centos,debian,fedora,opensuse,redhat}.packerlite.yaml`) déclarent désormais aussi un `pre_boot_command:` optionnel, exécuté juste après le démarrage de la VM — avant qu'une IP soit disponible — pour envoyer les frappes de navigation du menu GRUB au tout début du boot, réduisant l'attente aveugle initiale à 5s (au lieu d'environ 30s).

**Format du template** — un YAML minimal avec une liste `boot_command` d'entrées `title`/`commands` (`commands` est une **liste** de fragments de tokens/texte, concaténés bout à bout — pas une seule chaîne — ce qui permet de mettre un token par ligne pour la lisibilité) reprenant le vocabulaire de tokens de Packer, plus `variables:` et `boot_timeout`. Le `title` de chaque entrée est affiché comme sous-étape de progression et dans les logs — utile pour repérer où un provisioning s'est arrêté. `${var.username}`/`${var.password}` sont toujours injectées par `caked` (voir ci-dessus) ; les autres `${var.*}` viennent de `variables:` ou d'un `--var` correspondant.

Vocabulaire de tokens pris en charge :

| Token | Description |
| --- | --- |
| `<wait10s>`, `<wait1m>`, `<wait>` | Pause avant le token suivant (secondes par défaut, `s`/`m` acceptés ; `<wait>` seul = 1 s). |
| `<enter>`, `<tab>`, `<spacebar>`, `<esc>`, etc. | Frappe d'une touche nommée. Accepte un suffixe `repeat=N` pour répéter la frappe N fois en une seule fois, ex. `<tab repeat=3>`. |
| `<f1>` – `<f20>` | Touches de fonction. |
| `<leftShiftOn>`/`<leftShiftOff>`, `<fnOn>`/`<fnOff>`, etc. | Maintien/relâchement d'une touche de modification, à englober autour d'autres tokens. |
| `<click 'Texte affiché'>` ou `<click text='...' timeout=N>` | Recherche `Texte affiché` par OCR (Vision) et clique dessus ; réessaie jusqu'à expiration du délai (10 s par défaut, `timeout=N` pour le changer). |
| `<click X,Y>` ou `<click point="X,Y">` | Clique à des coordonnées d'écran fixes (`CGPoint`), sans OCR. |
| `<locate 'Texte affiché'>` ou `<locate text='...' timeout=N>` | Attend, via OCR, que `Texte affiché` apparaisse à l'écran — **sans cliquer** ; sert de point de synchronisation avant d'enchaîner des `<tab>`/`<spacebar>` à l'aveugle, plus robuste qu'un simple `<waitNs>` quand le délai d'affichage d'un écran varie. |
| `<scroll N>` ou `<scroll horizontal=N vertical=N>` | Émet un événement de défilement (molette) à la position actuelle du curseur ; la forme `<scroll N>` ne défile que verticalement. |
| `<keyboard 'com.apple.keylayout.XXX'>` ou `<keyboard 'current'>` | Change la disposition clavier utilisée pour traduire les caractères tapés à partir de ce point. |

```yaml
# mon-template.packerlite.yaml — extrait illustratif
boot_timeout: 45m        # échec si le provisioning n'est pas terminé dans ce délai

variables:
  greeting: hello         # valeur par défaut, surchageable via --var greeting=...

boot_command:
  - title: Écran de bienvenue
    commands:
      - <wait60s>
      - <spacebar>

  - title: Sélection de la langue
    commands:
      - <wait30s>
      - italiano
      - <esc>
      - english
      - <enter>

  - title: Sélection du pays ou de la région
    commands:
      - <click timeout=30 text='Select Your Country or Region'>
      - <wait5s>
      - united states
      - <leftShiftOn>
      - <tab>
      - <leftShiftOff>
      - <spacebar>

  - title: Transfert de données (synchronisation par OCR avant de continuer)
    commands:
      - <locate timeout=30 text='Transfer Your Data to This Mac'>
      - <tab repeat=3>
      - <spacebar>

  - title: Création du compte
    commands:
      - "${var.username}"
      - <tab>
      - "${var.password}"
      - <tab>
      - "${var.password}"
      - <tab>
      - <tab>
      - <spacebar>
```

Voir `Sources/cakedlib/PackerLite/Resources/*.packerlite.yaml` (tous les templates embarqués — macOS `vanilla-*` et Linux `linux-*`, avec les titres) pour des exemples complets et entièrement commentés.

<a name="provision-fr"></a>
### `provision` : relancer le provisioning de façon autonome

`build`/`create` ne pilote PackerLite automatiquement que si `--autoinstall` a été utilisé. Pour une VM (macOS ou Linux) dont le provisioning a été sauté au moment du build — ou construite avant que `--autoinstall` n'existe — `provision <vm>` relance la même automatisation directement sur une VM déjà construite. Disponible sous deux formes :

- **`caked provision <vm>`** — exécutée localement sur l'hôte où résident les fichiers de la VM ; démarre elle-même la VM avec une fenêtre visible (comme `vmrun`) plutôt que de supposer qu'elle tourne déjà, afin que vous puissiez suivre le provisioning à l'écran sur place.
- **`cakectl provision <vm>`** — la même opération via gRPC, en flux continu (comme `build`/`launch`), pour piloter le provisioning d'une VM à distance sans être physiquement devant l'hôte qui exécute `caked`. Le contenu du template (pas juste son chemin) est envoyé au serveur, donc `--template` peut pointer vers un fichier local à la machine où tourne `cakectl`, différente de celle qui héberge la VM.

Les deux s'appuient sur l'état déjà stocké de la VM plutôt que sur l'`.ipsw`/`.iso` d'origine :

- **VM macOS** : la version provient de `CakeConfig.osName` — enregistrée automatiquement à chaque build `.ipsw` — sauf si `--macos-version` la surcharge ; `--template` reste disponible pour ignorer complètement cette résolution.
- **VM non-macOS (Linux)** : la plateforme provient de `CakeConfig.configuredPlatform` — enregistrée automatiquement à chaque build depuis une ISO — et sélectionne le même template intégré que `build` (`fedora`, `centos`, `redhat`/`rhel`, `openSUSE`, `debian`). `--template` reste disponible pour le surcharger, et devient **obligatoire** seulement si la plateforme stockée n'a pas de template intégré (Ubuntu, ou une distribution non reconnue).
- Dans tous les cas, les identifiants du compte proviennent du `--user`/`--password` propre à la VM (`configuredUser`/`configuredPassword`), exactement comme au moment du build. Une fois le `boot_command` terminé et une IP obtenue, `provision` installe aussi le cakeagent si besoin — utile pour une VM Linux qui a sauté cloud-init.

```bash
# Reprovisionner une VM macOS avec sa version et ses identifiants stockés
cakectl provision my-vm

# Forcer la version macOS résolue
cakectl provision my-vm --macos-version macos26

# Reprovisionner une VM Linux dont la plateforme stockée a un template intégré (ex. Fedora)
cakectl provision my-fedora-vm

# Reprovisionner une VM Linux sans template intégré (template obligatoire)
cakectl provision my-linux-vm --template ./ma-distro.packerlite.yaml

# Même chose localement sur l'hôte caked, sans passer par gRPC
caked provision my-vm
```

| Option | Description |
| --- | --- |
| `--template <chemin>` | Template YAML PackerLite personnalisé ; contourne la version macOS ou la plateforme Linux stockée par la VM. Obligatoire uniquement si la plateforme stockée n'a pas de template intégré. |
| `--macos-version <macos12\|macos13\|macos14\|macos15\|macos26\|macos27>` | Version macOS à utiliser pour choisir le template intégré, à la place de l'`osName` stocké par la VM. Les anciens noms marketing restent acceptés en entrée. Sans effet pour Linux. |
| `--var <clé=valeur>` | Définit une variable de template (`${var.clé}`), répétable. |

`caked provision` refuse de s'exécuter si la VM tourne actuellement ou si elle a déjà été provisionnée — le premier démarrage ne se produit qu'une fois, donc relancer PackerLite sur une VM déjà provisionnée resterait bloqué à attendre des écrans qui n'apparaissent plus.

#### Enregistrement vidéo de débogage du provisioning

Pendant toute la durée d'un provisioning PackerLite (`build`/`create --autoinstall`, ou un `provision` autonome), la VM alimente automatiquement une vidéo `.mp4` H.264 à partir des captures d'écran périodiques qu'elle prend déjà toutes les 5 secondes (le même mécanisme utilisé pour `screenshot.png`/le flux GrandCentral) — pratique pour comprendre après coup pourquoi un template `boot_command` s'est mal comporté, sans avoir eu besoin de suivre la session VNC en direct. La vidéo est écrite dans `provision.mp4` à la racine du répertoire de la VM (à côté de `screenshot.png`, `config.json`, etc.). Le format est volontairement basique — H.264 dans un conteneur `.mp4` standard, jamais de ProRes ni de HEVC/MOV propriétaire à Apple — pour être lisible partout (VLC, QuickTime, un navigateur, Windows Media Player) sans codec additionnel. Comme il ne s'agit que d'environ une image toutes les 5 secondes réelles, la vidéo n'est pas fluide — ce n'est pas l'objectif, c'est une aide au débogage, pas un enregistrement d'écran classique.

- **Provisioning réussi** : la vidéo est supprimée automatiquement, aucune trace n'est laissée sur le disque.
- **Provisioning échoué** : la vidéo est conservée, et son emplacement est ajouté au message d'erreur (`reason`) renvoyé par `caked provision`/`caked build --autoinstall` et `cakectl provision`/`cakectl build --autoinstall` — pas besoin de fouiller le système de fichiers pour la retrouver.

Cet enregistrement respecte le réglage existant de désactivation des captures d'écran (`UserDefaults` `NoScreenshot`) — s'il est actif, il n'y a aucune image source et donc aucune vidéo. Voir `Sources/cakedlib/PackerLite/ProvisioningVideoRecorder.swift` (l'enregistreur lui-même), `VirtualMachine.swift` (démarrage/alimentation de l'enregistreur depuis le minuteur de captures d'écran existant), et `VMLocation.provisioningVideoURL`.

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

When `build`/`create` runs with `--autoinstall`, once installation finishes, `caked` automatically drives the VM's first boot (account creation, enabling Screen Sharing/Remote Login for macOS; a keystroke-driven installer for Linux) via **PackerLite** — a small built-in engine inspired by Packer's `boot_command` and its `packer-plugin-tart` plugin, with no external binary or plugin required. Without `--autoinstall`, no automatic provisioning happens.

Template resolution differs by source:

**From an `.ipsw` (macOS)** — resolved in this order, the build fails if nothing resolves:

1. **`--template <path>`** — an explicit path to a custom YAML template; wins over everything else.
2. **Automatic detection** of the macOS version from the IPSW's filename (Apple's `UniversalMac_<version>_<build>_Restore.ipsw` convention), loading the matching built-in template.
3. **`--macos-version <version>`** — if detection fails, uses the explicitly given version (`macos12`, `macos13`, `macos14`, `macos15`, `macos26`, or `macos27`; the former marketing names `monterey`/`ventura`/`sonoma`/`sequoia`/`tahoe`/`goldengate` are still accepted as input for backward compatibility) to pick the built-in template.

The detected macOS version (identifier + dotted version, e.g. `macos15` / `15.6`) is always recorded on the VM's config (`osName`/`osRelease`), whether or not `--autoinstall` was used — so a later `caked provision` run can find the right version without the original IPSW.

**From an `.iso` (Linux)** — resolved in this order:

1. **`--template <path>`** — an explicit path to a custom YAML template; wins over everything else.
2. **Automatic detection** of the distro from the ISO's filename/URL, loading the matching built-in template: `fedora`, `centos`, `redhat` (or `rhel`), `openSUSE`, `debian`.
3. Otherwise, **no provisioning happens** — silently, not an error. That's the expected outcome for Ubuntu (which already handles its own autoinstall via cloud-init/subiquity) or any distro caker doesn't recognize; provide your own `--template` for the latter.

In Caker.app's VM creation wizard, the "Provisioning yaml" file picker only appears for non-Ubuntu ISO sources; it stays optional when a built-in template exists for the detected platform, and only becomes required otherwise if autoinstall is enabled.

```bash
# macOS: version auto-detected from the IPSW filename
cakectl build my-vm https://updates.cdn-apple.com/.../UniversalMac_26.6_25G72_Restore.ipsw --autoinstall

# macOS: non-standard filename, version given explicitly
cakectl build my-vm ./restore.ipsw --autoinstall --macos-version macos26

# macOS: custom template, bypasses auto-detection entirely
cakectl build my-vm ./restore.ipsw --autoinstall --template ./my-template.packerlite.yaml

# Linux: distro auto-detected from the ISO filename (Fedora here)
cakectl build my-vm ./Fedora-Workstation-Live-x86_64-42.iso --autoinstall

# Linux: custom template, for a distro with no built-in template
cakectl build my-vm ./my-distro.iso --autoinstall --template ./my-distro.packerlite.yaml

# Extra template variables (repeatable)
cakectl build my-vm ./restore.ipsw --autoinstall --var greeting=hello
```

| Option | Description |
| --- | --- |
| `--autoinstall` | Enables automatic provisioning (required in all cases, macOS and Linux alike). |
| `--template <path>` | Custom PackerLite YAML template; bypasses auto-detection for both macOS and Linux. Only required if the detected platform has no built-in template. |
| `--macos-version <macos12\|macos13\|macos14\|macos15\|macos26\|macos27>` | macOS version to use for picking the built-in template when it can't be inferred from the IPSW filename. Former marketing names (`monterey`, `ventura`, `sonoma`, `sequoia`, `tahoe`, `goldengate`) are still accepted as input. No effect for Linux. |
| `--var <key=value>` | Sets a template variable (`${var.key}`), repeatable. |

**Account credentials**: the account provisioning creates always uses `--user`/`--password` (or the UI equivalent) — never a template-declared value. Inside a template, these are available as `${var.username}` / `${var.password}`.

**Built-in macOS templates**: six templates ship as embedded resources (`Sources/cakedlib/PackerLite/Resources/`), one per version — `macos12`, `macos13`, `macos14`, `macos15` (originally transcribed from a Packer `vanilla-sequoia.pkr.hcl` template), `macos26` (originally transcribed from `vanilla-tahoe.pkr.hcl`), and `macos27`. Those legacy Packer/Tart reference templates have since been removed from the repo — PackerLite no longer depends on them. All six recognized macOS versions now have a built-in template — `macos27` (formerly `goldengate`) was the last one still missing one. Version identifiers were renamed from their original marketing names (`monterey`→`macos12`, `ventura`→`macos13`, `sonoma`→`macos14`, `sequoia`→`macos15`, `tahoe`→`macos26`, `goldengate`→`macos27`); the old names remain accepted as `--macos-version` input for backward compatibility.

**Built-in Linux templates**: six templates also ship as embedded resources, under matching `linux-*.packerlite.yaml` filenames: `linux-fedora` (Fedora Workstation, Anaconda — Live ISO, selected when the URL/filename contains "workstation" or "desktop"), `linux-fedora-server` (Fedora Server, Anaconda — same flow as a CentOS/RHEL ISO, boots straight in with no live session; selected by default otherwise), `linux-centos` (CentOS Stream, Anaconda), `linux-redhat` (RHEL, Anaconda — both `redhat` and `rhel` are recognized in the filename), `linux-opensuse` (openSUSE Leap, YaST installer), and `linux-debian` (Debian, debian-installer). **None of these six have been validated against a real boot** — unlike the macOS templates, which were transcribed from working Packer recipes, these were only reviewed for plausibility and unit-tested for parseability; expect to need to adjust click targets. `linux-opensuse` targets the YaST installer (openSUSE Leap ≤ 15.6) — the newly-added Leap 16.0/16.1 ISOs in `VMImages.json` use the new Agama installer instead, which this template doesn't cover; bring your own `--template` for those versions in the meantime. Ubuntu has no PackerLite template (uses cloud-init/subiquity instead); any other distro needs a custom `--template`.

Several Linux templates (`linux-{centos,debian,fedora,opensuse,redhat}.packerlite.yaml`) now also declare an optional `pre_boot_command:`, run immediately after the VM starts — before an IP is available — to send GRUB boot-menu keystrokes right at the start of boot, cutting the initial blind wait down to 5s (from roughly 30s).

**Template format** — a minimal YAML file with a `boot_command` list of `title`/`commands` entries (`commands` is a **list** of token/text fragments, concatenated together — not a single string — so you can put one token per line for readability) using Packer's token vocabulary, plus `variables:` and `boot_timeout`. Each entry's `title` is surfaced as a progress substep and in the logs — handy for spotting exactly where a provisioning run stalled. `${var.username}`/`${var.password}` are always injected by `caked` (see above); any other `${var.*}` comes from `variables:` or a matching `--var`.

Supported token vocabulary:

| Token | Description |
| --- | --- |
| `<wait10s>`, `<wait1m>`, `<wait>` | Pause before the next token (seconds by default, `s`/`m` accepted; bare `<wait>` = 1s). |
| `<enter>`, `<tab>`, `<spacebar>`, `<esc>`, etc. | Press a named key. Accepts a `repeat=N` suffix to press it N times in one go, e.g. `<tab repeat=3>`. |
| `<f1>` – `<f20>` | Function keys. |
| `<leftShiftOn>`/`<leftShiftOff>`, `<fnOn>`/`<fnOff>`, etc. | Hold/release a modifier key, wrapped around other tokens. |
| `<click 'On-screen text'>` or `<click text='...' timeout=N>` | Locates `On-screen text` via Vision OCR and clicks it; retries until the timeout elapses (10s by default, `timeout=N` to change it). |
| `<click X,Y>` or `<click point="X,Y">` | Clicks a fixed screen coordinate (`CGPoint`), no OCR involved. |
| `<locate 'On-screen text'>` or `<locate text='...' timeout=N>` | Waits, via OCR, for `On-screen text` to appear — **without clicking**; a synchronization point before blindly chaining `<tab>`/`<spacebar>` steps, more robust than a bare `<waitNs>` when a screen's appearance time varies. |
| `<scroll N>` or `<scroll horizontal=N vertical=N>` | Emits a scroll-wheel event at the current cursor position; `<scroll N>` scrolls vertically only. |
| `<keyboard 'com.apple.keylayout.XXX'>` or `<keyboard 'current'>` | Switches the keyboard layout used to translate typed characters from this point on. |

```yaml
# my-template.packerlite.yaml — illustrative excerpt
boot_timeout: 45m        # fail if provisioning isn't done within this long

variables:
  greeting: hello         # default value, overridable via --var greeting=...

boot_command:
  - title: Welcome screen
    commands:
      - <wait60s>
      - <spacebar>

  - title: Select Language
    commands:
      - <wait30s>
      - italiano
      - <esc>
      - english
      - <enter>

  - title: Select Your Country or Region
    commands:
      - <click timeout=30 text='Select Your Country or Region'>
      - <wait5s>
      - united states
      - <leftShiftOn>
      - <tab>
      - <leftShiftOff>
      - <spacebar>

  - title: Transfer data (OCR-synchronized before continuing)
    commands:
      - <locate timeout=30 text='Transfer Your Data to This Mac'>
      - <tab repeat=3>
      - <spacebar>

  - title: Create Account
    commands:
      - "${var.username}"
      - <tab>
      - "${var.password}"
      - <tab>
      - "${var.password}"
      - <tab>
      - <tab>
      - <spacebar>
```

See `Sources/cakedlib/PackerLite/Resources/*.packerlite.yaml` (every bundled template — macOS `vanilla-*` and Linux `linux-*`, with titles) for full, fully-commented examples.

<a name="provision"></a>
### `provision`: re-running provisioning standalone

`build`/`create` only drives PackerLite automatically when `--autoinstall` was used. For a VM (macOS or Linux) that skipped provisioning at build time — or was built before `--autoinstall` existed — `provision <vm>` re-runs the same automation directly against an already-built VM. Available two ways:

- **`caked provision <vm>`** — runs locally on the host where the VM's files live; boots the VM itself with a visible window (like `vmrun`) rather than assuming it's already running, so you can watch provisioning happen right there.
- **`cakectl provision <vm>`** — the same operation over gRPC, streamed (like `build`/`launch`), for driving provisioning on a remote VM without being physically at the `caked` host. The template's *content* (not just its path) is sent to the server, so `--template` can point at a file local to wherever `cakectl` is running, not the machine hosting the VM.

Both use the VM's own stored state instead of the original `.ipsw`/`.iso`:

- **macOS VM**: the version comes from `CakeConfig.osName` — recorded automatically on every `.ipsw` build — unless overridden with `--macos-version`; `--template` is still available to bypass this resolution entirely.
- **Non-macOS (Linux) VM**: the platform comes from `CakeConfig.configuredPlatform` — recorded automatically on every ISO build — and picks the same built-in template `build` would (`fedora`, `centos`, `redhat`/`rhel`, `openSUSE`, `debian`). `--template` is still available to override it, and only becomes **required** if the stored platform has no built-in template (Ubuntu, or an unrecognized distro).
- Either way, account credentials come from the VM's own `--user`/`--password` (`configuredUser`/`configuredPassword`), exactly as at build time. Once the `boot_command` finishes and an IP is obtained, `provision` also installs the cakeagent if needed — useful for a Linux VM that skipped cloud-init.

```bash
# Re-provision a macOS VM using its stored version and credentials
cakectl provision my-vm

# Override the resolved macOS version
cakectl provision my-vm --macos-version macos26

# Re-provision a Linux VM whose stored platform has a built-in template (e.g. Fedora)
cakectl provision my-fedora-vm

# Re-provision a Linux VM with no built-in template (template required)
cakectl provision my-linux-vm --template ./my-distro.packerlite.yaml

# The same thing run locally on the caked host, without going through gRPC
caked provision my-vm
```

| Option | Description |
| --- | --- |
| `--template <path>` | Custom PackerLite YAML template; overrides the VM's stored macOS version or Linux platform. Only required if the stored platform has no built-in template. |
| `--macos-version <macos12\|macos13\|macos14\|macos15\|macos26\|macos27>` | macOS version to use for picking the built-in template, overriding the VM's stored `osName`. Former marketing names are still accepted as input. No effect for Linux. |
| `--var <key=value>` | Sets a template variable (`${var.key}`), repeatable. |

`caked provision` refuses to run if the VM is currently running or has already been provisioned — first boot only happens once, so re-running against an already-provisioned VM would just hang waiting for screens that no longer appear.

#### Provisioning debug video recording

For the whole duration of any PackerLite provisioning run (`build`/`create --autoinstall`, or a standalone `provision`), the VM automatically feeds an H.264 `.mp4` recording from the periodic screenshots it already takes every 5 seconds (the same mechanism behind `screenshot.png`/the GrandCentral stream) — handy for figuring out after the fact why a `boot_command` template misbehaved, without having had to watch the live VNC session. The video is written to `provision.mp4` at the root of the VM's directory (alongside `screenshot.png`, `config.json`, etc). The format is deliberately plain — standard H.264 inside a regular `.mp4` container, never ProRes or Apple-only HEVC-in-MOV — so it plays anywhere (VLC, QuickTime, a browser, Windows Media Player) with no extra codec needed. Since it's only about one frame every 5 real seconds, the video isn't smooth — that's expected, it's a debugging aid, not a screen recording.

- **Provisioning succeeds**: the video is deleted automatically, nothing is left on disk.
- **Provisioning fails**: the video is kept, and its location is appended to the failure `reason` returned by `caked provision`/`caked build --autoinstall` and `cakectl provision`/`cakectl build --autoinstall` — no need to go hunting for it on the filesystem.

This recording honors the existing screenshot opt-out (`UserDefaults`'s `NoScreenshot`) — if it's set, there's no frame source and therefore no video either. See `Sources/cakedlib/PackerLite/ProvisioningVideoRecorder.swift` (the recorder itself), `VirtualMachine.swift` (starting/feeding the recorder off the existing screenshot timer), and `VMLocation.provisioningVideoURL`.

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
