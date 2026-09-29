<!-- markdownlint-disable MD033 MD024 -->

<div class="lang-fr" style="display:none" markdown="1">

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

Le modèle généré par `compose init` est un exemple complet à deux VM (MariaDB + phpMyAdmin, compatible arm64/amd64), embarqué dans Caker sous forme de fichier `compose-template.yml` — MariaDB y crée un compte dédié `MYSQL_USER`/`MYSQL_PASSWORD` pour se connecter à phpMyAdmin, et phpMyAdmin accepte n'importe quel serveur ou celui indiqué par `PMA_HOST` — voir « Paquets », « Fichiers additionnels » et « Commandes post-installation » ci-dessous pour le détail de son installation via `packages`/`write_files`/`post_commands`.

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
    disk_format: raw      # format du disque (défaut : format par défaut de Caker)
    ifnames: true         # noms d'interfaces réseau prévisibles (défaut true)
    dynamic_port_forwarding: false  # redirection de ports dynamique (défaut false)
    ssh_authorized_key: ~/.ssh/id_ed25519.pub  # clé publique SSH, ou chemin d'un fichier qui la contient
    packages:             # paquets apt/dnf/apk/zypper installés via cloud-init à la construction
      - git
      - curl
    write_files:          # fichiers supplémentaires écrits dans l'invité via cloud-init
      - path: /etc/myapp/app.conf
        content: "key = value"   # texte inline …
      - path: /etc/myapp/from-host.conf
        source: ./app.conf       # … ou un fichier lu sur l'hôte (résolu comme `volumes:`)
    post_commands:        # exécutées après packages/write_files via cloud-init
      - systemctl enable --now docker

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
    driver: bridge       # attache la VM à un réseau physique/bridgé — voir "Réseaux" ci-dessous
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

### Ports et volumes

`ports:` accepte `hôte:invité[/tcp|udp|both]` (ou un port seul, utilisé des deux côtés) ; tout le reste — une adresse hôte (`127.0.0.1:8080:80`, `host_ip:` en forme longue), une plage de ports, un protocole inconnu — est refusé avec une erreur plutôt que transformé en silence en une redirection différente. Les entrées de `sockets:` illisibles sont refusées de la même façon.

`volumes:` accepte `hôte:invité` ; le `:ro` de Docker (ou `read_only: true` en forme longue) rend le partage en lecture seule.

### Réseaux

`driver: bridge` attache toujours la VM à un **réseau physique/bridgé réel** — au sens d'Apple Virtualization.framework, pas au sens Docker (qui désigne un simple commutateur virtuel privé, hébergé sur l'hôte). Caker n'a pas d'équivalent au « bridge » de Docker : il n'y a donc rien à *créer*, seulement une interface existante à référencer.

La résolution du nom cible fonctionne ainsi :

