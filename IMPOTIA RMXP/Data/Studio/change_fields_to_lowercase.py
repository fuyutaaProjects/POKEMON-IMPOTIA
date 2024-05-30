import os
import json

# Chemin du dossier contenant les fichiers JSON
folder_path = 'pokemon'

# Nom du fichier contenant la liste des Pokémon
pokemon_list_file = 'pokemon_list.txt'

# Lecture de la liste des Pokémon
with open(pokemon_list_file, 'r', encoding='utf-8') as f:
    pokemon_list = [line.strip().lower() for line in f]

# Fonction pour mettre à jour les champs des ressources dans les fichiers JSON
def update_resources(file_path, new_name):
    with open(file_path, 'r', encoding='utf-8') as file:
        data = json.load(file)
    
    resources = data["forms"][0]["resources"]
    
    # Mise à jour des champs nécessaires
    fields_to_update = [
        "icon", "iconShiny", "front", "frontShiny", "back", "backShiny", 
        "footprint", "character", "characterShiny", "frontF", "frontShinyF", 
        "backF", "backShinyF"
    ]
    
    for field in fields_to_update:
        if field in resources:
            resources[field] = new_name

    # Écriture des modifications dans le fichier JSON
    with open(file_path, 'w', encoding='utf-8') as file:
        json.dump(data, file, indent=4, ensure_ascii=False)

# Dictionnaire pour stocker les correspondances nom de Pokémon -> fichier JSON
pokemon_to_file = {}

# Parcours des fichiers dans le dossier pour remplir le dictionnaire
for file in os.listdir(folder_path):
    if file.endswith('.json'):
        file_path = os.path.join(folder_path, file)
        
        with open(file_path, 'r', encoding='utf-8') as json_file:
            data = json.load(json_file)
        
        # Récupération du nom du Pokémon depuis le champ "icon"
        pokemon_name = data["forms"][0]["resources"]["icon"].lower()
        
        # Ajout de la correspondance au dictionnaire
        pokemon_to_file[pokemon_name] = file_path

# Parcours de la liste des Pokémon pour mettre à jour les fichiers JSON correspondants
for pokemon_name in pokemon_list:
    if pokemon_name in pokemon_to_file:
        file_path = pokemon_to_file[pokemon_name]
        update_resources(file_path, pokemon_name)
        print(f"Mise à jour de {file_path} avec le nom {pokemon_name}")
    else:
        print(f"Aucun fichier JSON trouvé pour {pokemon_name}")

print("Mise à jour terminée.")
