import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib as mpl
from scipy.stats import gaussian_kde  # Required for manual density calculation
from pathlib import Path

#setting paths
root       = Path(__file__).resolve().parent.parent.parent
output_dir = root / "Tables and Figures" / "Figure_A2.pdf"
dta_path = root / "Stata Code" / "Stata Data Landing" / "DML Cleaned Data.dta"

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

mpl.rcParams["text.usetex"] = False

#load data
df = pd.read_stata(dta_path)
df = df.dropna(subset=["total_farm_expense"])
df = df[df.groupby("hhid")["hhid"].transform("size") == 2].copy()

fig, ax = plt.subplots(figsize=(8, 4.5))

#KDE helper function for cutting off at zero
def plot_corrected_reflection_kde(data, ax, color, label, linestyle="-"):

    #mirror the data
    reflected_data = np.concatenate([data, -data])
    
    #KDE using scipy
    kde = gaussian_kde(reflected_data, bw_method='scott') 
    x_grid = np.linspace(0, data.max() * 1.1, 1000)
    y_vals = kde(x_grid) * 2 
    
    #plot
    ax.plot(x_grid, y_vals, color=color, label=label, linestyle=linestyle, linewidth=2)

#HH w/ loans
plot_corrected_reflection_kde(
    df.loc[df["any_arv_farm_loan"] == 1, "total_farm_expense"], 
    ax, 
    color="tab:blue", 
    label="Households with Agricultural Loan(s)"
)

#HHs w/o loans
plot_corrected_reflection_kde(
    df.loc[df["any_arv_farm_loan"] == 0, "total_farm_expense"], 
    ax, 
    color="tab:orange", 
    label="Households without Agricultural Loan(s)"
)

#all HHs
plot_corrected_reflection_kde(
    df["total_farm_expense"], 
    ax, 
    color="black", 
    label="Full Sample", 
    linestyle="--"
)

ax.set_xlim(left=0)
ax.set_xlabel("Total Farm Expense (Millions of Naira)")
ax.set_ylabel("Density")
ax.set_title("Kernel Density: Distribution of Total Farm Expense")
ax.legend(frameon=False)

plt.tight_layout()
plt.savefig(output_dir, dpi=600, bbox_inches="tight")