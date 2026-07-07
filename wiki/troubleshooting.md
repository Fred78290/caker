<!-- markdownlint-disable MD033 MD024 -->

<div id="content-fr" style="display:none" markdown="1">

# Dépannage

## Échec des scripts de build signés

Symptômes :
- `./Scripts/build-signed-debug.sh` ou `./Scripts/build-signed-release.sh` se termine avec une erreur

Vérifications :
- le profil de provisioning existe dans `Resources/`
- les fichiers d'entitlements sont présents et valides
- l'identité de signature locale d'Xcode est configurée

## Problèmes de résolution des packages Swift

Symptômes :
- la résolution des dépendances boucle ou échoue

Vérifications :
- relancez la résolution des packages depuis Xcode
- exécutez `swift build -Xswiftc -D -Xswiftc SPARKLE` depuis la racine du dépôt
- videz le cache de build/derived data si nécessaire

## Échec de la publication du wiki

Symptômes :
- `publish-wiki.sh` indique qu'il ne peut pas accéder à `<repo>.wiki.git`

Vérifications :
- la fonctionnalité wiki est activée dans les paramètres du dépôt GitHub
- le jeton existe : `GITHUB_TOKEN` ou `GH_TOKEN`
- mode SSH si nécessaire : `USE_SSH=1`

## L'installation de macOS 27 échoue ou se bloque

**Symptômes :**
- L'installation se bloque à environ 78 % et ne se termine jamais (build App Store, ou hôte < macOS 26).
- Erreur : « Couldn't find a restorable device to install onto. »
- L'installation démarre mais la VM ne s'arrête jamais après la fin.

**Vérifications :**

1. **Vérifiez que vous utilisez un build hors App Store** — le backend AMRestore n'est disponible qu'en dehors de l'App Store. Le build App Store se replie sur `VZMacOSInstaller`, connu pour échouer vers 78 % pour les invités macOS 27 sur des hôtes macOS 26.

2. **Vérifiez que l'hôte est en macOS 26 ou ultérieur** — le chemin AMRestore nécessite les API `macOS 26.0`.

3. **Vérifiez si l'ECID peut être résolu** — le moteur AMRestore identifie la VM par son ECID (intégré à l'identifiant machine). Si Caker journalise « Cannot determine device ECID from VM configuration », l'identifiant machine de la VM est peut-être manquant ou corrompu. Supprimez et recréez la VM.

4. **Consultez les journaux de restauration** — quatre fichiers journaux sont écrits dans `~/Library/Application Support/Caker/VirtualInstall/Logs/`. Examinez d'abord `global.log` pour les erreurs de haut niveau, puis `host.log` pour la trace de restauration côté hôte.

5. **Appareil introuvable en 5 secondes** — si Caker journalise « Couldn't find device with ECID <n> », la VM n'est pas entrée en mode DFU à temps. Vérifiez qu'aucun autre processus ne bloque la VM ou n'empêche son démarrage.

6. **Forcer l'activation du backend AMRestore pour le diagnostic :**
   ```bash
   defaults write com.aldunelabs.Caker CakerForceVirtualInstallBackend -bool true
   ```
   Cela contourne la vérification de version et utilise toujours AMRestore, ce qui peut aider à isoler si le problème vient de la sélection du backend ou de la restauration elle-même.

