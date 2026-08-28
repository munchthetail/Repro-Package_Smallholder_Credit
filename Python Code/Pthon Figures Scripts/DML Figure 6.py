#pooled pie chart of loan composition by reason, among households that took a loan (any_loan==1)
#NOTE: DML Data Prep must be re-run first so loan_reason is carried into DML Cleaned Data.dta

import pandas as pd
import matplotlib.pyplot as plt
import matplotlib as mpl
from pathlib import Path

#setting paths
root     = Path(__file__).resolve().parent.parent.parent
dta_path = root / "Stata Code" / "Stata Data Landing" / "Pie Chart Data.dta"
fig_out  = root / "Tables and Figures" / "Figure_loan_composition_by_reason.pdf"

#load data, keep only households that actually took out a loan
df = pd.read_stata(dta_path, convert_categoricals=False)
df = df[df["any_loan"] == 1]

#loan_reason codes -> readable categories (labels are stripped in the cleaned data)
labels = {
    1:  "Farming",
    5:  "Non-farm business",
    7:  "Miscellaneous",
    8:  "Education",
    11: "Household consumption",
    12: "Health care",
}
counts = df["loan_reason"].map(labels).value_counts().reindex(labels.values())

#design style
mpl.rcParams.update({
    "font.family": "serif",
    "font.serif": ["CMU Serif", "Computer Modern Roman", "DejaVu Serif"],
    "mathtext.fontset": "cm",
    "axes.labelsize": 11, "font.size": 11, "legend.fontsize": 9,
    "xtick.labelsize": 10, "ytick.labelsize": 10,
})
mpl.rcParams["text.usetex"] = False

#pooled pie chart
fig, ax = plt.subplots(figsize=(8, 8))
ax.pie(counts, labels=counts.index, autopct="%1.1f%%",
       startangle=90, counterclock=False,
       wedgeprops={"edgecolor": "black", "linewidth": 0.8})
ax.set_title("Pooled Composition of Household Loans by Stated Purpose")

plt.tight_layout()
plt.savefig(fig_out, dpi=600, bbox_inches="tight")
print("saved ->", fig_out)
