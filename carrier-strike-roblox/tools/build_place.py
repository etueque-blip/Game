#!/usr/bin/env python3
"""Собирает CarrierStrike.rbxlx из папки src без Rojo.

Запуск:  python3 tools/build_place.py   ->  carrier-strike-roblox/CarrierStrike.rbxlx
Файл открывается в Roblox Studio (File > Open from File).
"""
import os
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
OUT = os.path.join(ROOT, "CarrierStrike.rbxlx")

ref_n = 0


def ref():
    global ref_n
    ref_n += 1
    return f"RBX{ref_n:08X}"


def cdata(text):
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def item(cls, name, props="", children="", source=None):
    p = f'<string name="Name">{escape(name)}</string>' + props
    if source is not None:
        p += f'<ProtectedString name="Source">{cdata(source)}</ProtectedString>'
    return f'<Item class="{cls}" referent="{ref()}"><Properties>{p}</Properties>{children}</Item>\n'


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def modules(folder, skip=()):
    out = ""
    for fn in sorted(os.listdir(folder)):
        if fn.endswith(".luau") and fn not in skip:
            out += item("ModuleScript", fn[:-5], source=read(os.path.join(folder, fn)))
    return out


def main():
    shared = item("Folder", "CarrierStrike", children=modules(os.path.join(SRC, "shared")))
    server_dir = os.path.join(SRC, "server")
    server = item("Script", "CarrierStrikeServer", source=read(os.path.join(server_dir, "init.server.luau")),
                  children=modules(server_dir, skip=("init.server.luau",)))
    client_dir = os.path.join(SRC, "client")
    client = item("LocalScript", "CarrierStrikeClient", source=read(os.path.join(client_dir, "init.client.luau")),
                  children=modules(client_dir, skip=("init.client.luau",)))

    xml = '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" version="4">\n'
    xml += item("Workspace", "Workspace",
                props='<bool name="StreamingEnabled">false</bool><float name="FallenPartsDestroyHeight">-2000</float>')
    xml += item("ReplicatedStorage", "ReplicatedStorage", children=shared)
    xml += item("ServerScriptService", "ServerScriptService", children=server)
    xml += item("StarterPlayer", "StarterPlayer",
                props='<bool name="EnableMouseLockOption">false</bool><float name="CameraMaxZoomDistance">400</float>',
                children=item("StarterPlayerScripts", "StarterPlayerScripts", children=client))
    xml += "</roblox>\n"
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(xml)
    print("OK ->", OUT)


if __name__ == "__main__":
    main()
