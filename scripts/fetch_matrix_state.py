"""
Fetches raw Matrix DAG state resolution arrays dynamically from live Server instances via HTTP.
"""

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
    stream=True,
    timeout=30,
)

if state_res.status_code != 200:
    print(f"Failed to fetch state: {state_res.text}", file=sys.stderr)
    sys.exit(1)

total_size = int(state_res.headers.get("content-length", 0))
downloaded = 0
chunks = []

print("Streaming state payload from Homeserver...", file=sys.stderr)
for chunk in state_res.iter_content(chunk_size=1024 * 1024):
    if chunk:
        chunks.append(chunk)
        downloaded += len(chunk)
        mb = downloaded / (1024 * 1024)
        if total_size > 0:
            percent = (downloaded / total_size) * 100
            print(
                f"\rDownloaded {mb:.2f} MB ({percent:.1f}%)...", end="", file=sys.stderr
            )
        else:
            print(f"\rDownloaded {mb:.2f} MB...", end="", file=sys.stderr)

print("\nParsing massive JSON payload into RAM...", file=sys.stderr)
raw_bytes = b"".join(chunks)
state_events = json.loads(raw_bytes.decode("utf-8"))

with open("res/real_matrix_state.json", "w", encoding="utf-8") as f:
    f.write(raw_bytes.decode("utf-8"))

print(
    f"\nSuccess! Saved {len(state_events)} real state events",
    file=sys.stderr,
)
