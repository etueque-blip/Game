#!/usr/bin/env python3
"""Сжимает кадры фотосессии: assets/photos/raw/*.png -> assets/photos/*.jpg (для Roblox)
и tools/photos.json (data URI для веб-версии)."""
import base64
import glob
import io
import json
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = os.path.join(ROOT, "assets", "photos", "raw")
OUT = os.path.join(ROOT, "assets", "photos")

data = {}
for p in sorted(glob.glob(os.path.join(RAW, "*.png"))):
    name = os.path.splitext(os.path.basename(p))[0]
    im = Image.open(p).convert("RGB")
    w, h = im.size
    # центр кадра 16:9 с небольшим наездом — самолёт крупнее
    cw, ch = int(w * 0.8), int(w * 0.8 * 9 / 16)
    left, top = (w - cw) // 2, (h - ch) // 2
    im = im.crop((left, top, left + cw, top + ch))
    big = im.resize((960, 540), Image.LANCZOS)
    big.save(os.path.join(OUT, name + ".jpg"), quality=86)
    small = im.resize((720, 405), Image.LANCZOS)
    buf = io.BytesIO()
    small.save(buf, "JPEG", quality=72, optimize=True)
    data[name] = "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()
# уже сохранённые фото (снятые раньше) тоже попадают в веб-версию
for p in sorted(glob.glob(os.path.join(OUT, "*.jpg"))):
    name = os.path.splitext(os.path.basename(p))[0]
    if name not in data:
        buf = io.BytesIO()
        Image.open(p).convert("RGB").resize((720, 405), Image.LANCZOS).save(buf, "JPEG", quality=72, optimize=True)
        data[name] = "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()
with open(os.path.join(ROOT, "tools", "photos.json"), "w") as f:
    json.dump(data, f)
print(len(data), "photos,", sum(len(v) for v in data.values()) // 1024, "KB inline")
