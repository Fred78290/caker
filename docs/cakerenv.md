---
layout: default
title: Environments (.cakerenv)
nav_order: 12
---

<!-- markdownlint-disable MD033 MD024 -->

<div class="lang-fr" style="display:none" markdown="1">

# Environnement `.cakerenv`

Un fichier `.cakerenv` décrit, en YAML, la ou les VM de développement dont un projet a besoin. Placé à la racine du projet (comme un `Vagrantfile`), il permet de recréer cet environnement avec une seule commande : `cakectl up` crée les VM qui n'existent pas encore et démarre les autres, `cakectl down` les arrête.

C'est le format le plus léger de Caker pour un environnement « par répertoire ». Pour une stack multi-VM plus complète (format compatible Docker Compose, registre de projets, `ps`/`rm`/`ls`, interface graphique, résolution DNS entre services), utilisez plutôt [Compose](compose) — voir [Choisir entre `.cakerenv` et Compose](#choisir-entre-cakerenv-et-compose) ci-dessous.

## Démarrage rapide

```bash
cd ~/src/monprojet

# Écrire un modèle .cakerenv commenté dans le répertoire courant
cakectl init

# Éditer .cakerenv, puis créer/démarrer toutes les VM
cakectl up

# Arrêter toutes les VM, dans l'ordre inverse des dépendances
cakectl down
```

