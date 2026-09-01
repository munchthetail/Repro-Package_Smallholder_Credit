#this produces the heterogenous marginal effect plot with confidence bands
#NOTE: first run DML Identification.py with tipping_point = 1
#NOTE: SEE doi:10.1093/pan/mpi014 for a clear rundown of the confidence bound math
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib as mpl
from scipy.stats import gaussian_kde  # Required for manual density calculation
from pathlib import Path
from scipy.stats import norm

#setting paths
root = Path(__file__).resolve().parent.parent.parent
dta_path = root / "Stata Code" / "Stata Data Landing" / "DML Cleaned Data.dta"
joint_path = root / "Tables and Figures" / "nuisance_cache" / "tipping_common" / "tipping_joint_K5_R30.npz"

#joint coefficient order: farm main, farm slope, nonfarm main, nonfarm slope
joint = np.load(joint_path)
q_reps = joint["coefficients_by_rep"]
V_reps = joint["covariance_by_rep"]
mean_size = float(joint["mean_size"])
expected_order = np.asarray(["farm_main", "farm_size", "nonfarm_main", "nonfarm_size"])
if not np.array_equal(joint["coefficient_order"], expected_order):
    raise RuntimeError("Unexpected coefficient order in the tipping-point cache")
if int(joint["k_folds"]) != 5 or int(joint["n_rep"]) != 30:
    raise RuntimeError("Figure 4 expects the K=5, R=30 common-sample run")
if q_reps.shape != (30, 4) or V_reps.shape != (30, 4, 4):
    raise RuntimeError("Unexpected coefficient or covariance dimensions in the tipping-point cache")

#use the exact common sample used by the tipping profile
df = pd.read_stata(dta_path)
df = df.dropna(subset=["ln_total_farm_expense", "ln_gen_consumption_flag", "w_farm_size_agland"])
df = df[df.groupby("hhid")["hhid"].transform("size") == 2].copy()

# =====================================================================
#  Common-sample conditional effects and their difference
# =====================================================================
alpha = 0.10                       # 90% bands, matching the 10% framing
z = norm.ppf(1 - alpha / 2)        # 1.645

#grid farm size
xv = df["w_farm_size_agland"].to_numpy()
xv = xv[np.isfinite(xv)]
xmax = np.quantile(xv, 0.99) * 1.05
xg = np.linspace(0.0, xmax, 400)
xc = xg - mean_size

farm_design = np.column_stack([np.ones_like(xc), xc, np.zeros_like(xc), np.zeros_like(xc)])
nonfarm_design = np.column_stack([np.zeros_like(xc), np.zeros_like(xc), np.ones_like(xc), xc])
diff_design = farm_design - nonfarm_design

def _aggregate_contrast(design):
    """Repeated-split median estimate and scalar variance for each grid contrast."""
    estimates_by_rep = q_reps @ design.T
    estimate = np.median(estimates_by_rep, axis=0)
    within_variance = np.einsum("ni,rij,nj->rn", design, V_reps, design)
    adjusted_variance = within_variance + (estimates_by_rep - estimate) ** 2
    variance = np.median(adjusted_variance, axis=0)
    return estimate, variance

tau1, var1 = _aggregate_contrast(farm_design)
tau2, var2 = _aggregate_contrast(nonfarm_design)
delta, var_d = _aggregate_contrast(diff_design)
se1 = np.sqrt(np.clip(var1, 0, None))
se2 = np.sqrt(np.clip(var2, 0, None))
se_d = np.sqrt(np.clip(var_d, 0, None))
lo1, hi1 = tau1 - z * se1, tau1 + z * se1
lo2, hi2 = tau2 - z * se2, tau2 + z * se2
lo_d, hi_d = delta - z * se_d, delta + z * se_d

# support density (reflection KDE cut at 0), echoing the old figure
def _refl_kde(data, grid):
    d = np.concatenate([data, -data])
    return gaussian_kde(d, bw_method="scott")(grid) * 2.0
dens = _refl_kde(xv, xg)
 
def _spans(grid, mask):
    out, run = [], None
    for i, m in enumerate(mask):
        if m and run is None:
            run = grid[i]
        if run is not None and not m:
            out.append((run, grid[i - 1])); run = None
        elif run is not None and i == len(mask) - 1:
            out.append((run, grid[i])); run = None
    return out

