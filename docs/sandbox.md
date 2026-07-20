---
layout: default
title: Sandbox
nav_order: 11
---

<!-- markdownlint-disable MD033 MD024 -->

<div class="lang-fr" style="display:none" markdown="1">

# Sandbox (bac à sable)

Caker propose deux versions : une version en téléchargement direct, sans App Sandbox, et une version App Store qui s'exécute dans l'App Sandbox de macOS (entitlement `com.apple.security.app-sandbox`). La version sandboxée ne peut lire et écrire que dans un ensemble de répertoires précis, et Caker applique en plus ses propres restrictions pour deux fonctionnalités liées aux VM : les sockets Unix et les répertoires partagés Virtio-FS. Cette page documente les deux.

## Vérifier si vous êtes en version sandboxée

```bash
cakectl sandbox                 # sandboxed: true / false
caked sandbox --format json     # {"sandboxed": true}
```

`Bundle.isApplicationSandboxed` est la source de vérité unique utilisée dans tout le code ; elle est calculée une seule fois (puis mise en cache) à partir de la signature de code du binaire en cours d'exécution, en vérifiant la présence de l'entitlement `com.apple.security.app-sandbox`.

## Chemins des sockets Unix

Un socket Unix se lie via une structure `sockaddr_un`, dont le champ `sun_path` est limité par macOS à 104 octets, terminateur NUL compris. Caker se réserve une marge de 103 octets (`URL.maxSocketPathLength`) pour la cible complète `unix://<chemin>`.

Les répertoires de VM peuvent être assez imbriqués (`~/Library/.../vms/<nom>/...`), si bien qu'un chemin de socket complet par VM (socket de l'agent, de la console, de contrôle réseau, du service `vmrun`) peut facilement dépasser cette marge dès que le nom de la VM ou du réseau est un peu long. Le cas échéant, `URL.socketPath(name:)` se rabat sur un chemin bien plus court :

- **Version sandboxée** : le chemin court est reconstruit directement sous le répertoire personnel du conteneur du sandbox, sous la forme `<dernier composant du chemin d'origine>.<name>` — sans sous-répertoire relatif au home, puisque seul le conteneur lui-même est garanti accessible en écriture.
- **Version non sandboxée** : le chemin court se rabat plutôt sur `NSTemporaryDirectory()`.

C'est cette même marge qui impose une limite de longueur aux noms de VM et de réseau : `URL.maxVirtualMachineNameLength` et `URL.maxNetworkNameLength` sont tous deux calculés comme `maxSocketPathLength` moins la longueur du chemin de votre répertoire personnel, moins les suffixes fixes ajoutés par Caker (`vms`/`cakedvm` ou `net`) — plus votre chemin home/conteneur est profond, plus le nom de VM ou de réseau autorisé doit être court.

Par ailleurs, les sockets définis par l'utilisateur et attachés à une VM (`cakectl config vm --socket <url>`) subissent une vérification plus stricte : quand le processus en cours est sandboxé *et* que ce n'est pas le runner de VM intégré à Caker.app (`Bundle.fileAccessRestricted`), tout socket dont le chemin de liaison sort du répertoire personnel du conteneur du sandbox est abandonné — silencieusement, avec seulement un avertissement dans les logs (`.fileAccessRestricted is enabled, skipping socket: ...`) — plutôt que de faire échouer le démarrage de la VM. L'App Sandbox ne peut tout simplement pas créer un fichier de socket Unix à un chemin arbitraire du disque.

## Répertoires partagés et disques additionnels

Le partage de répertoire (`-v`/`--mount <source>[:<destination>][,ro][,name=][,uid=][,gid=]`, basé sur `VZSharedDirectory`/Virtio-FS) et l'attachement de disques additionnels (disques supplémentaires au-delà du disque de démarrage) passent par le même filtre : `Utilities.isValidSharePoint`.

Hors du sandbox, ou lorsque l'exécution a lieu dans le processus GUI de Caker.app lui-même, n'importe quel chemin est autorisé — l'application peut déjà y accéder, ou l'utilisateur l'a choisi via un panneau de fichiers qui accorde un bookmark à portée de sécurité. Dans la CLI/le démon sandboxé (`fileAccessRestricted == true`), seuls ces chemins sont acceptés :

- `~/Documents`, `~/Download`, `~/Public` — les répertoires d'exception du sandbox propres à macOS, toujours accessibles en lecture/écriture par n'importe quelle application sandboxée
- Tout chemin sous le répertoire personnel du conteneur du sandbox de l'application elle-même

Tout le reste — un volume externe, un chemin sous un répertoire de projet, ou un dossier relatif au home absent de cette liste — est silencieusement retiré de la configuration de la VM (là encore, un simple avertissement dans les logs), sans erreur bloquante. La VM démarre quand même ; elle se retrouve simplement sans ce montage ou ce disque.

