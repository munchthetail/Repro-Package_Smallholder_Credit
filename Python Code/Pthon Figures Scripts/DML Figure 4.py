#%%

#NOTE: SEE doi:10.1093/pan/mpi014 for a clear rundown of the confidence bound math
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib as mpl
from scipy.stats import gaussian_kde  # Required for manual density calculation
from pathlib import Path

#setting paths
root       = Path(__file__).resolve().parent.parent.parent
output_dir = root / "Tables and Figures" / "Figure_A3.pdf"
dta_path = root / "Stata Code" / "Stata Data Landing" / "DML Cleaned Data.dta"

con_coef_path = root / "Tables and Figures" / "nuisance_cache" / "hte_gen_consumption.csv"
exp_coef_path = root / "Tables and Figures" / "nuisance_cache" / "hte_farm_expense.csv"

con_coef_ate = pd.read_csv(con_coef_path, header=None).iloc[0,0]
con_var_ate = pd.read_csv(con_coef_path, header=None).iloc[0,1]**2

exp_coef_ate = pd.read_csv(exp_coef_path, header=None).iloc[0,0]
exp_var_ate = pd.read_csv(exp_coef_path, header=None).iloc[0,1]**2
exp_coef_hte = pd.read_csv(exp_coef_path, header=None).iloc[0,2]
exp_var_hte = pd.read_csv(exp_coef_path, header=None).iloc[0,3]**2
exp_covar = pd.read_csv(exp_coef_path, header=None).iloc[0,4]

print(con_coef_ate, con_var_ate)
print(exp_coef_ate, exp_var_ate, exp_coef_hte, exp_var_hte, exp_covar)

#%%


df = pd.read_stata(dta_path)
df = df.dropna(subset=["w_farm_size_agland"])
df = df.dropna(subset=["ln_total_farm_expense"])
df = df[df.groupby("hhid")["hhid"].transform("size") == 2].copy()

# =====================================================================
#  Cross-over (tipping point) figure for two DML treatment effects.
#  Reg 1 (farm expense, with interaction):  tau1(x) = b1 + b2 * x
#  Reg 2 (general consumption, flat):       tau2    = g
#  Moderator x = w_farm_size_agland
# =====================================================================
from scipy.stats import norm
 
# read_csv(...).iloc[i] returns a 1-element Series -> coerce to float
def _f(x):
    return float(np.asarray(x, dtype=float).ravel()[0])
 
b1, vb1 = _f(exp_coef_ate), _f(exp_var_ate)   # Reg 1 ATE  (sig @ 10%)
b2, vb2 = _f(exp_coef_hte), _f(exp_var_hte)   # Reg 1 HTE  (insignificant slope)
g,  vg  = _f(con_coef_ate), _f(con_var_ate)   # Reg 2 ATE  (highly significant)
 
cov_b1_b2 = _f(exp_covar)   # Cov(exp ATE, exp HTE), loaded from row 4
cov_reg   = 0.0             # cross-model cov (not cached); 0 if models fit separately
 
alpha = 0.10                       # 90% bands, matching the 10% framing
z = norm.ppf(1 - alpha / 2)        # 1.645
 
# moderator grid from the (farm-size-cleaned, balanced) panel
xv = df["w_farm_size_agland"].to_numpy()
xv = xv[np.isfinite(xv)]
xmax = np.quantile(xv, 0.99) * 1.05
xg = np.linspace(0.0, xmax, 400)
 
# Reg 1 conditional effect + pointwise SE (Brambor-Clark-Golder)
mean_size  = df["w_farm_size_agland"].mean()
xc = xg - mean_size
tau1 = b1 + b2 * xc
var1 = vb1 + xc**2 * vb2 + 2.0 * xc * cov_b1_b2
se1  = np.sqrt(np.clip(var1, 0, None))
lo1, hi1 = tau1 - z * se1, tau1 + z * se1
 
# Reg 2 flat effect
tau2 = np.full_like(xc, g)
lo2, hi2 = g - z * np.sqrt(vg), g + z * np.sqrt(vg)
 
# difference tau1(x) - g and its band
delta = tau1 - g
Va = vb1 + vg - 2.0 * cov_reg
Cab = cov_b1_b2
Vb = vb2
var_d = Va + 2.0 * xc * Cab + xc**2 * Vb
se_d  = np.sqrt(np.clip(var_d, 0, None))
lo_d, hi_d = delta - z * se_d, delta + z * se_d
 
