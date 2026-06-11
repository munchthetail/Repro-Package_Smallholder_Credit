#variance plot for nonfarm, needs DML Identification for nonfarm utilization to run first

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib as mpl
import matplotlib.patheffects as pe
from numpy.polynomial import Polynomial
from pathlib import Path

#setting paths
root      = Path(__file__).resolve().parent.parent.parent
cache_dir = root / "Tables and Figures" / "nuisance_cache"
dta_path  = root / "Stata Code" / "Stata Data Landing" / "DML Cleaned Data.dta"
twfe_path = root / "Stata Code" / "Stata Data Landing" / "TWFE_farm_residuals.dta"
fig_out   = root / "Tables and Figures" / "Figure_residual_farm_variance_DML_vs_TWFE.pdf"

#load  data
dml  = pd.read_csv(cache_dir / "DML_farm_residuals.csv")
twfe = pd.read_stata(twfe_path)
size = pd.read_stata(dta_path)[["hhid", "wave", "w_farm_size_agland"]]

#normalize keys for merge, this should be irrelavent but just to be safe 
for d in (dml, twfe, size):
    d["hhid"] = d["hhid"].astype(int)
    d["wave"] = d["wave"].astype(int)

#merging on hhid and wave --- top panel
df = dml.merge(twfe, on=["hhid", "wave"], how="inner")
df = df.drop(columns=["w_farm_size_agland"], errors="ignore")  #avoid a merge collision
df = df.merge(size, on=["hhid", "wave"], how="inner")
df = df.dropna(subset=["DML_residuals", "TWFE_residuals", "w_farm_size_agland"])

#per-observation difference pooled --- bottom panel
df["resid_diff"] = np.abs(df["DML_residuals"] - df["TWFE_residuals"])

xcol = "w_farm_size_agland"

#grid for support
xmax = np.quantile(df[xcol], 0.99) * 1.05
xg   = np.linspace(0.0, xmax, 400)

#lots of diagnostics mentioned in results section
print("Var(DML residuals)  =", round(df["DML_residuals"].var(),  4))
print("Var(TWFE residuals) =", round(df["TWFE_residuals"].var(), 4))
print("SD(|difference|)   =", round(df["resid_diff"].std(),     4))
print("Mean(|difference|)   =", round(df["resid_diff"].mean(),     4))

#design style
mpl.rcParams.update({
    "font.family": "serif",
    "font.serif": ["CMU Serif", "Computer Modern Roman", "DejaVu Serif"],
    "mathtext.fontset": "cm",
    "axes.labelsize": 11, "font.size": 11, "legend.fontsize": 9,
    "xtick.labelsize": 10, "ytick.labelsize": 10,
})
mpl.rcParams["text.usetex"] = False

#scatter one pooled series and its basic 3 degree  fit
def plot_series(ax, y, color, label):
    ax.scatter(df[xcol], y, s=10, alpha=0.25, color=color, edgecolor="none")
    p = Polynomial.fit(df[xcol], y, 3)
    
    #R^2 isn't used in results section but interesting to report
    #SD is mentioned in the results section
    ss_res = np.sum((y - p(df[xcol]))**2)
    ss_tot = np.sum((y - y.mean())**2)
    r2 = 1 - ss_res / ss_tot
    print(f"{label}: R^2 value over data = {(r2):.2f}")
    print(f"{label}: SD value over data = {(p(xg).std()):.2f}")
    #label the fit line
    #black outline behind the colored line
    ax.plot(xg, p(xg), color=color, lw=2.5, label=label,
            path_effects=[pe.Stroke(linewidth=4.5, foreground="black"), pe.Normal()])

fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(8, 8), sharex=True)

#top panel pooled residuals
plot_series(ax1, df["DML_residuals"],  "tab:blue",   "DML")
plot_series(ax1, df["TWFE_residuals"], "tab:orange", "TWFE")
ax1.axhline(0, color="black", ls="--", lw=0.8)
ax1.set_title("Pooled Logged Farm Expenditure Residuals: DML vs TWFE")
ax1.set_ylabel("Residual")
ax1.legend(frameon=False, loc="upper left")

#bottom panel absolute difference of the two residual sets
plot_series(ax2, df["resid_diff"], "tab:green", "|DML - TWFE|")
ax2.axhline(0, color="gray", ls="--", lw=1, zorder=0)
ax2.set_title("Absolute difference in residuals |DML - TWFE|")
ax2.set_xlabel("Farm Size (hectares)")
ax2.set_ylabel("Absolute residual difference")
ax2.legend(frameon=False, loc="upper left")

ax1.set_xlim(0, xmax)
plt.tight_layout()
plt.savefig(fig_out, dpi=600, bbox_inches="tight")
print("saved ->", fig_out)
