import os
import json

"""
Ce script a pour objectif de parcourir tous les fichiers JSON présents dans le dossier "pokemon"
et de mettre à jour les valeurs des champs dans la section "resources" de chaque fichier.

Pour chaque fichier JSON, le script :
1. Lit le fichier JSON et extrait la valeur du champ "icon" dans la section "resources".
2. Met à jour tous les autres champs de "resources" pour qu'ils aient la même valeur que le champ "icon",
   à l'exception des champs "cry" et "hasFemale", qui restent inchangés.
"""

# Chemin du dossier contenant les fichiers JSON
folder = "pokemon"

# Fonction pour mettre à jour les ressources dans un fichier JSON
def update_resources(file_path):
    with open(file_path, 'r', encoding='utf-8') as file:
        data = json.load(file)

    icon_value = data["forms"][0]["resources"]["icon"]
    
    for form in data["forms"]:
        resources = form["resources"]
        for key in resources:
            if key not in ["cry", "hasFemale", "icon"]:
                resources[key] = icon_value
    
    with open(file_path, 'w', encoding='utf-8') as file:
        json.dump(data, file, indent=2)
        print(f"Mis à jour: {file_path}")

# Parcourir tous les fichiers dans le dossier
def update_all_files(folder):
    for filename in os.listdir(folder):
        if filename.endswith(".json"):
            file_path = os.path.join(folder, filename)
            update_resources(file_path)

if __name__ == "__main__":
    update_all_files(folder)
