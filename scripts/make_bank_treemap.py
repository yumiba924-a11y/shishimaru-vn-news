# -*- coding: utf-8 -*-
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, FancyBboxPatch
import matplotlib.font_manager as fm
import squarify

plt.rcParams["font.family"] = "Yu Gothic"
plt.rcParams["axes.unicode_minus"] = False

# ticker, mc(兆VND), ownership, VN30?
# 大手の時価総額は現行誌面の表示値に一致 (VCB511/BID290/CTG265=1,066兆 ほか)
BANKS = [
    ("VCB", 511, "gov",  True),
    ("BID", 290, "gov",  True),
    ("CTG", 265, "gov",  True),
    ("TCB", 239, "priv", True),
    ("VPB", 218, "priv", True),
    ("MBB", 204, "priv", True),
    ("LPB", 153, "priv", True),
    ("HDB", 136, "priv", True),
    ("STB", 133, "priv", True),
    ("ACB", 129, "priv", True),
    ("SHB",  65, "priv", True),
    ("SSB",  56, "priv", True),
    ("VIB",  55, "priv", True),
    ("MSB",  49, "priv", False),
    ("TPB",  45, "priv", True),
    ("EIB",  37, "priv", False),
    ("OCB",  35, "priv", False),
    ("NVB",  28, "priv", False),
    ("NAB",  27, "priv", False),
    ("ABB",  20, "priv", False),
    ("BAB",  18, "priv", False),
    ("KLB",  14, "priv", False),
    ("VBB",  12, "priv", False),
    ("PGB",  10, "priv", False),
    ("VAB",   8, "priv", False),
    ("BVB",   7, "priv", False),
    ("SGB",   6, "priv", False),
]

FILL = {"gov": "#0B3D26", "mil": "#2E6B4A", "priv": "#A8C6B4"}
TXT  = {"gov": "#FFFFFF", "mil": "#FFFFFF", "priv": "#0B3D26"}
GOLD = "#F5C400"

AR = 1.744
W, H = 100 * AR, 100.0
sizes = [b[1] for b in BANKS]
norm = squarify.normalize_sizes(sizes, W, H)
rects = squarify.squarify(norm, 0, 0, W, H)

fig, ax = plt.subplots(figsize=(11.68, 6.70), dpi=160)
ax.set_xlim(0, W); ax.set_ylim(0, H)
ax.invert_yaxis()
ax.axis("off")
fig.patch.set_facecolor("white")

PAD = 0.55
for (ticker, mc, own, vn30), r in zip(BANKS, rects):
    x, y, dx, dy = r["x"], r["y"], r["dx"], r["dy"]
    bx, by, bdx, bdy = x + PAD, y + PAD, dx - 2 * PAD, dy - 2 * PAD
    if bdx <= 0 or bdy <= 0:
        continue
    edge = GOLD if vn30 else "#FFFFFF"
    lw = 3.4 if vn30 else 2.2
    ax.add_patch(Rectangle((bx, by), bdx, bdy, facecolor=FILL[own],
                           edgecolor=edge, linewidth=lw, zorder=vn30 and 3 or 2))
    cx, cy = x + dx / 2.0, y + dy / 2.0
    m = min(dx, dy)
    tcol = TXT[own]
    if m >= 16:
        ax.text(cx, cy - dy * 0.06, ticker, ha="center", va="center",
                fontsize=min(26, m * 1.05), fontweight="bold", color=tcol)
        ax.text(cx, cy + dy * 0.16, f"{mc}兆", ha="center", va="center",
                fontsize=min(15, m * 0.55), color=tcol)
    elif m >= 8.5:
        ax.text(cx, cy - dy * 0.05, ticker, ha="center", va="center",
                fontsize=min(15, m * 0.9), fontweight="bold", color=tcol)
        ax.text(cx, cy + dy * 0.22, f"{mc}兆", ha="center", va="center",
                fontsize=min(10, m * 0.42), color=tcol)
    elif m >= 4.5:
        ax.text(cx, cy, ticker, ha="center", va="center",
                fontsize=min(11, m * 0.85), fontweight="bold", color=tcol)
    else:
        ax.text(cx, cy, ticker, ha="center", va="center",
                fontsize=max(6.5, m * 0.8), fontweight="bold", color=tcol)

ax.set_title("上場銀行27行の勢力図 ― 面積＝時価総額",
             fontsize=20, fontweight="bold", color="#0B3D26", pad=16)

# legend
from matplotlib.patches import Patch
handles = [
    Patch(facecolor=FILL["gov"],  edgecolor="none", label="国有（政府過半・VCB/BID/CTG）"),
    Patch(facecolor=FILL["priv"], edgecolor="none", label="民間（株式商業銀行）"),
    Patch(facecolor="#FFFFFF",    edgecolor=GOLD, linewidth=2.4, label="金枠＝VN30構成銘柄（14行）"),
]
leg = ax.legend(handles=handles, loc="upper center", bbox_to_anchor=(0.5, -0.02),
                ncol=3, frameon=False, fontsize=12, handlelength=1.4,
                columnspacing=1.8, handletextpad=0.5)
for t in leg.get_texts():
    t.set_color("#333333")

fig.subplots_adjust(left=0.02, right=0.98, top=0.92, bottom=0.10)
out = r"C:\Users\Shogo.Yumiba\Desktop\VN30新聞\docs\weekly_assets\bank_treemap.png"
fig.savefig(out, dpi=160, facecolor="white", bbox_inches="tight", pad_inches=0.15)
print("saved", out)
