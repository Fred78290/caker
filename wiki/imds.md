<!-- markdownlint-disable MD033 MD024 -->

<div class="lang-fr" style="display:none" markdown="1">

# IMDS (Instance Metadata Service)

Caker fournit un service de métadonnées d'instance de style AWS pour les VM Linux, accessible depuis l'intérieur de l'invité via HTTP, à la manière du `169.254.169.254` d'EC2. Il expose l'identifiant d'instance, le nom d'hôte, l'adresse MAC, le type d'instance et les informations réseau, avec prise en charge des jetons IMDSv1 et IMDSv2.

## Activation

IMDS est activé par défaut pour les VM Linux dès que `caked service listen` tourne — **y compris dans la version App Store sandboxée** : le serveur démarre sur un port non privilégié de la passerelle IMDS dès qu'une VM Linux démarre, et s'arrête quand la dernière VM Linux s'arrête. Les invités peuvent toujours le joindre directement à cette adresse, sans root ni `sudo`.

```bash
caked service listen                        # IMDS joignable par les invités sur son port non privilégié
caked service listen --imds-redirect         # IMDS également exposé sur le port standard 80
caked service listen --imds-port 9000        # change le port non privilégié (par défaut 28080)
```

| Option | Description |
| --- | --- |
| `--imds-port <port>` | Port non privilégié sur lequel IMDS écoute (par défaut `28080`). Ignoré si `caked` tourne en root. |
| `--imds-redirect` | Expose *en plus* IMDS aux invités sur le port standard 80, via une redirection `pf` installée par un assistant root de courte durée — pour les outils qui utilisent ce port en dur. Indisponible dans la version sandboxée (nécessite `sudo`) ; IMDS reste pleinement joignable sur `--imds-port` malgré tout. |

## Réseau et adressage

Chaque VM Linux reçoit une interface réseau dédiée « imds » (host-only), toutes les VM partageant le même commutateur virtuel `imds`. Le framework `vmnet` d'Apple n'acceptant que des sous-réseaux privés classiques (`192.168.0.0/16`), le sous-réseau réel est `192.168.169.0/24`, avec la passerelle `192.168.169.1` — pas l'adresse `169.254.169.x` habituelle d'AWS.

