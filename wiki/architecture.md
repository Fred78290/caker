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

<a name="privileges-fr"></a>

## Privilèges et sudo sans mot de passe

Quelques opérations ont besoin de root : démarrer un réseau vmnet (et son serveur DHCP/DNS), importer une instance Multipass située sous `/var/root`, ou installer `/etc/paths.d/com.aldunelabs.caker`. La version à télécharger les confie à un **assistant privilégié** (`Sources/helper`, un démon `SMAppService` joint par XPC et protégé par une autorisation `Authorization`) que l'utilisateur approuve une fois dans Réglages Système > Général > Éléments de connexion. L'assistant n'accepte que des opérations précises : `startNetwork`, `runNetwork`, `importVirtualMachine` (uniquement `--from=multipass`, avec deux noms simples et une liste d'arguments autorisés) et `installPriviligedFiles`.

Quand l'assistant n'est pas disponible, `caked` est lancé en root par `sudo`, grâce à une règle sudoers **par utilisateur** : `/etc/sudoers.d/caked-pinned-<uid>`, un fichier par utilisateur pour que plusieurs utilisateurs connectés sur le même Mac aient chacun la leur sans s'écraser. Elle nomme cet utilisateur (`#<uid>`), jamais `%everyone`, et le chemin du `caked` fourni :

```text
#501 ALL=(root:wheel) NOPASSWD:SETENV: /Applications/Caker.app/Contents/PlugIns/caked.app/Contents/MacOS/caked
```

Elle est écrite par le `postinstall` du paquet (utilisateur qui installe), par l'assistant (utilisateur appelant) et, en dernier recours, par l'application après une invite administrateur. Les anciens fichiers `/etc/sudoers.d/caked` (règle `%everyone`) et `/etc/sudoers.d/caked-pinned` (un seul utilisateur) sont supprimés. Le nom de fichier ne contient pas de point, car sudo ignore ceux qui en ont.

**Mode `BECOME_PARANOID`.** Compilé avec `BECOME_PARANOID=1` (voir [Développement](development)), le contrôle est plus strict : la règle épingle `caked` par son SHA-256 (`sha256:<empreinte>`), que sudo vérifie à chaque exécution ; elle n'est écrite que si `caked` et chaque dossier jusqu'au `.app` appartiennent à root et ne sont pas modifiables par d'autres ; et l'assistant n'exécute qu'un `caked` appartenant à root. L'empreinte change à chaque version, donc le `postinstall` la réécrit pour chaque utilisateur qui a déjà une règle, l'assistant fait de même, et l'application réécrit la sienne au lancement quand elle ne correspond plus (par exemple après une mise à jour Sparkle). Une copie glissée dans `/Applications` ou un build DerivedData n'a pas de règle dans ce mode.

## Activation de l'application graphique lancée depuis un terminal

Les chemins graphiques de `caked` (`Sources/caked/MainApp.swift`, utilisés par `caker` et par `caked provision --foreground`) sont parfois lancés par fork/exec depuis un terminal ou un script shell plutôt que via le Finder/LaunchServices. macOS n'accorde pas automatiquement à un tel processus le statut de premier plan/actif, et le cycle de vie des scènes `App`/`WindowGroup` de SwiftUI ne compense pas ce comportement à lui seul — la fenêtre peut s'ouvrir entièrement masquée derrière d'autres applications, sans aucun signe visible de son existence. `AppDelegate` contourne ce problème avec un écran de démarrage (`NSWindow` classique, pas une scène SwiftUI `Window`/`WindowGroup`) affiché au niveau `.floating`, associé à trois tentatives d'activation superposées (`NSApp.activate(ignoringOtherApps:)` dans `setDockIcon()`, le niveau `.floating` de la fenêtre de démarrage elle-même, et un appel différé de secours à `NSApp.activate()`), avant de basculer vers la vraie fenêtre `WindowGroup` via `EnvironmentValues().openWindow(id:)` une fois que `applicationDidBecomeActive` se déclenche réellement. Voir le commentaire au-dessus de `AppDelegate` dans `Sources/caked/MainApp.swift` pour le détail complet de chaque étape. Cet écran de démarrage (`SplashScreenView`) vit désormais dans `CakedLib` (`Sources/cakedlib/UI/SplashScreenView.swift`) et est réutilisé tel quel par `VNCApp` (`Sources/cakedlib/UI/VNC/VNCApp.swift`), la fenêtre VNC autonome ouverte par `cakectl provision` — même problème, même solution, sans dupliquer le code.

