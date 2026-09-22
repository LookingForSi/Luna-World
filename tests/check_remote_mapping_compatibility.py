import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PROJECTS = (
    "default.project.json",
    "test.project.json",
    "projects/lobby.project.json",
    "projects/moonfall.project.json",
    "projects/dungeon-selene.project.json",
    "projects/dev-combined.project.json",
    "projects/tests.project.json",
)


def remote_contract(project_name):
    project = json.loads((ROOT / project_name).read_text())
    remotes = project["tree"]["ReplicatedStorage"]["Remotes"]
    return {
        name: definition["$className"]
        for name, definition in remotes.items()
        if name != "$className"
    }


expected = remote_contract(PROJECTS[0])
for project_name in PROJECTS[1:]:
    assert remote_contract(project_name) == expected, f"Remote contract drift in {project_name}"

print("Place Remote mappings are compatible: PASS")
