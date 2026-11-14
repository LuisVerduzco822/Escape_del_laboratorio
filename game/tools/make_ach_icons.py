#!/usr/bin/env python3
"""Genera los iconos (emoji) de los logros como PNG de 32x32 a partir de Noto Color Emoji (SIL OFL 1.1).
Uso: python3 game/tools/make_ach_icons.py   (necesita Pillow y la fuente NotoColorEmoji.ttf)
Los PNG se guardan en game/assets/icons/ach/<id>.png; el juego no necesita la fuente en ejecución."""
import os
from PIL import Image, ImageDraw, ImageFont

FONT = "/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf"
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "icons", "ach")
LEVEL = {"intact": "\U0001F48E", "edge": "\U0001FA78", "clean": "\U0001F6E1"}   # 💎 🩸 🛡
BOSS = ["\U0001F9A0", "\U0001F419", "\U0001F987", "\U0001F47D", "\U0001F480"]    # 🦠 🐙 🦇 👽 💀
GENERAL = {
    "parry1": "\U0001F3AF", "parry50": "\U0001F94B", "untouchable": "\U0001F451", "fastboss": "\U0001F680",
    "rich": "\U0001F4B0", "allintact": "\U0001F3C6", "antidote": "\U0001F9EA", "flawless": "✨",
    "speed": "\U0001F550", "finaltop": "\U0001F3C1", "finaltop_clean": "\U0001F947",
}

def render(ch: str, path: str) -> None:
    font = ImageFont.truetype(FONT, 109)
    img = Image.new("RGBA", (136, 128), (0, 0, 0, 0))
    ImageDraw.Draw(img).text((0, 0), ch, font=font, embedded_color=True)
    box = img.getbbox()
    if box:
        img = img.crop(box)
    side = max(img.size)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    sq.paste(img, ((side - img.width) // 2, (side - img.height) // 2))
    sq.resize((32, 32), Image.LANCZOS).save(path)

os.makedirs(OUT, exist_ok=True)
for n in range(1, 6):
    for key, ch in LEVEL.items():
        render(ch, os.path.join(OUT, f"{key}{n}.png"))
    render(BOSS[n - 1], os.path.join(OUT, f"boss{n}.png"))
for key, ch in GENERAL.items():
    render(ch, os.path.join(OUT, f"{key}.png"))
print("ok", len(os.listdir(OUT)))
