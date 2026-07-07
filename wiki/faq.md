<!-- markdownlint-disable MD033 MD024 -->

<div id="content-fr" style="display:none" markdown="1">

# FAQ

## Questions générales

### Quelle est la différence entre `caked` et `cakectl` ?

- `caked` est le démon d'arrière-plan qui effectue les opérations.
- `cakectl` est le client CLI utilisé pour envoyer des commandes à `caked`.

Voyez cela comme Docker : `caked` est comme le démon Docker, et `cakectl` est comme la commande CLI `docker`.

## Sur quelle branche baser mon travail ?

- Utilisez `main` comme branche de base pour les contributions à ce dépôt.

### Quelles plateformes sont supportées ?

Actuellement, Caker ne supporte que macOS en raison de sa dépendance au framework Virtualization d'Apple. Le support de Linux et Windows n'est pas prévu pour le moment.

## Questions de développement

### Pourquoi la publication du wiki échoue-t-elle avec « repository not found » ?

Causes courantes :
- La fonctionnalité wiki n'est pas activée dans les paramètres du dépôt.
- Jeton d'authentification GitHub manquant ou invalide.
- Permissions insuffisantes pour l'accès au wiki d'un dépôt privé.

## Comment publier rapidement les pages du wiki ?

```bash
# Avec authentification par jeton
GH_TOKEN="${GITHUB_TOKEN}" ./Scripts/publish-wiki.sh Fred78290 caker

# Avec authentification SSH
USE_SSH=1 ./Scripts/publish-wiki.sh Fred78290 caker
```

### Pourquoi les scripts de build échouent-ils avec des erreurs de signature ?

Cela se produit généralement lorsque :
- Les profils de provisioning sont manquants ou expirés
- Les certificats de signature ne sont pas correctement configurés
- Les fichiers d'entitlements sont invalides

Consultez le guide de [Dépannage](troubleshooting) pour les solutions.

## Questions sur l'installation de macOS

### Pourquoi l'installation de macOS 27 échoue-t-elle à environ 78 % avec `VZMacOSInstaller` ?

