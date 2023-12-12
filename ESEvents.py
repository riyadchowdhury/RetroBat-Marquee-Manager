from flask import Flask, request
import configparser
import subprocess
import os
import json
import urllib.parse
import shlex
import xml.etree.ElementTree as ET

app = Flask(__name__)
config = configparser.ConfigParser()

def load_config():
    config.read('events.ini')
    print("Configuration chargée.")

def load_systems_config(xml_relative_path):
    script_dir = os.path.dirname(os.path.realpath(__file__))
    xml_path = os.path.join(script_dir, xml_relative_path)
    tree = ET.parse(xml_path)
    root = tree.getroot()

    system_folders = {}

    for system in root.findall('system'):
        if system.find('name') is not None and system.find('path') is not None:
            name = system.find('name').text
            path = system.find('path').text

            # Recherche du nom du dossier des roms
            roms_path = config['Settings']['RomsPath']
            folder_rom_name = os.path.basename(os.path.normpath(path.strip('~\\..')))

            print(f"Systeme {name} chargé avec le folder_rom_name {folder_rom_name} path {path}")
            system_folders[name] = folder_rom_name
        else:
            print(f"Élément manquant name et/ou path dans le fichier es_systems.cfg pour le système {system.tag}")

    return system_folders

def launch_media_player():
    kill_command = config['Settings']['MPVKillCommand']
    subprocess.run(kill_command, shell=True)
    print(f"Commande de kill exécutée : {kill_command}")

    launch_command = config['Settings']['MPVLaunchCommand'].format(
        MPVPath=config['Settings']['MPVPath'],
        IPCChannel=config['Settings']['IPCChannel'],
        ScreenNumber=config['Settings'].get('ScreenNumber', '1'),
        DefaultImagePath=config['Settings']['DefaultImagePath']
    )
    subprocess.Popen(launch_command, shell=True)
    print(f"Commande de lancement de MPV exécutée : {launch_command}")

def is_mpv_running():
    try:
        test_command = config['Settings']['MPVTestCommand'].format(IPCChannel=config['Settings']['IPCChannel'])
        subprocess.run(test_command, shell=True, check=True)
        print("MPV est en cours d'exécution.")
        return True
    except subprocess.CalledProcessError:
        print("MPV n'est pas en cours d'exécution.")
        return False

def ensure_mpv_running():
    if not is_mpv_running():
        launch_media_player()

def escape_file_path(path):
    return shlex.quote(path)

def find_marquee_file(system_name, game_name, systems_config):
    folder_rom_name = systems_config.get(system_name, system_name)

    if system_name == 'collection':
        full_marquee_path = os.path.join(config['Settings']['RetroBatPath'], 'marquees\images',game_name)
        print(f"COLLECTION param1 : {system_name} - param2 : {game_name} - folder_rom_name : {folder_rom_name}")
        print(f"Chemin du marquee de la collection(full_marquee_path) : {full_marquee_path}")
        marquee_file = find_file(full_marquee_path)
        if marquee_file:
            print(f"Marquee de la collection trouvé : {marquee_file}")
            return marquee_file

    marquee_structure = config['Settings']['MarqueeFilePath']
    marquee_path = marquee_structure.format(system_name=folder_rom_name, game_name=game_name)
    if game_name == '':
        game_name = folder_rom_name
    print(f"GAME marquee_structure : {marquee_structure} system_name : {system_name} - game_name : {game_name} - folder_rom_name : {folder_rom_name} - marquee_path : {marquee_path}")
    full_marquee_path = os.path.join(config['Settings']['MarqueeImagePath'], marquee_path)
    print(f"Chemin du marquee du jeu(full_marquee_path) : {full_marquee_path}")
    marquee_file = find_file(full_marquee_path)
    if marquee_file:
        print(f"Marquee du jeu trouvé : {marquee_file}")
        return marquee_file

    marquee_structure = config['Settings']['SystemFilePath']
    marquee_path = marquee_structure.format(system_name=folder_rom_name)
    print(f"SYSTEM marquee_structure : {marquee_structure} system_name : {system_name} - folder_rom_name : {folder_rom_name} - marquee_path : {marquee_path}")
    if not system_name and not folder_rom_name and not marquee_path:
            marquee_path = 'retrobat'
    full_marquee_path = os.path.join(config['Settings']['SystemMarqueePath'], marquee_path)
    print(f"Chemin du marquee du système(full_marquee_path) : {full_marquee_path}")
    marquee_file = find_file(full_marquee_path)
    if marquee_file:
        print(f"Marquee du système trouvé : {marquee_file}")
        return marquee_file

    print(f"Utilisation de l'image par défaut : {config['Settings']['DefaultImagePath']}")
    return config['Settings']['DefaultImagePath']

