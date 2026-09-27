"""Exercise actual XML overlay, including stale code and cross-tree references."""
import sys
from copy import deepcopy
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/deploy"))
import moonfall_overlay as overlay


def item(parent, name, kind, ref, source=None):
    node = ET.SubElement(parent, "Item", {"class": kind, "referent": ref})
    props = ET.SubElement(node, "Properties")
    ET.SubElement(props, "string", name="Name").text = name
    if source is not None:
        ET.SubElement(props, "ProtectedString", name="Source").text = source
    return node


def apply(base, donor):
    with tempfile.TemporaryDirectory() as directory:
        directory = Path(directory)
        source = directory / "base.rbxlx"
        code = directory / "code.rbxlx"
        output = directory / "output.rbxlx"
        source.write_bytes(ET.tostring(base))
        code.write_bytes(ET.tostring(donor))
        overlay.overlay_place(source, code, output)
        return ET.fromstring(output.read_bytes())


base = ET.Element("roblox", version="4")
world = item(base, "Workspace", "Workspace", "world")
terrain = item(world, "Terrain", "Terrain", "terrain")
ET.SubElement(terrain.find("Properties"), "BinaryString", name="SmoothGrid").text = "ACCEPTED"
storage = item(base, "ReplicatedStorage", "ReplicatedStorage", "storage")
old = item(storage, "Shared", "Folder", "old")
item(old, "Deleted", "ModuleScript", "deleted", "stale")
item(old, "BuildInfo", "ModuleScript", "old-build", "old version")
server_storage = item(base, "ServerStorage", "ServerStorage", "server-storage")
item(server_storage, "MoonfallAuthoring", "Folder", "authoring")
item(base, "ServerScriptService", "ServerScriptService", "base-server")
base_player = item(base, "StarterPlayer", "StarterPlayer", "base-player")
item(base_player, "StarterPlayerScripts", "StarterPlayerScripts", "base-scripts")
fresh = ET.Element("roblox", version="4")
fresh_storage = item(fresh, "ReplicatedStorage", "ReplicatedStorage", "storage")
shared = item(fresh_storage, "Shared", "Folder", "old")
item(shared, "BuildInfo", "ModuleScript", "new-build", 'Version = "0.1.0"')
item(fresh_storage, "Remotes", "Folder", "remotes")
item(fresh_storage, "StudioPlaceRole", "StringValue", "role")
server = item(fresh, "ServerScriptService", "ServerScriptService", "server")
item(server, "Server", "Script", "server-code", "current server")
player = item(fresh, "StarterPlayer", "StarterPlayer", "player")
scripts = item(player, "StarterPlayerScripts", "StarterPlayerScripts", "scripts")
item(scripts, "Client", "LocalScript", "client-code", "current client")
ET.SubElement(terrain.find("Properties"), "Ref", name="ExternalReference").text = "old-build"
ET.SubElement(shared.find("Properties"), "Ref", name="InternalReference").text = "new-build"
missing = deepcopy(fresh)
overlay.child(missing, "ReplicatedStorage").remove(overlay.child(overlay.child(missing, "ReplicatedStorage"), "Shared"))
try:
    apply(deepcopy(base), missing)
except ValueError as error:
    assert "missing production" in str(error)
else:
    raise AssertionError("missing donor root accepted")
preserved = ET.tostring(world)
base = apply(base, fresh)
world = overlay.child(base, "Workspace")
server_storage = overlay.child(base, "ServerStorage")
assert ET.tostring(world) == preserved
assert base.find(".//ProtectedString").text == 'Version = "0.1.0"'
assert not any(n.text == "Deleted" for n in base.iter("string"))
assert not server_storage.findall("Item")
refs = [n.get("referent") for n in base.iter("Item")]
assert len(refs) == len(set(refs))
assert overlay.child(base, "ReplicatedStorage").get("referent") == "storage"
assert base.find(".//Ref[@name='ExternalReference']").text == "old-build"
assert base.find(".//Ref[@name='InternalReference']").text == "old-build"
broken = deepcopy(base)
ET.SubElement(overlay.child(broken, "Workspace").find("Properties"), "Ref", name="Broken").text = "deleted"
with tempfile.TemporaryDirectory() as directory:
    directory = Path(directory)
    source = directory / "base.rbxlx"
    code = directory / "code.rbxlx"
    output = directory / "output.rbxlx"
    source.write_bytes(ET.tostring(broken))
    code.write_bytes(ET.tostring(fresh))
    output.write_bytes(b"previous valid artifact")
    try:
        overlay.overlay_place(source, code, output)
    except ValueError as error:
        assert "dangling" in str(error)
    else:
        raise AssertionError("dangling reference accepted")
    assert output.read_bytes() == b"previous valid artifact"

# An unexpected executable outside managed roots must not silently ship.
item(world, "Unexpected", "Script", "unexpected", "print('unsafe')")
try:
    apply(base, fresh)
except ValueError as error:
    assert "unmanaged" in str(error)
else:
    raise AssertionError("unmanaged script accepted")
print("Moonfall overlay preserves Terrain, replaces stale code, strips authoring, validates scripts/referents: PASS")
