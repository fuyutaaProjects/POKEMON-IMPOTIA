from pathlib import Path
from PIL import Image

# Créer le dossier pokeback s'il n'existe pas
Path("pokeback").mkdir(exist_ok=True)

# Traiter tous les PNG de pokefront
for sprite_path in Path("pokefront").glob("*.png"):
    img = Image.open(sprite_path)
    img_flipped = img.transpose(Image.FLIP_LEFT_RIGHT)
    img_flipped.save(f"pokeback/{sprite_path.name}")
    print(f"Flipped: {sprite_path.name}")