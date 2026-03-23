import json
import os
import sys

import requests

# You can easily change this to a room ID you are in that has a huge history
ROOM_ID = os.environ.get("MATRIX_ROOM_ID", "!OGEhHVWSdvArJbQdhm:matrix.org")
HOMESERVER = os.environ.get("MATRIX_HOMESERVER", "https://matrix.org")
ACCESS_TOKEN = os.environ.get("MATRIX_TOKEN")

if not ACCESS_TOKEN:
    print("Error: Please set the MATRIX_TOKEN environment variable.")
    print("How to get it:")
    print("  1. Open Element Web / Desktop")
    print("  2. Click your profile picture -> All Settings -> Help & About")
    print(
        "  3. Scroll to the bottom and click '<click to reveal>' next to Access Token"
    )
    print("\nThen run:")
    print("  export MATRIX_TOKEN='your_token'")
    print("  python3 .tmp/fetch_matrix_state.py")
    sys.exit(1)

print(f"Fetching room state for {ROOM_ID}...", file=sys.stderr)
headers = {"Authorization": f"Bearer {ACCESS_TOKEN}"}
state_res = requests.get(
    # f"{HOMESERVER}/_matrix/federation/v1/state_ids/{ROOM_ID}", headers=headers
    f"{HOMESERVER}/_matrix/client/v3/rooms/{ROOM_ID}/state",
    headers=headers,
)

if state_res.status_code != 200:
    print(f"Failed to fetch state: {state_res.text}", file=sys.stderr)
    sys.exit(1)

state_events = state_res.json()
with open("res/real_matrix_state.json", "w") as f:
    json.dump(state_events, f, indent=2)

print(
    f"\nSuccess! Saved {len(state_events)} real state events to res/real_matrix_state.json",
    file=sys.stderr,
)
