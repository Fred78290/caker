# Migration SPICE : De CALayer vers NSView ✅

La bibliothèque SPICE a été complètement migrée de `CALayer` vers `NSView` pour une meilleure intégration avec AppKit sur macOS. Cette migration permet une capture et un rendu plus natifs des applications macOS dans l'environnement de virtualisation.

## Architecture

### Fichiers principaux

- **SPICEServer.swift** : Serveur SPICE principal avec gestion des processus
- **SPICEClient.swift** : Client SPICE pour les connexions entrantes  
- **SPICEProtocol.swift** : Implémentation du protocole SPICE RedHat
- **SPICEManager.swift** : Gestionnaire de haut niveau pour l'intégration VM
- **SPICEExtensions.swift** : Extensions et utilitaires pour Virtualization.framework

### Nouveaux composants CALayer

- **SPICELayerServer.swift** : Serveur SPICE utilisant CALayer comme source
- **SPICELayerRenderer.swift** : Moteur de rendu optimisé GPU/CPU pour CALayer
- **SPICELayerCapture.swift** : Capture avancée avec détection de mouvement
- **SPICELayerIntegration.swift** : Point d'entrée principal pour l'intégration complète
- **SPICELayerExample.swift** : Exemples d'utilisation et démos

## Fonctionnalités

### Serveur SPICE

- ✅ Authentification par mot de passe
- ✅ Configuration des niveaux de compression
- ✅ Support audio/vidéo
- ✅ Redirection USB
- ✅ Multi-clients (configurable)
- ✅ Gestion des processus sécurisée

### Protocole

- ✅ Messages de liaison et d'authentification
- ✅ Canaux d'affichage, d'entrée, audio
- ✅ Parsing des messages entrants
- ✅ Gestion des événements clavier/souris

### Intégration VM

- ✅ Configuration automatique des périphériques
- ✅ Profiles de qualité prédéfinis
- ✅ Métriques de performance
- ✅ Diagnostic et monitoring

### Nouveautés CALayer

- ✅ Capture temps réel de CALayer
- ✅ Rendu GPU accéléré (Metal)
- ✅ Détection de mouvement adaptative
- ✅ Capture différentielle intelligente
- ✅ Région d'intérêt dynamique
- ✅ Compression adaptative
- ✅ Frame rate adaptatif
- ✅ Support de tous types de CALayer

## Utilisation

### Utilisation basique avec CALayer

```swift
// Créer un CALayer source
let sourceLayer = CALayer()
sourceLayer.frame = CGRect(x: 0, y: 0, width: 1920, height: 1080)
sourceLayer.backgroundColor = CGColor.black

// Intégration SPICE simple
let spiceIntegration = SPICELayerIntegration.forGaming(
    layer: sourceLayer,
    port: 5900,
    password: "gaming123"
)

// Démarrer l'intégration
spiceIntegration.start()

// URL de connexion
if let url = spiceIntegration.connectionURL {
    print("Connexion SPICE: \(url)")
}
```

### Utilisation avancée

```swift
// Configuration personnalisée
let spiceConfig = SPICEServer.Configuration(
    port: 5900,
    password: "monMotDePasse",
    enableAudio: true,
    enableUSBRedirection: true
)

// Configuration de rendu GPU
let renderConfig = SPICELayerRenderer.RenderConfiguration.highPerformance

// Configuration de capture intelligente
let captureSettings = SPICELayerCapture.CaptureSettings.interactive

// Intégration complète
let integrationConfig = SPICELayerIntegration.IntegrationConfiguration(
    spiceConfig: spiceConfig,
    renderConfig: renderConfig,
    captureSettings: captureSettings
)

let spiceIntegration = SPICELayerIntegration.custom(
    layer: sourceLayer,
    configuration: integrationConfig
)

spiceIntegration.start()
```

### Configurations prêtes à l'emploi

```swift
// Pour gaming/applications interactives
let gamingIntegration = SPICELayerIntegration.forGaming(
    layer: sourceLayer,
    port: 5900,
    password: "secret"
)

// Pour bureautique/productivité
let productivityIntegration = SPICELayerIntegration.forProductivity(
    layer: sourceLayer,
    port: 5901
)

// Pour connexions lentes
let lowBandwidthIntegration = SPICELayerIntegration.forLowBandwidth(
    layer: sourceLayer,
    port: 5902
)
```

### Support de différents types de layers