7. **Vérifiez l'accessibilité du serveur de signature** — AMRestore personnalise l'IPSW auprès de `gs.apple.com:443`. Assurez-vous que cet hôte est joignable depuis le Mac (pas de pare-feu ou de proxy d'entreprise le bloquant).

## L'agrandissement d'un disque ASIF échoue dans la version App Store (sandboxée)

**Symptômes :**
- `configure --disk-size <GiB>` sur une VM avec un disque ASIF échoue avec : `Resize disk is not available in sandboxed mode with command line interface, ...`
- L'application Caker affiche une alerte avec une commande `diskutil image resize` au lieu de redimensionner le disque (connexion distante ou service).

**Cause :**

La version App Store s'exécute dans le App Sandbox de macOS, ce qui empêche l'interface en ligne de commande et le service en arrière-plan d'invoquer `diskutil image resize` sur les disques ASIF. Il s'agit d'une restriction du sandbox, pas d'un bug.

**Solutions :**

1. **Utilisez l'application Caker** pour redimensionner le disque depuis l'interface des paramètres de la VM, ou
2. **Exécutez la commande manuellement** dans Terminal, avec la VM arrêtée :
   ```bash
   diskutil image resize --size=<new-size>G "$(caked home)/vms/<vm-name>.cakedvm/disk.img"
   ```
   L'alerte / le message d'erreur affiche la commande exacte à exécuter pour votre VM.

Les disques au format raw et le build en téléchargement direct ne sont pas concernés. Voir [Formats de disque : raw et ASIF](command-summary#disk-formats-raw-and-asif).

## Commandes utiles

- `swift build -Xswiftc -D -Xswiftc SPARKLE`
- `GH_TOKEN="${GITHUB_TOKEN}" ./Scripts/publish-wiki.sh Fred78290 caker`
- `USE_SSH=1 ./Scripts/publish-wiki.sh Fred78290 caker`

</div>

<div id="content-en" style="display:block" markdown="1">

# Troubleshooting

## Build signed scripts fail

Symptoms:
- `./Scripts/build-signed-debug.sh` or `./Scripts/build-signed-release.sh` exits with an error

Checks:
- provisioning profile exists in `Resources/`
- entitlements files are present and valid
- local Xcode signing identity is configured

## Swift package resolution issues

Symptoms:
- dependency resolution loops or fails

Checks:
- run package resolution again from Xcode
- run `swift build -Xswiftc -D -Xswiftc SPARKLE` from the repository root
- clear derived data/build cache if needed

## Wiki publication fails

Symptoms:
- `publish-wiki.sh` says it cannot access `<repo>.wiki.git`

Checks:
- wiki feature is enabled in GitHub repository settings
- token exists: `GITHUB_TOKEN` or `GH_TOKEN`
- SSH mode if needed: `USE_SSH=1`

## macOS 27 installation fails or stalls

**Symptoms:**
- Installation stalls at ~78% and never completes (App Store build, or host < macOS 26).
- Error: "Couldn't find a restorable device to install onto."
- Installation starts but the VM never shuts down after completion.

**Checks:**

1. **Verify you are using a non-App Store build** — the AMRestore backend is only available outside the App Store. The App Store build falls back to `VZMacOSInstaller`, which is known to fail at ~78% for macOS 27 guests on macOS 26 hosts.

2. **Verify the host is macOS 26 or later** — the AMRestore path requires `macOS 26.0` APIs.

3. **Check whether the ECID can be resolved** — the AMRestore engine identifies the VM by its ECID (embedded in the machine identifier). If Caker logs `"Cannot determine device ECID from VM configuration"`, the VM's machine identifier may be missing or corrupted. Delete and recreate the VM.

4. **Check the restore logs** — four log files are written to `~/Library/Application Support/Caker/VirtualInstall/Logs/`. Review `global.log` first for top-level errors, then `host.log` for the host-side restore trace.

5. **Device not found within 5 seconds** — if Caker logs `"Couldn't find device with ECID <n>"`, the VM did not enter DFU mode in time. Confirm that no other process is holding the VM or preventing it from starting.

6. **Force-enable the AMRestore backend for diagnosis:**
   ```bash
   defaults write com.aldunelabs.Caker CakerForceVirtualInstallBackend -bool true
   ```
   This bypasses the version check and always uses AMRestore, which can help isolate whether the issue is in backend selection or in the restore itself.

7. **Check signing server reachability** — AMRestore personalizes the IPSW against `gs.apple.com:443`. Make sure that host is reachable from the Mac (no corporate firewall or proxy blocking it).

## ASIF disk resize fails in the App Store (sandboxed) version

**Symptoms:**
- `configure --disk-size <GiB>` on a VM with an ASIF disk fails with: `Resize disk is not available in sandboxed mode with command line interface, ...`
- The Caker application shows an alert with a `diskutil image resize` command instead of resizing the disk (remote or service connection).

**Cause:**

The App Store version runs inside the macOS App Sandbox, which prevents the command-line interface and the background service from invoking `diskutil image resize` on ASIF disks. This is a sandbox restriction, not a bug.

**Solutions:**

1. **Use the Caker application** to resize the disk from the VM settings UI, or
2. **Run the command manually** in Terminal, with the VM stopped:
   ```bash
   diskutil image resize --size=<new-size>G "$(caked home)/vms/<vm-name>.cakedvm/disk.img"
   ```
   The alert / error message shows the exact command to run for your VM.

Raw-format disks and the direct-download build are not affected. See [Disk formats: raw and ASIF](command-summary#disk-formats-raw-and-asif).

## Useful commands

- `swift build -Xswiftc -D -Xswiftc SPARKLE`
- `GH_TOKEN="${GITHUB_TOKEN}" ./Scripts/publish-wiki.sh Fred78290 caker`
- `USE_SSH=1 ./Scripts/publish-wiki.sh Fred78290 caker`

</div>
