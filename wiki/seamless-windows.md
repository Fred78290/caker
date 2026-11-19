<!-- markdownlint-disable MD033 MD024 -->

<div class="lang-fr" style="display:none" markdown="1">

# Fenêtres intégrées (seamless) pour les VM Linux

Une VM Linux peut afficher ses fenêtres comme de vraies fenêtres macOS, à la manière de WSLg : un compositeur Wayland dans l'invité envoie une image par fenêtre (fenêtre principale ou menu contextuel) par **vsock**, et l'hôte les affiche chacune dans sa propre `NSWindow` en renvoyant le clavier et la souris. Il n'y a ni RDP ni périphérique virtio personnalisé. Le compositeur et l'agent côté invité sont dans [cakeagent](https://github.com/Fred78290/cakeagent/wiki/seamless-windows).

Les fenêtres portent le préfixe `[<vm>]` dans leur titre (`[myvm] foot`), et `<utilisateur> :` après lui pour un compte autre que celui de la VM.

## Prérequis

- Une VM **Linux** (pas macOS, pas Windows) avec un cakeagent récent dans l'invité (**v1.0.321 ou plus** ; un agent plus ancien ignore l'option et n'affiche rien).
- La VM tourne et son agent répond.

## Activer

```bash
caked build --seamless ubuntu-vm            # dès la création : le seed cloud-init installe le compositeur
cakectl launch --seamless ubuntu-vm
cakectl configure ubuntu-vm --seamless true # plus tard : pris en compte au prochain démarrage, sans reconstruire
```

Dans Caker.app, c'est la case « Fenêtres intégrées » de l'assistant de création et des réglages de la VM. L'agent est réenregistré au démarrage suivant quand les options de son service ont changé (fenêtres intégrées, montages) : l'opération passe par l'agent lui-même, pas par SSH.

## Afficher les fenêtres

Un seul processus affiche les fenêtres d'une VM à la fois (un verrou sur le socket `smls` de la VM) :

| VM exécutée par | Qui affiche les fenêtres |
| --- | --- |
| Caker.app (mode `app`) | Caker.app |
| `caked start` / `caked vmrun` | le processus `vmrun`, sans icône dans le Dock |
| un service `caked` (local ou distant) | un client : Caker.app, ou `cakectl seamless <vm>` (tunnel gRPC) |

`cakectl sh`, `cakectl exec` et `cakectl app run` affichent eux-mêmes les fenêtres d'une VM seamless (`--seamless false` désactive l'affichage pour `sh`/`exec`). Quand un autre processus les affiche déjà, `sh`/`exec` continuent et reprennent les fenêtres dès que l'autre les lâche ; `app run` démarre simplement l'application.

## Utilisateurs

`exec` et `sh` s'exécutent sous le compte de la VM (voir [`exec` et `sh`](command-summary)), ce qui permet à un programme graphique lancé depuis ce shell de s'ouvrir sur l'hôte. Un autre compte (`--user`) obtient son propre compositeur à la demande.

## Applications et lanceurs

On peut démarrer les applications installées dans l'invité sans passer par un terminal :

```bash
cakectl app list myvm                         # applications (.desktop) de l'invité
cakectl app run myvm firefox                  # démarre Firefox, ses fenêtres s'affichent sur le Mac
cakectl app create-launcher myvm firefox      # crée ~/Applications/Firefox (myvm).app
```

- Dans Caker.app, le bouton **Applications** de la barre d'outils de la fenêtre d'une VM seamless ouvre la liste (recherche, icône de chaque application lue dans l'invité) ; un clic démarre l'application et le bouton à droite de la ligne crée un lanceur.
- Un **lanceur** est une petite application macOS (Dock, Spotlight, Launchpad) qui démarre la VM si besoin puis l'application ; son icône est celle de l'application dans l'invité (thèmes d'icônes du système, de snap et de Flatpak). Il n'est pas signé.
- Les applications en terminal (`htop`, `vim`) sont lancées dans l'émulateur de terminal de l'invité.
- Le détail des options est dans [`app`](command-summary).

## Limites

