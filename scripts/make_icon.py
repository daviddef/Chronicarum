"""Generate the Chronicarum app icon.

App Store rules: 1024x1024, no alpha channel, no pre-applied rounded corners (the system
masks it). Drawn at 4x and downsampled so the curves are clean without needing AA.

Design: a classical arch in the app's accent gold on ink — the motif reads at 60px in
Settings, which a wordmark or fine detail would not.
"""
from PIL import Image, ImageDraw

S = 1024
F = 4                      # supersample factor
W = S * F
GOLD      = (201, 168, 76)
GOLD_DIM  = (150, 124, 55)
INK_TOP   = (28, 32, 42)
INK_BOT   = (12, 14, 19)

img = Image.new("RGB", (W, W), INK_BOT)
d = ImageDraw.Draw(img)

# Vertical gradient background
for y in range(W):
    t = y / W
    d.line([(0, y), (W, y)],
           fill=(int(INK_TOP[0] + (INK_BOT[0] - INK_TOP[0]) * t),
                 int(INK_TOP[1] + (INK_BOT[1] - INK_TOP[1]) * t),
                 int(INK_TOP[2] + (INK_BOT[2] - INK_TOP[2]) * t)))

cx = W // 2

# Faint meridian rings — a globe hint that stays subtle at small sizes
for r, col in ((int(W * 0.395), GOLD_DIM), (int(W * 0.435), (60, 55, 40))):
    d.ellipse([cx - r, cx - r, cx + r, cx + r], outline=col, width=max(2, int(W * 0.004)))

# Classical arch: two piers carrying a semicircular head
pier_w   = int(W * 0.085)
span     = int(W * 0.30)          # centre-to-centre of the piers
base_y   = int(W * 0.735)
cap_y    = int(W * 0.470)         # springing line of the arch
outer_r  = span // 2 + pier_w // 2
inner_r  = span // 2 - pier_w // 2

# Arch head (drawn as a filled ring segment, then the opening cut back to background)
d.pieslice([cx - outer_r, cap_y - outer_r, cx + outer_r, cap_y + outer_r],
           start=180, end=360, fill=GOLD)

# Piers
for sign in (-1, 1):
    x = cx + sign * (span // 2)
    d.rectangle([x - pier_w // 2, cap_y, x + pier_w // 2, base_y], fill=GOLD)

# Cut the opening: pie slice + rectangle below it, filled with the local background tone
def bg_at(y):
    t = max(0.0, min(1.0, y / W))
    return (int(INK_TOP[0] + (INK_BOT[0] - INK_TOP[0]) * t),
            int(INK_TOP[1] + (INK_BOT[1] - INK_TOP[1]) * t),
            int(INK_TOP[2] + (INK_BOT[2] - INK_TOP[2]) * t))

cut = Image.new("RGB", (W, W))
cd = ImageDraw.Draw(cut)
for y in range(W):
    cd.line([(0, y), (W, y)], fill=bg_at(y))
mask = Image.new("L", (W, W), 0)
md = ImageDraw.Draw(mask)
md.pieslice([cx - inner_r, cap_y - inner_r, cx + inner_r, cap_y + inner_r],
            start=180, end=360, fill=255)
md.rectangle([cx - inner_r, cap_y, cx + inner_r, base_y], fill=255)
img.paste(cut, (0, 0), mask)

# Stylobate — the step the arch stands on
step_w = int(W * 0.46)
d.rectangle([cx - step_w // 2, base_y, cx + step_w // 2, base_y + int(W * 0.030)], fill=GOLD)
d.rectangle([cx - int(step_w * 0.57), base_y + int(W * 0.030),
             cx + int(step_w * 0.57), base_y + int(W * 0.056)], fill=GOLD_DIM)

img = img.resize((S, S), Image.LANCZOS)
out = "/Users/daviddefranceski/Claude/Projects/Chronicarum/Chronicarum/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
img.save(out, "PNG")
print(f"wrote {out}  mode={img.mode} size={img.size}")
