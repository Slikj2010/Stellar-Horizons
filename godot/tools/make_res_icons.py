"""Draws the three resource icons (Ore chunk, Supply water drop, Fuel flame) into assets/icons/.  Needs Pillow."""
from PIL import Image, ImageDraw, ImageFilter
import math, os
S = 512; OUT = 64
def new(): return Image.new("RGBA", (S, S), (0, 0, 0, 0))
def poly(d, pts, fill, outline=None, w=0):
    d.polygon([(x * S, y * S) for x, y in pts], fill=fill)
    if outline: d.line([(x * S, y * S) for x, y in pts + [pts[0]]], fill=outline, width=w, joint="curve")
def vgrad(box, top, bot):
    x0, y0, x1, y1 = box; g = Image.new("RGBA", (S, S), (0, 0, 0, 0)); d = ImageDraw.Draw(g)
    for y in range(int(y0), int(y1)):
        t = (y - y0) / max(1, y1 - y0); d.line([(0, y), (S, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(4)))
    return g
def clip(img, mask_img):
    m = mask_img.split()[3]; out = Image.new("RGBA", (S, S), (0, 0, 0, 0)); out.paste(img, (0, 0), m); return out

def ore():
    base = new(); d = ImageDraw.Draw(base)
    body = [(.50, .08), (.80, .22), (.92, .52), (.76, .84), (.42, .92), (.14, .74), (.10, .38), (.28, .16)]
    poly(d, body, (140, 150, 168, 255))
    shapes = [  # facets: lighter on top-left, darker bottom-right
        ([(.50, .08), (.80, .22), (.58, .38), (.28, .16)], (214, 222, 234, 255)),
        ([(.28, .16), (.58, .38), (.44, .60), (.10, .38)], (176, 186, 202, 255)),
        ([(.80, .22), (.92, .52), (.70, .60), (.58, .38)], (122, 132, 150, 255)),
        ([(.10, .38), (.44, .60), (.42, .92), (.14, .74)], (110, 120, 138, 255)),
        ([(.44, .60), (.70, .60), (.76, .84), (.42, .92)], (84, 94, 112, 255)),
        ([(.70, .60), (.92, .52), (.76, .84)], (96, 106, 124, 255)),
    ]
    for pts, col in shapes: poly(d, pts, col)
    # a glint of ore vein
    poly(d, [(.36, .30), (.46, .26), (.50, .34), (.40, .38)], (255, 255, 255, 190))
    d.line([(x * S, y * S) for x, y in body + [body[0]]], fill=(38, 44, 58, 255), width=10, joint="curve")
    return base
def drop():
    img = new(); d = ImageDraw.Draw(img)
    pts = []
    cx, cy, r = .5, .62, .31
    for a in range(-30, 211, 3):  # round belly
        t = math.radians(a); pts.append((cx + r * math.cos(t), cy + r * math.sin(t)))
    pts = [(cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))) for a in range(-30, 211, 3)]
    # tip
    tip = (.5, .06)
    shape = [tip] + [(cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a))) for a in range(-35, 216, 3)]
    mask = new(); md = ImageDraw.Draw(mask); poly(md, shape, (255, 255, 255, 255))
    g = vgrad((0, S * .06, S, S * .93), (120, 205, 255, 255), (20, 90, 200, 255))
    img = clip(g, mask)
    d = ImageDraw.Draw(img)
    # highlight
    d.ellipse([S * .33, S * .5, S * .44, S * .68], fill=(255, 255, 255, 210))
    d.line([(x * S, y * S) for x, y in shape + [shape[0]]], fill=(10, 50, 120, 255), width=10, joint="curve")
    return img
def flame():
    img = new(); d = ImageDraw.Draw(img)
    outer = [(.52, .04), (.62, .22), (.80, .38), (.88, .60), (.80, .82), (.62, .95), (.40, .95), (.20, .84), (.12, .62), (.22, .44), (.34, .50), (.38, .30), (.46, .18)]
    mask = new(); md = ImageDraw.Draw(mask); poly(md, outer, (255, 255, 255, 255)); mask = mask.filter(ImageFilter.GaussianBlur(10)).point(lambda v: 255 if v > 128 else 0)
    g = vgrad((0, S * .04, S, S * .95), (255, 170, 40, 255), (230, 60, 20, 255))
    img = clip(g, mask); d = ImageDraw.Draw(img)
    inner = [(.52, .40), (.62, .54), (.70, .68), (.62, .86), (.46, .90), (.34, .80), (.34, .64), (.44, .56)]
    m2 = new(); poly(ImageDraw.Draw(m2), inner, (255, 255, 255, 255)); m2 = m2.filter(ImageFilter.GaussianBlur(8)).point(lambda v: 255 if v > 128 else 0)
    img.alpha_composite(clip(vgrad((0, S * .4, S, S * .9), (255, 245, 150, 255), (255, 200, 60, 255)), m2))
    # soft dark outline from the mask edge
    edge = mask.filter(ImageFilter.MaxFilter(11))
    ol = Image.new("RGBA", (S, S), (110, 20, 10, 255)); outl = Image.new("RGBA", (S, S), (0, 0, 0, 0)); outl.paste(ol, (0, 0), edge.split()[3])
    outl.alpha_composite(img); return outl
here = os.path.join(os.path.dirname(__file__), "..", "assets", "icons")
os.makedirs(here, exist_ok=True)
for name, fn in (("res_ore", ore), ("res_sup", drop), ("res_fuel", flame)):
    fn().resize((OUT, OUT), Image.LANCZOS).save(os.path.join(here, name + ".png"))
print("ok")
