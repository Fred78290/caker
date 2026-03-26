#!/bin/bash
# Script pour créer une image de fond simple pour le DMG

cd "$(dirname "$0")"

echo "Creating background image for DMG..."

# Vérifier si ImageMagick est disponible
if python3 -c "import PIL" 2>/dev/null; then
    echo "Using Python/Pillow to create background..."
    python3 create_background.py
elif command -v convert >/dev/null 2>&1; then
    echo "Using ImageMagick to create background..."
    magick convert -size 500x300 gradient:#f0f0f0-#e0e0e0 \
            -gravity South \
			-font /Library/Fonts/SF-Pro-Rounded-Medium.otf \
            -pointsize 24 \
            -fill "#666666" \
            -annotate +0+30 "Drag and drop Caker.app to Applications to install" \
            background.png
    echo "Background image created successfully: background.png"
else
    echo "Neither ImageMagick nor Pillow are available."
    echo "Creating a simple background with available tools..."
    
    # Créer une image simple avec un fond uni
    cat > background_simple.png << 'EOF'
iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==
EOF
    
    # Étendre cette image 1x1 à 500x300 avec sips
    sips -z 300 500 background_simple.png --out background.png 2>/dev/null && rm background_simple.png
    
    if [ -f background.png ]; then
        echo "Simple background created: background.png"
    else
        echo "Warning: Could not create background image automatically."
        echo "Please create a 500x300 PNG image named 'background.png' manually."
        echo "The DMG will still work without a background image."
    fi
fi