- Pas de presse-papiers partagé, pas de glisser-déposer, pas de méthode de saisie (IME), pas de XWayland, pas d'accélération 3D ; le curseur dessiné par l'application n'est pas transmis (les formes standard le sont).
- Une application démarre sans argument ni fichier.
- Un invité Windows ou macOS ne l'a pas. L'installation de la VM App Store n'a pas été vérifiée.
- Un redémarrage du service `caked` coupe le tunnel ; Caker.app se reconnecte toutes les 3 secondes.

Voir aussi `SEAMLESS_WINDOWS_PLAN.md` dans le dépôt pour la conception, le protocole et les limites connues.

</div>

<div class="lang-en" style="display:block" markdown="1">

# Seamless windows for Linux VMs

A Linux VM can show its windows as real macOS windows, WSLg style: a Wayland compositor in the guest sends one pixel buffer per window (a main window or a popup menu) over **vsock**, and the host shows each in its own `NSWindow`, sending keyboard and mouse back. There is no RDP and no custom virtio device. The compositor and the guest-side agent are described in the [cakeagent wiki](https://github.com/Fred78290/cakeagent/wiki/seamless-windows).

Windows are titled `[<vm>]` first (`[myvm] foot`), then `<user>: ` for an account other than the VM's own.

## Requirements

- A **Linux** VM (not macOS, not Windows) with a recent cakeagent in the guest (**v1.0.321 or later**; an older agent ignores the option and shows nothing).
- The VM is running and its agent answers.

## Turn it on

```bash
caked build --seamless ubuntu-vm            # at creation: the cloud-init seed installs the compositor
cakectl launch --seamless ubuntu-vm
cakectl configure ubuntu-vm --seamless true # later: applied at the next start, no rebuild
```

In Caker.app it is the "Seamless windows" switch of the creation wizard and of the VM settings. The agent is registered again at the next start when its service options changed (seamless windows, mounts): that goes through the agent itself, not SSH.

## Showing the windows

Only one process shows the windows of a VM at a time (a lock on the VM's `smls` socket):

| VM run by | Who shows the windows |
| --- | --- |
| Caker.app (`app` mode) | Caker.app |
| `caked start` / `caked vmrun` | the `vmrun` process, with no Dock icon |
| a `caked` service (local or remote) | a client: Caker.app, or `cakectl seamless <vm>` (gRPC tunnel) |

`cakectl sh`, `cakectl exec` and `cakectl app run` show the windows of a seamless VM themselves (`--seamless false` opts out for `sh`/`exec`). When another process already shows them, `sh`/`exec` keep running and take the windows over as soon as the other lets go; `app run` just starts the application.

## Users

`exec` and `sh` run as the VM's account (see [`exec` and `sh`](command-summary)), which is what lets a graphical program started from that shell open on the host. Another account (`--user`) gets its own compositor on demand.

## Applications and launchers

Start the applications installed in the guest without a terminal:

```bash
cakectl app list myvm                         # the guest's applications (.desktop)
cakectl app run myvm firefox                  # starts Firefox, its windows show on the Mac
cakectl app create-launcher myvm firefox      # creates ~/Applications/Firefox (myvm).app
```

- In Caker.app, the **Applications** button in the toolbar of a seamless VM's window opens the list (search, each application's icon read from the guest); a click starts the application and the button at the right of the row creates a launcher.
- A **launcher** is a small macOS application (Dock, Spotlight, Launchpad) that starts the VM if needed and then the application; its icon is the application's icon in the guest (system, snap and Flatpak icon themes). It is not code-signed.
- Terminal applications (`htop`, `vim`) are started in the guest's terminal emulator.
- The options are detailed under [`app`](command-summary).

## Limits

- No shared clipboard, no drag and drop, no input method (IME), no XWayland, no 3D acceleration; a cursor image drawn by the application is not forwarded (the standard shapes are).
- An application starts without arguments or files.
- A Windows or macOS guest doesn't have it. The App Store build has not been checked.
- Restarting the `caked` service drops the tunnel; Caker.app reconnects every 3 seconds.

See also `SEAMLESS_WINDOWS_PLAN.md` in the repository for the design, the protocol and the known gaps.

</div>
