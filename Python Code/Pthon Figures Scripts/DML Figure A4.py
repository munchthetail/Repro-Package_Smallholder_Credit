#%%
# -*- coding: utf-8 -*-
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib as mpl
import matplotlib.patheffects as pe
from numpy.polynomial import Polynomial
from pathlib import Path

#setting paths
root     = Path(__file__).resolve().parent.parent.parent
dta_path = root / "Stata Code" / "Stata Data Landing" / "DML Cleaned Data.dta"
fig_out  = root / "Tables and Figures" / "Figure_farm_expense_by_size.pdf"

#load the full sample, keep only rows with the two variables we plot
df = pd.read_stata(dta_path)
df = df.dropna(subset=["w_farm_size_agland", "ln_total_farm_expense","w_farm_size_agland"])
df = df[df.groupby("hhid")["hhid"].transform("size") == 2].copy()

xcol, ycol = "w_farm_size_agland", "ln_total_farm_expense"

#wave styling (waves are coded 4 and 5 in the data)
wave_labels = {4: "Wave 4", 5: "Wave 5"}
wave_colors = {4: "tab:blue", 5: "tab:orange"}

#grid for the fitted curves; trim the far-right tail so the view stays readable (no rows dropped)
xmax = np.quantile(df[xcol], 0.99) * 1.05
xg   = np.linspace(0.0, xmax, 400)

#design style copied from DML Figure 2
mpl.rcParams.update({
    "font.family": "serif",
    "font.serif": ["CMU Serif", "Computer Modern Roman", "DejaVu Serif"],
    "mathtext.fontset": "cm",
    "axes.labelsize": 11, "font.size": 11, "legend.fontsize": 9,
    "xtick.labelsize": 10, "ytick.labelsize": 10,
})
mpl.rcParams["text.usetex"] = False

fig, ax = plt.subplots(figsize=(8, 6))

for w in sorted(df["wave"].unique()):
    sub   = df[df["wave"] == w]
    color = wave_colors.get(int(w))
    label = wave_labels.get(int(w), f"Wave {int(w)}")
    #raw points
    ax.scatter(sub[xcol], sub[ycol], s=10, alpha=0.25, color=color, edgecolor="none")
    #basic 3rd-degree (cubic) fit per wave; label the line (not the faint scatter) so it
    #shows in the legend, with a black outline so it stands out against the points
    p = Polynomial.fit(sub[xcol], sub[ycol], 3)
    ax.plot(xg, p(xg), color=color, lw=2.5, label=f"{label} (n={len(sub)})",
            path_effects=[pe.Stroke(linewidth=4.5, foreground="black"), pe.Normal()])

ax.set_xlim(left=0, right=xmax)
ax.set_xlabel("Farm Size (hectares)")
ax.set_ylabel("Log Total Farm Expenditures")
ax.set_title("Total Farm Expenditures by Farm Size and Wave")
ax.legend(frameon=False, loc="upper left")

plt.tight_layout()
plt.savefig(fig_out, dpi=600, bbox_inches="tight")
print("saved ->", fig_out)
