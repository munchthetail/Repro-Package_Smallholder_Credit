import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.ticker import PercentFormatter

import matplotlib as mpl

# source of data "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Analysis Consumption - No IV - logged - v1.do"
# Load Stata file
df = pd.read_stata(
    r"C:/Users/Will/OneDrive - The Ohio State University/RA/Data/DML Cleaned Data.dta"
)

#aligning dataset with the DML dataset
#df = df.dropna(subset=["w_farm_size_agland"])

#removing households with only one observation    
df = df[df.groupby("hhid")["hhid"].transform("size") == 2].copy()

independent_variables = [
    "any_arv_farm_loan",
    "farming_loan_total_amount",
    "w_farm_size_agland", 
    "w_value_crop_production",
    "w_value_assets", 
    "w_nonfarm_income", 
    "w_lvstck_holding_tlu",
    "ag_plot_formal_rights_hh",
    "income_shock", 
    "food_shock", 
    "price_shock",
    "head_maritial_status", 
    "head_age", 
    "head_sex", 
    "member", 
    "adult_member",
    "phone_access", 
    "internet_access", 
    "probability_moderately_insecure", 
    "FCS_index", 
    "non_farming_loan"
]

dependent_variables = [
    "total_farm_expense", 
    "total_input_exp", 
    "land_total_exp", 
    "labor_expense_total", 
    "animal_total_exp",
    "gen_consumption_flag", 
    "food_flag", 
    "non_food_gen_consumption",
    "total_fert_kg_ha"]

for v in dependent_variables + ["farming_loan_total_amount"]:
    df[v] = df[v] / 1000

# =========================
# Build quartiles
# =========================
# (qcut assigns ~equal counts per bin; duplicates='drop' avoids errors if many ties)
df = df.copy()
df["farm_q"] = pd.qcut(df["w_farm_size_agland"], q=4, labels=[1,2,3,4], duplicates="drop")

# Optional: make it ordered categorical (nice for tables)
df["farm_q"] = pd.Categorical(df["farm_q"], categories=[1,2,3,4], ordered=True)

# =========================
#Total Mean
# =========================
def aggregate_means(
    data: pd.DataFrame,
    y_vars: list[str],
    loan_var: str = "farming_loan_total_amount",
    loan_flag: str = "any_arv_farm_loan",
) -> pd.Series:
    """
    Aggregate means with a conditional mean for the loan amount variable.
    """
    means = {}

    for y in y_vars:
        if y == loan_var:
            means[y] = (
                data.loc[data[loan_flag] == 1, y]
                .dropna()
                .mean()
            )
        else:
            means[y] = data[y].dropna().mean()

    return pd.Series(means)


# =========================
# Summary table builder
# =========================
def quartile_summary_table(
    data: pd.DataFrame,
    vars_list: list,
    q: str = "farm_q",
    label_map: dict | None = None,
    decimals: int = 3
) -> pd.DataFrame:
    rows = []
    for v in vars_list:
        if v not in data.columns:
            continue

        # Quartile means
        if v == "farming_loan_total_amount":
            means = data.loc[data["any_arv_farm_loan"] == 1].groupby(q, observed=True)[v].mean()
            n_total = int(data.loc[data["any_arv_farm_loan"] == 1, v].notna().sum())
        else:
            means = data.groupby(q, observed=True)[v].mean()
            n_total = int(data[v].notna().sum())

        # Overall N used for means (non-missing)
        n_total = int(data[v].notna().sum())

        # ANOVA p-value
        mean_full = aggregate_means(data, [v]).get(v, np.nan)

        row = {
            "Variable": label_map.get(v, v) if label_map else v,
            "N": n_total,
            "Mean Q1 (smallest)": means.get(1, np.nan),
            "Mean Q2": means.get(2, np.nan),
            "Mean Q3": means.get(3, np.nan),
            "Mean Q4 (largest)": means.get(4, np.nan),
            "Mean Overall": mean_full,
            "Min": np.nanmin(data[v]),
            "Max": np.nanmax(data[v]),
        }
        rows.append(row)

    out = pd.DataFrame(rows)

    # Formatting (keep numeric types if you want; here we round for printing)
    num_cols = ["Mean Q1 (smallest)", "Mean Q2", "Mean Q3", "Mean Q4 (largest)", "Mean Overall"]
    out[num_cols] = out[num_cols].astype(float).round(decimals)

    # Optional: nicer p-value display
    # out["ANOVA p-value"] = out["ANOVA p-value"].map(lambda x: f"{x:.3f}" if pd.notna(x) else "")

    return out

# =========================
# Run for your variables
# =========================
all_vars = independent_variables + dependent_variables

summary_df = quartile_summary_table(df, all_vars, q="farm_q", decimals=3)

# Print nicely
with pd.option_context("display.max_rows", 200, "display.max_columns", 20, "display.width", 200):
    print(summary_df)

# Save if you want
summary_df.to_csv("quartile_summary_anova.csv", index=False)

import matplotlib.pyplot as plt
df_q1 = df.loc[df["farm_q"] == 1]
plt.figure(figsize=(6,4))
plt.hist(df_q1["w_farm_size_agland"], bins=30, edgecolor="black", alpha=0.7)
plt.title("Farm size distribution — Quartile 1")
plt.xlabel("Agricultural land (ha)")
plt.ylabel("Frequency")
plt.tight_layout()
plt.show()

min_val = df_q1["w_farm_size_agland"].min()
max_val = df_q1["w_farm_size_agland"].max()

print(f"Q1 min: {min_val:,}")
print(f"Q1 max: {max_val:,}")