```swift
// CAMetalLayer avec GPU
let metalLayer = CAMetalLayer()
let metalSPICE = SPICELayerServer.forMetalLayer(
    metalLayer,
    spiceConfig: config,
    captureConfig: .performance
)

// CAOpenGLLayer
let openGLLayer = CAOpenGLLayer()
let openGLSPICE = SPICELayerServer.forOpenGLLayer(
    openGLLayer,
    spiceConfig: config
)

// Layer de contenu standard
let contentLayer = CALayer()
let contentSPICE = SPICELayerServer.forContentLayer(
    contentLayer,
    spiceConfig: config,
    captureConfig: .quality
)
```

### Intégration avec VZVirtualMachine

```swift
// Configuration complète de la VM pour SPICE
vmConfiguration.configureForSPICE(
    displayWidth: 1920,
    displayHeight: 1080,
    enableAudio: true,
    enableUSB: true
)

// Démarrage avec SPICE intégré
virtualMachine.startWithSPICE(spiceConfiguration: config) { result in
    switch result {
    case .success(let spiceManager):
        print("SPICE actif sur: \(spiceManager.connectionURL!)")
    case .failure(let error):
        print("Erreur SPICE: \(error)")
    }
}
```

## Profils de qualité

### Performance (Gaming/CAO)
- Compression minimale (niveau 1)
- Faible latence
- Audio et USB activés
- Idéal pour applications interactives

### Équilibré (Bureautique)
- Compression modérée (niveau 6-8)  
- Bon compromis qualité/performance
- Tous les périphériques activés
- Usage général recommandé

### Faible bande passante
- Compression maximale (niveau 9)
- Audio désactivé
- USB limité
- Idéal pour connexions lentes

## Diagnostic et monitoring

```swift
// Informations de diagnostic
let info = spiceManager.diagnosticInfo()
print(info.description)

// Test de connectivité
spiceManager.testConnectivity { success, error in
    print("Connectivité SPICE: \(success)")
}

// Métriques de performance
let metrics = spiceManager.collectMetrics()
print(metrics.summary)
```

## Configuration réseau

```swift
// Port automatique
let config = SPICENetworkUtils.autoConfiguration(password: "secret")

// Vérification de port
if SPICENetworkUtils.isPortAvailable(5900) {
    print("Port 5900 disponible")
}

// Port libre à partir de 5900
let port = SPICENetworkUtils.findAvailablePort(startingFrom: 5900)
```

## Gestion d'erreurs

```swift
spiceManager.stateChangeHandler = { state in
    switch state {
    case .active:
        print("Serveur SPICE actif")
    case .error(let error):
        print("Erreur SPICE: \(error.localizedDescription)")
    case .inactive:
        print("Serveur SPICE arrêté")
    }
}
```

## Prérequis

- macOS 12.0+ (pour Virtualization.framework)
- Xcode 13+
- Swift 5.5+
- Binaire `spice-server` installé dans `/usr/local/bin/`

## Installation du serveur SPICE

```bash
# Via Homebrew (recommandé)
brew install spice-gtk

# Ou compilation depuis les sources
git clone https://gitlab.freedesktop.org/spice/spice-server.git
cd spice-server
./configure --prefix=/usr/local
make && sudo make install
```

## Sécurité

- ⚠️ Utilisez toujours des mots de passe forts
- 🔒 Limitez l'accès réseau au serveur SPICE
- 🔐 Considérez l'utilisation de TLS pour les connexions
- 📝 Surveillez les logs de connexion

## Codecs supportés

- MJPEG (par défaut)
- VP8
- H.264
- VP9 (si disponible)
- H.265/HEVC (si disponible)

## Limitations connues

- Nécessite un binaire `spice-server` externe
- Pas de support TLS intégré (à implémenter)
- Métriques limitées (simulation pour le moment)
- Un seul client par défaut (configurable)

## Dépannage

### Serveur ne démarre pas
- Vérifiez que le port n'est pas utilisé
- Confirmez l'installation de `spice-server`
- Vérifiez les permissions d'exécution

### Connexion échoue
- Validez le mot de passe
- Testez la connectivité réseau
- Vérifiez les firewalls

### Performances dégradées
- Ajustez les niveaux de compression
- Utilisez le profil `performance`
- Vérifiez les ressources système

## Développement futur

- [ ] Support TLS/SSL natif
- [ ] Métriques temps réel
- [ ] Clustering multi-serveurs
- [ ] Interface de configuration web
- [ ] Support des codecs hardware
- [ ] Authentification SASL