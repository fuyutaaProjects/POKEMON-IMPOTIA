import os
import json
import re

# Chemin du dossier contenant les fichiers JSON
pokemon_folder_path = 'Data/Studio/pokemon'

# Nom du fichier contenant la liste des Pokémon
pokemon_list_file = 'pokemon_list.txt'

# Types de fichiers à éditer
file_types = ['.json', '.csv', '.yml']

# Lecture de la liste des Pokémon
with open(pokemon_list_file, 'r', encoding='utf-8') as f:
    pokemon_list = [line.strip().lower() for line in f]

# Variable pour stocker les correspondances
correspondences = []
non_found_correspondences = pokemon_list.copy()

# Parcours des fichiers dans le dossier pour trouver les correspondances
for file in os.listdir(pokemon_folder_path):
    if file.endswith('.json'):
        file_path = os.path.join(pokemon_folder_path, file)
        
        with open(file_path, 'r', encoding='utf-8') as json_file:
            data = json.load(json_file)
        
        # Récupération du nom du Pokémon depuis le champ "icon"
        pokemon_name = data["forms"][0]["resources"]["icon"].lower()
        
        # Si le nom du Pokémon est dans la liste, ajouter à la liste des correspondances
        if pokemon_name in pokemon_list:
            correspondences.append((pokemon_name, file_path))
            if pokemon_name in non_found_correspondences:
                non_found_correspondences.remove(pokemon_name)

# Fonction pour remplacer les noms dans un fichier
def replace_names_in_file(file_path, replacements):
    with open(file_path, 'r', encoding='utf-8') as file:
        content = file.read()
    
    for old_name, new_name in replacements:
        # Remplacer en tenant compte de la casse
        content = re.sub(re.escape(old_name), new_name, content)
        content = re.sub(re.escape(old_name.capitalize()), new_name.capitalize(), content)
    
    with open(file_path, 'w', encoding='utf-8') as file:
        file.write(content)

# Trouver tous les fichiers dans le projet à partir de la racine
project_root = os.getcwd()

# Liste pour stocker les chemins des fichiers à modifier
files_to_modify = []

# Parcours de tous les fichiers du projet
for root, _, files in os.walk(project_root):
    for file in files:
        if any(file.endswith(ext) for ext in file_types):
            files_to_modify.append(os.path.join(root, file))

# Remplacements à effectuer (nom actuel -> nouveau nom)
replacements = [(os.path.splitext(os.path.basename(file_path))[0], pokemon_name)
                for pokemon_name, file_path in correspondences]

# Remplacer les noms dans chaque fichier à modifier
for file_path in files_to_modify:
    replace_names_in_file(file_path, replacements)

# Renommer les fichiers JSON
for old_name, new_name in replacements:
    old_file_path = os.path.join(pokemon_folder_path, old_name + '.json')
    new_file_path = os.path.join(pokemon_folder_path, new_name + '.json')
    
    if os.path.exists(old_file_path):
        os.rename(old_file_path, new_file_path)
        print(f"Renommé {old_file_path} en {new_file_path}")

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
