#!/usr/bin/env python3
"""Собирает ВСЕ_СКРИПТЫ.txt: все скрипты одним текстом и куда вставлять каждый."""
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")
where = {
    "shared": "ReplicatedStorage → папка CarrierStrike → ModuleScript «{n}»",
    "server": "ServerScriptService → CarrierStrikeServer → ModuleScript «{n}»",
    "client": "StarterPlayer → StarterPlayerScripts → CarrierStrikeClient → ModuleScript «{n}»",
}
items = []
for folder in ("shared", "server", "client"):
    d = os.path.join(SRC, folder)
    for fn in sorted(os.listdir(d)):
        if not fn.endswith(".luau"):
            continue
        if fn == "init.server.luau":
            items.insert(0, ("ServerScriptService → Script «CarrierStrikeServer»", os.path.join(d, fn)))
        elif fn == "init.client.luau":
            items.append(("StarterPlayer → StarterPlayerScripts → LocalScript «CarrierStrikeClient»", os.path.join(d, fn)))
        else:
            items.append((where[folder].format(n=fn[:-5]), os.path.join(d, fn)))
out = f"CARRIER STRIKE — ВСЕ СКРИПТЫ ({len(items)} шт.)\nКуда вставлять — написано перед каждым. Копируй текст между линиями целиком.\n\n"
for w, f in items:
    rel = os.path.relpath(f, ROOT)
    out += "=" * 78 + f"\n{w}\n(файл {rel})\n" + "=" * 78 + "\n" + open(f, encoding="utf-8").read().rstrip() + "\n\n"
open(os.path.join(ROOT, "ВСЕ_СКРИПТЫ.txt"), "w", encoding="utf-8").write(out)
print(len(items), "скриптов →", os.path.join(ROOT, "ВСЕ_СКРИПТЫ.txt"))
