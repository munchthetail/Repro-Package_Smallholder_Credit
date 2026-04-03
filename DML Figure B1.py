import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib as mpl
from scipy.stats import gaussian_kde  # Required for manual density calculation

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

# Load Data
df = pd.read_stata(
    r"C:/Users/Admin/OneDrive - The Ohio State University/RA/Data/DML Cleaned Data.dta"
)
df = df.dropna(subset=["w_farm_size_agland"])
df = df[df.groupby("hhid")["hhid"].transform("size") == 2].copy()

fig, ax = plt.subplots(figsize=(8, 4.5))

# --- Helper Function for Corrected Reflection KDE ---
def plot_corrected_reflection_kde(data, ax, color, label, linestyle="-"):
    """
    1. Mirrors data to fix boundary bias at 0.
    2. Calculates KDE.
    3. Multiplies Density by 2 to correct for the doubled sample size.
    """
    # 1. Mirror the data
    reflected_data = np.concatenate([data, -data])
    
    # 2. Calculate KDE using scipy
    # bw_method='scott' is standard; you can adjust the scalar to smooth/sharpen
    kde = gaussian_kde(reflected_data, bw_method='scott') 
    
    # Create a grid of x values starting strictly from 0
    x_grid = np.linspace(0, data.max() * 1.1, 1000)
    
    # 3. Evaluate and Multiply by 2
    y_vals = kde(x_grid) * 2 
    
    # Plot
    ax.plot(x_grid, y_vals, color=color, label=label, linestyle=linestyle, linewidth=2)

# --- Plotting ---

# 2. Households WITH Loans (Blue)
plot_corrected_reflection_kde(
    df.loc[df["any_arv_farm_loan"] == 1, "w_farm_size_agland"], 
    ax, 
    color="tab:blue", 
    label="Households with Agricultural Loans"
)

# 3. Households WITHOUT Loans (Orange)
plot_corrected_reflection_kde(
    df.loc[df["any_arv_farm_loan"] == 0, "w_farm_size_agland"], 
    ax, 
    color="tab:orange", 
    label="Households without Agricultural Loans"
)

# 1. All Households (Gray, Dashed)
plot_corrected_reflection_kde(
    df["w_farm_size_agland"], 
    ax, 
    color="black", 
    label="Full Sample", 
    linestyle="--"
)

ax.set_xlim(left=0)
ax.set_xlabel("Farm Size (hectares)")
ax.set_ylabel("Density")
ax.set_title("Kernel Density: Distribution of Farm Size")
ax.legend(frameon=False)

plt.tight_layout()
plt.show()