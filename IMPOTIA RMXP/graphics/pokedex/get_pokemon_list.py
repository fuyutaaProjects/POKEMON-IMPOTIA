import os

# Chemin du dossier contenant les fichiers PNG
folder_path = 'pokefront'

# Nom du fichier de sortie
output_file = 'pokemon_list.txt'

# Liste pour stocker les noms des fichiers sans extension
file_names = []

# Lecture des fichiers dans le dossier
for file in os.listdir(folder_path):
    if file.endswith('.png'):
        # Enlever l'extension du fichier
        file_name = os.path.splitext(file)[0]
        # Ajouter le nom à la liste
        file_names.append(file_name)

# Vérification si le fichier de sortie existe, sinon le créer
if not os.path.exists(output_file):
    open(output_file, 'w').close()

# Écriture des noms de fichiers dans le fichier de sortie
with open(output_file, 'w') as f:
    for name in file_names:
        f.write(name + '\n')

print(f"Les noms des fichiers ont été écrits dans {output_file}")
