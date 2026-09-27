"""Overlay the explicitly owned production roots; never reconstruct the world."""

from __future__ import annotations

import hashlib
from pathlib import Path
import re
import xml.etree.ElementTree as ET


MANAGED_PATHS = (
    ("ReplicatedStorage", "Shared"),
    ("ReplicatedStorage", "Remotes"),
    ("ReplicatedStorage", "StudioPlaceRole"),
    ("ServerScriptService", "Server"),
    ("StarterPlayer", "StarterPlayerScripts", "Client"),
)

_ITEM_TOKEN = re.compile(
    rb"<!\[CDATA\[.*?\]\]>|<!--.*?-->|<Item\b[^>]*>|</Item\s*>",
    re.DOTALL,
)
_OPAQUE_XML = re.compile(rb"(<!\[CDATA\[.*?\]\]>|<!--.*?-->)", re.DOTALL)


def child(parent: ET.Element, name: str) -> ET.Element | None:
    matches = [node for node in parent.findall("Item")
               if node.findtext("Properties/string[@name='Name']") == name]
    if len(matches) > 1:
        raise ValueError(f"ambiguous instance name: {name}")
    return matches[0] if matches else None


def at_path(root: ET.Element, path: tuple[str, ...]) -> ET.Element | None:
    node = root
    for name in path:
        node = child(node, name)
        if node is None:
            return None
    return node


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


def _item_spans(document: bytes) -> dict[str, tuple[int, int]]:
    spans = {}
    stack: list[tuple[str, int]] = []
    for token in _ITEM_TOKEN.finditer(document):
        value = token.group(0)
        if value.startswith(b"<Item"):
            match = re.search(rb'\breferent="([^"]+)"', value)
            if match is None:
                raise ValueError("serialized Item has no referent")
            stack.append((match.group(1).decode("utf-8"), token.start()))
        elif value.startswith(b"</Item"):
            if not stack:
                raise ValueError("serialized Item closing tag has no opening tag")
            referent, start = stack.pop()
            if referent in spans:
                raise ValueError(f"duplicate serialized referent: {referent}")
            spans[referent] = (start, token.end())
    if stack:
        raise ValueError(f"unterminated serialized instance: {stack[-1][0]}")
    return spans


def _item_span(document: bytes, referent: str) -> tuple[int, int]:
    span = _item_spans(document).get(referent)
    if span is None:
        raise ValueError(f"serialized instance is missing: {referent}")
    return span


def serialized_item(document: bytes, node: ET.Element) -> bytes:
    start, end = _item_span(document, node.get("referent", ""))
    return document[start:end]


def _validated_remap(base: ET.Element, code: ET.Element) -> tuple[ET.Element, dict[str, str]]:
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

    existing = {path: at_path(base, path) for path in generated}
    used = {node.get("referent") for node in base.iter("Item")}
    remap = {}
    for number, (path, node) in enumerate(generated.items()):
        old = existing.get(path)
        if old is not None and old.get("class") == node.get("class"):
            ref = old.get("referent")
        else:
            seed = "/".join(path) + f"#{number}"
            ref = "RBX" + hashlib.sha256(seed.encode("utf-8")).hexdigest()[:32].upper()
            while ref in used:
                ref += "A"
        used.add(ref)
        remap[node.get("referent", "")] = ref

    donor = ET.fromstring(ET.tostring(code))
    for node in donor.iter("Item"):
        node.set("referent", remap[node.get("referent", "")])
    for ref in donor.iter("Ref"):
        if ref.text in remap:
            ref.text = remap[ref.text]
    return donor, remap


