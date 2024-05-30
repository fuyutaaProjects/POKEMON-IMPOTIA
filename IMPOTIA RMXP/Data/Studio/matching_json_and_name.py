import os
import json

# Chemin du dossier contenant les fichiers JSON
folder_path = 'pokemon'

# Nom du fichier contenant la liste des Pokémon
pokemon_list_file = 'pokemon_list.txt'

# Lecture de la liste des Pokémon
with open(pokemon_list_file, 'r', encoding='utf-8') as f:
    pokemon_list = [line.strip().lower() for line in f]

# Variable pour stocker les correspondances
correspondences = []
non_found_correspondences = pokemon_list.copy()

# Parcours des fichiers dans le dossier pour trouver les correspondances
for file in os.listdir(folder_path):
    if file.endswith('.json'):
        file_path = os.path.join(folder_path, file)
        
        with open(file_path, 'r', encoding='utf-8') as json_file:
            data = json.load(json_file)
        
        # Récupération du nom du Pokémon depuis le champ "icon"
        pokemon_name = data["forms"][0]["resources"]["icon"].lower()
        
        # Si le nom du Pokémon est dans la liste, ajouter à la liste des correspondances
        if pokemon_name in pokemon_list:
            correspondences.append((pokemon_name, file_path))
            if pokemon_name in non_found_correspondences:
                non_found_correspondences.remove(pokemon_name)

# Affichage de certaines valeurs de la liste de correspondances
total_pokemon = len(pokemon_list)
total_correspondences = len(correspondences)

print("Correspondances trouvées:")
for pokemon_name, file_path in correspondences:
    print(f"Pokémon: {pokemon_name.capitalize()}, Fichier JSON: {file_path}")

print(f"Total des correspondances trouvées: {total_correspondences}/{total_pokemon}")

# Affichage des 5 premières correspondances
print("\nPremières correspondances:")
for pokemon_name, file_path in correspondences[:5]:
    print(f"Pokémon: {pokemon_name.capitalize()}, Fichier JSON: {file_path}")

# Affichage des correspondances non trouvées
print("\nCorrespondances non trouvées:")
for pokemon_name in non_found_correspondences:
    print(f"Pokémon: {pokemon_name.capitalize()}")

print(f"Total des correspondances non trouvées: {len(non_found_correspondences)}")
