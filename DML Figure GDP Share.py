import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib as mpl
import matplotlib.ticker as mticker

# ── Typography (matches DML figures) ──────────────────────────────────────────
mpl.rcParams.update({
    "font.family":      "serif",
    "font.serif":       ["CMU Serif", "Computer Modern Roman", "DejaVu Serif"],
    "mathtext.fontset": "cm",
    "axes.labelsize":   11,
    "font.size":        11,
    "legend.fontsize":  10,
    "xtick.labelsize":  10,
    "ytick.labelsize":  10,
})
mpl.rcParams["text.usetex"] = False

# ── Load Data ─────────────────────────────────────────────────────────────────
path = r"C:/Users/Will/OneDrive - The Ohio State University/RA/Data/Nigeria GDP By Sector Data.xlsx"

raw = pd.read_excel(path, header=None)

# The real header sits on row 2 (0-indexed); data starts row 3
df = raw.iloc[2:].copy()
df.columns = ["Year", "Agriculture", "Oil_Rents"]
df = df[df["Year"].apply(lambda x: str(x).isdigit())].copy()
df["Year"]        = df["Year"].astype(int)
df["Agriculture"] = pd.to_numeric(df["Agriculture"], errors="coerce")
df["Oil_Rents"]   = pd.to_numeric(df["Oil_Rents"],   errors="coerce")
df = df[df["Year"] <= 2024].reset_index(drop=True)

# ── Colour palette (tab colours, consistent with DML figures) ─────────────────
COL_AGR  = "tab:green"
COL_OIL  = "tab:blue"
COL_ANNO = "#555555"

# ── Plot ──────────────────────────────────────────────────────────────────────
fig, ax = plt.subplots(figsize=(7, 5.5))

# Agriculture
ax.plot(
    df["Year"], df["Agriculture"],
    color=COL_AGR, linewidth=2.2, label="Agriculture, Forestry & Fishing",
    zorder=3,
)

# Oil rents
ax.plot(
    df["Year"], df["Oil_Rents"],
    color=COL_OIL, linewidth=2.2, label="Oil Rents",
    zorder=3,
)

# ── Shaded region between the two series (where both exist) ───────────────────
both = df.dropna(subset=["Agriculture", "Oil_Rents"])
ax.fill_between(
    both["Year"], both["Agriculture"], both["Oil_Rents"],
    where=(both["Agriculture"] >= both["Oil_Rents"]),
    alpha=0.10, color=COL_AGR, interpolate=True,
)
ax.fill_between(
    both["Year"], both["Agriculture"], both["Oil_Rents"],
    where=(both["Agriculture"] < both["Oil_Rents"]),
    alpha=0.10, color=COL_OIL, interpolate=True,
)

# ── Axes formatting ───────────────────────────────────────────────────────────
ax.set_xlim(1990, 2025)
ax.set_ylim(0, 45)
ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"{x:.0f}%"))
ax.xaxis.set_major_locator(mticker.MultipleLocator(5))
ax.xaxis.set_minor_locator(mticker.MultipleLocator(1))
ax.yaxis.set_major_locator(mticker.MultipleLocator(5))

ax.tick_params(axis="both", which="major", length=4, width=0.8)
ax.tick_params(axis="x",    which="minor", length=2, width=0.5)

for spine in ax.spines.values():
    spine.set_linewidth(0.8)

ax.set_xlabel("Year")
ax.set_ylabel("Share of GDP (%)")
ax.set_title(
    "Nigeria: GDP Share by Sector, 1990–2024",
    fontsize=13, pad=10,
)

# ── Data-source footnote ──────────────────────────────────────────────────────
fig.text(
    0.01, -0.02,
    "Source: World Bank World Development Indicators. "
    "Agriculture series begins 1981; Oil Rents series ends 2021.",
    fontsize=8, color="#666666", ha="left",
)

ax.legend(frameon=False, loc="upper right")
plt.tight_layout()

# ── Save ──────────────────────────────────────────────────────────────────────
out = r"C:\Users\Will\OneDrive - The Ohio State University\RA\Data\Nigeria_GDP_By_Sector_Chart.pdf"
plt.savefig(out, dpi=300, bbox_inches="tight")
print(f"Saved: {out}")
plt.show()
