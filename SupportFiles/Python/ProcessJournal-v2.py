import os
import json
import time
import pyttsx3
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

# Configurations
INPUT_FOLDER_PATH = r"D:\Users\Den\Saved Games\Frontier Developments\Elite Dangerous"
OUTPUT_FOLDER_PATH = r"C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\Output"
TRACKING_FILE_PATH = r"C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\Tracking.txt"
JSON_FILE_PATH = os.path.join(OUTPUT_FOLDER_PATH, "MyJournalData.json")
MAP_FILE_PATH = r"C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\PowerShell\Lookup\EDData.json"

# Ensure directories exist
os.makedirs(OUTPUT_FOLDER_PATH, exist_ok=True)

# Ensure tracking file exists
if not os.path.exists(TRACKING_FILE_PATH):
    with open(TRACKING_FILE_PATH, "w", encoding="ascii") as f:
        json.dump({"lastTimestamp": None}, f)

# Initialize TTS
engine = pyttsx3.init()
engine.setProperty("voice", "Microsoft Catherine")
engine.setProperty("rate", 150)
engine.setProperty("volume", 0.75)

def speak_text(text):
    """Speak the given text using TTS."""
    engine.say(text)
    engine.runAndWait()

speak_text("Journal processor loading")

# Load Map Data
if os.path.exists(MAP_FILE_PATH):
    with open(MAP_FILE_PATH, "r", encoding="utf-8") as f:
        map_data = json.load(f)
else:
    map_data = {}

def get_mapped_value(map_name, key):
    """Retrieve a mapped value from the map JSON file."""
    return map_data.get(map_name, {}).get(key, "not found")

# Initialize Global Variables
def initialize_global_variables():
    """Ensure global JSON data is initialized with default values."""
    if not os.path.exists(JSON_FILE_PATH):
        default_data = {
            "CMDRName": "not set",
            "ShipName": "not set",
            "ShipType": "not set",
            "StationName": "not set",
            "StationType": "not set",
            "SystemName": "not set",
            "BodyName": "not set",
            "OrganicFound": "not set",
        }
        with open(JSON_FILE_PATH, "w", encoding="utf-8") as f:
            json.dump(default_data, f, indent=4)

    with open(JSON_FILE_PATH, "r", encoding="utf-8") as f:
        return json.load(f)

global_variables = initialize_global_variables()

# Compare and Update Variables
def compare_and_update_variables(new_data):
    """Update global variables if new data differs."""
    changed = False
    keys = ["CMDRName", "ShipName", "ShipType", "StationName", "StationType", "SystemName", "BodyName", "OrganicFound"]

    for key in keys:
        if new_data.get(key) and new_data[key] != global_variables[key]:
            global_variables[key] = new_data[key]
            changed = True

    if changed:
        with open(JSON_FILE_PATH, "w", encoding="utf-8") as f:
            json.dump(global_variables, f, indent=4)
        print("Updated Global Variables:", global_variables)

def process_log_entry(entry):
    """Process a single event entry from the log file."""
    event_type = entry.get("event", "Unknown")
    print(f"Processing Event: {event_type}")

    if event_type == "Commander":
        global_variables["CMDRName"] = entry.get("Name", "Unknown")
    elif event_type == "LoadGame":
        global_variables["ShipType"] = get_mapped_value("ShipType_map", entry.get("Ship", "Unknown"))
    elif event_type == "Docked":
        global_variables["StationName"] = entry.get("StationName", "Unknown")
        global_variables["StationType"] = entry.get("StationType", "Unknown")
    elif event_type == "ShipyardSwap":
        global_variables["ShipType"] = get_mapped_value("ShipType_map", entry.get("Ship", "Unknown"))
    elif event_type == "Location":
        global_variables["SystemName"] = entry.get("StarSystem", "Unknown")
        global_variables["BodyName"] = entry.get("Body", "Unknown")
    elif event_type == "Touchdown":
        global_variables["BodyName"] = entry.get("Body", "Unknown")
    elif event_type == "DockingGranted":
        global_variables["StationName"] = entry.get("StationName", "Unknown")
        global_variables["StationType"] = entry.get("StationType", "Unknown")
    elif event_type == "FSDJump":
        global_variables["SystemName"] = entry.get("StarSystem", "Unknown")
    elif event_type == "ScanOrganic":
        if entry.get("ScanType") == "Analyse" and "Species_Localised" in entry:
            species = entry["Species_Localised"]
            global_variables["OrganicFound"] = species
            value = get_mapped_value("Exobiology_Value_map", species)
            speak_text(f"Value of {species} is {value} million")
    elif event_type == "Shutdown":
        print("Game shutdown detected. Stopping file watcher...")
        observer.stop()

    compare_and_update_variables(global_variables)

class JournalFileHandler(FileSystemEventHandler):
    """Handles new log files in the monitored directory."""
    def on_modified(self, event):
        if event.is_directory or not event.src_path.endswith(".log"):
            return
        process_journal_file(event.src_path)

def process_journal_file(filepath):
    """Process the new or modified journal file."""
    print(f"Processing: {filepath}")
    
    with open(filepath, "r", encoding="utf-8") as file:
        lines = file.readlines()
    
    for line in lines:
        try:
            entry = json.loads(line)
            process_log_entry(entry)
        except json.JSONDecodeError:
            continue
    
    # Update tracking file
    with open(TRACKING_FILE_PATH, "w", encoding="utf-8") as f:
        json.dump({"lastTimestamp": time.time()}, f)

# Start File Watcher
event_handler = JournalFileHandler()
observer = Observer()
observer.schedule(event_handler, INPUT_FOLDER_PATH, recursive=False)

print("Watching for changes in:", INPUT_FOLDER_PATH)
observer.start()

try:
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    observer.stop()

observer.join()
