#!/usr/bin/env python3
"""Publish an already validated production artifact set in fail-fast order."""

from __future__ import annotations

import json
import os
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CONFIG = json.loads((ROOT / "tools/deploy/production.json").read_text(encoding="utf-8"))
ARTIFACT_DIR = ROOT / "artifacts/deploy"
RESULT_PATH = ARTIFACT_DIR / "publish-results.json"


def refuse(message: str) -> None:
    raise SystemExit(f"production publish refused: {message}")


def publish(universe_id: str, place: dict, api_key: str) -> dict:
    artifact = ARTIFACT_DIR / place["artifact"]
    query = urllib.parse.urlencode({"versionType": "Published"})
    url = f"https://apis.roblox.com/universes/v1/{universe_id}/places/{place['placeId']}/versions?{query}"
    print(f"Publishing {place['name']} (Place {place['placeId']})")
    request = urllib.request.Request(
        url,
        data=artifact.read_bytes(),
        method="POST",
        headers={"x-api-key": api_key, "Content-Type": "application/xml"},
    )
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            payload = response.read().decode("utf-8")
            if not 200 <= response.status < 300:
                refuse(f"{place['name']} returned HTTP {response.status}: {payload}")
    except urllib.error.HTTPError as error:
        detail = error.read().decode("utf-8", errors="replace")
        refuse(f"{place['name']} returned HTTP {error.code}: {detail}")
    except urllib.error.URLError as error:
        refuse(f"{place['name']} request failed: {error.reason}")
    try:
        result = json.loads(payload)
    except json.JSONDecodeError:
        result = {"response": payload}
    version = result.get("versionNumber", result.get("version", result))
    print(f"Published {place['name']}; Roblox result/version: {version}")
    return {"key": place["key"], "name": place["name"], "placeId": place["placeId"], "result": result}


def main() -> None:
    api_key = os.environ.get("ROBLOX_API_KEY")
    if not api_key:
        refuse("ROBLOX_API_KEY is not set")
    places = CONFIG.get("places", [])
    if [place.get("key") for place in places] != ["ruins", "moonfall", "lobby"]:
        refuse("configured deployment order must be ruins, moonfall, lobby")
    for place in places:
        artifact = ARTIFACT_DIR / place["artifact"]
        if not artifact.is_file() or artifact.stat().st_size == 0:
            refuse(f"artifact is missing or empty: {artifact.relative_to(ROOT)}")

    results = []
    for place in places:
        results.append(publish(CONFIG["universeId"], place, api_key))
    RESULT_PATH.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
