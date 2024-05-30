import os
import json
import shutil

# Path to the directory containing the JSON files
json_directory = './pokemon'  # Make sure the path is correct to your JSON files

# Read the list of Pokémon from pokemons_to_scrape.txt
with open('pokemons_to_scrape.txt', 'r') as file:
    pokemons_to_scrape = [line.strip() for line in file.readlines()]

# Create a new directory for website JSON files
output_directory = './pokemon_website_jsons'
os.makedirs(output_directory, exist_ok=True)

# Function to copy JSON files
def copy_pokemon_files(directory, pokemons_list, output_dir):
    for pokemon_file in os.listdir(directory):
        if pokemon_file.endswith('.json'):
            file_path = os.path.join(directory, pokemon_file)
            with open(file_path, 'r') as f:
                data = json.load(f)
                if 'forms' in data and isinstance(data['forms'], list):
                    for form in data['forms']:
                        if 'resources' in form and 'icon' in form['resources']:
                            icon_name = form['resources']['icon']
                            if icon_name in pokemons_list:
                                # Change the file name to the searched Pokémon's name
                                output_file_name = icon_name + '.json'
                                output_file_path = os.path.join(output_dir, output_file_name)
                                shutil.copyfile(file_path, output_file_path)
                                print(f"Copied {pokemon_file} to {output_file_path}")
                                # Break out of loop if found to prevent copying multiple times
                                break
                else:
                    print(f"Warning: 'forms' key not found or not in correct format in JSON file {pokemon_file}.")

# Call the function
copy_pokemon_files(json_directory, pokemons_to_scrape, output_directory)