def find_file(base_path):
    for fmt in config['Settings']['AcceptedFormats'].split(','):
        full_path = f"{base_path}.{fmt.strip()}"
        if os.path.isfile(full_path):
            print(f"Fichier trouvé : {full_path}")
            return full_path
    print(f"Aucun fichier trouvé pour : {base_path}")
    return None

def parse_path(params, systems_config):
    system_detected = False
    game_detected = False
    system_name = ''
    for param in params.values():
        decoded_param = urllib.parse.unquote_plus(param)
        print(f"Paramètre décodé : {decoded_param}")
        formatted_path = os.path.normpath(decoded_param)
        print(f"Chemin formaté : {formatted_path}")

        folder_rom_name = systems_config.get(decoded_param, '')
        if folder_rom_name == '' :
            roms_path = config['Settings']['RomsPath']
            if formatted_path.startswith(roms_path):
                folder_rom_name = formatted_path[len(roms_path):].strip('\\/')
                folder_rom_name = folder_rom_name.split('\\')[0] if '\\' in folder_rom_name else folder_rom_name
                system_name = folder_rom_name
            else:
                folder_rom_name = os.path.basename(os.path.normpath(formatted_path))

        print(f"folder_rom_name : {folder_rom_name}")
        folder_rom_path = os.path.join(config['Settings']['RomsPath'], folder_rom_name)
        print(f"folder_rom_path : {folder_rom_path}")
        if folder_rom_name and os.path.isdir(folder_rom_path):
            print(f"Dossier de roms système détecté : {decoded_param}")
            system_detected = True
            if system_name == '' :
                system_name = decoded_param

        if os.path.isfile(formatted_path):
            game_detected = True
            path_parts = formatted_path.split(os.sep)
            game_name = os.path.splitext(os.path.basename(formatted_path))[0]
            if system_name == '' :
                system_name = path_parts[-2] if len(path_parts) > 1 else ''
            print(f"Dossier de roms système : {system_name}, Nom du jeu : {game_name}")
            return system_name, game_name

    if system_detected:
        return system_name, ''

    if not game_detected and not system_detected and params:
        first_param = next(iter(params.values()))
        print(f"Simple paramètre détecté : {first_param}")
        return 'collection', first_param

    print("Aucun chemin de fichier valide trouvé dans les paramètres.")
    return '', ''

def execute_command(action, params, systems_config):
    if action in config['Commands']:
        system_name, game_name = parse_path(params, systems_config)
        marquee_file = find_marquee_file(system_name, game_name, systems_config)
        escaped_marquee_file = escape_file_path(marquee_file)
        command = config['Commands'][action].format(
            marquee_file=escaped_marquee_file,
            IPCChannel=config['Settings']['IPCChannel']
        )
        print(f"Exécution de la commande : {command}")
        subprocess.run(command, shell=True)
        return json.dumps({"status": "success", "action": action, "command": command})
    return json.dumps({"status": "error", "message": "No command configured for this action"})

@app.route('/', methods=['GET'])
def handle_request():
    ensure_mpv_running()
    action = request.args.get('event', '')
    params = dict(request.args)
    print(f"Action reçue : {action}, Paramètres : {params}")
    params.pop('event', None)
    return execute_command(action, params, systems_config)

if __name__ == '__main__':
    load_config()
    launch_media_player()
    systems_config = load_systems_config(os.path.join(config['Settings']['RetroBatPath'], 'emulationstation', '.emulationstation', 'es_systems.cfg'))
    app.run(host=config['Settings']['Host'], port=int(config['Settings']['Port']), debug=False)
