import matplotlib.pyplot as plt
import matplotlib as mpl
import geopandas as gpd
import pandas as pd
from shapely.geometry import Point

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

# ── Boundary files ─────────────────────────────────────────────────────────────
ADM0 = r"C:\Users\Will\OneDrive - The Ohio State University\RA\Data\Official State Boundary Data\Combined geojson\NGA_ADM0_country.geojson"
ADM1 = r"C:\Users\Will\OneDrive - The Ohio State University\RA\Data\Official State Boundary Data\Combined geojson\NGA_ADM1_states.geojson"

adm0 = gpd.read_file(ADM0).to_crs(4326)
adm1 = gpd.read_file(ADM1).to_crs(4326)

# ── Base map function ──────────────────────────────────────────────────────────
def make_nigeria_map(figsize=(9, 9), title="", source=""):
    fig, ax = plt.subplots(figsize=figsize)
    adm0.boundary.plot(ax=ax, linewidth=1.8, color="black", zorder=1)
    adm1.boundary.plot(ax=ax, linewidth=0.5, color="#888888", zorder=2)
    ax.set_aspect("equal", adjustable="box")
    ax.set_xlabel("Longitude")
    ax.set_ylabel("Latitude")
    if title:
        ax.set_title(title, fontsize=13, pad=10)
    if source:
        ax.text(
            0.0, -0.07, source,
            transform=ax.transAxes,
            fontsize=8, color="#666666", ha="left", va="top",
        )
    plt.tight_layout()
    return fig, ax

# ── Load enumeration area data ─────────────────────────────────────────────────
CSV = r"C:\Users\Will\OneDrive - The Ohio State University\RA\Data\used_in_dml_geo_data.csv"

df = pd.read_csv(CSV)

# Drop rows missing coordinates and deduplicate to one point per EA
ea = (
    df[["enumeration_area", "latitude", "longitude"]]
    .dropna(subset=["latitude", "longitude"])
    .drop_duplicates(subset=["enumeration_area"])
    .reset_index(drop=True)
)

ea_gdf = gpd.GeoDataFrame(
    ea,
    geometry=[Point(lon, lat) for lon, lat in zip(ea["longitude"], ea["latitude"])],
    crs="EPSG:4326",
)

print(f"Enumeration areas to plot: {len(ea_gdf)}")

# ── Plot ───────────────────────────────────────────────────────────────────────
fig, ax = make_nigeria_map(
    figsize=(9, 9),
    title=f"Nigeria: Enumeration Areas in Analysis (n={len(ea_gdf):,})",
    source="Source: World Bank; Nigeria General Household Survey panel data.",
)

ax.scatter(
    ea_gdf.geometry.x,
    ea_gdf.geometry.y,
    s=18,
    facecolors="none",
    edgecolors="tab:red",
    linewidths=0.8,
    alpha=0.7,
    zorder=3,
    label="Enumeration Area",
)

ax.legend(frameon=False, loc="lower left")

# ── Save ───────────────────────────────────────────────────────────────────────
OUT_PDF = r"C:\Users\Will\OneDrive - The Ohio State University\RA\Data\Nigeria_Enumeration_Areas.pdf"
OUT_PNG = r"C:\Users\Will\OneDrive - The Ohio State University\RA\Data\Nigeria_Enumeration_Areas.png"

plt.savefig(OUT_PDF, dpi=300, bbox_inches="tight")
plt.savefig(OUT_PNG, dpi=150, bbox_inches="tight")
print(f"Saved: {OUT_PDF}")
plt.show()