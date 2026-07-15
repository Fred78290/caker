<!-- markdownlint-disable MD033 MD024 -->

<div class="lang-fr" style="display:none" markdown="1">

# IMDS (Instance Metadata Service)

Caker fournit un service de métadonnées d'instance de style AWS pour les VM Linux, accessible depuis l'intérieur de l'invité via HTTP, à la manière du `169.254.169.254` d'EC2. Il expose l'identifiant d'instance, le nom d'hôte, l'adresse MAC, le type d'instance et les informations réseau, avec prise en charge des jetons IMDSv1 et IMDSv2.

## Activation

IMDS est activé par défaut pour les VM Linux dès que `caked service listen` tourne — **y compris dans la version App Store sandboxée** : le serveur démarre sur un port non privilégié de la passerelle IMDS dès qu'une VM Linux démarre, et s'arrête quand la dernière VM Linux s'arrête. Les invités peuvent toujours le joindre directement à cette adresse, sans root ni `sudo`.

```bash
caked service listen                        # IMDS joignable par les invités sur son port non privilégié
caked service listen --imds-port 9000        # change le port non privilégié (par défaut 28080)
```

| Option | Description |
| --- | --- |
| `--imds-port <port>` | Port non privilégié sur lequel IMDS écoute (par défaut `28080`). Ignoré si `caked` tourne en root. |

## Réseau et adressage

Chaque VM Linux reçoit une interface réseau dédiée « imds » (host-only), toutes les VM partageant le même commutateur virtuel `imds`. Le framework `vmnet` d'Apple n'acceptant que des sous-réseaux privés classiques (`192.168.0.0/16`), le sous-réseau réel est `192.168.169.0/24`, avec la passerelle `192.168.169.1` — pas l'adresse `169.254.169.x` habituelle d'AWS.