def _zero_crossings(grid, values):
    """Crossings of the directly aggregated difference curve."""
    idx = np.where(np.signbit(values[:-1]) != np.signbit(values[1:]))[0]
    return [
        grid[i] - values[i] * (grid[i + 1] - grid[i]) / (values[i + 1] - values[i])
        for i in idx
    ]

farm_positive_spans = _spans(xg, lo1 > 0)
equality_spans = _spans(xg, (lo_d <= 0) & (hi_d >= 0))
descriptive_crossings = _zero_crossings(xg, delta)
print("Descriptive difference-curve crossings:", descriptive_crossings or "none")
print("Farm-effect 90% positive regions:", farm_positive_spans or "none")
print("Farm/nonfarm 90% equality regions:", equality_spans or "none")
 
mpl.rcParams.update({
    "font.family": "serif",
    "font.serif": ["CMU Serif", "Computer Modern Roman", "DejaVu Serif"],
    "mathtext.fontset": "cm",
    "axes.labelsize": 11, "font.size": 11, "legend.fontsize": 9,
    "xtick.labelsize": 10, "ytick.labelsize": 10,
})
mpl.rcParams["text.usetex"] = False
 
fig, (ax1, ax2) = plt.subplots(2, 1, figsize=(8, 7), sharex=True,
                               gridspec_kw={"height_ratios": [2, 1]})
 
# Panel A: the two effects with 90% bands + farm-size support
axd = ax1.twinx()
axd.plot(xg, dens, color="black", ls="--", lw=0.8, alpha=0.45, zorder=0,
         label="Farm size distribution")
axd.set_yticks([]); axd.set_ylim(bottom=0)
 
panel1_min = min(lo1.min(), lo2.min(), 0.0)
panel1_max = max(hi1.max(), hi2.max(), 0.0)
panel1_pad = 0.05 * (panel1_max - panel1_min)
ax1.set_ylim(panel1_min - panel1_pad, panel1_max + panel1_pad)
ax1.fill_between(xg, lo1, hi1, color="tab:blue", alpha=0.25, linewidth=0)
ax1.plot(xg, tau1, color="tab:blue", lw=2, label="Effect on farm expenditures")
ax1.fill_between(xg, lo2, hi2, color="tab:orange", alpha=0.25, linewidth=0)
ax1.plot(xg, tau2, color="tab:orange", lw=2, label="Effect on nonfarm expenditures")
ax1.axhline(0, color="black", lw=0.8)   
ax1.set_ylabel("Effect of loan (log points)")
ax1.set_title("Common-Sample Conditional Loan Effects by Farm Size - 90% Pointwise Bands")
h1, l1 = ax1.get_legend_handles_labels()
h2, l2 = axd.get_legend_handles_labels()
ax1.legend(h1 + h2, l1 + l2, frameon=False, loc="upper right")
ax1.set_zorder(axd.get_zorder() + 1); ax1.patch.set_visible(False)
 
# Panel B: difference + region where the two effects are indistinguishable
panel2_min = min(lo_d.min(), 0.0)
panel2_max = max(hi_d.max(), 0.0)
panel2_pad = 0.05 * (panel2_max - panel2_min)
ax2.set_ylim(panel2_min - panel2_pad, panel2_max + panel2_pad)
ax2.axhline(0, color="gray", ls="--", lw=1, label="No difference")
ax2.fill_between(xg, lo_d, hi_d, color="green", alpha=0.15, linewidth=0)
ax2.plot(xg, delta, color="green", lw=2, label="Difference in effects")
for s, e in equality_spans:
    ax2.axvspan(s, e, color="gray", alpha=0.12, linewidth=0)
for i, crossing in enumerate(descriptive_crossings):
    ax2.axvline(crossing, color="black", ls=":", lw=1.2,
                label="Descriptive crossing" if i == 0 else None)
ax2.set_xlabel("Farm Size (hectares)")
ax2.set_ylabel("Difference in effects")
ax2.legend(frameon=False, loc="upper right")
ax2.set_xlim(left=0, right=xmax)
 
plt.tight_layout()
#save separately so the existing paper figure is untouched until the results are reviewed
fig_out = root / "Tables and Figures" / "tipping_common" / "Figure_tipping_point_common_sample.pdf"
fig_out.parent.mkdir(parents=True, exist_ok=True)
plt.savefig(fig_out, dpi=600, bbox_inches="tight")
print("saved ->", fig_out)