Les mêmes commandes existent côté `caked` (`caked init`, `caked up`, `caked down`), qui agissent directement sur la machine locale sans passer par le démon — voir [Commandes](#commandes).

## Commandes

| Commande | Rôle |
|---|---|
| `init [-f/--force]` | Écrit le modèle `.cakerenv` dans le répertoire courant. Refuse d'écraser un fichier existant sans `--force`. |
| `up [-f/--env-file <path>] [--wait-ip-timeout N] [vm...]` | Crée les VM absentes et démarre les autres, dans l'ordre de `depends-on`. Sans argument, traite toutes les VM du fichier. `--wait-ip-timeout` (défaut 180 s) borne l'attente de l'adresse IP de chaque VM. |
| `down [-f/--env-file <path>] [--force] [vm...]` | Arrête les VM dans l'ordre inverse de `depends-on`. `--force` arrête sans attendre l'extinction propre. |

`up` et `down` lisent `.cakerenv` dans le répertoire courant, ou le fichier indiqué par `-f`/`--env-file` (qui peut porter n'importe quel nom). Il n'y a ni `ps` ni `rm` : utilisez `cakectl list`, `cakectl infos <vm>` et `cakectl delete <vm>`.

`cakectl up/down` passent par le démon `caked` via gRPC ; `caked up/down` font le même travail localement (utile quand le démon ne tourne pas, ou dans un script sur la machine hôte).

## Format du fichier

Le fichier accepte deux formes.

### Mode VM unique

Tous les champs sont au premier niveau du fichier ; il décrit une seule VM.

```yaml
name: myapp            # facultatif : nom du répertoire courant par défaut
image: ubuntu:24.04
cpus: 2
memory: 2048           # Mio
disk: 20               # Gio
ports:
  - "3000:3000"
mounts:
  - "~/src/myapp:/workspace"
```

Le nom de la VM est, dans l'ordre : le champ `name:`, sinon le nom du **répertoire courant** (celui d'où la commande est lancée, même avec `--env-file`).

### Mode multi-VM

Une map `vms:` dont chaque clé est le nom d'une VM et chaque valeur une spécification de VM. Dès que `vms:` est présente et non vide, **tous les champs de premier niveau sont ignorés**, y compris `name:`.

```yaml
vms:
  app:
    image: ubuntu:24.04
    cpus: 2
    memory: 2048
    ports:
      - "3000:3000"
    depends-on:
      - database

  database:
    image: ubuntu:24.04
    memory: 4096
    disk: 40
```

La clé est utilisée **telle quelle** comme nom de VM (`app`, `database`) — sans préfixe, contrairement à Compose qui nomme ses VM `compose-<projet>-<service>`. Voir [Limites](#limites).

### Champs d'une VM

Les mêmes champs s'utilisent au premier niveau (mode VM unique) ou sous chaque entrée de `vms:`. Seul `depends-on` est réservé au mode multi-VM.

| Champ | Type | Défaut | Description |
|---|---|---|---|
| `image` | chaîne | image cloud Ubuntu 24.04 LTS | Source de l'image, même syntaxe que `cakectl build` : `ubuntu:24.04` (remote simplestreams `ubuntu`), URL `https://…` d'une image cloud, `oci://…`, `template://…`, etc. Un chemin local n'est accepté que par `caked up`. |
| `cpus` | entier | `2` | Nombre de vCPU. |
| `memory` | entier | `2048` | Mémoire en **Mio** (nombre seul, pas de suffixe `M`/`G`). |
| `disk` | entier | `10` | Taille du disque racine en **Gio**. |
| `ports` | liste | aucun | Redirections de ports hôte → invité. Voir [Syntaxe des champs](#syntaxe-des-champs). |
| `sockets` | liste | aucun | Redirections de sockets Unix hôte → invité. |
| `mounts` | liste | aucun | Partages de répertoires Virtio-FS. Aucun répertoire n'est partagé par défaut. |
| `networks` | liste | NAT seul | Interfaces réseau supplémentaires. Chaque VM a toujours une interface NAT, même si la liste est vide. |
| `cloud-init` | chaîne (bloc) | aucun | user-data cloud-init en ligne, voir [Bloc cloud-init](#bloc-cloud-init). |
| `autostart` | booléen | `false` | Démarrer la VM au lancement de `caked`. |
| `nested` | booléen | `false` | Activer la virtualisation imbriquée (désactivée silencieusement si l'hôte ne la prend pas en charge). |
| `depends-on` | liste | aucun | Noms d'autres VM du même fichier à démarrer avant celle-ci (mode multi-VM uniquement). |
| `user` | chaîne | `admin` | Nom du compte créé dans l'invité à la construction de la VM. |
| `password` | chaîne | `admin` | Mot de passe de ce compte. |

Le format du disque n'est pas configurable : c'est le format par défaut de Caker pour la plateforme. Les clés inconnues sont ignorées sans erreur — une faute de frappe dans un nom de champ ne produit aucun message.

### Syntaxe des champs

| Champ | Syntaxe | Exemples |
|---|---|---|
| `ports` | `hôte:invité[/proto]` — proto : `tcp` (défaut), `udp` ou `both` | `"3000:3000"`, `"8053:53/udp"` |
| `sockets` | `chemin_hôte:chemin_invité[/proto]` — même proto que `ports` | `"/tmp/docker.sock:/var/run/docker.sock"` |
| `mounts` | `source[:destination][,ro][,name=…][,uid=…][,gid=…]` | `"~/src/myapp:/workspace"`, `"~/data:/data,ro"` |
| `networks` | `réseau[,mode=…][,mac=…]` — mode : `auto` ou `manual` | `nat`, `bridged`, `en0`, un réseau de `cakectl networks list` |

- **`ports`** : seule la forme `hôte:invité[/proto]` est prise en charge. Contrairement à Compose, `.cakerenv` ne valide pas les ports : une adresse IP en préfixe (`127.0.0.1:8080:80`) ou une plage (`3000-3005:3000-3005`) est mal interprétée, et une entrée illisible est ignorée sans message.
- **`mounts`** : la lecture seule s'écrit `,ro` ; la forme Docker `:ro` n'est **pas** reconnue (le `:ro` est perdu et le partage reste en lecture-écriture).
- **Chemins relatifs** : avec `cakectl up`, le chemin source d'un montage est résolu dans le répertoire de travail du **démon** `caked`, pas dans celui de votre shell. Utilisez des chemins absolus ou `~/…` (le modèle généré contient `".:/workspace"`, qui ne fonctionne comme prévu qu'avec `caked up`).

### Bloc cloud-init

`cloud-init: |` contient un document cloud-config (sans en-tête `#cloud-config`, Caker l'ajoute). Il est fusionné avec la configuration générée par Caker (compte, clé SSH, agent) : les listes comme `packages` ou `runcmd` s'y ajoutent.

```yaml
vms:
  app:
    image: ubuntu:24.04
    cloud-init: |
      package_update: true
      packages:
        - nodejs
        - git
      runcmd:
        - echo "ready" > /etc/motd
```

Le contenu est écrit dans un fichier temporaire puis passé comme user-data, exactement comme `cakectl build --cloud-init <fichier>`. Il ne s'applique qu'à la **création** de la VM.

## Ordre de démarrage et `depends-on`

- `up` démarre les VM dans l'ordre topologique de `depends-on` ; en dehors de cette contrainte, les VM sont traitées par ordre alphabétique (ou dans l'ordre des noms passés en argument). `down` utilise l'ordre inverse.
- Une dépendance vers une VM absente du fichier, ou un cycle, fait échouer la commande avant toute action.
- Un nom de VM inconnu passé en argument (`cakectl up typo`) est une erreur.
- **Filtrer ne tire pas les dépendances** : `cakectl up app` ne démarre que `app`, même si `app` dépend de `database` (contrairement à `docker compose up app`). L'ordre ne s'applique qu'entre les VM demandées : `cakectl up app database` démarre bien `database` puis `app`. De même, `cakectl down database` n'arrête pas `app`.
- `depends-on` porte sur l'**ordre** uniquement : `up` attend l'adresse IP de chaque VM avant de passer à la suivante, pas qu'un service applicatif soit prêt à l'intérieur.

## Comportement de `up` sur une VM existante

`up` ne crée une VM que si aucune VM de ce nom n'existe. Pour une VM existante :

| État | `cakectl up` | `caked up` |
|---|---|---|
| arrêtée | démarrée | démarrée |
| en cours d'exécution | « already running » | attend son adresse IP et la renvoie |
| en pause | message invitant à lancer `cakectl start <vm>` | tentative de démarrage, sans traitement particulier |

**Une VM existante n'est jamais reconfigurée ni reconstruite** : modifier `cpus`, `memory`, `ports`, `mounts`, `cloud-init`… dans `.cakerenv` n'a aucun effet sur une VM déjà créée. Pour appliquer le changement, utilisez `cakectl configure <vm> …` ou supprimez la VM (`cakectl delete <vm>`) puis relancez `cakectl up`.

## Choisir entre `.cakerenv` et Compose

| | `.cakerenv` | [Compose](compose) |
|---|---|---|
| Fichier | `.cakerenv` (ou `-f`) | `compose.yml`, `compose.yaml`, `docker-compose.yml`… |
| Format | propre à Caker, minimal | compatible Docker Compose (+ extensions VM) |
| Commandes | `init`, `up`, `down` | `init`, `up`, `down`, `ps`, `rm`, `ls` |
| Nom des VM | la clé (`app`) | `compose-<projet>-<service>` |
| Registre de projets | non | oui (`compose ls`, panneau Compose de Caker.app) |
| Personnalisation de l'invité | bloc `cloud-init` brut | `packages`, `environment`, `write_files`, `post_commands`… |
| Réseaux | attachés tels quels | section `networks:` validée par `up` |
| Interface graphique | non (CLI seulement) | oui |

Choisissez `.cakerenv` pour une ou deux VM de développement liées à un dépôt ; Compose dès que vous avez besoin de suivre l'état d'une stack ou de la piloter depuis Caker.app.

## Limites

- **Noms non isolés** : les VM portent exactement le nom donné dans le fichier. Si une VM `app` existe déjà (créée à la main ou par un autre `.cakerenv`), `up` la démarre au lieu d'en créer une, et `down` l'arrête.
- Pas de reconfiguration des VM existantes (voir plus haut).
- Avec `cakectl up`, l'image doit être distante (pas de chemin local) et les chemins de montage relatifs sont résolus côté démon.
- Les clés inconnues et les entrées de `ports`/`sockets` illisibles sont ignorées sans erreur.

## Voir aussi

- [Compose](compose) — stacks multi-VM au format Docker Compose
- [Résumé des commandes](command-summary) — options de `build`/`launch` (`--publish`, `--mount`, `--network`, `--cloud-init`)
- [Pense-bête](cheat-sheet)

</div>

<div class="lang-en" style="display:block" markdown="1">

# `.cakerenv` environments

A `.cakerenv` file describes, in YAML, the development VM(s) a project needs. Kept at the project root (much like a `Vagrantfile`), it lets anyone recreate that environment with one command: `cakectl up` creates the VMs that don't exist yet and starts the others, `cakectl down` stops them.

It is Caker's lightest-weight, per-directory environment format. For a fuller multi-VM stack (Docker Compose–compatible format, project registry, `ps`/`rm`/`ls`, GUI, DNS between services), use [Compose](compose) instead — see [Choosing between `.cakerenv` and Compose](#choosing-between-cakerenv-and-compose) below.

## Quick start

```bash
cd ~/src/myproject

# Write a commented .cakerenv template in the current directory
cakectl init

# Edit .cakerenv, then create/start every VM
cakectl up

# Stop every VM, in reverse dependency order
cakectl down
```

The same commands exist on the `caked` side (`caked init`, `caked up`, `caked down`); they act on the local machine directly, without going through the daemon — see [Commands](#commands).

## Commands

| Command | Purpose |
|---|---|
| `init [-f/--force]` | Write the `.cakerenv` template into the current directory. Refuses to overwrite an existing file without `--force`. |
| `up [-f/--env-file <path>] [--wait-ip-timeout N] [vm...]` | Create missing VMs and start the others, in `depends-on` order. With no arguments, every VM in the file. `--wait-ip-timeout` (default 180 s) bounds the wait for each VM's IP address. |
| `down [-f/--env-file <path>] [--force] [vm...]` | Stop VMs in reverse `depends-on` order. `--force` stops without waiting for a graceful shutdown. |

`up` and `down` read `.cakerenv` from the current directory, or the file given with `-f`/`--env-file` (which can have any name). There is no `ps` or `rm`: use `cakectl list`, `cakectl infos <vm>` and `cakectl delete <vm>`.

`cakectl up/down` go through the `caked` daemon over gRPC; `caked up/down` do the same work locally (useful when the daemon isn't running, or in a script on the host).

## File format

The file comes in two shapes.

### Single-VM mode

Every field sits at the top level of the file, which describes one VM.

```yaml
name: myapp            # optional: defaults to the current directory name
image: ubuntu:24.04
cpus: 2
memory: 2048           # MiB
disk: 20               # GiB
ports:
  - "3000:3000"
mounts:
  - "~/src/myapp:/workspace"
```

The VM's name is, in order: the `name:` field, otherwise the name of the **current directory** (the one the command runs from, even with `--env-file`).

### Multi-VM mode

A `vms:` map whose keys are VM names and whose values are VM specs. As soon as `vms:` is present and non-empty, **every top-level field is ignored**, `name:` included.

```yaml
vms:
  app:
    image: ubuntu:24.04
    cpus: 2
    memory: 2048
    ports:
      - "3000:3000"
    depends-on:
      - database

  database:
    image: ubuntu:24.04
    memory: 4096
    disk: 40
```

The key is used **as-is** as the VM name (`app`, `database`) — no prefix, unlike Compose, which names its VMs `compose-<project>-<service>`. See [Limitations](#limitations).

### VM fields

The same fields work at the top level (single-VM mode) or under each `vms:` entry. Only `depends-on` is specific to multi-VM mode.

| Field | Type | Default | Description |
|---|---|---|---|
| `image` | string | Ubuntu 24.04 LTS cloud image | Image source, same syntax as `cakectl build`: `ubuntu:24.04` (the `ubuntu` simplestreams remote), an `https://…` cloud-image URL, `oci://…`, `template://…`, etc. A local path is only accepted by `caked up`. |
| `cpus` | integer | `2` | Number of vCPUs. |
| `memory` | integer | `2048` | Memory in **MiB** (a bare number, no `M`/`G` suffix). |
| `disk` | integer | `10` | Root disk size in **GiB**. |
| `ports` | list | none | Host → guest port forwards. See [String formats](#string-formats). |
| `sockets` | list | none | Host → guest Unix socket forwards. |
| `mounts` | list | none | Virtio-FS directory shares. Nothing is shared by default. |
| `networks` | list | NAT only | Additional network interfaces. Every VM always gets a NAT interface, even with an empty list. |
| `cloud-init` | string (block) | none | Inline cloud-init user-data, see [cloud-init](#cloud-init). |
| `autostart` | boolean | `false` | Start the VM when `caked` starts. |
| `nested` | boolean | `false` | Enable nested virtualization (silently turned off if the host doesn't support it). |
| `depends-on` | list | none | Names of other VMs in the same file to start before this one (multi-VM mode only). |
| `user` | string | `admin` | Name of the account created in the guest when the VM is built. |
| `password` | string | `admin` | That account's password. |

The disk format isn't configurable: it is Caker's default format for the platform. Unknown keys are ignored without an error — a typo in a field name produces no message.

### String formats

| Field | Syntax | Examples |
|---|---|---|
| `ports` | `host:guest[/proto]` — proto: `tcp` (default), `udp` or `both` | `"3000:3000"`, `"8053:53/udp"` |
| `sockets` | `host_path:guest_path[/proto]` — same proto as `ports` | `"/tmp/docker.sock:/var/run/docker.sock"` |
| `mounts` | `source[:destination][,ro][,name=…][,uid=…][,gid=…]` | `"~/src/myapp:/workspace"`, `"~/data:/data,ro"` |
| `networks` | `network[,mode=…][,mac=…]` — mode: `auto` or `manual` | `nat`, `bridged`, `en0`, a network from `cakectl networks list` |

- **`ports`**: only the `host:guest[/proto]` form is supported. Unlike Compose, `.cakerenv` doesn't validate ports: an IP prefix (`127.0.0.1:8080:80`) or a range (`3000-3005:3000-3005`) is misread, and an unparseable entry is dropped silently.
- **`mounts`**: read-only is written `,ro`; Docker's `:ro` form is **not** recognized (the `:ro` is lost and the share stays read-write).
- **Relative paths**: with `cakectl up`, a mount's source path is resolved in the **`caked` daemon's** working directory, not your shell's. Use absolute or `~/…` paths (the generated template contains `".:/workspace"`, which only works as intended with `caked up`).

### cloud-init

`cloud-init: |` holds a cloud-config document (without a `#cloud-config` header — Caker adds it). It is merged with the configuration Caker generates (account, SSH key, agent): lists such as `packages` or `runcmd` are appended to it.

```yaml
vms:
  app:
    image: ubuntu:24.04
    cloud-init: |
      package_update: true
      packages:
        - nodejs
        - git
      runcmd:
        - echo "ready" > /etc/motd
```

The content is written to a temporary file and passed as user-data, exactly like `cakectl build --cloud-init <file>`. It only applies when the VM is **created**.

## Start order and `depends-on`

- `up` starts VMs in the topological order given by `depends-on`; beyond that constraint, VMs are processed in alphabetical order (or in the order of the names passed as arguments). `down` uses the reverse order.
- A dependency on a VM that isn't in the file, or a cycle, fails the command before anything is done.
- An unknown VM name passed as an argument (`cakectl up typo`) is an error.
- **Filtering doesn't pull in dependencies**: `cakectl up app` starts only `app`, even if `app` depends on `database` (unlike `docker compose up app`). The order only applies between the VMs you asked for: `cakectl up app database` does start `database` first, then `app`. Likewise, `cakectl down database` doesn't stop `app`.
- `depends-on` is about **order** only: `up` waits for each VM's IP address before moving on to the next one, not for an application inside it to be ready.

## `up` on an existing VM

`up` only creates a VM when no VM with that name exists. For an existing VM:

| State | `cakectl up` | `caked up` |
|---|---|---|
| stopped | started | started |
| running | "already running" | waits for its IP and reports it |
| paused | message suggesting `cakectl start <vm>` | a start is attempted, no special handling |

**An existing VM is never reconfigured or rebuilt**: changing `cpus`, `memory`, `ports`, `mounts`, `cloud-init`… in `.cakerenv` has no effect on a VM that already exists. To apply the change, use `cakectl configure <vm> …`, or delete the VM (`cakectl delete <vm>`) and run `cakectl up` again.

## Choosing between `.cakerenv` and Compose

| | `.cakerenv` | [Compose](compose) |
|---|---|---|
| File | `.cakerenv` (or `-f`) | `compose.yml`, `compose.yaml`, `docker-compose.yml`… |
| Format | Caker-specific, minimal | Docker Compose–compatible (+ VM extensions) |
| Commands | `init`, `up`, `down` | `init`, `up`, `down`, `ps`, `rm`, `ls` |
| VM names | the key (`app`) | `compose-<project>-<service>` |
| Project registry | no | yes (`compose ls`, Caker.app's Compose pane) |
| Guest customization | raw `cloud-init` block | `packages`, `environment`, `write_files`, `post_commands`… |
| Networks | attached as written | `networks:` section validated by `up` |
| GUI | no (CLI only) | yes |

Pick `.cakerenv` for one or two development VMs tied to a repository; pick Compose as soon as you need to track a stack's state or drive it from Caker.app.

## Limitations

- **Names aren't isolated**: VMs get exactly the name written in the file. If a VM named `app` already exists (created by hand or by another `.cakerenv`), `up` starts it instead of creating one, and `down` stops it.
- Existing VMs aren't reconfigured (see above).
- With `cakectl up`, the image must be remote (no local path) and relative mount paths are resolved on the daemon side.
- Unknown keys and unparseable `ports`/`sockets` entries are ignored without an error.

## See also

- [Compose](compose) — multi-VM stacks in Docker Compose format
- [Command Summary](command-summary) — `build`/`launch` options (`--publish`, `--mount`, `--network`, `--cloud-init`)
- [Cheat Sheet](cheat-sheet)

</div>

{% include lang-toggle.html %}
