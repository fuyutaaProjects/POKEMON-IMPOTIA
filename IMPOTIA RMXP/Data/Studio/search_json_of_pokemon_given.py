import os
import json

# asks for a pokemon name, and searches the corresponding json

folder = "pokemon"

def search_by_icon(icon_name):
    for filename in os.listdir(folder):
        if filename.endswith(".json"):
            file_path = os.path.join(folder, filename)
            with open(file_path, 'r', encoding='utf-8') as file:
                data = json.load(file)
                for form in data["forms"]:
                    if form["resources"]["icon"] == icon_name:
                        return filename
    return None

if __name__ == "__main__":
    icon_name = input("Entrez le nom de l'icon à rechercher: ")
    result = search_by_icon(icon_name)
    if result:
        print(f"Le fichier contenant l'icon '{icon_name}' est : {result}")
    else:
        print(f"Aucun fichier ne contient l'icon '{icon_name}'")