## Structure du dépôt

```text
Sources/
├── caked/          # Implémentation du démon
│   └── REST/       # Serveur et contrôleurs API REST LXD
├── caker/          # Application graphique (macOS SwiftUI)
├── cakectl/        # Client CLI
├── cakedlib/       # Bibliothèques partagées
├── helper/         # Assistant privilégié (démon SMAppService)
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

<a name="privileges"></a>

## Privileges and passwordless sudo

A few operations need root: starting a vmnet network (and its DHCP/DNS server), importing a Multipass instance that lives under `/var/root`, or installing `/etc/paths.d/com.aldunelabs.caker`. The direct-download build hands them to a **privileged helper** (`Sources/helper`, an `SMAppService` daemon reached over XPC and guarded by an `Authorization` right) that the user approves once in System Settings > General > Login Items. The helper only accepts specific operations: `startNetwork`, `runNetwork`, `importVirtualMachine` (only `--from=multipass`, with two plain names and an allowlist of arguments) and `installPriviligedFiles`.

When the helper is not available, `caked` is run as root through `sudo`, thanks to a **per-user** sudoers rule: `/etc/sudoers.d/caked-pinned-<uid>`, one file per user so that several users logged in on the same Mac each have their own and never overwrite one another's. It names that user (`#<uid>`), never `%everyone`, and the path of the bundled `caked`:

```text
#501 ALL=(root:wheel) NOPASSWD:SETENV: /Applications/Caker.app/Contents/PlugIns/caked.app/Contents/MacOS/caked
```

It is written by the package's `postinstall` (the installing user), by the helper (the calling user) and, as a last resort, by the app after an administrator prompt. The earlier `/etc/sudoers.d/caked` (the `%everyone` rule) and `/etc/sudoers.d/caked-pinned` (a single user) are removed. The file name has no dot, because sudo skips files that contain one.

**`BECOME_PARANOID` mode.** Built with `BECOME_PARANOID=1` (see [Development](development)), the checks are stricter: the rule pins `caked` by its SHA-256 (`sha256:<digest>`), which sudo verifies on every run; it is only written when `caked` and every directory up to the `.app` are owned by root and not writable by others; and the helper only runs a root-owned `caked`. The digest changes with every release, so the `postinstall` rewrites it for each user that already has a rule, the helper does the same, and the app rewrites its own at launch when it no longer matches (for example after a Sparkle update). A copy dragged into `/Applications` or a DerivedData build gets no rule in this mode.

## GUI activation from a terminal launch

`caked`'s GUI paths (`Sources/caked/MainApp.swift`, used by `caker` and by `caked provision --foreground`) are sometimes launched via fork/exec from a terminal or shell script rather than through Finder/LaunchServices. macOS does not automatically grant a process launched that way frontmost/active status, and SwiftUI's `App`/`WindowGroup` scene lifecycle alone doesn't compensate for this — the window can open fully behind other apps with no visible cue that it exists. `AppDelegate` works around this with a plain splash screen (`NSWindow`, not a SwiftUI `Window`/`WindowGroup` scene) shown at `.floating` level, plus three layered activation attempts (`NSApp.activate(ignoringOtherApps:)` in `setDockIcon()`, the splash window's own `.floating` level, and a delayed `NSApp.activate()` fallback), transitioning to the real `WindowGroup` via `EnvironmentValues().openWindow(id:)` once `applicationDidBecomeActive` actually fires. See the comment above `AppDelegate` in `Sources/caked/MainApp.swift` for the full breakdown of each layer. This splash screen (`SplashScreenView`) now lives in `CakedLib` (`Sources/cakedlib/UI/SplashScreenView.swift`) and is reused as-is by `VNCApp` (`Sources/cakedlib/UI/VNC/VNCApp.swift`), the standalone VNC window `cakectl provision` opens — same problem, same fix, without duplicating the code.

## Repository Structure

```text
Sources/
├── caked/          # Daemon implementation
│   └── REST/       # LXD REST API server and controllers
├── caker/          # GUI app (macOS SwiftUI)
├── cakectl/        # CLI client
├── cakedlib/       # Shared libraries
├── helper/         # Privileged helper (SMAppService daemon)
└── grpc/           # gRPC definitions and generated code
scripts/            # Some useful scripts to build and other
webui/              # React/Vite web UI
```

</div>
