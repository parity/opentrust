#!/usr/bin/env python3
"""Rebuilds every logo-derived asset from docs/brand/opentrust-logo-original.png (a transparent PNG of the bird + wordmark).
Needs Pillow:  python3 -m venv /tmp/v && /tmp/v/bin/pip install pillow && /tmp/v/bin/python scripts/build_brand_assets.py
Writes: header logo + bird mark (app/assets/images/logo), favicon/app icons and social card (public/),
Shopify app icon (integrations/shopify/assets), WordPress.org plugin icons (integrations/woocommerce/wordpress-org-assets)."""
from PIL import Image, ImageDraw, ImageFont

src = Image.open("docs/brand/opentrust-logo-original.png").convert("RGBA")
PAPER = (238, 239, 233, 255)  # the site's background


def trim(im, pad=0):
    l, t, r, b = im.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    return im.crop((max(l - pad, 0), max(t - pad, 0), r + pad, b + pad))


lockup = trim(src, 6)
mark = trim(src.crop((0, 0, 370, src.height)), 6)  # the bird only, left of the wordmark
lockup.save("app/assets/images/logo/opentrust-logo.png", optimize=True)
mark.save("app/assets/images/logo/opentrust-mark.png", optimize=True)


def on_square(size, bg, fill=0.78):
    canvas = Image.new("RGBA", (size, size), bg)
    m = mark.copy()
    scale = size * fill / max(m.size)
    m = m.resize((round(m.width * scale), round(m.height * scale)), Image.LANCZOS)
    canvas.alpha_composite(m, ((size - m.width) // 2, (size - m.height) // 2))
    return canvas


on_square(512, PAPER).convert("RGB").save("public/icon.png", optimize=True)
for name in ("apple-touch-icon", "apple-touch-icon-precomposed"):
    on_square(180, PAPER, 0.82).convert("RGB").save(f"public/{name}.png", optimize=True)
fav = [on_square(s, (0, 0, 0, 0), 0.94) for s in (16, 32, 48)]
fav[2].save("public/favicon.ico", sizes=[(16, 16), (32, 32), (48, 48)], append_images=fav[:2])
on_square(1200, PAPER, 0.74).convert("RGB").save("integrations/shopify/assets/app-icon-1200.png", optimize=True)
for s in (128, 256):
    on_square(s, PAPER, 0.80).convert("RGB").save(f"integrations/woocommerce/wordpress-org-assets/icon-{s}x{s}.png", optimize=True)

card = Image.new("RGBA", (1200, 630), PAPER)
lw = 780
lh = round(lockup.height * lw / lockup.width)
card.alpha_composite(lockup.resize((lw, lh), Image.LANCZOS), ((1200 - lw) // 2, 150))
d = ImageDraw.Draw(card)
try:
    f = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf", 40)
except OSError:
    f = ImageFont.load_default()
tag = "Merchants looking out for each other"
d.text(((1200 - d.textlength(tag, font=f)) / 2, 150 + lh + 46), tag, fill=(70, 78, 56, 255), font=f)
card.convert("RGB").save("public/og-image.png", optimize=True)
print("brand assets rebuilt")
