#!/usr/bin/env python3
"""
Script pour créer une image de fond pour le DMG de Caker.
Génère une image simple et élégante avec un gradient de fond.
"""

import os

from PIL import Image, ImageDraw, ImageFont


def create_dmg_background():
    # Dimensions du DMG (800x340 pixels)
    width, height = 800, 340
    
    # Créer une nouvelle image avec un gradient bleu doux
    img = Image.new('RGBA', (width, height), color='white')
    draw = ImageDraw.Draw(img)
    
    # Créer un gradient vertical doux
    target_color = (69, 175, 244)  # Bleu très clair
    for y in range(height):
        # Gradient de blanc vers bleu très clair
        ratio = y / height
        r = int(255 - ratio * (255 - target_color[0]))
        g = int(255 - ratio * (255 - target_color[1]))
        b = int(255 - ratio * (255 - target_color[2]))
        color = (r, g, b, 160)
        draw.line([(0, y), (width, y)], fill=color)
    
    # Ajouter un texte discret en bas
    try:
        # Essayer d'utiliser une police système
        font = ImageFont.truetype("/System/Library/Fonts/Noteworthy.ttc", 24)
    except:
        # Fallback vers la police par défaut
        font = ImageFont.load_default()
    
    text = "Drag and drop Caker.app to Applications to install"
    
    # Calculer la position du texte (centré en bas)
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_x = (width - text_width) // 2
    text_y = height - 50
    
    # Ajouter des cercles décoratifs discrets
    #circle_color = (9, 64, 128, 100)
    #draw.ellipse([width-80, 20, width-20, 80], fill=circle_color)
    #draw.ellipse([20, height-80, 80, height-20], fill=circle_color)
    
    # Dessiner le texte avec une couleur grise douce
    draw.text((text_x, text_y), text, fill=(9, 64, 128), font=font)
    
    return img

if __name__ == "__main__":
    # Déterminer le chemin de sortie
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(script_dir, "background.png")
    
    print("Création de l'image de fond pour le DMG...")
    
    try:
        img = create_dmg_background()
        img.save(output_path, "PNG")
        print(f"Image de fond créée avec succès : {output_path}")
    except ImportError:
        print("Warning: Pillow (PIL) n'est pas installé.")
        print("Vous pouvez installer Pillow avec : pip install Pillow")
        print("Ou créer manuellement une image background.png de 500x300 pixels.")
    except Exception as e:
        print(f"Erreur lors de la création de l'image : {e}")
        print("Vous pouvez créer manuellement une image background.png de 500x300 pixels.")