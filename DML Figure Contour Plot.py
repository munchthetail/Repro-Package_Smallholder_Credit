import re
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
from pathlib import Path

# ================================
# CONFIG
# ================================

OUTPUT_DIR = Path(r"C:\Users\Will\OneDrive - The Ohio State University\RA\Output\Prelim")

K     = 5
N_REP = 10

# Outcome to plot — change to "ln_total_farm_expense" for farm expense
y_col = "ln_gen_consumption_flag"

outcome_title = {
    "ln_gen_consumption_flag": "Log General Consumption",
    "ln_total_farm_expense":   "Log Total Farm Expense",
}

# Grid range for C_Y and C_D (0 to 6%)
C_MAX   = 0.10
N_GRID  = 500

# rho — use 1.0 for adversarial (conservative) lower bound
rho = 1.0

# ================================
# HELPERS
# ================================

def safe_outcome_label(y_col):
    return re.sub(r"[^A-Za-z0-9_]+", "_", str(y_col))

def load_csv(K, N_REP, y_col):
    y_lbl = safe_outcome_label(y_col)
    path  = OUTPUT_DIR / f"benchmark_K{K}_Rep{N_REP}_{y_lbl}.csv"
    if not path.exists():
        raise FileNotFoundError(f"CSV not found: {path}")
    return pd.read_csv(path, index_col="parameter")

# ================================
# LOAD BASELINE VALUES
# ================================

df        = load_csv(K, N_REP, y_col)
theta_0   = float(df.loc["theta",  "__base__"])
sigma2_0  = float(df.loc["sigma2", "__base__"])
nu2_0     = float(df.loc["nu2",    "__base__"])

sigma_0   = np.sqrt(sigma2_0)
nu_0      = np.sqrt(nu2_0)

print(f"Baseline theta:  {theta_0:.6f}")
print(f"Baseline sigma:  {sigma_0:.6f}")
print(f"Baseline nu:     {nu_0:.6f}")
print(f"S = sigma*nu:    {sigma_0*nu_0:.6f}")

# Load benchmarked (c_y, c_d) points from all dropped columns
bench_points = {}
for col in df.columns:
    if col == "__base__":
        continue
    try:
        c_y = float(df.loc["c_y", col])
        c_d = float(df.loc["c_d", col])
        if c_y >= 0 and c_d >= 0:
            bench_points[col] = (c_y, c_d)
    except (ValueError, KeyError):
        pass

# ================================
# COMPUTE LOWER BOUND SURFACE
# ================================
# theta_- = theta_0 - |rho| * sigma_0 * nu_0 * C_Y * C_D
# where C_Y = sqrt(c_y) and C_D = sqrt(c_d) per the paper notation
# (c_y and c_d are already C_Y^2 and C_D^2 in Chernozhukov et al.)

c_y_vec = np.linspace(0, C_MAX, N_GRID)
c_d_vec = np.linspace(0, C_MAX, N_GRID)
CY, CD  = np.meshgrid(c_y_vec, c_d_vec)

# Bias = |rho| * sigma_0 * nu_0 * sqrt(c_y) * sqrt(c_d)
#      = |rho| * sigma_0 * nu_0 * sqrt(c_y * c_d)
bias         = rho * sigma_0 * nu_0 * np.sqrt(CY * CD)
theta_lower  = theta_0 - bias

# ================================
# PLOT
# ================================

fig, ax = plt.subplots(figsize=(8, 6.5))
fig.patch.set_facecolor("white")

# Filled contour — lower bound of theta
n_levels = 20
cf = ax.contourf(
    CY * 100, CD * 100, theta_lower,
    levels=n_levels,
    cmap="RdYlGn",
    vmin=min(theta_lower.min(), -0.02),
    vmax=theta_0
)

# Contour lines (subtle)
cs = ax.contour(
    CY * 100, CD * 100, theta_lower,
    levels=n_levels,
    colors="white", linewidths=0.3, alpha=0.4
)

# Zero tipping-point line — thick black
zero_contour = ax.contour(
    CY * 100, CD * 100, theta_lower,
    levels=[0.0],
    colors="black", linewidths=2.5
)
ax.clabel(zero_contour, fmt=r"$\hat{\theta}_0 = 0$", fontsize=11,
          inline=True, inline_spacing=6)

# Benchmark variable points
# Human-readable short labels for annotation
bench_labels = {
    "w_value_crop_production":         "Crop value",
    "w_value_assets":                  "HH assets",
    "w_nonfarm_income":                "Non-farm income",
    "w_lvstck_holding_tlu":            "Livestock",
    "ag_plot_formal_rights_hh":        "Land rights",
    "income_shock":                    "Income shock",
    "food_shock":                      "Food shock",
    "price_shock":                     "Price shock",
    "head_maritial_status":            "Marital status",
    "head_age":                        "Head age",
    "head_sex":                        "Head sex",
    "member":                          "HH members",
    "adult_member":                    "Adult members",
    "phone_access":                    "Phone access",
    "internet_access":                 "Internet access",
    "probability_moderately_insecure": "Food insecurity",
    "FCS_index":                       "FCS index",
    "non_farming_loan":                "Non-farm loan",
    "w_farm_size_agland":              "Farm size",
}

plotted = []

# Colorbar
cbar = fig.colorbar(cf, ax=ax, pad=0.02, fraction=0.046)
cbar.ax.tick_params(labelsize=9)

# Axis formatting
ax.xaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"{x:.1f}%"))
ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda y, _: f"{y:.1f}%"))
ax.set_xlim(0, C_MAX * 100)
ax.set_ylim(0, C_MAX * 100)
ax.set_xlabel(r"$C_Y^2$ — Partial $R^2$ of confounder with outcome", fontsize=12, labelpad=8)
ax.set_ylabel(r"$C_D^2$ — Partial $R^2$ of confounder with treatment", fontsize=12, labelpad=8)
ax.tick_params(axis="both", labelsize=10)

for spine in ax.spines.values():
    spine.set_linewidth(1.5)
    spine.set_color("#AAAAAA")

ax.grid(color="white", linewidth=0.4, alpha=0.5)

# Titles
fig.suptitle(
    f"Sensitivity of Treatment Effect to Omitted Variable Bias: {outcome_title.get(y_col, y_col)}",
    fontsize=14, y=1.01
)

plt.tight_layout()

out_path = OUTPUT_DIR / f"sensitivity_contour_{safe_outcome_label(y_col)}_K{K}_Rep{N_REP}.png"
plt.savefig(out_path, dpi=180, bbox_inches="tight", facecolor="white")
plt.show()
print(f"Saved to: {out_path}")