#tipping point + Fieller CI
#NOTE: we assume coefficient covariance is zero across the two regressions, which simplifies the math a lot
x_star = (g - b1) / b2 + mean_size
x_positive = np.interp(0.0, lo1, xg)
a, bb = b1 - g, b2
A = bb**2 - z**2 * Vb
B = 2.0 * (a * bb - z**2 * Cab)
C = a**2 - z**2 * Va
disc = B**2 - 4.0 * A * C
print(f"Tipping point  x* = {x_star:.3f} ha")
print(f"Farm effect is statistically positive for x > {x_positive:.3f} ha")
if disc < 0 and A < 0:
    print("Fieller 90% CI: entire real line  -> x* unidentified (band never excludes 0)")
elif A < 0:
    r1, r2 = sorted([(-B - np.sqrt(disc)) / (2*A), (-B + np.sqrt(disc)) / (2*A)])
    print(f"Fieller 90% CI: (-inf, {r1:.3f}] U [{r2:.3f}, +inf)  -> unbounded (slope insignificant)")
else:
    r1, r2 = sorted([(-B - np.sqrt(disc)) / (2*A), (-B + np.sqrt(disc)) / (2*A)])
    print(f"Fieller 90% CI: [{r1:.3f}, {r2:.3f}] ha")
 
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
        if run is not None and (not m or i == len(mask) - 1):
            out.append((run, grid[i])); run = None
    return out
 
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
 
ax1.set_ylim(-.25, .75)
ax1.fill_between(xg, lo1, hi1, color="tab:blue", alpha=0.25, linewidth=0)
ax1.plot(xg, tau1, color="tab:blue", lw=2, label="Effect on farm expenditures")
ax1.fill_between(xg, lo2, hi2, color="tab:orange", alpha=0.25, linewidth=0)
ax1.plot(xg, tau2, color="tab:orange", lw=2, label="Effect on nonfarm expenditures")
if 0 <= x_star <= xmax:
    ax1.axvline(x_star, color="black", ls=":", lw=1.2, label="Cross-over point")
    ax1.annotate(f"{x_star:.2f} ha", xy=(x_star, ax1.get_ylim()[1]),
                 xytext=(4, -4), textcoords="offset points",
                 ha="left", va="top", fontsize=9)
if 0 <= x_positive <= xmax:
    ax1.axvline(x_positive, color="black", ls=":", lw=1.2)
    ax1.annotate(f"{x_positive:.2f} ha", xy=(x_positive, ax1.get_ylim()[1]),
                 xytext=(-36, -14), textcoords="offset points",
                 ha="left", va="top", fontsize=9)
ax1.axhline(0, color="black", lw=0.8)   
ax1.set_ylabel("Effect of loan (log points)")
ax1.set_title("Conditional Loan Effects by Farm Size and the Johnson–Neyman Cross-Over - 90% Bands")
h1, l1 = ax1.get_legend_handles_labels()
h2, l2 = axd.get_legend_handles_labels()
ax1.legend(h1 + h2, l1 + l2, frameon=False, loc="upper right")
ax1.set_zorder(axd.get_zorder() + 1); ax1.patch.set_visible(False)
 
# Panel B: difference + region where the two effects are indistinguishable
ax2.set_ylim(-.25, .75)
ax2.axhline(0, color="gray", ls="--", lw=1, label="No difference")
ax2.fill_between(xg, lo_d, hi_d, color="green", alpha=0.15, linewidth=0)
ax2.plot(xg, delta, color="green", lw=2, label="Difference in effects")
mask = (lo_d <= 0) & (hi_d >= 0)
for s, e in _spans(xg, mask):
    ax2.axvspan(s, e, color="gray", alpha=0.12, linewidth=0)
if 0 <= x_star <= xmax:
    ax2.axvline(x_star, color="black", ls=":", lw=1.2, label="Cross-over point")
ax2.set_xlabel("Farm Size (hectares)")
ax2.set_ylabel("Difference in effects")
ax2.legend(frameon=False, loc="upper right")
ax2.set_xlim(left=0, right=xmax)
 
plt.tight_layout()
# save in the same idiom as the original (new filename so Figure_A3.pdf is untouched)
fig_out = root / "Tables and Figures" / "Figure_tipping_point.pdf"
plt.savefig(fig_out, dpi=600, bbox_inches="tight")
print("saved ->", fig_out)
