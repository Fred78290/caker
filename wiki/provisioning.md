<!-- markdownlint-disable MD033 MD024 -->

<div class="lang-fr" style="display:none" markdown="1">

# Provisioning automatisé et enregistrement (PackerLite)

Caker automatise le premier démarrage d'une VM fraîchement installée — création du compte, activation du partage d'écran pour macOS, ou un installeur Linux piloté au clavier — via **PackerLite**, un mini-moteur intégré inspiré du `boot_command` de HashiCorp Packer et de son plugin `packer-plugin-tart`, mais sans dépendre d'aucun binaire ou plugin externe. Cette page couvre les trois façons d'interagir avec lui :

- **[`--autoinstall`](#autoinstall-fr)** — provisioning automatique au moment du `build`/`create`.
- **[`provision`](#provision-fr)** — relance le provisioning sur une VM déjà construite.
- **[`record`](#record-fr)** — enregistre une session manuelle pour produire un template au lieu de l'écrire à la main.

Pour la sélection d'image par catalogue (`--alias`/`aliases`), voir la section correspondante de [Command Summary](command-summary#alias-fr).

<a name="autoinstall-fr"></a>
## Provisioning automatique avec `--autoinstall`

Quand `build`/`create` est lancé avec `--autoinstall`, une fois l'installation terminée, `caked` pilote automatiquement le premier démarrage de la VM. Sans `--autoinstall`, aucun provisioning automatique n'a lieu.

### Résolution du template

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

**Variables de provisioning mémorisées** : `--var` (en CLI, `caked build`/`provision` et `cakectl build`/`provision`) et l'éditeur « Provisioning variables » du wizard de création de VM de Caker.app (affiché sous le sélecteur d'image ISO/IPSW) partagent le même magasin persistant, `<CAKE_HOME>/ProvisionVariables.json` — toute variable ajoutée d'un côté est automatiquement disponible de l'autre, sans avoir à la ressaisir à chaque VM. Ces variables mémorisées sont préfixées avant celles passées explicitement sur la ligne de commande, ce qui leur donne une priorité **plus faible** : un `--var clé=valeur` explicite l'emporte toujours sur une valeur mémorisée du même nom. Les noms/valeurs ne peuvent pas contenir `=` ni `|`.

### Templates intégrés

**macOS** : six templates sont fournis en ressources embarquées (`Sources/cakedlib/PackerLite/Resources/`), un par version — `macos12`, `macos13`, `macos14`, `macos15` (à l'origine transcrit depuis un template Packer `vanilla-sequoia.pkr.hcl`), `macos26` (à l'origine transcrit depuis `vanilla-tahoe.pkr.hcl`) et `macos27`. Ces anciens templates Packer/Tart de référence ont depuis été retirés du dépôt — PackerLite ne dépend plus d'eux. Toutes les six versions macOS reconnues ont désormais un template intégré. Les identifiants de version ont été renommés depuis les noms marketing d'origine (`monterey`→`macos12`, `ventura`→`macos13`, `sonoma`→`macos14`, `sequoia`→`macos15`, `tahoe`→`macos26`, `goldengate`→`macos27`) ; les anciens noms restent acceptés comme valeur de `--macos-version` par compatibilité.

**Linux** : neuf templates sont également fournis en ressources embarquées, sous les mêmes noms de fichiers `linux-*.packerlite.yaml` : `linux-fedora` (Fedora Workstation, Anaconda — ISO Live, sélectionné quand l'URL/nom de fichier contient « workstation » ou « desktop »), `linux-fedora-server` (Fedora Server, Anaconda — même flux qu'un ISO CentOS/RHEL, boot direct sans session live ; sélectionné par défaut sinon), `linux-centos` (CentOS Stream, Anaconda), `linux-redhat` (RHEL, Anaconda — `redhat` **et** `rhel` sont tous deux reconnus dans le nom de fichier), `linux-opensuse` (openSUSE Leap, installeur YaST), `linux-debian` (Debian, debian-installer), `linux-alpine` (Alpine, `setup-alpine`), et `linux-ubuntu`/`linux-ubuntu-server` (Ubuntu Desktop et Server). La plupart ont depuis été réécrits pour utiliser une navigation synchronisée par OCR (`<locate>`) plutôt que des clics/délais fixes, au fil de plusieurs passes de correction visant explicitement à coller à ce que l'installeur affiche réellement — contrairement à leur état d'origine (relu pour la plausibilité seulement), cela suppose une itération contre de vrais démarrages, même si aucun commit ne revendique une validation de bout en bout complète ; attendez-vous malgré tout à devoir ajuster ponctuellement des cibles de clic. Le template `linux-opensuse` cible l'installeur YaST (openSUSE Leap ≤ 15.6) — les ISO Leap 16.0/16.1 récemment ajoutées à `VMImages.json` utilisent le nouvel installeur Agama, non couvert par ce template ; fournissez votre propre `--template` pour ces versions en attendant. Ubuntu conserve aussi son propre mécanisme d'installation automatisée natif (cloud-init/subiquity, via l'option de démarrage « autoinstall ») — les templates `linux-ubuntu*` sont une alternative optionnelle qui passe par la même approche PackerLite pilotée par OCR que toutes les autres distributions ; contrairement aux autres templates Linux embarqués, leur `boot_command` ne saisit pas les identifiants du compte, il se contente de naviguer le menu GRUB et le clavier puis d'attendre que le flux « autoinstall » natif d'Ubuntu se termine de lui-même. Toute autre distribution nécessite un `--template` personnalisé.

Certains templates Linux (`linux-{centos,debian,fedora,opensuse,redhat}.packerlite.yaml`) déclarent désormais aussi un `pre_boot_command:` optionnel, exécuté juste après le démarrage de la VM — avant qu'une IP soit disponible — pour envoyer les frappes de navigation du menu GRUB au tout début du boot, réduisant l'attente aveugle initiale à 5s (au lieu d'environ 30s).

### Format du template et vocabulaire de tokens

Un template est un YAML minimal avec une liste `boot_command` d'entrées `title`/`commands` (`commands` est une **liste** de fragments de tokens/texte, concaténés bout à bout — pas une seule chaîne — ce qui permet de mettre un token par ligne pour la lisibilité), plus `variables:` et `boot_timeout`. Le `title` de chaque entrée est affiché comme sous-étape de progression et dans les logs — utile pour repérer où un provisioning s'est arrêté. `${var.username}`/`${var.password}` sont toujours injectées par `caked` ; les autres `${var.*}` viennent de `variables:` ou d'un `--var` correspondant.

| Token | Description |
| --- | --- |
| `<wait10s>`, `<wait1m>`, `<wait>` | Pause avant le token suivant (secondes par défaut, `s`/`m` acceptés ; `<wait>` seul = 1 s). |
| `<enter>`, `<tab>`, `<spacebar>`, `<esc>`, etc. | Frappe d'une touche nommée. Accepte un suffixe `repeat=N` pour répéter la frappe N fois en une seule fois, ex. `<tab repeat=3>`. |
| `<f1>` – `<f20>` | Touches de fonction. |
| `<leftShiftOn>`/`<leftShiftOff>`, `<fnOn>`/`<fnOff>`, etc. | Maintien/relâchement d'une touche de modification, à englober autour d'autres tokens. |
| `<click 'Texte affiché'>` ou `<click text='...' timeout=N>` | Recherche `Texte affiché` par OCR (Vision) et clique dessus ; réessaie jusqu'à expiration du délai (10 s par défaut, `timeout=N` pour le changer). |
| `<click X,Y>` ou `<click point="X,Y">` | Clique à des coordonnées d'écran fixes (`CGPoint`), sans OCR. |
| `<locate 'Texte affiché'>` ou `<locate text='...' timeout=N>` | Attend, via OCR, que `Texte affiché` apparaisse à l'écran — **sans cliquer** ; sert de point de synchronisation avant d'enchaîner des `<tab>`/`<spacebar>` à l'aveugle, plus robuste qu'un simple `<waitNs>` quand le délai d'affichage d'un écran varie. |
| `<skipCommandIfNotFound text='...' timeout=N>` ou `<skipCommandIfNotFound 'Texte affiché'>` | Attend, via OCR, que le texte apparaisse dans le délai imparti (10 s par défaut) ; s'il n'apparaît jamais, abandonne le reste des étapes du bloc `title` courant et passe à l'entrée `boot_command` suivante, au lieu de lever une erreur. Utile pour un écran qui n'apparaît que parfois (ex. une étape dépendant de la langue). |
| `<skipStepIfNotFound text='...' steps=N timeout=N>` | Comme `<skipCommandIfNotFound>`, mais au lieu d'abandonner le reste du bloc `title` courant si le texte n'apparaît pas dans le délai, saute exactement les `N` étapes suivantes (par défaut 1) puis continue normalement. Plus précis que `<skipCommandIfNotFound>` quand seules quelques étapes d'un écran sont conditionnelles. |
| `<scroll N>` ou `<scroll horizontal=N vertical=N>` | Émet un événement de défilement (molette) à la position actuelle du curseur ; la forme `<scroll N>` ne défile que verticalement. |
| `<keyboard 'com.apple.keylayout.XXX'>` ou `<keyboard 'current'>` | Change la disposition clavier utilisée pour traduire les caractères tapés à partir de ce point. |
| `<voiceOverOn>` ou `<voiceOverOn confirm=true>` | Active VoiceOver (macOS uniquement) via la séquence de touches habituelle (Option+Fn+F5) ; `confirm=true` tape aussi « v » ensuite, pour la boîte de dialogue « Utiliser VoiceOver ? » qui n'apparaît qu'à la toute première activation sur une installation neuve. |
| `<voiceOverOff>` | Désactive VoiceOver (même séquence de touches). |

`<click text=...>`, `<locate>`, `<skipCommandIfNotFound>` et `<skipStepIfNotFound>` acceptent aussi une liste d'alternatives séparées par `|` dans `text=`, ex. `text="Accept|Continue"` — l'étape correspond si l'une des deux chaînes est reconnue à l'écran, utile pour un texte dont le libellé varie selon la version/la langue de l'installeur.

En plus de `boot_command`/`pre_boot_command`, un template peut déclarer `ignore_ip: true` : le provisioning n'attend alors jamais d'adresse IP pour la VM, ni avant ni après `boot_command` — utile pour un `boot_command` qui n'a de toute façon pas besoin du réseau, ou pour un invité dont le DHCP est trop lent/peu fiable pour valoir l'attente. Effet de bord : une VM avec `ignore_ip: true` ne reçoit pas non plus l'installation automatique du cakeagent en fin de provisioning, puisque celle-ci dépend elle-même d'avoir une IP.

`install_agent: false` a le même effet ciblé sur l'agent seul, sans toucher à l'attente d'IP — utile pour un invité où le cakeagent n'a pas de sens.

`required_variables: [nom1, nom2, ...]` déclare des variables que le template exige : si l'une d'elles manque au moment de la résolution (ni fournie via `--var`, ni via l'éditeur de variables du wizard, ni via les variables intégrées ci-dessous), le provisioning échoue immédiatement avec un message d'erreur explicite plutôt que de substituer silencieusement une chaîne vide. Le template `linux-redhat` l'utilise pour `redhat_username`/`redhat_password` — les identifiants de souscription Red Hat nécessaires à l'enregistrement du système, distincts du compte `--user`/`--password` de la VM.

Outre `${var.username}`/`${var.password}`, deux variables intégrées supplémentaires sont désormais toujours disponibles : `${var.hostname}` (le nom de la VM) et `${var.ssh_authorized_key}` (la ou les clé(s) SSH publique(s) configurée(s), absente si aucune n'est configurée).

`post_boot_command: [commande1, commande2, ...]` déclare une liste de commandes shell exécutées via SSH une fois l'étape d'installation de l'agent terminée (que `install_agent` ait tourné ou non), pratique pour configurer la VM après l'installation — installer des paquets, écrire des fichiers de configuration, lancer un script — sans avoir à le faire via les frappes clavier de `boot_command`. L'exécution s'arrête à la première commande en échec. Comme `boot_command`/`pre_boot_command`, les commandes acceptent la même substitution `${var.*}`.

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
## `provision` : relancer le provisioning de façon autonome

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

### Enregistrement vidéo de débogage du provisioning

Pendant toute la durée d'un provisioning PackerLite (`build`/`create --autoinstall`, ou un `provision` autonome), la VM alimente automatiquement une vidéo `.mp4` H.264 à partir des captures d'écran périodiques qu'elle prend déjà toutes les 5 secondes (le même mécanisme utilisé pour `screenshot.png`/le flux GrandCentral) — pratique pour comprendre après coup pourquoi un template `boot_command` s'est mal comporté, sans avoir eu besoin de suivre la session VNC en direct. La vidéo est écrite dans `provision.mp4` à la racine du répertoire de la VM (à côté de `screenshot.png`, `config.json`, etc.). Le format est volontairement basique — H.264 dans un conteneur `.mp4` standard, jamais de ProRes ni de HEVC/MOV propriétaire à Apple — pour être lisible partout (VLC, QuickTime, un navigateur, Windows Media Player) sans codec additionnel. Comme il ne s'agit que d'environ une image toutes les 5 secondes réelles, la vidéo n'est pas fluide — ce n'est pas l'objectif, c'est une aide au débogage, pas un enregistrement d'écran classique.

- **Provisioning réussi** : la vidéo est supprimée automatiquement, aucune trace n'est laissée sur le disque.
- **Provisioning échoué** : la vidéo est conservée, et son emplacement est ajouté au message d'erreur (`reason`) renvoyé par `caked provision`/`caked build --autoinstall` et `cakectl provision`/`cakectl build --autoinstall` — pas besoin de fouiller le système de fichiers pour la retrouver.

Cet enregistrement respecte le réglage existant de désactivation des captures d'écran (`UserDefaults` `NoScreenshot`) — s'il est actif, il n'y a aucune image source et donc aucune vidéo. Voir `Sources/cakedlib/PackerLite/ProvisioningVideoRecorder.swift` (l'enregistreur lui-même), `VirtualMachine.swift` (démarrage/alimentation de l'enregistreur depuis le minuteur de captures d'écran existant), et `VMLocation.provisioningVideoURL`.

<a name="record-fr"></a>
## `record` : enregistrer un template `boot_command` à la main

Écrire un template `boot_command` à la main revient à deviner des coordonnées et des délais, puis à itérer contre un vrai démarrage. `caked record <vm>` fait l'inverse : elle démarre `<vm>` (déjà construite, mais **pas** encore démarrée — typiquement une VM créée sans `--autoinstall`, donc arrêtée sur son écran de premier démarrage), ouvre une fenêtre locale, et enregistre chaque clic et chaque frappe que vous effectuez à la main à travers cette fenêtre. Appuyez sur `Ctrl-C` dans le terminal pour arrêter l'enregistrement : le template `boot_command` correspondant est alors écrit sur disque.

Cette capture se fait directement sur les événements `NSEvent` natifs de la fenêtre locale de la VM (`VNCVirtualMachineView.actionRecorder`) — aucun serveur VNC n'est démarré et aucun port réseau n'est ouvert. C'est délibérément plus simple et plus direct que l'ancienne approche par interception d'un serveur VNC (toujours utilisée par `caked provision`) : pas d'aller-retour par un keysym protocole VNC, juste les événements que macOS délivre déjà à la fenêtre. La contrepartie est que cette capture ne peut être pilotée que par un opérateur assis devant cette machine — contrairement à `caked provision`, elle ne peut pas être pilotée par un client VNC distant.

```bash
# Enregistrer une session dans le fichier par défaut (record.packerlite.yaml, dans le répertoire de la VM)
caked record my-vm

# Choisir un autre emplacement de sortie
caked record my-vm --output ./mon-template.packerlite.yaml
```

**Disponible uniquement en local (`caked record`) pour l'instant** — pas encore d'équivalent `cakectl`/gRPC, comme `caked provision` à ses débuts. `Scripts/record.sh` automatise les étapes manuelles habituelles d'une session d'enregistrement (supprime toute VM homonyme existante, duplique le template `vanilla`, lance `caked record` avec la journalisation de débogage et le bon chemin de sortie).

**Caker.app** offre aussi cet enregistrement, directement dans la fenêtre de la VM (pour une VM lancée dans l'app, pas externe/distante) — le bouton « Record » de la barre d'outils, avec les mêmes contrôles mode repérage/Reset/VoiceOver décrits ci-dessous, sans avoir besoin de la ligne de commande.

### Pendant l'enregistrement

- **Pause/reprise** : la fenêtre d'enregistrement affiche un bouton dans sa barre d'outils — « Recording » (pulsant) pendant l'enregistrement, cliquez pour mettre en pause ; « Paused » pendant la pause, cliquez pour reprendre. La pause suspend uniquement la capture des actions, la VM continue de tourner. `Ctrl-C` reste le seul moyen d'arrêter réellement l'enregistrement et d'écrire le fichier, à tout moment, pause ou non.
- **Clics assistés par OCR** : un bouton « mode repérage » dans la barre d'outils de la fenêtre d'enregistrement fait apparaître un surlignage bleu sur chaque texte reconnu à l'écran (reconnaissance Vision). Une fois ce mode activé, le **bouton gauche** de la souris sur une zone surlignée enregistre un token `<clickText text='...'>`, et le **bouton droit** sur une zone surlignée enregistre un token `<locate text='...'>` — les deux à la place d'un `<click point="X,Y">` basé sur des coordonnées fixes, un ancrage qui résiste mieux à un léger décalage de mise en page qu'une coordonnée brute. Un clic gauche en dehors de toute zone surlignée (ou avec le mode repérage désactivé) enregistre toujours un `<click point="X,Y">` classique ; un clic droit en dehors de toute zone surlignée n'enregistre rien du tout (contrairement au bouton gauche, il n'existe pas de repli en coordonnées pour le bouton droit, car `<locate>` n'a de sens que comme ancre OCR). Ce mode s'active explicitement via le bouton — jamais en maintenant une touche enfoncée — pour ne jamais entrer en conflit avec de vrais raccourcis macOS que vous pourriez avoir besoin d'enregistrer tels quels (par ex. Fn+F5 pour VoiceOver).
- **Bouton VoiceOver** (VM macOS uniquement — masqué pour les VM Linux) : bascule VoiceOver et enregistre un token `<voiceOverOn>`/`<voiceOverOff>` (voir le tableau des tokens ci-dessus) plutôt que la séquence de touches brute. Un clic simple enregistre une bascule non confirmée ; **Option+clic** enregistre une bascule confirmée (`confirm=true`), pour la boîte de dialogue « Utiliser VoiceOver ? » qui n'apparaît qu'à la toute première activation.
- **Délais avant `<clickText>`/`<locate>` repliés dans leur propre `timeout=`** : pour tout autre type d'étape, une pause ≥1s avant l'action suivante devient un `<waitNs>` séparé. Mais `<clickText>`/`<locate>` attendent déjà, via OCR, que leur texte apparaisse (jusqu'à expiration d'un `timeout=`) plutôt que de s'exécuter à l'aveugle — un `<waitNs>` séparé devant l'un de ces deux tokens serait donc redondant. L'enregistreur reporte à la place la pause mesurée (arrondie à la seconde, plus 10s de marge pour la latence de reconnaissance/rendu OCR) directement dans le `timeout=` du token, par ex. `<locate text='...' timeout=13>` pour une pause de 3,4s. Une pause sous le seuil d'1s ne force aucun `timeout=` : la valeur par défaut du parseur (10s) s'applique alors normalement.
- **VMs Linux** : la première action enregistrée est automatiquement placée dans `pre_boot_command:` plutôt que `boot_command:` (utile pour une frappe de navigation GRUB avant que l'installeur n'ait une IP) — les VMs macOS n'ont pas ce champ. Ceci reste une heuristique grossière : vérifiez la coupure `pre_boot_command`/`boot_command` du fichier généré, elle peut avoir besoin d'un ajustement manuel.

### Ce qui est produit

**Le résultat est un premier jet, pas un template fiable clé en main** : les clics deviennent des tokens `<click point="X,Y">`, le texte tapé est coalescé en une seule ligne par plage continue de frappes, les touches spéciales et les modificateurs (`<enter>`, `<tab>`, `<leftShiftOn>`/`<leftShiftOff>`, etc.) utilisent le même vocabulaire de tokens que les templates écrits à la main — mais les pauses entre les actions deviennent des `<waitNs>` à délai fixe (sauf devant `<clickText>`/`<locate>`, voir ci-dessus). Ce projet s'est justement éloigné des délais fixes au profit d'ancres `<locate>` synchronisées par OCR, précisément parce que les délais fixes sont peu fiables (voir la section provisioning ci-dessus) — considérez le résultat comme un point de départ à renforcer avec des ancres `<locate>` avant de vous y fier pour un `--autoinstall` non surveillé.

Les identifiants du compte (`--user`/`--password` de la VM) ne sont jamais écrits en clair dans le fichier : un texte enregistré qui correspond exactement au nom d'utilisateur ou au mot de passe configuré de la VM est automatiquement remplacé par `${var.username}`/`${var.password}`.

</div>

<div class="lang-en" style="display:block" markdown="1">

# Automated Provisioning and Recording (PackerLite)

Caker automates a freshly-installed VM's first boot — account creation, enabling Screen Sharing for macOS, or a keystroke-driven Linux installer — via **PackerLite**, a small built-in engine inspired by HashiCorp Packer's `boot_command` and its `packer-plugin-tart` plugin, with no external binary or plugin required. This page covers the three ways to interact with it:

- **[`--autoinstall`](#autoinstall)** — automatic provisioning at `build`/`create` time.
- **[`provision`](#provision)** — re-runs provisioning on an already-built VM.
- **[`record`](#record)** — records a manual session to produce a template instead of writing one by hand.

For catalog-based image selection (`--alias`/`aliases`), see the corresponding section of [Command Summary](command-summary#alias).

<a name="autoinstall"></a>
## Automatic provisioning with `--autoinstall`

When `build`/`create` runs with `--autoinstall`, once installation finishes, `caked` automatically drives the VM's first boot. Without `--autoinstall`, no automatic provisioning happens.

### Template resolution

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

**Stored provisioning variables**: `--var` (on the CLI — `caked build`/`provision` and `cakectl build`/`provision`) and Caker.app's VM creation wizard "Provisioning variables" editor (shown below the ISO/IPSW image picker) share the same persistent store, `<CAKE_HOME>/ProvisionVariables.json` — a variable added on either side is automatically available on the other, without re-entering it per VM. Stored variables are prepended before anything passed explicitly on the command line, giving them **lower** precedence: an explicit `--var key=value` always wins over a same-named stored value. Names/values can't contain `=` or `|`.

### Built-in templates

**macOS**: six templates ship as embedded resources (`Sources/cakedlib/PackerLite/Resources/`), one per version — `macos12`, `macos13`, `macos14`, `macos15` (originally transcribed from a Packer `vanilla-sequoia.pkr.hcl` template), `macos26` (originally transcribed from `vanilla-tahoe.pkr.hcl`), and `macos27`. Those legacy Packer/Tart reference templates have since been removed from the repo — PackerLite no longer depends on them. All six recognized macOS versions now have a built-in template. Version identifiers were renamed from their original marketing names (`monterey`→`macos12`, `ventura`→`macos13`, `sonoma`→`macos14`, `sequoia`→`macos15`, `tahoe`→`macos26`, `goldengate`→`macos27`); the old names remain accepted as `--macos-version` input for backward compatibility.

**Linux**: nine templates also ship as embedded resources, under matching `linux-*.packerlite.yaml` filenames: `linux-fedora` (Fedora Workstation, Anaconda — Live ISO, selected when the URL/filename contains "workstation" or "desktop"), `linux-fedora-server` (Fedora Server, Anaconda — same flow as a CentOS/RHEL ISO, boots straight in with no live session; selected by default otherwise), `linux-centos` (CentOS Stream, Anaconda), `linux-redhat` (RHEL, Anaconda — both `redhat` and `rhel` are recognized in the filename), `linux-opensuse` (openSUSE Leap, YaST installer), `linux-debian` (Debian, debian-installer), `linux-alpine` (Alpine, `setup-alpine`), and `linux-ubuntu`/`linux-ubuntu-server` (Ubuntu Desktop and Server). Most have since been rewritten to use OCR-synchronized (`<locate>`) navigation instead of fixed clicks/delays, across several fix passes explicitly aimed at matching what the real installer actually shows — unlike their original "reviewed for plausibility only" state, that implies iteration against real boots, though no commit claims full end-to-end validation; still expect to need to nudge the occasional click target. `linux-opensuse` targets the YaST installer (openSUSE Leap ≤ 15.6) — the newly-added Leap 16.0/16.1 ISOs in `VMImages.json` use the new Agama installer instead, which this template doesn't cover; bring your own `--template` for those versions in the meantime. Ubuntu also still has its own native unattended-install mechanism (cloud-init/subiquity, via the "autoinstall" boot option) — the `linux-ubuntu*` templates are an optional alternative that goes through the same OCR-driven PackerLite approach every other distro here uses; unlike the other bundled Linux templates, their `boot_command` never types the account credentials, it just navigates the GRUB menu and keyboard layout, then waits for Ubuntu's own autoinstall flow to finish on its own. Any other distro needs a custom `--template`.

Several Linux templates (`linux-{centos,debian,fedora,opensuse,redhat}.packerlite.yaml`) now also declare an optional `pre_boot_command:`, run immediately after the VM starts — before an IP is available — to send GRUB boot-menu keystrokes right at the start of boot, cutting the initial blind wait down to 5s (from roughly 30s).

### Template format and token vocabulary

A template is a minimal YAML file with a `boot_command` list of `title`/`commands` entries (`commands` is a **list** of token/text fragments, concatenated together — not a single string — so you can put one token per line for readability), plus `variables:` and `boot_timeout`. Each entry's `title` is surfaced as a progress substep and in the logs — handy for spotting exactly where a provisioning run stalled. `${var.username}`/`${var.password}` are always injected by `caked`; any other `${var.*}` comes from `variables:` or a matching `--var`.

| Token | Description |
| --- | --- |
| `<wait10s>`, `<wait1m>`, `<wait>` | Pause before the next token (seconds by default, `s`/`m` accepted; bare `<wait>` = 1s). |
| `<enter>`, `<tab>`, `<spacebar>`, `<esc>`, etc. | Press a named key. Accepts a `repeat=N` suffix to press it N times in one go, e.g. `<tab repeat=3>`. |
| `<f1>` – `<f20>` | Function keys. |
| `<leftShiftOn>`/`<leftShiftOff>`, `<fnOn>`/`<fnOff>`, etc. | Hold/release a modifier key, wrapped around other tokens. |
| `<click 'On-screen text'>` or `<click text='...' timeout=N>` | Locates `On-screen text` via Vision OCR and clicks it; retries until the timeout elapses (10s by default, `timeout=N` to change it). |
| `<click X,Y>` or `<click point="X,Y">` | Clicks a fixed screen coordinate (`CGPoint`), no OCR involved. |
| `<locate 'On-screen text'>` or `<locate text='...' timeout=N>` | Waits, via OCR, for `On-screen text` to appear — **without clicking**; a synchronization point before blindly chaining `<tab>`/`<spacebar>` steps, more robust than a bare `<waitNs>` when a screen's appearance time varies. |
| `<skipCommandIfNotFound text='...' timeout=N>` or `<skipCommandIfNotFound 'On-screen text'>` | Polls via OCR for the text to appear within `timeout` seconds (10s default); if it never does, abandons the rest of the steps in the current `title` block and moves on to the next `boot_command` entry, instead of throwing. Useful for a screen that only sometimes appears (e.g. a locale-dependent step). |
| `<skipStepIfNotFound text='...' steps=N timeout=N>` | Like `<skipCommandIfNotFound>`, but instead of abandoning the rest of the current `title` block when the text isn't found in time, skips exactly the next `N` steps (default 1) and then continues normally. More precise than `<skipCommandIfNotFound>` when only a couple of a screen's steps are conditional. |
| `<scroll N>` or `<scroll horizontal=N vertical=N>` | Emits a scroll-wheel event at the current cursor position; `<scroll N>` scrolls vertically only. |
| `<keyboard 'com.apple.keylayout.XXX'>` or `<keyboard 'current'>` | Switches the keyboard layout used to translate typed characters from this point on. |
| `<voiceOverOn>` or `<voiceOverOn confirm=true>` | Turns VoiceOver on (macOS only) via the usual key sequence (Option+Fn+F5); `confirm=true` also types "v" afterward, for the "Use VoiceOver?" dialog that only appears the very first time it's enabled on a fresh install. |
| `<voiceOverOff>` | Turns VoiceOver off (same key sequence). |

`<click text=...>`, `<locate>`, `<skipCommandIfNotFound>`, and `<skipStepIfNotFound>` all also accept a pipe-delimited list of alternatives in `text=`, e.g. `text="Accept|Continue"` — the step matches if either string is recognized on screen, useful for wording that varies across installer versions/locales.

Besides `boot_command`/`pre_boot_command`, a template can declare `ignore_ip: true`: provisioning then never waits for the VM's IP address, either before or after `boot_command`. Useful for a `boot_command` that doesn't need the network anyway, or a guest whose DHCP is too slow/unreliable to be worth waiting on. Side effect: a VM with `ignore_ip: true` also skips the automatic cakeagent install at the end of provisioning, since that step itself depends on having an IP.

`install_agent: false` has the same targeted effect on the agent alone, without touching the IP wait — useful for a guest where the cakeagent doesn't make sense.

`required_variables: [name1, name2, ...]` declares variables the template requires: if any of them is missing at resolve time (not supplied via `--var`, the wizard's variable editor, or the built-in variables below), provisioning fails immediately with a clear error instead of silently substituting an empty string. The `linux-redhat` template uses this for `redhat_username`/`redhat_password` — the Red Hat subscription credentials needed to register the system, distinct from the VM's own `--user`/`--password` account.

Beyond `${var.username}`/`${var.password}`, two more built-in variables are now always available: `${var.hostname}` (the VM's own name) and `${var.ssh_authorized_key}` (the configured SSH public key(s), absent if none are configured).

`post_boot_command: [command1, command2, ...]` declares a list of shell commands run over SSH once the agent-install step has finished (whether or not `install_agent` actually ran) — handy for configuring the VM after install, such as installing packages, writing config files, or running a setup script, without having to drive it through `boot_command`'s keystrokes. Execution stops at the first command that fails. Like `boot_command`/`pre_boot_command`, these commands support the same `${var.*}` substitution.

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
## `provision`: re-running provisioning standalone

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

### Provisioning debug video recording

For the whole duration of any PackerLite provisioning run (`build`/`create --autoinstall`, or a standalone `provision`), the VM automatically feeds an H.264 `.mp4` recording from the periodic screenshots it already takes every 5 seconds (the same mechanism behind `screenshot.png`/the GrandCentral stream) — handy for figuring out after the fact why a `boot_command` template misbehaved, without having had to watch the live VNC session. The video is written to `provision.mp4` at the root of the VM's directory (alongside `screenshot.png`, `config.json`, etc). The format is deliberately plain — standard H.264 inside a regular `.mp4` container, never ProRes or Apple-only HEVC-in-MOV — so it plays anywhere (VLC, QuickTime, a browser, Windows Media Player) with no extra codec needed. Since it's only about one frame every 5 real seconds, the video isn't smooth — that's expected, it's a debugging aid, not a screen recording.

- **Provisioning succeeds**: the video is deleted automatically, nothing is left on disk.
- **Provisioning fails**: the video is kept, and its location is appended to the failure `reason` returned by `caked provision`/`caked build --autoinstall` and `cakectl provision`/`cakectl build --autoinstall` — no need to go hunting for it on the filesystem.

This recording honors the existing screenshot opt-out (`UserDefaults`'s `NoScreenshot`) — if it's set, there's no frame source and therefore no video either. See `Sources/cakedlib/PackerLite/ProvisioningVideoRecorder.swift` (the recorder itself), `VirtualMachine.swift` (starting/feeding the recorder off the existing screenshot timer), and `VMLocation.provisioningVideoURL`.

<a name="record"></a>
## `record`: recording a `boot_command` template by hand

Writing a `boot_command` template by hand means guessing coordinates and timing, then iterating against a real boot. `caked record <vm>` does the reverse: it boots `<vm>` (already built, but **not** running yet — typically a VM created without `--autoinstall`, so it's sitting at its first-boot screen), opens a local window, and records every click and keystroke you perform through it by hand. Press `Ctrl-C` in the terminal to stop recording — the matching `boot_command` template is then written to disk.

This capture works directly off the local window's own native `NSEvent`s (`VNCVirtualMachineView.actionRecorder`) — no VNC server is started and no network port is opened. That's deliberately simpler and more direct than tapping a VNC server (still how `caked provision` itself works): no VNC-protocol keysym round-trip, just the events macOS already delivers to the window. The trade-off is that this capture can only be driven by an operator sitting at this host — unlike `caked provision`, it can't be driven by a remote VNC client.

```bash
# Record a session to the default file (record.packerlite.yaml, inside the VM's own directory)
caked record my-vm

# Pick a different output location
caked record my-vm --output ./my-template.packerlite.yaml
```

**Local-only (`caked record`) for now** — no `cakectl`/gRPC counterpart yet, same as `caked provision` when it first shipped. `Scripts/record.sh` automates the usual manual steps around a recording session (deletes any existing same-named VM, duplicates the vanilla template, runs `caked record` with debug logging and the right output path).

**Caker.app** offers the same recording feature directly inside the VM window (for a VM running in the app, not external/remote) — the toolbar's Record button, with the same locate-mode/Reset/VoiceOver controls described below, no command line needed.

### While recording

- **Pause/resume**: the recording window's toolbar shows a button — a pulsing "Recording" button while capturing (tap to pause), a hollow "Paused" button while paused (tap to resume). Pausing only suspends action capture; the VM keeps running either way. `Ctrl-C` is still the only way to actually stop recording and write the file, whether paused or not.
- **OCR-assisted clicks**: a "locate mode" toggle button in the recording window's toolbar highlights every piece of recognized on-screen text in blue (Vision OCR). Once armed, the **left** mouse button on a highlighted region records a `<clickText text='...'>` token, and the **right** mouse button on a highlighted region records a `<locate text='...'>` token — both instead of a raw coordinate-based `<click point="X,Y">`, an anchor that's more resilient to small layout shifts than a bare coordinate. A left-click outside any highlighted region (or with locate mode off) still records the usual `<click point="X,Y">`; a right-click outside any highlighted region records nothing at all (unlike the left button, there's no coordinate fallback for the right button, since `<locate>` only makes sense as an OCR anchor). This mode is an explicit button toggle, never a held key — so it can never conflict with a real macOS shortcut you might need to record verbatim (e.g. Fn+F5 for VoiceOver).
- **VoiceOver button** (macOS VMs only — hidden for Linux VMs): toggles VoiceOver and records a `<voiceOverOn>`/`<voiceOverOff>` token (see the token table above) instead of the raw key sequence. A plain click records an unconfirmed toggle; **Option-click** records a confirmed one (`confirm=true`), for the "Use VoiceOver?" dialog that only appears the very first time it's enabled.
- **Wait gaps before `<clickText>`/`<locate>` fold into their own `timeout=`**: every other step type still gets a separate `<waitNs>` for a ≥1s gap. But `<clickText>`/`<locate>` already poll, via OCR, for their text to appear (up to a `timeout=` in seconds) instead of firing blind — a separate `<waitNs>` in front of either would just be redundant. The recorder instead folds the measured gap (rounded to the second, plus a flat 10s of slack for OCR recognition/rendering latency) straight into the token's own `timeout=`, e.g. `<locate text='...' timeout=13>` for a 3.4s gap. A gap below the 1s threshold forces no `timeout=` override either — the parser's own 10s default applies as usual.
- **Linux VMs**: the first recorded action is automatically routed into `pre_boot_command:` instead of `boot_command:` (useful for a GRUB-navigation keystroke sent before the installer has an IP) — macOS VMs never get this field. This is a coarse heuristic — check the generated file's `pre_boot_command`/`boot_command` split, it may need a manual tweak.

### What comes out

**The result is a first draft, not a finished, reliable template**: clicks become `<click point="X,Y">` tokens, typed text is coalesced into one line per continuous run of keystrokes, special keys and modifiers (`<enter>`, `<tab>`, `<leftShiftOn>`/`<leftShiftOff>`, etc.) use the same token vocabulary as hand-written templates — but pauses between actions become fixed-delay `<waitNs>` steps (except in front of `<clickText>`/`<locate>`, see above). This project has deliberately moved away from fixed delays in favor of OCR-synced `<locate>` anchors, precisely because fixed delays are unreliable (see the provisioning section above) — treat the result as a starting point to harden with `<locate>` anchors before relying on it for unattended `--autoinstall` runs.

Account credentials (the VM's own `--user`/`--password`) are never written out in plaintext: any recorded text that exactly matches the VM's configured username or password is automatically replaced with `${var.username}`/`${var.password}`.

</div>