Une route statique `169.254.169.254/32` via cette passerelle est ajoutée à la configuration réseau de l'invité (netplan), sur le même principe qu'AWS lui-même (`169.254.169.254` n'est pas directement rattachée au sous-réseau EC2 non plus, elle est routée). Comme cette adresse n'est pas elle-même rattachée au sous-réseau, `caked` installe aussi une redirection `pf` de type alias d'adresse : le trafic vers `169.254.169.254` port 80 est redirigé vers `192.168.169.1` sur le port réellement utilisé par IMDS (80 en root, ou `--imds-port` sinon) — mise en place automatiquement au démarrage d'IMDS (nécessite `sudo`, au mieux, indisponible en version sandboxée). La passerelle elle-même, `192.168.169.1`, reste toujours joignable sur son port sans avoir besoin de cette redirection.

## Modèle de privilèges

`caked service listen` tourne normalement sans privilèges, or lier le port standard 80 nécessite root. IMDS lui-même n'a jamais besoin de root — il lie toujours *un* port de la passerelle que les invités peuvent joindre sans aucun privilège. Le comportement dépend du contexte :

- **`caked` tourne en root** (`service listen --system`) : IMDS lie directement `192.168.169.1:80`, aucune étape supplémentaire.
- **`caked` tourne sans privilège** (cas courant, y compris en version sandboxée) : IMDS lie `192.168.169.1:<imds-port>` — les invités peuvent déjà le joindre là, sans `sudo`.

Indépendamment de ce qui précède, un court appel `sudo` installe aussi l'alias d'adresse `169.254.169.254` mentionné dans [Réseau et adressage](#réseau-et-adressage) — mis en place automatiquement au démarrage d'IMDS, que `caked` tourne en root ou non, et de même indisponible (avec la passerelle toujours pleinement joignable) en version sandboxée. C'est cet alias, et lui seul, qui expose IMDS sur le port standard 80 lorsque `caked` tourne sans privilège — voir [`caked networks imds-redirect`](command-summary), une sous-commande interne.

## Utiliser IMDS depuis l'invité

```bash
# IMDSv1 (pas de jeton requis) — remplacez 28080 par votre --imds-port si modifié ; le
# port 80 sur 169.254.169.254 ne fonctionne que si l'alias pf est en place (voir
# Modèle de privilèges), et le port 80 sur 192.168.169.1 seulement si caked tourne en root
curl http://192.168.169.1:28080/latest/meta-data/instance-id
curl http://169.254.169.254/latest/meta-data/instance-id

# IMDSv2 : obtenir un jeton, puis l'utiliser
TOKEN=$(curl -X PUT "http://192.168.169.1:28080/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -H "X-aws-ec2-metadata-token: $TOKEN" http://192.168.169.1:28080/latest/meta-data/hostname
```

`GET /` (la racine, sans préfixe `latest/meta-data`) renvoie la liste des versions d'API prises en charge, comme sur une vraie instance EC2 (`1.0`, une série de dates, puis `latest`).

Points de terminaison disponibles sous `latest/meta-data` : `instance-id`, `hostname`, `local-hostname`, `local-ipv4`, `mac`, `public-hostname`, `public-ipv4`, `ami-id`, `ami-launch-index`, `instance-type`, `placement/availability-zone`, `placement/region`, `network/interfaces/macs/<mac>/{local-ipv4s,subnet-ipv4-cidr-block,vpc-id}`.

`public-ipv4` / `public-hostname` ne sont disponibles que pour les VM possédant une interface réseau `bridged` (par exemple `cakectl config vm --network name=bridged`) — l'équivalent le plus proche d'une adresse IP publique EC2, puisque le mode bridgé place la VM directement sur le réseau local physique. `public-ipv4` est résolue en direct via le cache ARP de l'hôte pour l'adresse MAC de cette interface (comme pour l'adresse IMDS elle-même), et n'est donc renvoyée qu'une fois que la VM a effectivement émis du trafic sur ce réseau. `public-hostname` tente ensuite une résolution DNS inverse (PTR) sur cette adresse via le résolveur système — ce qui couvre à la fois de vrais enregistrements PTR (si le routeur/DNS du réseau local en publie) et les noms mDNS/Bonjour (`.local`), macOS relayant cette dernière résolution vers `mDNSResponder` — puis se rabat sur `<hostname>.local` si aucune des deux n'aboutit. Sans interface `bridged`, ces deux points de terminaison renvoient 404, comme sur une véritable instance EC2 sans IP publique.

<a name="imds-limitations-fr"></a>
## Limitations

- **VM lancée via `caked vmrun` en dehors du démon** (par exemple, un processus autonome qui contourne `caked service listen`) : la VM reçoit bien son interface réseau et sa route netplan, mais comme rien n'enregistre la VM auprès d'un `IMDSCoordinator` (ce mécanisme dépend des événements du démon), aucun serveur IMDS ne répond côté hôte.
- **Joindre IMDS à l'adresse `169.254.169.254` de style AWS** nécessite `sudo` pour la redirection `pf` d'alias d'adresse, donc c'est indisponible dans la version App Store sandboxée. IMDS lui-même fonctionne toujours là, joignable à la vraie adresse de la passerelle sur son port non privilégié.

</div>

<div class="lang-en" style="display:block" markdown="1">

# IMDS (Instance Metadata Service)

Caker provides an AWS-style instance metadata service for Linux VMs, reachable from inside the guest over HTTP, the same way EC2's `169.254.169.254` works. It exposes the instance ID, hostname, MAC address, instance type, and network info, with both IMDSv1 and IMDSv2 (token-based) support.

## Enabling it

IMDS is enabled by default for Linux VMs whenever `caked service listen` is running — **including in the sandboxed App Store build**: the server starts on an unprivileged port on the IMDS gateway as soon as a Linux VM starts, and stops once the last Linux VM stops. Guests can always reach it there directly, no root or `sudo` required.

```bash
caked service listen                        # IMDS reachable by guests on its unprivileged port
caked service listen --imds-port 9000        # override the unprivileged port (default 28080)
```

| Option | Description |
| --- | --- |
| `--imds-port <port>` | Unprivileged port IMDS listens on (default `28080`). Ignored when `caked` runs as root. |

## Network and addressing

Every Linux VM gets a dedicated, host-only "imds" network interface — all VMs on a host share the same "imds" virtual switch. Apple's `vmnet.framework` only accepts ordinary private subnets (`192.168.0.0/16`), so the actual subnet is `192.168.169.0/24` with gateway `192.168.169.1`, not the AWS-style `169.254.169.x` addressing.

A static route for `169.254.169.254/32` via that gateway is added to the guest's network config (netplan), matching AWS's own convention (`169.254.169.254` isn't directly on-link in EC2 either — it's routed there too). Since that address isn't itself on-link, `caked` also installs a `pf` address-alias redirect: traffic to `169.254.169.254` port 80 is redirected to `192.168.169.1` on whichever port IMDS actually bound (80 as root, or `--imds-port` otherwise) — set up automatically whenever IMDS starts (needs `sudo`, best-effort, not available in sandboxed builds). The gateway address itself, `192.168.169.1`, is always reachable on its own port regardless and needs no such redirect.

## Privilege model

`caked service listen` normally runs unprivileged, but binding the standard port 80 requires root. IMDS itself never needs root — it always binds *some* port on the gateway that guests can reach with no privilege involved. Behavior depends on context:

- **`caked` runs as root** (`service listen --system`): IMDS binds `192.168.169.1:80` directly, nothing else needed.
- **`caked` runs unprivileged** (the common case, including sandboxed builds): IMDS binds `192.168.169.1:<imds-port>` — guests can already reach it there, no `sudo` involved.

Independently of the above, a short `sudo` call also installs the `169.254.169.254` address alias mentioned in [Network and addressing](#network-and-addressing) — this runs automatically whenever IMDS starts, on both root and unprivileged `caked`, and is likewise skipped (with the gateway address still fully reachable) in sandboxed builds. This alias is the *only* thing that exposes IMDS on the standard port 80 when `caked` runs unprivileged — see [`caked networks imds-redirect`](command-summary), an internal subcommand.

## Using IMDS from the guest

```bash
# IMDSv1 (no token required) — replace 28080 with your --imds-port if you changed it;
# port 80 on 169.254.169.254 only works if the pf address alias is set up (see
# Privilege model), and port 80 on 192.168.169.1 only if caked runs as root
curl http://192.168.169.1:28080/latest/meta-data/instance-id
curl http://169.254.169.254/latest/meta-data/instance-id

# IMDSv2: get a token, then use it
TOKEN=$(curl -X PUT "http://192.168.169.1:28080/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
curl -H "X-aws-ec2-metadata-token: $TOKEN" http://192.168.169.1:28080/latest/meta-data/hostname
```

`GET /` (the bare root, no `latest/meta-data` prefix) returns the list of supported API versions, matching a real EC2 instance (`1.0`, a run of dates, then `latest`).

Available endpoints under `latest/meta-data`: `instance-id`, `hostname`, `local-hostname`, `local-ipv4`, `mac`, `public-hostname`, `public-ipv4`, `ami-id`, `ami-launch-index`, `instance-type`, `placement/availability-zone`, `placement/region`, `network/interfaces/macs/<mac>/{local-ipv4s,subnet-ipv4-cidr-block,vpc-id}`.

`public-ipv4` / `public-hostname` are only available for VMs with a `bridged` network attachment (e.g. `cakectl config vm --network name=bridged`) — the closest analogue to an EC2 public IP this host has, since bridged mode puts the VM directly on the physical LAN. `public-ipv4` is resolved live from the host's ARP cache for that interface's MAC address (the same mechanism used for the IMDS network itself), so it's only returned once the VM has actually sent traffic on that network. `public-hostname` then attempts a reverse DNS (PTR) lookup on that address through the system resolver — covering both real PTR records (if the LAN's router/DNS publishes one) and mDNS/Bonjour `.local` names, since macOS transparently routes that lookup through `mDNSResponder` — falling back to `<hostname>.local` if neither resolves. With no `bridged` attachment, both endpoints return 404, matching a real EC2 instance with no public IP.

<a name="imds-limitations"></a>
## Limitations

- **VM launched via `caked vmrun` outside the daemon** (e.g. a standalone process that bypasses `caked service listen`): the VM still gets its network interface and netplan route, but since nothing registers the VM with an `IMDSCoordinator` (that mechanism depends on daemon-side events), no IMDS server answers on the host side.
- **Reaching IMDS at the AWS-style `169.254.169.254` address** needs `sudo` for its `pf` address-alias redirect, so it's not available in the sandboxed App Store build. IMDS itself still works there, reachable at the real gateway address on its unprivileged port.

</div>
