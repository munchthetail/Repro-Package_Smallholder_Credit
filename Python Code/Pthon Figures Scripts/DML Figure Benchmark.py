import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from pathlib import Path
import matplotlib as mpl

# ================================
# CONFIG
# ================================

#paths
root       = Path(__file__).resolve().parent.parent.parent
OUTPUT_DIR = root / "Tables and Figures"
csv_path = root / "Tables and Figures"

mpl.rcParams.update({
    "font.family": "serif",
    "font.serif": ["CMU Serif", "Computer Modern Roman", "DejaVu Serif"],
})

#we assume this is the specification
K     = 5
N_REP = 30

outcome_vars = ["ln_gen_consumption_flag", "ln_total_farm_expense", "ln_total_fert_kg_ha"]

#labels for table
drop_labels = {
    "__base__":                        "Baseline (full model)",
    "w_farm_size_agland":              "Farm size (agland)",
    "w_value_crop_production":         "Crop production value",
    "w_value_assets":                  "Household assets",
    "w_nonfarm_income":                "Non-farm income",
    "w_lvstck_holding_tlu":            "Livestock holdings (TLU)",
    "ag_plot_formal_rights_hh":        "Formal land rights",
    "income_shock":                    "Income shock",
    "food_shock":                      "Food shock",
    "price_shock":                     "Price shock",
    "head_maritial_status":            "HH head marital status",
    "head_age":                        "HH head age",
    "head_sex":                        "HH head sex",
    "member":                          "Household members",
    "adult_member":                    "Adult household members",
    "phone_access":                    "Phone access",
    "internet_access":                 "Internet access",
    "probability_moderately_insecure": "Food insecurity risk",
    "FCS_index":                       "Food consumption score",
    "non_farming_loan":                "Non-farm loan",
}

series_labels = {
    ("ln_gen_consumption_flag", "loan"): "Log nonfarm expenditures (ATE)",
    ("ln_total_farm_expense", "loan"):   "Log farm expenditures (ATE)",
    ("ln_total_fert_kg_ha", "loan_x_size"):     "Log fertilizer expenditures (ATE)"
}

COLORS = {
    ("ln_gen_consumption_flag", "loan"): "#185FA5",
    ("ln_total_farm_expense", "loan"):   "#B45609",
    ("ln_total_fert_kg_ha", "loan_x_size"):   "#B48609",
}

# ================================
# HELPERS
# ================================

#we store data by rep and outcome, this just targets that specifically
def load_csv(K, N_REP, y_col, d_name="loan"):
    path = csv_path / f"benchmark_CI_K{K}_R{N_REP}.csv"
    df = pd.read_csv(path)
    # filter to this outcome/treatment/K
    return df[(df["outcome"] == y_col) & (df["treatment"] == d_name) & (df["K"] == K)].set_index("dropped")

#just marking sure labels are good to print on charts
def make_label(col):
    if "_AND_" not in col:
        return drop_labels.get(col, col)
    parts = col.split("_AND_")
    resolved = [drop_labels.get(p.strip(), p.strip()) for p in parts]
    lines = [r + " +" for r in resolved[:-1]] + [resolved[-1]]
    return "\n".join(lines)

# ================================
# LOAD DATA
# ================================

dfs = {}
for y_col in outcome_vars:
    for d_name in ["loan", "loan_x_size"]:
        if y_col == "ln_gen_consumption_flag" and d_name == "loan_x_size":
            continue
        else:
            dfs[(y_col, d_name)] = load_csv(K, N_REP, y_col, d_name)
            print(f"Loaded: {y_col}")

#all drop columns across all loaded CSVs
all_cols = set()
for df in dfs.values():
    all_cols.update(df.index.tolist())
all_cols = ["__base__"] + sorted(all_cols - {"__base__"})

series = [(y_col, d_name) for y_col in outcome_vars for d_name in ["loan", "loan_x_size"]
          if not ((y_col in {"ln_total_farm_expense", "ln_gen_consumption_flag"} and d_name == "loan_x_size") or (y_col == "ln_total_fert_kg_ha" and d_name == "loan"))]
n_series = len(series)

#building rows
rows = []
for (y_col, d_name), df in dfs.items():
    theta_base = float(df.loc["__base__","theta"])
    for col in all_cols:
        lo_adv = float(df.loc[col,"bound_lower_adv"])
        hi_adv = float(df.loc[col,"bound_upper_adv"])
        lo_emp = float(df.loc[col,"bound_lower_emp"])
        hi_emp = float(df.loc[ col, "bound_upper_emp"])
        rho    = float(df.loc[col, "rho"]) if str(df.loc[col, "rho"]) not in ("", "nan") else np.nan
        delta  = float(df.loc[col,"delta_theta"])
    
        valid = not (np.isnan(lo_adv) or np.isnan(hi_adv))
        rows.append({
            "y_col":       y_col,
            "d_name":      d_name,
            "drop_lbl":    col,
            "theta":       theta_base,
            "lo_adv":      lo_adv,
            "hi_adv":      hi_adv,
            "lo_emp":      lo_emp,
            "hi_emp":      hi_emp,
            "rho":         rho,
            "valid":       valid,
            "delta_theta": delta,
        })

#keep only columns with at least one valid bound and exclude baseline
cols_with_bounds = {r["drop_lbl"] for r in rows if r["valid"]}
cols_to_plot = [
    c for c in all_cols if c != "__base__" and c in cols_with_bounds
]

#trimming down to make the table legible
def avg_abs_delta(col):
    deltas = [
        abs(r["delta_theta"])
        for r in rows
        if r["drop_lbl"] == col and not np.isnan(r["delta_theta"])
    ]
    return np.mean(deltas) if deltas else np.inf

bench_set_sorted = sorted(cols_to_plot, key=avg_abs_delta)

