from pathlib import Path
from PIL import Image

# Créer le dossier pokebackshiny s'il n'existe pas
Path("pokebackshiny").mkdir(exist_ok=True)

# Traiter tous les PNG de pokefrontshiny (sans recursion)
for sprite_path in Path("pokefrontshiny").glob("*.png"):
    img = Image.open(sprite_path)
    img_flipped = img.transpose(Image.FLIP_LEFT_RIGHT)
    img_flipped.save(f"pokebackshiny/{sprite_path.name}")
    print(f"Flipped: {sprite_path.name}")