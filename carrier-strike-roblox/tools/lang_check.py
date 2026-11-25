#!/usr/bin/env python3
"""Проверяет, что у каждого текста L("...") есть перевод в Lang.luau (оба языка)."""
import re, glob, sys
lang = open("src/shared/Lang.luau", encoding="utf-8").read()
keys = set(re.findall(r"^\t([a-z_0-9A-Z]+) = \{", lang, re.M))
need = set()
for f in glob.glob("src/*/*.luau"):
    s = open(f, encoding="utf-8").read()
    for k in re.findall(r'\bL\("([A-Za-z_0-9]+)"\s*[,)]', s):
        need.add(k)
srv = open("src/server/init.server.luau", encoding="utf-8").read()
need |= {"n_" + k for k in re.findall(r'NotifyR:Fire\w+\([^,]+,\s*"(\w+)"', srv)}
need |= {"n_" + k for k in re.findall(r'NotifyR:FireAllClients\(\s*"(\w+)"', srv)}
need |= {"r_" + k for k in re.findall(r'\breward\([^,]+,\s*"(\w+)"\)', srv)}
need |= {"r_" + k for k in re.findall(r'\bgive\([^)]*"(\w+)"\)', srv) if not k.startswith("quest")}
need |= {"r_quest", "r_purchase"}
prog = open("src/shared/Progress.luau", encoding="utf-8").read()
need |= {"q_" + k for k in re.findall(r'\{ id = "(\w+)", n =', prog)}
need |= {"role_" + k for k in re.findall(r'^\t(\w+) = \{ cost', prog, re.M)}
need |= {"base_" + k for k in "ABCDE"} | {"cam_1", "cam_2", "cam_3"} | {"team_Blue", "team_Red"}
need |= {"crash_water", "crash_carrier", "crash_ground", "killed_zone", "w_gun", "w_msl"}
need |= {"tab_" + k for k in ("hangar", "missions", "top", "shop")}
need |= {t + s for t in ("tut1", "tut2", "tut3", "tut4") for s in ("", "_t")}
missing = sorted(need - keys)
for k in missing:
    print("нет перевода:", k)
# оба языка заполнены
for m in re.finditer(r'^\t([a-z_0-9A-Z]+) = \{\s*"', lang, re.M):
    pass
print(f"ключей в Lang: {len(keys)}, нужно: {len(need)}, не хватает: {len(missing)}")
sys.exit(1 if missing else 0)