- Si le réseau déclare un champ `name:`, celui-ci l'emporte — utilisé notamment avec `external: true`, pour désigner une interface déjà existante.
- Sinon, la **clé** du réseau elle-même sert directement d'identifiant d'interface physique (par ex. `en0`) — Caker vérifie qu'une telle interface existe réellement sur l'hôte et échoue immédiatement sinon (`compose up` renvoie une erreur claire plutôt que de démarrer la VM sans réseau).
- Exception : la clé réservée **`default`** (la convention Docker Compose de réseau implicite — c'est celle du modèle généré par `compose init`) se résout vers l'interface bridgée par défaut configurée dans Caker (réglable dans `caker` → Réglages avancés → « Bridged network ») — il n'y a pas moyen de deviner quelle carte réseau hôte un réseau `default` nu devrait utiliser. Un `default` non déclaré (aucune entrée `networks:` de premier niveau, ou un `default:` vide) se résout de la même façon, comme le réseau implicite de Docker Compose.

Lorsque `external: true`, Caker attache simplement la VM de service à l'interface déjà existante, sans validation supplémentaire.

### Paquets (`packages`)

Une extension VM Caker : liste de paquets (`apt`/`dnf`/`apk`/`zypper` selon la distribution de l'image) installés via cloud-init dès le premier démarrage de la VM, avant que `compose up` ne la considère comme prête. Dès que `packages:` est renseigné, Caker met par défaut à jour l'index des paquets au préalable (voir `package_update` ci-dessous pour le désactiver) — sans quoi l'installation peut échouer sur un index périmé ou vide dans une image fraîchement créée.

```yaml
packages:
  - git
  - curl
```

`package_update` (autre extension VM Caker) contrôle la mise à jour de l'index des paquets avant l'installation. Par défaut, elle est activée automatiquement dès que `packages:` ou `package_upgrade:` est renseigné ; une valeur explicite l'emporte toujours, dans les deux sens :

- `package_update: true` force la mise à jour même sans `packages:` — utile pour un service qui installe tout depuis `post_commands:` (comme `phpmyadmin` dans le modèle généré par `compose init`), qui sinon partirait d'un index périmé.
- `package_update: false` désactive la mise à jour implicite (miroir local pré-rempli, ou image de base dont l'index est déjà à jour et pour laquelle l'aller-retour ne fait que ralentir la construction).

```yaml
package_update: true
```

`package_upgrade: true` (autre extension VM Caker, indépendante de `packages:`) met à niveau **tous** les paquets déjà installés sur l'image, pas seulement ceux listés — contrairement à la mise à jour de l'index, ceci n'est jamais activé automatiquement : une mise à niveau complète a un coût réel (construction plus lente, image moins reproductible), c'est donc à activer explicitement.

```yaml
package_upgrade: true
```

### Fichiers additionnels (`write_files`)

Une autre extension VM Caker : liste de fichiers écrits dans l'invité via cloud-init au premier démarrage. Chaque entrée précise `path:` et exactement l'un de `content:` (texte inline) ou `source:` (un chemin lu sur l'**hôte**, résolu de la même façon que le côté hôte de `volumes:` — relatif au répertoire courant) ; `permissions:`, `owner:` et `append:` sont optionnels.

```yaml
write_files:
  - path: /etc/myapp/app.conf
    content: "key = value"
    permissions: "0644"
  - path: /etc/myapp/from-host.conf
    source: ./app.conf
    append: true
```

Un fichier `source:` qui n'est pas du texte UTF-8 valide est encodé en base64 automatiquement (`encoding: b64`), plutôt que de faire échouer la construction — un petit fichier binaire fonctionne donc aussi.

### Commandes post-installation (`post_commands`)

Une autre extension VM Caker : liste de commandes shell exécutées via cloud-init **après** l'installation des paquets et l'écriture des fichiers (`runcmd` de cloud-init s'exécute toujours dans la dernière étape du démarrage, quel que soit l'ordre des sections dans le fichier).

```yaml
post_commands:
  - systemctl enable --now docker
  - usermod -aG docker ubuntu
```

`packages`, `write_files`, `post_commands` et `environment` partagent le même document cloud-init `user-data` — tous sont combinés en un seul fichier lors de la construction (y compris le fichier `/etc/environment` généré par `environment`, fusionné dans la même clé `write_files:` que vos propres entrées), vous pouvez donc les utiliser ensemble sans conflit.

### Autres extensions VM

Quelques extensions VM Caker supplémentaires, toutes facultatives :

- `disk_format` — format du disque de la VM (`raw`, etc.) ; par défaut, le format par défaut de Caker.
- `ifnames` — noms d'interfaces réseau prévisibles dans l'invité ; `true` par défaut.
- `dynamic_port_forwarding` — active la redirection de ports dynamique ; `false` par défaut.
- `ssh_authorized_key` — une clé publique SSH (`ssh-ed25519 AAAA…`) **ou le chemin d'un fichier** qui la contient (`~` est développé). Un chemin est lu et nettoyé dès le chargement du fichier : un fichier introuvable fait échouer `compose up` immédiatement, avant qu'aucune VM de la stack ne soit construite.

Quand `user`/`password` sont omis, l'invité est créé avec `admin`/`admin`.

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

Le fichier lu par `up` remplace la définition enregistrée pour ce projet, donc un service **ajouté** au fichier depuis le dernier `up` est construit et démarré. Une VM déjà construite, elle, n'est jamais reconstruite : son matériel, son disque, son réseau et sa configuration cloud-init sont fixés à la création. Si la définition d'un tel service a changé, `up` se contente de le démarrer et l'indique dans son message — pour appliquer le changement, supprimez-le (`compose rm`) puis relancez `compose up`. De même, un service **retiré** du fichier garde sa VM (qui n'est plus atteinte par `down`/`rm`/`ps`, puisqu'ils parcourent la définition courante) et `up` le signale.

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
cakectl compose rm [-f <file>] [--stop] [--force] [services...]
caked    compose rm [-f <file>] [--stop] [--force] [services...]
```

| Option | Défaut | Description |
| --- | --- | --- |
| `-f, --file <path>` | détection auto | Chemin du fichier compose |
| `--stop` | désactivé | Arrêter les services en cours avant suppression |
| `--force` | désactivé | Forcer l'arrêt sans arrêt gracieux (n'a d'effet qu'avec `--stop`) |
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

## App Caker (interface graphique)

Au-delà de la CLI, l'app `caker` offre une gestion complète de Compose dans son interface — disponible dans tous les modes de connexion, y compris `.app` (VM embarquées dans le processus, sans `caked` séparé), puisque la logique Compose ne dépend d'aucun processus serveur.

- **Catégorie « Compose » de la barre latérale** — liste tous les projets enregistrés (mise à jour toutes les 3 secondes, il n'y a pas de mécanisme de notification push pour Compose). Chaque ligne affiche un résumé (« n/m en cours »), un indicateur d'état, et propose Éditer / Démarrer-ou-Arrêter / Supprimer une fois sélectionnée. Un panneau de détail affiche le statut de chaque service individuellement.
- **Éditeur Compose** — un éditeur YAML brut plutôt qu'un formulaire structuré complet (la richesse polymorphe du format — formes courtes/longues pour `depends_on`/`environment`/`ports`/`volumes` — rendrait un formulaire complet disproportionné pour une première version). Pré-rempli avec le modèle par défaut pour un nouveau projet, ou une reconstruction du projet existant pour une édition (seuls le nom et l'image de chaque service sont mémorisés par le registre — ports, volumes, environnement, réseaux et depends_on doivent être ré-ajoutés si nécessaire). Un indicateur « Analyse OK » / « Erreur d'analyse : … » se met à jour en direct pendant la frappe ; « Enregistrer et démarrer » relance simplement `compose up` avec la définition éditée : les nouveaux services sont construits, ceux dont la VM existe déjà sont seulement démarrés (voir `compose up`). Un petit formulaire « Ajouter un service » insère un bloc YAML préformaté sans avoir à éditer le YAML brut pour un ajout simple.
- **Extras de la barre de menus** — un sous-menu « Compose » liste les projets enregistrés avec des actions Ouvrir/Démarrer/Arrêter par projet, plus un élément « Nouveau projet compose… » qui ouvre directement l'éditeur.

## Résolution DNS entre services

Un service peut joindre un autre service du même projet par son nom, à l'adresse `<service>.<projet>.compose.internal` (par ex. `mariadb.myapp.compose.internal`) — pas besoin de récupérer une IP à la main dans `environment:`. `caked` fait tourner un petit résolveur DNS lié à l'adresse de la passerelle du réseau NAT — le réseau que **chaque** VM possède déjà, quel que soit son système ou son réseau `driver:` principal — et n'y répond que pour ce domaine synthétique ; toute autre requête reçoit `REFUSED`, jamais utilisable comme résolveur ouvert. Chaque VM créée par compose reçoit automatiquement, dans son cloud-init, la configuration `resolvectl` qui route uniquement `*.compose.internal` vers ce résolveur — le reste de la résolution DNS de l'invité n'est pas modifié.

Fonctionnement interne détaillé, mise en garde sur la portée non testée de bout en bout (VM à VM sur le réseau NAT partagé) et code source : voir la section « Compose DNS » de `CLAUDE.md`.

## Différences avec Docker Compose

| Fonctionnalité | Docker Compose | Caker compose |
| --- | --- | --- |
| Runtime | Démon de conteneurs | VM Apple Virtualization.framework |
| Extensions VM | Non | `disk`, `disk_format`, `user`, `password`, `nested`, `autostart`, `ifnames`, `dynamic_port_forwarding`, `ssh_authorized_key`, `sockets`, `packages`, `package_update`, `package_upgrade`, `write_files`, `post_commands` |
| `restart` | Politique appliquée | Accepté, non appliqué |
| `deploy.replicas`, `deploy.resources.reservations` | Appliqués | Acceptés, non appliqués — une seule VM par service, seules les `limits` sont utilisées |
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

<div class="lang-en" style="display:block" markdown="1">

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

The template `compose init` generates is a full two-VM example (MariaDB + phpMyAdmin, works on both arm64 and amd64), shipped inside Caker as a `compose-template.yml` file — MariaDB creates a dedicated `MYSQL_USER`/`MYSQL_PASSWORD` account for logging in to phpMyAdmin, and phpMyAdmin accepts any server or the one given by `PMA_HOST` — see "Packages", "Extra files", and "Post-install commands" below for how it installs each via `packages`/`write_files`/`post_commands`.

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
    disk_format: raw     # disk format (default: Caker's default format)
    ifnames: true        # predictable network interface names (default true)
    dynamic_port_forwarding: false  # dynamic port forwarding (default false)
    ssh_authorized_key: ~/.ssh/id_ed25519.pub  # SSH public key, or path to a file holding one
    packages:            # apt/dnf/apk/zypper packages installed via cloud-init at build
      - git
      - curl
    write_files:         # extra files written into the guest via cloud-init
      - path: /etc/myapp/app.conf
        content: "key = value"   # inline text …
      - path: /etc/myapp/from-host.conf
        source: ./app.conf       # … or a file read from the host (resolved like `volumes:`)
    post_commands:       # run after packages/write_files, via cloud-init
      - systemctl enable --now docker

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
    driver: bridge       # attaches the VM to a physical/bridged network — see "Networks" below
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

### Ports and volumes

`ports:` accepts `host:guest[/tcp|udp|both]` (or a single port, used on both sides); anything else — a host address (`127.0.0.1:8080:80`, `host_ip:` in the long form), a port range, an unknown protocol — is rejected with an error rather than silently turned into a different forward. An unparseable `sockets:` entry is rejected the same way.

`volumes:` accepts `host:guest`; Docker's `:ro` (or `read_only: true` in the long form) makes the share read-only.

### Networks

`driver: bridge` always attaches the VM to a **real physical/bridged network** — in Apple Virtualization.framework's sense of "bridged," not Docker's own sense (a private, host-only virtual switch). Caker has no equivalent of Docker's own "bridge" driver, so there is nothing to *create* here, only an existing interface to reference.

The target name resolves as follows:

- If the network declares a `name:` field, that wins — typically paired with `external: true`, to point at an interface that already exists.
- Otherwise, the network's own **key** is used directly as a physical interface identifier (e.g. `en0`) — Caker verifies that interface actually exists on the host and fails immediately if it doesn't (`compose up` returns a clear error instead of starting the VM with no network device).
- Exception: the reserved key **`default`** (Docker Compose's own implicit-network convention — also what `compose init`'s own template uses) resolves to Caker's configured default bridged interface (set under `caker` → Advanced Settings → "Bridged network") — there's no way to infer which host NIC a bare `default` network should bridge to. An undeclared `default` (no top-level `networks:` entry at all, or a bare `default:`) resolves the same way, as Docker Compose's implicit network.

When `external: true`, Caker just attaches the service VM to the already-existing interface, with no further validation.

### Packages (`packages`)

A Caker VM extension: a list of packages (`apt`/`dnf`/`apk`/`zypper`, depending on the image's distro) installed via cloud-init on the VM's very first boot, before `compose up` considers it ready. Whenever `packages:` is set, Caker refreshes the package index first by default (see `package_update` below to turn that off) — without it, the install can fail against a stale or empty index on a freshly created image.

```yaml
packages:
  - git
  - curl
```

`package_update` (another Caker VM extension) controls refreshing the package index before installing. By default it's turned on automatically whenever `packages:` or `package_upgrade:` is set; an explicit value always wins, in both directions:

- `package_update: true` forces the refresh even with no `packages:` — useful for a service that installs everything from `post_commands:` (like `phpmyadmin` in the template `compose init` generates), which would otherwise start from a stale index.
- `package_update: false` turns off the implied refresh (a pre-populated local mirror, or a base image whose index is already fresh and where the round trip only slows the build down).

```yaml
package_update: true
```

`package_upgrade: true` (another Caker VM extension, independent of `packages:`) upgrades **every** already-installed package on the image, not just the ones listed — unlike the index refresh, this is never turned on automatically: a full-system upgrade has a real cost (slower builds, a less reproducible image), so it's opt-in.

```yaml
package_upgrade: true
```

### Extra files (`write_files`)

Another Caker VM extension: a list of files written into the guest via cloud-init on first boot. Each entry gives `path:` and exactly one of `content:` (inline text) or `source:` (a path read from the **host**, resolved the same way `volumes:`'s host side already is — relative to the current directory); `permissions:`, `owner:`, and `append:` are optional.

```yaml
write_files:
  - path: /etc/myapp/app.conf
    content: "key = value"
    permissions: "0644"
  - path: /etc/myapp/from-host.conf
    source: ./app.conf
    append: true
```

A `source:` file that isn't valid UTF-8 text is base64-encoded automatically (`encoding: b64`) instead of failing the build — so a small binary file works too.

### Post-install commands (`post_commands`)

Another Caker VM extension: a list of shell commands run via cloud-init **after** packages are installed and files are written (cloud-init's own `runcmd` always executes in the last boot stage, regardless of section order in the file).

```yaml
post_commands:
  - systemctl enable --now docker
  - usermod -aG docker ubuntu
```

`packages`, `write_files`, `post_commands`, and `environment` all share the same cloud-init `user-data` document — they're combined into one file at build time (including the `/etc/environment` file `environment` itself generates, merged into the same `write_files:` key as your own entries), so you can use them together without conflict.

### Other VM extensions

A few more optional Caker VM extensions:

- `disk_format` — the VM's disk format (`raw`, etc.); defaults to Caker's default format.
- `ifnames` — predictable network interface names inside the guest; `true` by default.
- `dynamic_port_forwarding` — turns on dynamic port forwarding; `false` by default.
- `ssh_authorized_key` — an SSH public key (`ssh-ed25519 AAAA…`) **or the path to a file** holding one (`~` is expanded). A path is read and trimmed as soon as the file is loaded: a missing file makes `compose up` fail immediately, before any VM in the stack is built.

When `user`/`password` are omitted, the guest is created with `admin`/`admin`.

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

The file `up` reads replaces the definition registered for that project, so a service **added** to the file since the last `up` is built and started. A VM that is already built is never rebuilt, though: its hardware, disk, network and cloud-init configuration are fixed when it is created. If such a service's definition has changed, `up` only starts it and says so in its output — to apply the change, remove it (`compose rm`) and run `compose up` again. Likewise, a service **removed** from the file keeps its VM (which `down`/`rm`/`ps` no longer reach, since they walk the current definition) and `up` points that out.

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
cakectl compose rm [-f <file>] [--stop] [--force] [services...]
caked    compose rm [-f <file>] [--stop] [--force] [services...]
```

| Flag | Default | Description |
| --- | --- | --- |
| `-f, --file <path>` | auto-detect | Path to compose file |
| `--stop` | off | Stop running services before removing |
| `--force` | off | Force stop without graceful shutdown (only has an effect with `--stop`) |
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

## Caker app (GUI)

Beyond the CLI, the `caker` app offers full Compose management in its own interface — available in every connection mode, including `.app` (VMs embedded in-process, no separate `caked`), since the Compose logic has no server-process dependency at all.

- **"Compose" sidebar category** — lists every registered project (polled every 3 seconds; there's no push-notification mechanism for Compose state). Each row shows a summary ("n/m running"), a status indicator, and offers Edit / Start-or-Stop / Delete once selected. A detail pane shows each service's individual status.
- **Compose Editor** — a raw-YAML editor rather than a fully structured form (the format's polymorphic richness — short/long forms for `depends_on`/`environment`/`ports`/`volumes` — would make a complete structured form out of proportion for a first pass). Seeded from the default template for a new project, or a best-effort reconstruction of an existing one for editing (only each service's name and image are remembered by the registry — ports, volumes, environment, networks and depends_on must be re-added if the project needs them). A live "Parses OK" / "Parse error: …" indicator updates as you type; "Save & Start" simply re-runs `compose up` with the edited definition: new services are built, services whose VM already exists are only started (see `compose up`). A small "Add service" form inserts a formatted YAML block for a quick addition without hand-editing the raw YAML.
- **Menu bar extras** — a "Compose" submenu lists registered projects with per-project Open/Start/Stop actions, plus a "New compose project…" item that opens the editor directly.

## DNS resolution between services

A service can reach another service in the same project by name, at `<service>.<project>.compose.internal` (e.g. `mariadb.myapp.compose.internal`) — no need to hand-copy an IP into `environment:`. `caked` runs a small DNS resolver bound to the NAT network's gateway address — the network **every** VM already has, regardless of its OS or its primary `driver:` — and answers only for that synthetic domain; any other query gets `REFUSED`, never usable as an open resolver. Every compose-created VM's cloud-init automatically gets the `resolvectl` setup that routes only `*.compose.internal` to this resolver — the rest of the guest's DNS resolution is untouched.

For the full mechanism, and the one caveat worth knowing (VM-to-VM traffic on the shared NAT network is reasoned from code, not yet verified end to end with a real two-VM boot), see the "Compose DNS" section of `CLAUDE.md`.

## Differences from Docker Compose

| Feature | Docker Compose | Caker compose |
| --- | --- | --- |
| Runtime | Container daemon | Apple Virtualization.framework VMs |
| VM extensions | No | `disk`, `disk_format`, `user`, `password`, `nested`, `autostart`, `ifnames`, `dynamic_port_forwarding`, `ssh_authorized_key`, `sockets`, `packages`, `package_update`, `package_upgrade`, `write_files`, `post_commands` |
| `restart` | Enforced policy | Accepted, not enforced |
| `deploy.replicas`, `deploy.resources.reservations` | Enforced | Accepted, not applied — one VM per service, only `limits` are used |
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
