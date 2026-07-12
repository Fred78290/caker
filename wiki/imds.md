<!-- markdownlint-disable MD033 MD024 -->

<div class="lang-fr" style="display:none" markdown="1">

# IMDS (Instance Metadata Service)

Caker fournit un service de métadonnées d'instance de style AWS pour les VM Linux, accessible depuis l'intérieur de l'invité via HTTP, à la manière du `169.254.169.254` d'EC2. Il expose l'identifiant d'instance, le nom d'hôte, l'adresse MAC, le type d'instance et les informations réseau, avec prise en charge des jetons IMDSv1 et IMDSv2.

## Activation

IMDS est activé par défaut pour les VM Linux dès que `caked service listen` tourne (hors version App Store sandboxée — voir [Limitations](#imds-limitations-fr)) : le serveur démarre sur un port interne non privilégié dès qu'une VM Linux démarre, et s'arrête quand la dernière VM Linux s'arrête.

```bash
caked service listen                        # IMDS actif en interne, non exposé aux invités
caked service listen --imds-redirect         # IMDS également exposé aux invités sur le port 80
caked service listen --imds-port 9000        # change le port interne (par défaut 28080)
```

| Option | Description |
| --- | --- |
| `--imds-port <port>` | Port interne non privilégié sur lequel IMDS écoute (par défaut `28080`). Ignoré si `caked` tourne en root. |
| `--imds-redirect` | Expose IMDS aux invités sur le port 80 via une redirection `pf` installée par un assistant root de courte durée. Sans cette option, IMDS tourne mais n'est joignable que sur le port interne. Indisponible dans la version sandboxée. |

## Réseau et adressage

Chaque VM Linux reçoit une interface réseau dédiée « imds » (host-only), toutes les VM partageant le même commutateur virtuel `imds`. Le framework `vmnet` d'Apple n'acceptant que des sous-réseaux privés classiques (`192.168.0.0/16`), le sous-réseau réel est `192.168.169.0/24`, avec la passerelle `192.168.169.1` — pas l'adresse `169.254.169.x` habituelle d'AWS.

Une route statique `169.254.169.254/32` via cette passerelle est tout de même ajoutée à la configuration réseau de l'invité (netplan), sur le même principe qu'AWS lui-même (`169.254.169.254` n'est pas directement rattachée au sous-réseau EC2 non plus, elle est routée). Cette compatibilité est fournie au mieux, sans garantie : l'adresse fiable et toujours joignable est la passerelle `192.168.169.1`.

## Modèle de privilèges

`caked service listen` tourne normalement sans privilèges, or lier le port 80 nécessite root. Le comportement dépend du contexte :

- **`caked` tourne en root** (`service listen --system`) : IMDS lie directement `192.168.169.1:80`, aucune étape supplémentaire.
- **`caked` tourne sans privilège** (cas courant) : IMDS lie un port non privilégié en local (`127.0.0.1:<imds-port>`). Avec `--imds-redirect`, un court appel `sudo` installe une redirection `pf` (`192.168.169.1:80 → 127.0.0.1:<imds-port>`) — voir [`caked networks imds-redirect`](command-summary), une sous-commande interne. Cela nécessite un `sudo` non interactif déjà configuré pour `caked` ; en son absence, l'échec est journalisé et IMDS reste joignable uniquement en interne.
- **Version App Store (sandboxée)** : IMDS n'est jamais démarré du tout — voir [Limitations](#imds-limitations-fr).

## Utiliser IMDS depuis l'invité

Ces exemples interrogent directement la passerelle, qui ne répond que si `caked` tourne en root ou si `--imds-redirect` est actif (voir [Modèle de privilèges](#modèle-de-privilèges) ci-dessus) — sinon IMDS n'est joignable que depuis l'hôte lui-même, sur le port interne.

```bash
# IMDSv1 (pas de jeton requis)
curl http://192.168.169.1/latest/meta-data/instance-id

# IMDSv2 : obtenir un jeton, puis l'utiliser
TOKEN=$(curl -X PUT "http://192.168.169.1/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -H "X-aws-ec2-metadata-token: $TOKEN" http://192.168.169.1/latest/meta-data/hostname
```

Points de terminaison disponibles : `instance-id`, `hostname`, `local-hostname`, `local-ipv4`, `mac`, `ami-id`, `ami-launch-index`, `instance-type`, `placement/availability-zone`, `placement/region`, `network/interfaces/macs/<mac>/{local-ipv4s,subnet-ipv4-cidr-block,vpc-id}`.

<a name="imds-limitations-fr"></a>
## Limitations

- **Version App Store (sandboxée)** : IMDS est totalement désactivé — aucune interface réseau « imds » n'est même attachée à la VM, aucune route netplan n'est générée, et le serveur IMDS n'est jamais démarré. Le App Sandbox macOS interdit l'invocation de `sudo`, rendant toute redirection `pf` impossible de toute façon.
- **VM lancée via `caked vmrun` en dehors du démon** (par exemple, un processus autonome qui contourne `caked service listen`) : la VM reçoit bien son interface réseau et sa route netplan, mais comme rien n'enregistre la VM auprès d'un `IMDSCoordinator` (ce mécanisme dépend des événements du démon), aucun serveur IMDS ne répond côté hôte.

</div>

<div class="lang-en" style="display:block" markdown="1">

# IMDS (Instance Metadata Service)

Caker provides an AWS-style instance metadata service for Linux VMs, reachable from inside the guest over HTTP, the same way EC2's `169.254.169.254` works. It exposes the instance ID, hostname, MAC address, instance type, and network info, with both IMDSv1 and IMDSv2 (token-based) support.

## Enabling it

IMDS is enabled by default for Linux VMs whenever `caked service listen` is running (except in the sandboxed App Store build — see [Limitations](#imds-limitations)): the server starts on an internal, unprivileged port as soon as a Linux VM starts, and stops once the last Linux VM stops.

```bash
caked service listen                        # IMDS running internally, not exposed to guests
caked service listen --imds-redirect         # IMDS also exposed to guests on port 80
caked service listen --imds-port 9000        # override the internal port (default 28080)
```

| Option | Description |
| --- | --- |
| `--imds-port <port>` | Internal, unprivileged port IMDS listens on (default `28080`). Ignored when `caked` runs as root. |
| `--imds-redirect` | Expose IMDS to guests on port 80 via a `pf` redirect installed by a short-lived root helper. Without this, IMDS still runs but is only reachable on the internal port. Not available in the sandboxed build. |

## Network and addressing

Every Linux VM gets a dedicated, host-only "imds" network interface — all VMs on a host share the same "imds" virtual switch. Apple's `vmnet.framework` only accepts ordinary private subnets (`192.168.0.0/16`), so the actual subnet is `192.168.169.0/24` with gateway `192.168.169.1`, not the AWS-style `169.254.169.x` addressing.

A static route for `169.254.169.254/32` via that gateway is still added to the guest's network config (netplan), matching AWS's own convention (`169.254.169.254` isn't directly on-link in EC2 either — it's routed there too). This is provided on a best-effort basis, not guaranteed — the reliable, always-reachable address is the gateway itself, `192.168.169.1`.

## Privilege model

`caked service listen` normally runs unprivileged, but binding port 80 requires root. Behavior depends on context:

- **`caked` runs as root** (`service listen --system`): IMDS binds `192.168.169.1:80` directly, nothing else needed.
- **`caked` runs unprivileged** (the common case): IMDS binds an unprivileged port on loopback (`127.0.0.1:<imds-port>`). With `--imds-redirect`, a short `sudo` call installs a `pf` redirect (`192.168.169.1:80 → 127.0.0.1:<imds-port>`) — see [`caked networks imds-redirect`](command-summary), an internal subcommand. This needs passwordless sudo already configured for `caked`; without it, the failure is logged and IMDS stays reachable internally only.
- **App Store (sandboxed) build**: IMDS is never started at all — see [Limitations](#imds-limitations).

## Using IMDS from the guest

These examples query the gateway address directly, which only answers when `caked` runs as root or `--imds-redirect` is set (see [Privilege model](#privilege-model) above) — otherwise IMDS is only reachable from the host itself, on the internal port.

```bash
# IMDSv1 (no token required)
curl http://192.168.169.1/latest/meta-data/instance-id

# IMDSv2: get a token, then use it
TOKEN=$(curl -X PUT "http://192.168.169.1/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -H "X-aws-ec2-metadata-token: $TOKEN" http://192.168.169.1/latest/meta-data/hostname
```

Available endpoints: `instance-id`, `hostname`, `local-hostname`, `local-ipv4`, `mac`, `ami-id`, `ami-launch-index`, `instance-type`, `placement/availability-zone`, `placement/region`, `network/interfaces/macs/<mac>/{local-ipv4s,subnet-ipv4-cidr-block,vpc-id}`.

<a name="imds-limitations"></a>
## Limitations

- **App Store (sandboxed) build**: IMDS is disabled entirely — no "imds" network interface is even attached to the VM, no netplan route is generated, and the IMDS server is never started. The macOS App Sandbox blocks invoking `sudo` at all, which would make any `pf` redirect impossible anyway.
- **VM launched via `caked vmrun` outside the daemon** (e.g. a standalone process that bypasses `caked service listen`): the VM still gets its network interface and netplan route, but since nothing registers the VM with an `IMDSCoordinator` (that mechanism depends on daemon-side events), no IMDS server answers on the host side.

</div>
