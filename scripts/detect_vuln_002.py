#!/usr/bin/env python3
import glob
import json
import os
import sys


def check_vk(filepath):
    try:
        with open(filepath) as f:
            vk = json.load(f)

        gamma_2 = vk.get("vk_gamma_2")
        delta_2 = vk.get("vk_delta_2")

        if not gamma_2 or not delta_2:
            return True

        if gamma_2 == delta_2:
            print(
                f"[!] VULNERABILITY DETECTED in {filepath}: vk_gamma_2 == vk_delta_2 (Skipped Phase 2 Setup)"
            )
            return False
        else:
            return True

    except Exception as e:
        # Not a json file or invalid json, ignore
        pass
    return True


if __name__ == "__main__":
    success = True
    # Search for all json files in the project
    for root, _, files in os.walk("."):
        if "/target/" in root or "/node_modules/" in root or "/.git/" in root:
            continue
        for file in files:
            if file.endswith(".json"):
                path = os.path.join(root, file)
                if not check_vk(path):
                    success = False

    if not success:
        sys.exit(1)
    else:
        print(
            "[✓] No Groth16 Phase 2 setup vulnerabilities (vk_gamma_2 == vk_delta_2) detected."
        )
        sys.exit(0)
