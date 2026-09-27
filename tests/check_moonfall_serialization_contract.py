"""The deploy overlay must not reserialize the accepted authored Place."""

import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/deploy"))
import moonfall_overlay as overlay


BASE = b'''<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" version="4">
\t<Item class="Workspace" referent="RBX00000000000000000000000000000001">
\t\t<Properties><string name="Name">Workspace</string></Properties>
\t\t<Item class="Terrain" referent="RBX00000000000000000000000000000002"><Properties><string name="Name">Terrain</string><BinaryString name="SmoothGrid"><![CDATA[A+/=]]></BinaryString><Ref name="ExternalReference">RBX00000000000000000000000000000005</Ref></Properties></Item>
\t\t<Item class="Part" referent="RBX0000000000000000000000000000000C"><Properties><string name="Name">AuthoredRock</string></Properties></Item>
\t\t<Item class="Part" referent="RBX0000000000000000000000000000000D"><Properties><string name="Name">AuthoredRock</string></Properties></Item>
\t</Item>
\t<Item class="ReplicatedStorage" referent="RBX00000000000000000000000000000003"><Properties><string name="Name">ReplicatedStorage</string></Properties><Item class="Folder" referent="RBX00000000000000000000000000000004"><Properties><string name="Name">Shared</string></Properties><Item class="ModuleScript" referent="RBX00000000000000000000000000000005"><Properties><string name="Name">BuildInfo</string><ProtectedString name="Source"><![CDATA[old <code>]]></ProtectedString></Properties></Item></Item></Item>
\t<Item class="ServerStorage" referent="RBX00000000000000000000000000000006"><Properties><string name="Name">ServerStorage</string></Properties><Item class="Folder" referent="RBX00000000000000000000000000000007"><Properties><string name="Name">MoonfallAuthoring</string></Properties></Item></Item>
\t<Item class="ServerScriptService" referent="RBX00000000000000000000000000000008"><Properties><string name="Name">ServerScriptService</string></Properties></Item>
\t<Item class="StarterPlayer" referent="RBX00000000000000000000000000000009"><Properties><string name="Name">StarterPlayer</string></Properties><Item class="StarterPlayerScripts" referent="RBX0000000000000000000000000000000A"><Properties><string name="Name">StarterPlayerScripts</string></Properties></Item></Item>
\t<Item class="Lighting" referent="RBX0000000000000000000000000000000B"><Properties><string name="Name">Lighting</string><BinaryString name="AttributesSerialize"><![CDATA[LIGHT+/=]]></BinaryString></Properties></Item>
\t<SharedStrings><SharedString md5="accepted=="></SharedString></SharedStrings>
</roblox>'''

DONOR = b'''<roblox version="4">
  <Item class="ReplicatedStorage" referent="0"><Properties><string name="Name">ReplicatedStorage</string></Properties>
    <Item class="Folder" referent="1"><Properties><string name="Name">Shared</string></Properties><Item class="ModuleScript" referent="2"><Properties><string name="Name">BuildInfo</string><string name="Source"><![CDATA[new <code> & current; local marker = 'referent="2"'; local fixture = '<Item class="Folder" referent="3"><Properties></Properties></Item>']]></string></Properties></Item><Item class="ModuleScript" referent="10"><Properties><string name="Name">PlainSource</string><string name="Source">local known = 'referent="3"'; local unknown = 'referent="unknown"'</string></Properties></Item></Item>
    <!-- <Item class="StringValue" referent="4"><Properties><string name="Name">FakeRole</string></Properties></Item> -->
    <Item class="Folder" referent="3"><Properties><string name="Name">Remotes</string></Properties></Item>
    <Item class="StringValue" referent="4"><Properties><string name="Name">StudioPlaceRole</string><string name="Value">World</string></Properties></Item>
  </Item>
  <Item class="ServerScriptService" referent="5"><Properties><string name="Name">ServerScriptService</string></Properties><Item class="Script" referent="6"><Properties><string name="Name">Server</string><string name="Source"><![CDATA[return <server>]]></string></Properties></Item></Item>
  <Item class="StarterPlayer" referent="7"><Properties><string name="Name">StarterPlayer</string></Properties><Item class="StarterPlayerScripts" referent="8"><Properties><string name="Name">StarterPlayerScripts</string></Properties><Item class="LocalScript" referent="9"><Properties><string name="Name">Client</string><string name="Source"><![CDATA[return <client>]]></string></Properties></Item></Item></Item>
</roblox>'''


with tempfile.TemporaryDirectory() as directory:
    directory = Path(directory)
    source = directory / "accepted.rbxlx"
    donor = directory / "code.rbxlx"
    output = directory / "moonfall.rbxlx"
    source.write_bytes(BASE)
    donor.write_bytes(DONOR)
    overlay.overlay_place(source, donor, output)
    result = output.read_bytes()

assert result.startswith(BASE.split(b"\n", 1)[0] + b"\n")
assert b'<BinaryString name="SmoothGrid"><![CDATA[A+/=]]></BinaryString>' in result
assert b'<BinaryString name="AttributesSerialize"><![CDATA[LIGHT+/=]]></BinaryString>' in result
assert b'<SharedString md5="accepted=="></SharedString>' in result
assert b'''local fixture = '<Item class="Folder" referent="3"><Properties></Properties></Item>']]></string>''' in result
assert b'''local known = 'referent="3"'; local unknown = 'referent="unknown"' '''.rstrip() in result
assert b'FakeRole' not in result
assert b'MoonfallAuthoring' not in result
assert b'old <code>' not in result
assert b'<Ref name="ExternalReference">RBX00000000000000000000000000000005</Ref>' in result
ET.fromstring(result)
print("Moonfall file overlay preserves Studio XML serialization and applies Rojo code: PASS")
