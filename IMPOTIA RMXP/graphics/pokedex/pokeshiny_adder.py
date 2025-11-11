from pathlib import Path
import shutil

# Lister tous les PNG dans pokefront
sprites_pokefront = {f.name for f in Path("pokefront").glob("*.png")}

# Lister tous les PNG dans pokefrontshiny
sprites_shiny = {f.name for f in Path("pokefrontshiny").glob("*.png")}

# Créer un mapping lowercase pour comparaison
sprites_shiny_lower = {s.lower(): s for s in sprites_shiny}

# Trouver les manquants
manquants = []
for sprite in sprites_pokefront:
    if sprite not in sprites_shiny and sprite.lower() not in sprites_shiny_lower:
        manquants.append(sprite)

manquants = sorted(manquants)

# Afficher les manquants
if manquants:
    print("-" * 50)
    print("Sprites manquants dans pokefrontshiny:")
    for sprite in manquants:
        print(f"  {sprite}")
    print("-" * 50)
    
    # Créer le dossier pokefrontshiny s'il n'existe pas
    Path("pokefrontshiny").mkdir(exist_ok=True)
    
    # Copier les sprites manquants
    copies = []
    for sprite in manquants:
        src = Path("pokefront") / sprite
        dst = Path("pokefrontshiny") / sprite
        shutil.copy2(src, dst)
        copies.append(sprite)
        print(f"Copié: {sprite}")
    
    # Écrire la liste dans un fichier texte
    with open("sprites_copies.txt", "w", encoding="utf-8") as f:
        f.write("Sprites copiés de pokefront vers pokefrontshiny:\n")
        f.write("=" * 50 + "\n")
        for sprite in copies:
            f.write(f"{sprite}\n")
    
    print("-" * 50)
    print(f"✓ {len(copies)} sprite(s) copié(s)")
    print(f"✓ Liste sauvegardée dans sprites_copies.txt")
else:
    print("Aucun sprite manquant dans pokefrontshiny")