Il s'agit d'une régression connue de `VZMacOSInstaller` ([utmapp/UTM#7746](https://github.com/utmapp/UTM/issues/7746)) qui affecte les invités macOS 27 installés sur des hôtes macOS 26. Caker contourne automatiquement ce problème en basculant vers le backend `AppleMobileDeviceRestore` (AMRestore) dès que l'IPSW cible macOS 27 ou une version ultérieure.

### Comment Caker choisit-il quel backend d'installation utiliser ?

Le choix est effectué au début de chaque installation `build` (IPSW) :

1. Si `CakerForceVirtualInstallBackend` vaut `true` dans UserDefaults → AMRestore.
2. Si `operatingSystemVersion.majorVersion >= 27` de l'IPSW → AMRestore.
3. Sinon → `VZMacOSInstaller`.

### L'installation de macOS 27 est-elle disponible dans le build App Store ?

Oui. Le chemin AMRestore — qui repose sur le framework privé `AppleMobileDeviceRestore` et le démon `com.apple.mobile.restored` — est désormais activé dans le build App Store via le feature flag `USE_VIRTUAL_INSTALL_BACKEND`.

### Comment puis-je forcer le backend AMRestore pour les tests ?

```bash
defaults write com.aldunelabs.Caker CakerForceVirtualInstallBackend -bool true
```

Supprimez-le une fois terminé :

```bash
defaults delete com.aldunelabs.Caker CakerForceVirtualInstallBackend
```

### Où puis-je trouver les journaux de restauration ?

AMRestore écrit quatre fichiers journaux dans `~/Library/Application Support/Caker/VirtualInstall/Logs/` :

| Fichier | Contenu |
| --- | --- |
| `global.log` | Messages globaux du moteur AMRestore |
| `host.log` | Progression de la restauration côté hôte |
| `device.log` | Messages provenant de l'appareil virtuel |
| `serial.log` | Sortie série de la VM pendant la restauration |

## Limitations App Store

### Puis-je utiliser des périphériques bloc physiques (mode disque raw) dans la version App Store ?

Non. La version App Store s'exécute dans le App Sandbox de macOS, ce qui empêche l'acquisition du verrou exclusif (`O_EXLOCK`) requis par Caker pour ouvrir un périphérique bloc physique (`/dev/diskN`). Cette restriction s'applique même si le sandbox accorde un accès en lecture-écriture temporaire à `/dev`.

Opérations concernées :
- `caked spawn <name> /dev/diskN` — échoue avec une erreur de permission.
- `caked spawn-start <name> /dev/diskN` — idem.
- Toute configuration de VM référençant un chemin `/dev/diskN` comme disque racine ou supplémentaire.

Les fichiers image raw (`.raw`, `.img`, `.qcow2` après conversion, etc.) stockés dans votre répertoire personnel ne sont pas concernés et fonctionnent normalement dans la version App Store.

Si vous devez démarrer une VM directement depuis un périphérique bloc physique, utilisez le **build en téléchargement direct** de Caker disponible sur la [page des releases GitHub](https://github.com/Fred78290/caker/releases).

### Puis-je redimensionner un disque ASIF depuis la ligne de commande dans la version App Store ?

Non. Le redimensionnement d'un disque ASIF (Apple Sparse Image Format) repose sur `diskutil image resize`, que l'App Sandbox n'autorise pas l'interface en ligne de commande `caked`/`cakectl` ni le service en arrière-plan à invoquer. L'exécution de `configure --disk-size` sur un disque ASIF échoue avec une erreur explicite dans la version sandboxée.

Solutions de contournement :

- **Utilisez l'application Caker** — le redimensionnement depuis l'interface des paramètres de la VM fonctionne normalement, ou
- **Exécutez la commande manuellement** dans Terminal, avec la VM arrêtée :

```bash
diskutil image resize --size=<new-size>G "$(caked home)/vms/<vm-name>.cakedvm/disk.img"
```

Lorsque le redimensionnement est refusé, l'application Caker affiche la commande exacte à exécuter pour votre VM. Les disques au format raw ne sont pas concernés, pas plus que le build en téléchargement direct. Voir [Formats de disque : raw et ASIF](command-summary#disk-formats-raw-and-asif-fr) pour plus de détails.

## Questions d'utilisation

### Puis-je exécuter plusieurs VM simultanément ?

Oui, Caker permet d'exécuter plusieurs VM en parallèle, dans la limite des ressources disponibles sur votre système (CPU, mémoire, espace disque).

### Comment configurer le réseau pour les VM ?

Caker prend en charge plusieurs modes réseau :
- **Mode pont (bridge)** : accès direct au réseau de l'hôte
- **Mode hébergé (hosted)** : communication VM-hôte
- **Mode NAT** : accès Internet sortant avec redirection de ports

Voir le [Résumé des commandes](command-summary) pour les commandes de configuration réseau.

### Comment transférer des fichiers entre l'hôte et la VM ?

Vous pouvez utiliser :
- Des points de montage configurés lors de la création de la VM
- La commande `exec` pour exécuter des outils de transfert de fichiers
- Des protocoles de partage de fichiers réseau

### Quels formats d'image Caker supporte-t-il ?

Caker fonctionne avec :
- Des images de VM personnalisées construites avec Caker
- Des images provenant de registres configurés (OCI, simplestream, HTTPS)
- Des images importées depuis d'autres plateformes de virtualisation (via la commande `import`)
- Des images QCOW2 et VMDK converties au format raw avec `caked convert`

Les disques racines peuvent utiliser le format **raw** ou **ASIF** (Apple Sparse Image Format, macOS 26+) — voir [Formats de disque : raw et ASIF](command-summary#disk-formats-raw-and-asif-fr).

## Questions d'intégration

### Puis-je utiliser Caker dans des pipelines CI/CD ?

Oui, Caker est conçu pour fonctionner dans des environnements automatisés. L'interface CLI (`cakectl`) fournit des commandes scriptables pour la gestion du cycle de vie des VM.

### Y a-t-il un support de l'API REST ?

Oui. `caked` inclut un serveur API REST optionnel compatible LXD. Démarrez-le avec l'option `--rest` :

```bash
caked service listen --rest
```

Cela expose une API HTTP/HTTPS sur `/1.0/instances`, `/1.0/networks`, `/1.0/images`, et d'autres points de terminaison compatibles LXD. Le port par défaut est `8443` pour HTTPS (mTLS) et `8080` pour HTTP ; modifiable avec `--rest-port`.

L'interface principale reste gRPC (`cakectl` ↔ `caked`), mais l'API REST permet l'intégration avec des outils compatibles LXD et l'interface Web fournie.

Voir la page [Architecture](architecture) pour une référence complète des points de terminaison.

### Comment Caker se compare-t-il aux autres outils de virtualisation ?

Caker est spécifiquement conçu pour :
- les environnements macOS utilisant le framework Virtualization
- les workflows et l'automatisation pour développeurs
- l'intégration native Swift
- la gestion de VM pilotée par configuration

Il se différencie d'outils comme Docker (conteneurs) ou VirtualBox (VM multiplateformes) en se concentrant sur la virtualisation macOS native avec une interface conviviale pour les développeurs.

## Besoin d'aide supplémentaire

Vous ne trouvez pas la réponse à votre question ici ?

1. Consultez le guide de [Dépannage](troubleshooting)
2. Consultez le [Résumé des commandes](command-summary) pour les détails d'utilisation
3. Visitez la section [Développement](development) pour les informations de contribution
4. Ouvrez un ticket sur [GitHub](https://github.com/Fred78290/caker/issues)

</div>

<div id="content-en" style="display:block" markdown="1">

# FAQ

## General Questions

## What is the difference between `caked` and `cakectl`?

- `caked` is the background daemon that performs operations.
- `cakectl` is the CLI client used to send commands to `caked`.

Think of it like Docker: `caked` is like the Docker daemon, and `cakectl` is like the `docker` CLI command.

## What branch should I base my work on?

- Use `main` as the base branch for contributions in this repository.

### What platforms are supported?

Currently, Caker only supports macOS due to its reliance on the Apple Virtualization framework. Linux and Windows support is not planned at this time.

## Development Questions

## Why does wiki publishing fail with “repository not found”?

Common causes:
- Wiki feature is not enabled in repository settings.
- Missing or invalid GitHub authentication token.
- Insufficient permissions for private repository wiki access.

## How do I publish wiki pages quickly?

```bash
# Using token authentication
GH_TOKEN="${GITHUB_TOKEN}" ./Scripts/publish-wiki.sh Fred78290 caker

# Using SSH authentication
USE_SSH=1 ./Scripts/publish-wiki.sh Fred78290 caker
```

### Why do build scripts fail with signing errors?

This typically happens when:
- Provisioning profiles are missing or expired
- Signing certificates aren't properly configured
- Entitlements files are invalid

Check the [Troubleshooting](troubleshooting) guide for solutions.

## macOS Installation Questions

### Why does macOS 27 installation fail at ~78% with `VZMacOSInstaller`?

This is a known `VZMacOSInstaller` regression ([utmapp/UTM#7746](https://github.com/utmapp/UTM/issues/7746)) that affects macOS 27 guests installed on macOS 26 hosts. Caker works around this automatically by switching to the `AppleMobileDeviceRestore` (AMRestore) backend whenever the IPSW targets macOS 27 or later.

### How does Caker decide which installation backend to use?

The choice is made at the start of each `build` (IPSW) install:

1. If `CakerForceVirtualInstallBackend` is `true` in UserDefaults → AMRestore.
2. If the IPSW's `operatingSystemVersion.majorVersion >= 27` → AMRestore.
3. Otherwise → `VZMacOSInstaller`.

### Is macOS 27 installation available in the App Store build?

Yes. The AMRestore path — which relies on the private `AppleMobileDeviceRestore` framework and the `com.apple.mobile.restored` daemon — is now enabled in the App Store build via the `USE_VIRTUAL_INSTALL_BACKEND` feature flag.

### How can I force the AMRestore backend for testing?

```bash
defaults write com.aldunelabs.Caker CakerForceVirtualInstallBackend -bool true
```

Remove it when you are done:

```bash
defaults delete com.aldunelabs.Caker CakerForceVirtualInstallBackend
```

### Where can I find the restore logs?

AMRestore writes four log files to `~/Library/Application Support/Caker/VirtualInstall/Logs/`:

| File | Content |
| --- | --- |
| `global.log` | Global AMRestore engine messages |
| `host.log` | Host-side restore progress |
| `device.log` | Messages from the virtual device |
| `serial.log` | Serial output from the VM during restore |

## App Store Limitations

### Can I use physical block devices (raw disk mode) in the App Store version?

No. The App Store version runs inside the macOS App Sandbox, which prevents acquiring the exclusive lock (`O_EXLOCK`) that Caker requires when opening a physical block device (`/dev/diskN`). This restriction applies even though the sandbox grants temporary read-write access to `/dev`.

Affected operations:
- `caked spawn <name> /dev/diskN` — fails with a permission error.
- `caked spawn-start <name> /dev/diskN` — same.
- Any VM configuration that references a `/dev/diskN` path as a root or additional disk.

Raw image files (`.raw`, `.img`, `.qcow2` after conversion, etc.) stored in your home directory are not affected and work normally in the App Store version.

If you need to boot a VM directly from a physical block device, use the **direct-download build** of Caker available from the [GitHub releases page](https://github.com/Fred78290/caker/releases).

### Can I resize an ASIF disk from the command line in the App Store version?

No. Resizing an ASIF (Apple Sparse Image Format) disk relies on `diskutil image resize`, which the App Sandbox does not allow the `caked`/`cakectl` command-line interface or the background service to invoke. Running `configure --disk-size` on an ASIF disk fails with an explicit error in the sandboxed version.

Workarounds:

- **Use the Caker application** — resizing from the VM settings UI works normally, or
- **Run the command manually** in Terminal, with the VM stopped:

```bash
diskutil image resize --size=<new-size>G "$(caked home)/vms/<vm-name>.cakedvm/disk.img"
```

When the resize is refused, the Caker application shows the exact command to run for your VM. Raw-format disks are not affected, and neither is the direct-download build. See [Disk formats: raw and ASIF](command-summary#disk-formats-raw-and-asif) for details.

## Usage Questions

### Can I run multiple VMs simultaneously?

Yes, Caker supports running multiple VMs concurrently, limited by your system's available resources (CPU, memory, disk space).

### How do I configure networking for VMs?

Caker supports multiple networking modes:
- **Bridge mode**: Direct access to host network
- **Hosted mode**: VM-to-host communication
- **NAT mode**: Outbound internet access with port forwarding

See the [Command Summary](command-summary) for network configuration commands.

### How do I transfer files between host and VM?

You can use:
- Mount points configured during VM creation
- The `exec` command to run file transfer tools
- Network file sharing protocols

### What image formats does Caker support?

Caker works with:
- Custom VM images built with Caker
- Images from configured registries (OCI, simplestream, HTTPS)
- Imported images from other virtualization platforms (via `import` command)
- QCOW2 and VMDK images converted to raw format with `caked convert`

Root disks can use the **raw** or **ASIF** (Apple Sparse Image Format, macOS 26+) format — see [Disk formats: raw and ASIF](command-summary#disk-formats-raw-and-asif).

## Integration Questions

### Can I use Caker in CI/CD pipelines?

Yes, Caker is designed to work in automated environments. The CLI interface (`cakectl`) provides scriptable commands for VM lifecycle management.

### Is there REST API support?

Yes. `caked` includes an optional LXD-compatible REST API server. Start it with the `--rest` flag:

```bash
caked service listen --rest
```

This exposes an HTTP/HTTPS API at `/1.0/instances`, `/1.0/networks`, `/1.0/images`, and other LXD-compatible endpoints. The default port is `8443` for HTTPS (mTLS) and `8080` for HTTP; override with `--rest-port`.

The primary interface remains gRPC (`cakectl` ↔ `caked`), but the REST API allows integration with LXD-compatible tooling and the bundled web UI.

See the [Architecture](architecture) page for a full endpoint reference.

### How does Caker compare to other virtualization tools?

Caker is specifically designed for:
- macOS environments using the Virtualization framework
- Developer workflows and automation
- Swift/native integration
- Configuration-driven VM management

It differs from tools like Docker (containers) or VirtualBox (cross-platform VMs) by focusing on native macOS virtualization with a developer-friendly interface.

## Getting More Help

Don't see your question answered here?

1. Check the [Troubleshooting](troubleshooting) guide
2. Review the [Command Summary](command-summary) for usage details
3. Visit the [Development](development) section for contribution info
4. Open an issue on [GitHub](https://github.com/Fred78290/caker/issues)

</div>