Notez que cette liste d'autorisation est plus restreinte que les exceptions de lecture seule/lecture-écriture relatives au home déclarées dans les entitlements de l'application (`~/.ssh/`, `~/.tart/`, `~/.docker/`, répertoires de support d'UTM/VirtualBuddy, etc.) — celles-ci existent pour permettre à Caker d'*importer* des VM/clés depuis d'autres outils, elles n'étendent pas ce que vous pouvez passer à `--mount` ou attacher comme disque additionnel.

Dans l'interface graphique de Caker.app, le sélecteur de montage démarre par défaut sur `~/Public` en version sandboxée (au lieu de tout votre répertoire personnel), pour indiquer un dossier garanti fonctionnel.

## Voir aussi

- [Résumé des commandes](command-summary) — référence complète des options `--mount`, `--socket`, `--disk`
- [Dépannage](troubleshooting) — redimensionnement de disque ASIF et autres échecs propres au sandbox
- [FAQ](faq) — différences fonctionnelles entre version sandboxée et version en téléchargement direct

</div>

<div class="lang-en" style="display:block" markdown="1">

# Sandbox

Caker ships two builds: a direct-download build with no App Sandbox, and an App Store build that runs inside the macOS App Sandbox (`com.apple.security.app-sandbox`). The sandboxed build can only read and write a fixed set of locations, and Caker enforces additional restrictions of its own on top of that for two VM-facing features: Unix domain sockets and Virtio-FS shared directories. This page documents both.

## Checking whether you're sandboxed

```bash
cakectl sandbox                 # sandboxed: true / false
caked sandbox --format json     # {"sandboxed": true}
```

`Bundle.isApplicationSandboxed` is the single source of truth used throughout the codebase; it's derived once (and cached) from the running binary's code signature, by checking for the `com.apple.security.app-sandbox` entitlement.

## Unix domain socket paths

Unix domain sockets are bound through a `sockaddr_un` struct, whose `sun_path` field macOS limits to 104 bytes including the NUL terminator. Caker uses a 103-byte budget (`URL.maxSocketPathLength`) for the full `unix://<path>` target.

VM directories can nest fairly deep (`~/Library/.../vms/<name>/...`), so a fully-qualified per-VM socket path (agent socket, console socket, network control socket, VM-run service socket) can easily exceed that budget once you factor in a long VM or network name. When it does, `URL.socketPath(name:)` falls back to a much shorter path:

- **Sandboxed build**: the short path is rebuilt directly under the sandbox container's home directory, as `<original last path component>.<name>` — no home-relative subdirectories, since only the container itself is guaranteed writable.
- **Non-sandboxed build**: the short path falls back to `NSTemporaryDirectory()` instead.

This same budget is why VM names and network names have a length ceiling: `URL.maxVirtualMachineNameLength` and `URL.maxNetworkNameLength` are both computed as `maxSocketPathLength` minus your home directory path length minus the fixed suffixes Caker appends (`vms`/`cakedvm` or `net`) — the deeper your home/container path, the shorter a VM or network name is allowed to be.

Separately, user-defined sockets attached to a VM (`cakectl config vm --socket <url>`) are subject to a stricter check: when the running process is sandboxed *and* not the embedded Caker.app VM runner (`Bundle.fileAccessRestricted`), any socket whose bind path resolves outside your sandbox container's home directory is dropped — silently, with only a warning logged (`.fileAccessRestricted is enabled, skipping socket: ...`) — rather than failing the VM start. The App Sandbox simply cannot create a Unix socket file at an arbitrary path on disk.

## Shared directories and additional disks

Directory sharing (`-v`/`--mount <source>[:<destination>][,ro][,name=][,uid=][,gid=]`, backed by `VZSharedDirectory`/Virtio-FS) and additional disk attachments (extra disk images beyond the boot disk) go through the same gate: `Utilities.isValidSharePoint`.

Outside the sandbox, or when running inside Caker.app's own GUI process, any path is allowed — the app can already read it, or the user picked it through a file panel that grants a security-scoped bookmark. In the sandboxed CLI/daemon (`fileAccessRestricted == true`), only these are accepted:

- `~/Documents`, `~/Download`, `~/Public` — macOS's own sandbox-exception folders, always readable/writable by any sandboxed app
- Any path under the app's own sandbox container home directory

Anything else — an external volume, a path under a project directory, or a home-relative folder not in that list — is silently dropped from the VM configuration (again just a warning log), not rejected with an error. The VM still starts; it simply comes up without that mount or disk.

Note that this allow-list is narrower than the read-only/read-write home-relative exceptions declared in the app's entitlements (`~/.ssh/`, `~/.tart/`, `~/.docker/`, UTM/VirtualBuddy support directories, etc.) — those exist to let Caker *import* VMs/keys from other tools, they don't extend what you can pass to `--mount` or attach as an extra disk.

In the Caker.app GUI, the mount picker defaults to browsing `~/Public` when sandboxed (instead of your full home directory) as a hint toward a folder that's guaranteed to work.

## See also

- [Command Summary](command-summary) — full `--mount`, `--socket`, `--disk` flag reference
- [Troubleshooting](troubleshooting) — ASIF disk resize and other sandbox-only failures
- [FAQ](faq) — sandboxed vs. direct-download build feature differences

</div>

{% include lang-toggle.html %}
