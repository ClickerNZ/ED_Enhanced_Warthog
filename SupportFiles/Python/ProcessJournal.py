import os
import json
import time
import pyttsx3
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

# Configurations (Equivalent to PowerShell parameters)
INPUT_FOLDER_PATH = r"D:\Users\Den\Saved Games\Frontier Developments\Elite Dangerous"
OUTPUT_FOLDER_PATH = r"C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\Python\Output"
TRACKING_FILE_PATH = r"C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\Python\Tracking.txt"
JSON_FILE_PATH = os.path.join(OUTPUT_FOLDER_PATH, "MyJournalData.json")
MAP_FILE_PATH = r"C:\Thrustmaster\ED_TargetScript_Warthog\SupportFiles\Python\Lookup\EDData.json"

# Ensure output directory exists
os.makedirs(OUTPUT_FOLDER_PATH, exist_ok=True)

# Ensure tracking file exists
if not os.path.exists(TRACKING_FILE_PATH):
    with open(TRACKING_FILE_PATH, "w", encoding="ascii") as f:
        json.dump({"lastTimestamp": None}, f)

# Initialize TTS
engine = pyttsx3.init()
engine.setProperty("voice", "Microsoft Catherine")
engine.setProperty("rate", 150)  # Adjust to match PowerShell's TTS rate
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

# File Watcher for Journal Logs
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

    if lines:
        last_line = json.loads(lines[-1])  # Assuming logs are JSON lines
        compare_and_update_variables(last_line)

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