def _remap_serialized_references(value: bytes, remap: dict[str, str]) -> bytes:
    def item_tag(match: re.Match[bytes]) -> bytes:
        tag = match.group(0)
        attribute = re.search(rb'\breferent="([^"]+)"', tag)
        if attribute is None:
            raise ValueError("serialized Item has no referent")
        old = attribute.group(1).decode("utf-8")
        if old not in remap:
            raise ValueError(f"serialized donor referent is unknown: {old}")
        start, end = attribute.span(1)
        return tag[:start] + remap[old].encode("utf-8") + tag[end:]

    def reference(match: re.Match[bytes]) -> bytes:
        old = match.group(2).decode("utf-8")
        replacement = remap.get(old, old).encode("utf-8")
        return match.group(1) + replacement + match.group(3)

    chunks = _OPAQUE_XML.split(value)
    for index in range(0, len(chunks), 2):
        chunks[index] = re.sub(rb'<Item\b[^>]*>', item_tag, chunks[index])
        chunks[index] = re.sub(rb'(<Ref\b[^>]*>)([^<]*)(</Ref>)', reference, chunks[index])
    return b"".join(chunks)


def _validate_result(root: ET.Element) -> None:
    managed_ids = set()
    for path in MANAGED_PATHS:
        parent = root
        for name in path:
            parent = child(parent, name)
            if parent is None:
                raise ValueError(f"missing production root: {'/'.join(path)}")
        managed_ids.update(id(node) for node in parent.iter("Item"))
    for node in root.iter("Item"):
        if node.get("class") in {"Script", "LocalScript", "ModuleScript"} and id(node) not in managed_ids:
            raise ValueError("unmanaged executable in accepted Place")
    refs = [node.get("referent") for node in root.iter("Item")]
    if None in refs or len(refs) != len(set(refs)):
        raise ValueError("missing or duplicate instance referents")
    valid_refs = {None, "null", "nil", *refs}
    for ref in root.iter("Ref"):
        if ref.text not in valid_refs:
            raise ValueError(f"dangling instance reference: {ref.text}")


def overlay_place(source: Path, code_source: Path, output: Path) -> None:
    """Splice Rojo-owned subtrees without reserializing the accepted Place."""
    document = source.read_bytes()
    code_document = code_source.read_bytes()
    base = ET.fromstring(document)
    code = ET.fromstring(code_document)
    donor, remap = _validated_remap(base, code)
    required_base_paths = {
        path for managed in MANAGED_PATHS for path in (managed, managed[:-1])
    }
    required_base_paths.add(("ServerStorage", "MoonfallAuthoring"))
    base_index = {path: at_path(base, path) for path in required_base_paths}
    donor_index = index(donor)
    code_index = index(code)
    patches: list[tuple[int, int, bytes]] = []

    storage = base_index.get(("ServerStorage", "MoonfallAuthoring"))
    if storage is not None:
        start, end = _item_span(document, storage.get("referent", ""))
        patches.append((start, end, b""))

    insertions: dict[int, list[bytes]] = {}
    for path in MANAGED_PATHS:
        raw = serialized_item(code_document, code_index[path])
        raw = _remap_serialized_references(raw, remap)
        old = base_index.get(path)
        if old is not None:
            start, end = _item_span(document, old.get("referent", ""))
            patches.append((start, end, raw))
            continue
        parent = base_index.get(path[:-1])
        if parent is None:
            raise ValueError(f"accepted Place is missing container: {'/'.join(path[:-1])}")
        _, parent_end = _item_span(document, parent.get("referent", ""))
        closing = document.rfind(b"</Item", 0, parent_end)
        if closing < 0:
            raise ValueError(f"accepted container is unterminated: {'/'.join(path[:-1])}")
        line = document.rfind(b"\n", 0, closing) + 1
        indent = document[line:closing]
        if indent.strip():
            indent = b""
        insertions.setdefault(closing, []).append(raw + b"\n" + indent)

    for position, values in insertions.items():
        patches.append((position, position, b"".join(values)))
    patches.sort(key=lambda patch: (patch[0], patch[1]), reverse=True)
    previous_start = len(document) + 1
    for start, end, replacement in patches:
        if end > previous_start:
            raise ValueError("overlapping serialized Moonfall patches")
        document = document[:start] + replacement + document[end:]
        previous_start = start

    result = ET.fromstring(document)
    _validate_result(result)
    # Ensure the remapped donor itself remained structurally complete.
    if any(path not in donor_index for path in MANAGED_PATHS):
        raise ValueError("remapped code donor lost a production root")
    output.write_bytes(document)
