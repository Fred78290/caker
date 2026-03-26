# Ressources DMG pour Caker

Ce dossier contient les ressources utilisées pour créer le fichier DMG de distribution de Caker.

## Image de fond (optionnelle)

Pour personnaliser l'apparence du DMG, vous pouvez ajouter une image de fond :

1. Créez une image PNG de 500x300 pixels
2. Nommez-la `background.png`
3. Placez-la dans ce dossier

L'image de fond sera automatiquement utilisée lors de la création du DMG.

## Structure du DMG

Le DMG final contiendra :
- `Caker.app` - L'application principale
- `Applications` - Un lien symbolique vers le dossier Applications du système

Les utilisateurs pourront installer Caker en glissant-déposant l'icône `Caker.app` sur le dossier `Applications`.

## Utilisation

Utilisez le script `create-dmg.sh` pour générer le DMG :

```bash
cd .ci
./create-dmg.sh [keychain]
```

Le paramètre `keychain` est optionnel et peut être utilisé pour spécifier un trousseau particulier pour la signature du code.