#just keeping the top 6
bench_set_sorted = bench_set_sorted[-6:]

# ================================
# PLOT
# ================================

n_drops    = len(bench_set_sorted)

#within_gap controls separation of the two outcome lines inside a group
#group_gap controls space between different benchmark variable groups
#Keep within_gap stable to avoid end-cap overlap; reduce group_gap to compress
within_gap = 0.05
group_gap  = 0.1

# End caps scaled just under half of within_gap so they never overlap
cap_size = within_gap * 0.45

fig, ax = plt.subplots(figsize=(12, 0.42 * n_drops * n_series + 1.8))
fig.patch.set_facecolor("white")
ax.set_facecolor("#F9F9F8")

yticks, yticklabels = [], []

for g_idx, col in enumerate(bench_set_sorted):
    y_center = -(g_idx * (n_series * within_gap + group_gap))

    # Alternating row shading
    if g_idx % 2 == 0:
        ax.axhspan(
            y_center - (n_series * within_gap) / 2 - 0.04,
            y_center + (n_series * within_gap) / 2 + 0.04,
            color="#EBEBEA", zorder=0, linewidth=0
        )

    yticks.append(y_center)
    yticklabels.append(make_label(col))

    for o_idx, (y_col, d_name) in enumerate(series):
        row = next(
            (r for r in rows if r["y_col"] == y_col and r["d_name"] == d_name and r["drop_lbl"] == col),
            None
        )
        if row is None:
            continue

        color = COLORS[(y_col, d_name)]
        y_pos = y_center + (o_idx - (n_series - 1) / 2) * within_gap
        theta = row["theta"]

        if row["valid"]:
            #ddversarial bounds (rho=1)
            ax.plot(
                [row["lo_adv"], row["hi_adv"]], [y_pos, y_pos],
                color=color, linewidth=1.8, alpha=0.35,
                solid_capstyle="round", zorder=2
            )
            ax.plot(
                [row["lo_adv"], row["lo_adv"]],
                [y_pos - cap_size, y_pos + cap_size],
                color=color, linewidth=1.2, alpha=0.5, zorder=2
            )
            ax.plot(
                [row["hi_adv"], row["hi_adv"]],
                [y_pos - cap_size, y_pos + cap_size],
                color=color, linewidth=1.2, alpha=0.5, zorder=2
            )
            #empirical rho bounds
            ax.plot(
                [row["lo_emp"], row["hi_emp"]], [y_pos, y_pos],
                color=color, linewidth=2.2, alpha=0.85,
                solid_capstyle="round", zorder=3
            )
            #diamond at theta
            ax.plot(
                theta, y_pos,
                marker="D", markersize=5, color=color,
                markeredgewidth=0, zorder=4
            )
        else:
            #no valid bounds
            ax.plot(
                theta, y_pos,
                marker="D", markersize=5, color=color,
                markerfacecolor="none", markeredgewidth=1.0,
                markeredgecolor=color, zorder=4, alpha=0.55
            )
            

#baseline reference lines
for y_col, d_name in series:
    base_row = next(
        (r for r in rows if r["y_col"] == y_col and r["d_name"] == d_name and r["drop_lbl"] == "__base__"),
        None
    )
    if base_row:
        ax.axvline(
            base_row["theta"], color=COLORS[(y_col, d_name)],
            linewidth=1.5, linestyle="--", alpha=0.4, zorder=1
        )

legend_elements = []
for key in series:
    legend_elements.append(
        mpatches.Patch(facecolor=COLORS[key], label=series_labels[key], alpha=0.75)
    )
legend_elements += [
    plt.Line2D([0], [0], color="gray", linewidth=2.2, alpha=0.85,
               label=r"Empirical bounds ($\hat{\rho}^2$)"),
    plt.Line2D([0], [0], color="gray", linewidth=1.8, alpha=0.35,
               label=r"Conservative bounds ($\hat{\rho}^2=1$)"),
    plt.Line2D([0], [0], marker="D", color="gray", markersize=5,
               linestyle="None", label=r"$\hat{\theta}$ estimate"),
]


#yaxis
ax.set_yticks(yticks)
ax.set_yticklabels(yticklabels, fontsize=14, rotation=0, va="center", ha="right",
                   linespacing=1.4)
ax.tick_params(axis="y", length=0, pad=8)
ax.tick_params(axis="x", labelsize=13, length=3, color="#AAAAAA", width=1.5)
plt.xlabel(r"Agricultural Loan Treatment Effect ($\hat{\theta}$)", fontsize=17, labelpad=10)
ax.set_xlim(0, 0.2)

#spines
for spine in ["top", "right", "left"]:
    ax.spines[spine].set_visible(False)
ax.spines["bottom"].set_color("#CCCCCC")
ax.spines["bottom"].set_linewidth(1.5)
ax.grid(axis="x", color="#AAAAAA", linewidth=1.5, zorder=0)

#legend at top left corner
ax.legend(
    handles=legend_elements,
    loc="upper left",
    bbox_to_anchor=(0.70, 0.99),
    bbox_transform=ax.transAxes,
    fontsize=12, framealpha=0.92, edgecolor="#CCCCCC",
    borderpad=0.7, labelspacing=0.5
)

fig.suptitle("Sensitivity of Treatment Effects to Omitted Variables",
             fontsize=23, y=0.97, x=0.5, ha="center")
fig.text(0.5, 0.895, "Estimated via Observed Variable Benchmarking bounds",
         fontsize=19, ha="center")


plt.tight_layout(rect=[0, 0, 1, 0.93])

out_path = OUTPUT_DIR / f"sensitivity_forest_plot_K{K}_Rep{N_REP}.pdf"
plt.savefig(out_path, dpi=600, bbox_inches="tight", facecolor="white")
