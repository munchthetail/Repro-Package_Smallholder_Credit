import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib as mpl
from pathlib import Path

#setting paths
root       = Path(__file__).resolve().parent.parent.parent
output_dir = root / "Tables and Figures" / "Figure_A1.pdf"
dta_path = root / "Stata Code" / "Stata Data Landing" / "DML Cleaned Data.dta"

#cosmetic settings
mpl.rcParams.update({
    "font.family": "serif",
    "font.serif": ["CMU Serif", "Computer Modern Roman", "DejaVu Serif"],
    "mathtext.fontset": "cm",
    "axes.labelsize": 11,
    "font.size": 11,
    "legend.fontsize": 10,
    "xtick.labelsize": 10,
    "ytick.labelsize": 10,
})

#KDE settings
def silverman_bandwidth(x: np.ndarray) -> float:
    x = x[np.isfinite(x)]
    n = x.size
    if n < 2:
        return np.nan
    std = np.std(x, ddof=1)
    iqr = np.subtract(*np.percentile(x, [75, 25]))
    sigma = min(std, iqr / 1.349) if iqr > 0 else std
    h = 0.9 * sigma * n ** (-1/5)
    return h if h > 0 else (std * 1e-3 if std > 0 else 1.0)

def gaussian_kde_numpy(x: np.ndarray, grid: np.ndarray, bw: float | None = None) -> np.ndarray:
    x = x[np.isfinite(x)]
    if x.size == 0:
        return np.full_like(grid, np.nan, dtype=float)

    if bw is None:
        bw = silverman_bandwidth(x)

    z = (grid[:, None] - x[None, :]) / bw
    dens = np.exp(-0.5 * z**2).mean(axis=1) / (bw * np.sqrt(2 * np.pi))
    return dens

#loan and align data (those that have land values)
df = pd.read_stata(dta_path)

df = df.dropna(subset=["w_farm_size_agland"])
df = df[df.groupby("hhid")["hhid"].transform("size") == 2].copy()

#KDE FIES
x4 = df.loc[df["wave"] == 4, "probability_moderately_insecure"].to_numpy(dtype=float)
x5 = df.loc[df["wave"] == 5, "probability_moderately_insecure"].to_numpy(dtype=float)

#grid
x_all = np.concatenate([x4[np.isfinite(x4)], x5[np.isfinite(x5)]])
lo, hi = np.percentile(x_all, [0.5, 99.5])  
grid = np.linspace(lo, hi, 400)

d4 = gaussian_kde_numpy(x4, grid) 
d5 = gaussian_kde_numpy(x5, grid)

fig, ax = plt.subplots(figsize=(8, 4.5))

#both lines
ax.plot(grid, d4, linewidth=2, label="2018/19")
ax.plot(grid, d5, linewidth=2, label="2023/24")

ax.set_xlabel("Probability of Being Moderately Food Insecure")
ax.set_ylabel("Density")
ax.set_title("Kernel Density: Probability of Being Moderately Food Insecure (FIES)")
ax.legend(frameon=False)

plt.tight_layout()

plt.savefig(output_dir, dpi=600, bbox_inches="tight")