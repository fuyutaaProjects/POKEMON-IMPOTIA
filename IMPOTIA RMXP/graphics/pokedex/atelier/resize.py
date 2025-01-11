from PIL import Image
import os

def downscale_images(input_folder):
    """
    Redimensionne les images de 128x64 en 64x32 dans le dossier d'entrée et écrase les images originales.

    Args:
        input_folder (str): Chemin vers le dossier contenant les images.
    """
    # Parcourir toutes les images dans le dossier d'entrée
    for filename in os.listdir(input_folder):
        if filename.endswith('.png'):
            filepath = os.path.join(input_folder, filename)
            with Image.open(filepath) as img:
                # Vérifier la taille de l'image
                if img.size == (128, 64):
                    # Redimensionner l'image en 64x32
                    resized_img = img.resize((64, 32), resample=Image.NEAREST)
                    # Sauvegarder l'image redimensionnée au même chemin
                    resized_img.save(filepath)
                    print(f"Image {filename} redimensionnée et écrasée.")
                else:
                    print(f"Image {filename} ignorée (taille: {img.size})")

if __name__ == "__main__":
    # Chemin vers le dossier contenant les images
    input_folder = "pokeiconshiny"

    downscale_images(input_folder)
