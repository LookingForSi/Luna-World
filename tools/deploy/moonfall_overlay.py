"""Overlay the explicitly owned production roots; never reconstruct the world."""

from __future__ import annotations

from copy import deepcopy
import xml.etree.ElementTree as ET


MANAGED_PATHS = (
    ("ReplicatedStorage", "Shared"),
    ("ReplicatedStorage", "Remotes"),
    ("ReplicatedStorage", "StudioPlaceRole"),
    ("ServerScriptService", "Server"),
    ("StarterPlayer", "StarterPlayerScripts", "Client"),
)


def child(parent: ET.Element, name: str) -> ET.Element | None:
    matches = [node for node in parent.findall("Item")
               if node.findtext("Properties/string[@name='Name']") == name]
    if len(matches) > 1:
        raise ValueError(f"ambiguous instance name: {name}")
    return matches[0] if matches else None


def index(root: ET.Element) -> dict[tuple[str, ...], ET.Element]:
    result = {}

    def walk(parent, path):
        for node in parent.findall("Item"):
            name = node.findtext("Properties/string[@name='Name']")
            key = (*path, name)
            if key in result:
                raise ValueError(f"ambiguous managed path: {key}")
            result[key] = node
            walk(node, key)

    walk(root, ())
    return result


def apply_overlay(base: ET.Element, code: ET.Element) -> None:
    # Rojo is a code/config donor only. New ownership needs an explicit review.
    generated = index(code)
    if any(path not in generated for path in MANAGED_PATHS):
        raise ValueError("missing production root in code donor")
    allowed = lambda path: any(path[:len(p)] == p or p[:len(path)] == path for p in MANAGED_PATHS)
    if any(not allowed(path) for path in generated):
        raise ValueError("production project contains unsupported ownership paths")
    if code.find("SharedStrings") is not None:
        raise ValueError("unexpected shared-string table in code donor")
    for path, node in generated.items():
        if not any(path[:len(p)] == p for p in MANAGED_PATHS):
            if any(prop.get("name") != "Name" for prop in node.findall("Properties/*")):
                raise ValueError(f"unsupported container properties: {path}")

    # Remove only the known dev-only export residue, never authored geometry.
    storage = child(base, "ServerStorage")
    if storage is not None:
        authoring = child(storage, "MoonfallAuthoring")
        if authoring is not None:
            storage.remove(authoring)

    # Index only managed service trees: authored models may use duplicate names.
    existing = {}
    for path in generated:
        parent = base
        for name in path:
            parent = child(parent, name)
            if parent is None:
                break
        if parent is not None:
            existing[path] = parent
    used = {node.get("referent") for node in base.iter("Item")}
    remap = {}
    for number, (path, node) in enumerate(generated.items()):
        old = existing.get(path)
        if old is not None and old.get("class") == node.get("class"):
            ref = old.get("referent")
        else:
            ref = f"RBXLUNADEPLOY{number}"
            while ref in used:
                ref += "X"
        used.add(ref)
        remap[node.get("referent")] = ref
    donor = deepcopy(code)
    for node in donor.iter("Item"):
        node.set("referent", remap[node.get("referent")])
    for ref in donor.iter("Ref"):
        if ref.text in remap:
            ref.text = remap[ref.text]
    generated = index(donor)
    for path in MANAGED_PATHS:
        parent = base
        for depth, name in enumerate(path[:-1], 1):
            found = child(parent, name)
            if found is None:
                found = deepcopy(generated[path[:depth]])
                for nested in found.findall("Item"):
                    found.remove(nested)
                parent.append(found)
            elif found.get("class") != generated[path[:depth]].get("class"):
                raise ValueError(f"container class mismatch: {path[:depth]}")
            parent = found
        old = child(parent, path[-1])
        if old is not None:
            parent.remove(old)
        parent.append(deepcopy(generated[path]))

    managed_ids = set()
    for path in MANAGED_PATHS:
        parent = base
        for name in path:
            parent = child(parent, name)
            if parent is None:
                break
        if parent is not None:
            managed_ids.update(id(node) for node in parent.iter("Item"))
    for node in base.iter("Item"):
        if node.get("class") in {"Script", "LocalScript", "ModuleScript"} and id(node) not in managed_ids:
            raise ValueError("unmanaged executable in accepted Place")
    refs = [node.get("referent") for node in base.iter("Item")]
    if None in refs or len(refs) != len(set(refs)):
        raise ValueError("missing or duplicate instance referents")
    valid_refs = {None, "null", "nil", *refs}
    for ref in base.iter("Ref"):
        if ref.text not in valid_refs:
            raise ValueError(f"dangling instance reference: {ref.text}")
