import os
import shutil

# Scanner to check if there are missing files in one folder compared to another (or if a file is missing among all folders)
# There are several scan options.

# Folder paths
folders = {
    "pokefront": "pokefront",
    "pokefrontshiny": "pokefrontshiny",
    "pokeicon": "pokeicon",
    "pokeiconshiny": "pokeiconshiny",
    "pokeback": "pokeback",
    "pokebackshiny": "pokebackshiny",
    "missing_sprites": "missing_sprites"
}

# Function to get the list of files in a folder
def list_files(folder):
    return set(os.listdir(folder))

# Function to check if the content of one folder is present in another
def check_content(folder1, folder2):
    files1 = list_files(folders[folder1])
    files2 = list_files(folders[folder2])
    missing_in_folder2 = files1 - files2
    missing_in_folder1 = files2 - files1
    return missing_in_folder2, missing_in_folder1

# Function to copy missing files to a destination folder
def copy_files_to_missing_folder(missing_files, src_folder):
    missing_folder = folders["missing_sprites"]
    os.makedirs(missing_folder, exist_ok=True)
    for file in missing_files:
        src_path = os.path.join(folders[src_folder], file)
        dest_path = os.path.join(missing_folder, file)
        shutil.copy(src_path, dest_path)
        print(f"Copied {file} from {src_folder} to {missing_folder}")

# Function to display results and prompt to copy missing files
def display_results_and_copy(missing_in_folder2, missing_in_folder1, folder1, folder2):
    if not missing_in_folder2 and not missing_in_folder1:
        print(f"Folders {folder1} and {folder2} have the same content.")
    else:
        if missing_in_folder2:
            print(f"The following files are missing in {folder2}: {missing_in_folder2}")
            copy = input(f"Do you want to copy the missing files from {folder1} to the 'missing_sprites' folder? (yes/no): ")
            if copy.lower() == 'yes':
                copy_files_to_missing_folder(missing_in_folder2, folder1)
        if missing_in_folder1:
            print(f"The following files are missing in {folder1}: {missing_in_folder1}")
            copy = input(f"Do you want to copy the missing files from {folder2} to the 'missing_sprites' folder? (yes/no): ")
            if copy.lower() == 'yes':
                copy_files_to_missing_folder(missing_in_folder1, folder2)

# Main menu
def main():
    while True:
        print("\nMenu:")
        print("1. Check if the content of pokefront is present in all folders")
        print("2. Check if pokefront and pokeback have the same content")
        print("3. Check if pokeicon and pokeiconshiny have the same content")
        print("4. Compare pokefrontshiny with pokefront")
        print("5. Compare pokeback with pokebackshiny")
        print("6. Compare two other folders")
        print("7. Exit")

        choice = input("Choose an option: ")

        if choice == '1':
            for folder in folders:
                if folder != "pokefront" and folder != "missing_sprites":
                    print(f"\nChecking pokefront with {folder}:")
                    missing_in_folder2, missing_in_folder1 = check_content("pokefront", folder)
                    display_results_and_copy(missing_in_folder2, missing_in_folder1, "pokefront", folder)
        
        elif choice == '2':
            print("\nChecking pokefront with pokeback:")
            missing_in_folder2, missing_in_folder1 = check_content("pokefront", "pokeback")
            display_results_and_copy(missing_in_folder2, missing_in_folder1, "pokefront", "pokeback")
        
        elif choice == '3':
            print("\nChecking pokeicon with pokeiconshiny:")
            missing_in_folder2, missing_in_folder1 = check_content("pokeicon", "pokeiconshiny")
            display_results_and_copy(missing_in_folder2, missing_in_folder1, "pokeicon", "pokeiconshiny")

        elif choice == '4':
            print("\nChecking pokefrontshiny with pokefront:")
            missing_in_folder2, missing_in_folder1 = check_content("pokefrontshiny", "pokefront")
            display_results_and_copy(missing_in_folder2, missing_in_folder1, "pokefrontshiny", "pokefront")

        elif choice == '5':
            print("\nChecking pokeback with pokebackshiny:")
            missing_in_folder2, missing_in_folder1 = check_content("pokeback", "pokebackshiny")
            display_results_and_copy(missing_in_folder2, missing_in_folder1, "pokeback", "pokebackshiny")
        
        elif choice == '6':
            print("\nList of available folders: ")
            for i, folder in enumerate(folders.keys()):
                print(f"{i+1}. {folder}")
            folder1 = int(input("Choose the first folder: ")) - 1
            folder2 = int(input("Choose the second folder: ")) - 1
            folder1_name = list(folders.keys())[folder1]
            folder2_name = list(folders.keys())[folder2]
            print(f"\nChecking {folder1_name} with {folder2_name}:")
            missing_in_folder2, missing_in_folder1 = check_content(folder1_name, folder2_name)
            display_results_and_copy(missing_in_folder2, missing_in_folder1, folder1_name, folder2_name)
        
        elif choice == '7':
            break
        else:
            print("Invalid choice, please try again.")

if __name__ == "__main__":
    main()
