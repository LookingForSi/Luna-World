#!/usr/bin/env python3
"""Release version contract: repository VERSION and runtime BuildInfo stay synchronized."""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
build_info = (ROOT / "src/shared/config/BuildInfo.luau").read_text(encoding="utf-8")
character_config = (ROOT / "src/shared/config/CharacterConfig.luau").read_text(encoding="utf-8")

match = re.search(r'Version\s*=\s*"([^"]+)"', build_info)
assert match is not None, "BuildInfo.Version missing"
assert match.group(1) == version, f"VERSION={version!r} != BuildInfo.Version={match.group(1)!r}"
assert f'BuildLabel = "v{version}"' in build_info, "runtime BuildLabel must be v<VERSION>"
assert 'BuildLabel = BuildInfo.BuildLabel' in character_config, "CharacterConfig must not hardcode a build label"
assert "dev0.3-playtest-rc1" not in character_config, "legacy hardcoded playtest label must not return"

print(f"Version contract: PASS ({version})")