Une route statique `169.254.169.254/32` via cette passerelle est ajoutée à la configuration réseau de l'invité (netplan), sur le même principe qu'AWS lui-même (`169.254.169.254` n'est pas directement rattachée au sous-réseau EC2 non plus, elle est routée). Comme cette adresse n'est pas elle-même rattachée au sous-réseau, `caked` installe aussi une redirection `pf` de type alias d'adresse (`169.254.169.254 → 192.168.169.1`, port conservé) pour que l'hôte y réponde réellement — mise en place automatiquement au démarrage d'IMDS, de la même façon que la redirection du port 80 (nécessite `sudo`, au mieux, indisponible en version sandboxée). La passerelle elle-même, `192.168.169.1`, reste toujours joignable sans avoir besoin de cette redirection.

## Modèle de privilèges

`caked service listen` tourne normalement sans privilèges, or lier le port standard 80 nécessite root. IMDS lui-même n'a jamais besoin de root — il lie toujours *un* port de la passerelle que les invités peuvent joindre sans aucun privilège. Le comportement dépend du contexte :

- **`caked` tourne en root** (`service listen --system`) : IMDS lie directement `192.168.169.1:80`, aucune étape supplémentaire.
- **`caked` tourne sans privilège** (cas courant, y compris en version sandboxée) : IMDS lie `192.168.169.1:<imds-port>` — les invités peuvent déjà le joindre là, sans `sudo`. Avec `--imds-redirect`, un court appel `sudo` installe *en plus* une redirection `pf` pour que `192.168.169.1:80` fonctionne aussi, pour les outils qui utilisent ce port en dur — voir [`caked networks imds-redirect`](command-summary), une sous-commande interne. Cela nécessite un `sudo` non interactif déjà configuré pour `caked` et n'est pas disponible en version sandboxée ; en son absence, IMDS reste joignable sur `--imds-port` malgré tout.

Indépendamment de ce qui précède, un court appel `sudo` installe aussi l'alias d'adresse `169.254.169.254` mentionné dans [Réseau et adressage](#réseau-et-adressage) — mis en place automatiquement au démarrage d'IMDS, que `caked` tourne en root ou non, et de même indisponible (avec la passerelle toujours pleinement joignable) en version sandboxée.

## Utiliser IMDS depuis l'invité

```bash
# IMDSv1 (pas de jeton requis) — les deux adresses fonctionnent si l'alias pf est en
# place (voir Modèle de privilèges) ; remplacez 28080 par votre --imds-port si modifié,
# ou utilisez le port 80 si caked tourne en root ou si --imds-redirect est actif
curl http://192.168.169.1:28080/latest/meta-data/instance-id
curl http://169.254.169.254:28080/latest/meta-data/instance-id

# IMDSv2 : obtenir un jeton, puis l'utiliser
TOKEN=$(curl -X PUT "http://192.168.169.1:28080/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -H "X-aws-ec2-metadata-token: $TOKEN" http://192.168.169.1:28080/latest/meta-data/hostname
```

Points de terminaison disponibles : `instance-id`, `hostname`, `local-hostname`, `local-ipv4`, `mac`, `ami-id`, `ami-launch-index`, `instance-type`, `placement/availability-zone`, `placement/region`, `network/interfaces/macs/<mac>/{local-ipv4s,subnet-ipv4-cidr-block,vpc-id}`.

<a name="imds-limitations-fr"></a>
## Limitations

- **VM lancée via `caked vmrun` en dehors du démon** (par exemple, un processus autonome qui contourne `caked service listen`) : la VM reçoit bien son interface réseau et sa route netplan, mais comme rien n'enregistre la VM auprès d'un `IMDSCoordinator` (ce mécanisme dépend des événements du démon), aucun serveur IMDS ne répond côté hôte.
- **Exposer IMDS sur le port standard 80** (`--imds-redirect`) et **le joindre à l'adresse `169.254.169.254` de style AWS** nécessitent tous deux `sudo` pour leurs redirections `pf` respectives, donc aucun des deux n'est disponible dans la version App Store sandboxée. IMDS lui-même fonctionne toujours là, joignable à la vraie adresse de la passerelle sur son port non privilégié.

</div>

<div class="lang-en" style="display:block" markdown="1">

# IMDS (Instance Metadata Service)

Caker provides an AWS-style instance metadata service for Linux VMs, reachable from inside the guest over HTTP, the same way EC2's `169.254.169.254` works. It exposes the instance ID, hostname, MAC address, instance type, and network info, with both IMDSv1 and IMDSv2 (token-based) support.

## Enabling it

IMDS is enabled by default for Linux VMs whenever `caked service listen` is running — **including in the sandboxed App Store build**: the server starts on an unprivileged port on the IMDS gateway as soon as a Linux VM starts, and stops once the last Linux VM stops. Guests can always reach it there directly, no root or `sudo` required.

```bash
caked service listen                        # IMDS reachable by guests on its unprivileged port
caked service listen --imds-redirect         # IMDS additionally exposed on the standard port 80
caked service listen --imds-port 9000        # override the unprivileged port (default 28080)
```

| Option | Description |
| --- | --- |
| `--imds-port <port>` | Unprivileged port IMDS listens on (default `28080`). Ignored when `caked` runs as root. |
| `--imds-redirect` | *Additionally* expose IMDS to guests on the standard port 80, via a `pf` redirect installed by a short-lived root helper — for tooling that hardcodes it. Not available in the sandboxed build (needs `sudo`); IMDS remains fully reachable on `--imds-port` regardless. |

## Network and addressing

Every Linux VM gets a dedicated, host-only "imds" network interface — all VMs on a host share the same "imds" virtual switch. Apple's `vmnet.framework` only accepts ordinary private subnets (`192.168.0.0/16`), so the actual subnet is `192.168.169.0/24` with gateway `192.168.169.1`, not the AWS-style `169.254.169.x` addressing.

A static route for `169.254.169.254/32` via that gateway is added to the guest's network config (netplan), matching AWS's own convention (`169.254.169.254` isn't directly on-link in EC2 either — it's routed there too). Since that address isn't itself on-link, `caked` also installs a `pf` address-alias redirect (`169.254.169.254 → 192.168.169.1`, any port preserved) so the host actually answers there — set up automatically whenever IMDS starts, the same way as the port-80 redirect (needs `sudo`, best-effort, not available in sandboxed builds). The gateway address itself, `192.168.169.1`, is always reachable regardless and needs no such redirect.

## Privilege model

`caked service listen` normally runs unprivileged, but binding the standard port 80 requires root. IMDS itself never needs root — it always binds *some* port on the gateway that guests can reach with no privilege involved. Behavior depends on context:

- **`caked` runs as root** (`service listen --system`): IMDS binds `192.168.169.1:80` directly, nothing else needed.
- **`caked` runs unprivileged** (the common case, including sandboxed builds): IMDS binds `192.168.169.1:<imds-port>` — guests can already reach it there, no `sudo` involved. With `--imds-redirect`, a short `sudo` call *additionally* installs a `pf` redirect so `192.168.169.1:80` also works, for tooling that hardcodes port 80 — see [`caked networks imds-redirect`](command-summary), an internal subcommand. This needs passwordless sudo already configured for `caked` and isn't available in sandboxed builds; without it, IMDS stays reachable on `--imds-port` regardless.

Independently of the above, a short `sudo` call also installs the `169.254.169.254` address alias mentioned in [Network and addressing](#network-and-addressing) — this runs automatically whenever IMDS starts, on both root and unprivileged `caked`, and is likewise skipped (with the gateway address still fully reachable) in sandboxed builds.

## Using IMDS from the guest

```bash
# IMDSv1 (no token required) — either address works if the pf address alias is set up
# (see Privilege model); replace 28080 with your --imds-port if you changed it, or use
# port 80 if caked runs as root or --imds-redirect is set
curl http://192.168.169.1:28080/latest/meta-data/instance-id
curl http://169.254.169.254:28080/latest/meta-data/instance-id

# IMDSv2: get a token, then use it
TOKEN=$(curl -X PUT "http://192.168.169.1:28080/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -H "X-aws-ec2-metadata-token: $TOKEN" http://192.168.169.1:28080/latest/meta-data/hostname
```

Available endpoints: `instance-id`, `hostname`, `local-hostname`, `local-ipv4`, `mac`, `ami-id`, `ami-launch-index`, `instance-type`, `placement/availability-zone`, `placement/region`, `network/interfaces/macs/<mac>/{local-ipv4s,subnet-ipv4-cidr-block,vpc-id}`.

<a name="imds-limitations"></a>
## Limitations

- **VM launched via `caked vmrun` outside the daemon** (e.g. a standalone process that bypasses `caked service listen`): the VM still gets its network interface and netplan route, but since nothing registers the VM with an `IMDSCoordinator` (that mechanism depends on daemon-side events), no IMDS server answers on the host side.
- **Exposing IMDS on the standard port 80** (`--imds-redirect`) and **reaching it at the AWS-style `169.254.169.254` address** both need `sudo` for their respective `pf` redirects, so neither is available in the sandboxed App Store build. IMDS itself still works there, reachable at the real gateway address on its unprivileged port.

</div>
