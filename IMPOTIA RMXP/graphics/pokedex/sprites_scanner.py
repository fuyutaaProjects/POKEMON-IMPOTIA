from pathlib import Path

sous_dossiers = [
    "pokeback",
    "pokebackshiny",
    "pokefront",
    "pokefrontshiny",
    "pokeicon",
    "pokeiconshiny"
]

# Lister tous les PNG dans pokefront
sprites_pokefront = {f.name for f in Path("pokefront").glob("*.png")}

# Vérifier chaque sous-dossier
for sous_dossier in sous_dossiers:
    if sous_dossier == "pokefront":
        continue
    
    sprites_actuels = {f.name for f in Path(sous_dossier).glob("*.png")}
    
    # Créer des mappings lowercase pour comparaison insensible à la casse
    sprites_actuels_lower = {s.lower(): s for s in sprites_actuels}
    
    manquants = []
    for sprite in sprites_pokefront:
        # Chercher d'abord le nom exact, sinon en lowercase
        if sprite not in sprites_actuels and sprite.lower() not in sprites_actuels_lower:
            manquants.append(sprite)
    
    manquants = sorted(manquants)
    
    if manquants:
        print("-" * 50)
        print(f"{sous_dossier}:")
        for sprite in sorted(manquants):
            print(f"  {sprite}")

if __name__ == "__main__":
    pass