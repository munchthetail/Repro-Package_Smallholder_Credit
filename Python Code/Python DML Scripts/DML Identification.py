# DML Identification.py 
# THIS IS THE AVERAGE TREATMENT EFFECT (ATE) ESTIMATION SCRIPT
# =============================================================================
# Core DML estimation script. Runs the partial linear regression model for each
# outcome variable using nuisance function predictions calculated independently 
# we do this so we can have unique learner ensembles for treatment and outcome to
# maximize predictive performance
# additionally, externalizing the nuisance estimation allows us to parallelize at the 
# rep level and cache predictions to speed up high rep run and reruns sensitivity analyses.
#
# HOW TO USE:
#   1. Set "outcome_vars" to the variables you want to estimate.
#   2. Set k_fold_vector, N_REP, N_WORKERS to match the desired specification and hardware limitations.
#      Paper results use K=5, N_REP=30. Start with N_REP=5 to test timing.
#      Determine the number of avialable cores your CPU has
#   3. Set re_estimate_nuisance=False (default) to reuse cached nuisance predictions,
#      or True to force re-fitting from scratch.
#   4. Choose if you would like heterogenous treatment effect (HTE=True) 
#      or if you would like quartile analysis HTE_GATE=True
#
# PIPELINE STAGES:
#   Stage 1 — Generate master household-level folds (shared across all outcomes)
#   Stage 2 — Estimate loan propensity on full base sample (once, cached)
#   Stage 3 — For each outcome:
#               a. Subset, clean, impute, build CREs
#               b. Estimate outcome learner (cached per outcome)
#               c. Match loan predictions to outcome subsample
#               d. Run DML PLR with both nuisances (plugged in from prior calculations)
#               e. Print estimates and learner diagnostics

#thread limits must come before any numpy/sklearn imports to prevent CPU oversubscription
import os
os.environ["OMP_NUM_THREADS"] = "1"
os.environ["MKL_NUM_THREADS"] = "1"
os.environ["OPENBLAS_NUM_THREADS"] = "1"
os.environ["NUMEXPR_NUM_THREADS"] = "1"

#quite convergence warnings to avoid clogging output (fairly common with regularized linear models)
import warnings
warnings.simplefilter(action='ignore', category=FutureWarning)
warnings.simplefilter(action='ignore', category=DeprecationWarning)

#neccesary imports
import pandas as pd
from pathlib import Path
import numpy as np
from doubleml import DoubleMLPLR
from doubleml.data import DoubleMLClusterData
from sklearn.metrics import r2_score, roc_auc_score, average_precision_score
from sklearn.dummy import DummyRegressor
import sys
import re
from datetime import datetime
import statsmodels.api as sm

#custom imports from other scripts in this project
from fold_generator import fold_generator
from helper_functions import translate_folds, align_to_subsample
from nuisance_function_residual_est import estimate_loan_nuisance, estimate_outcome_nuisance
from learners import make_ml_m_loan_clf

# ============================================================
# OUTPUT LOGGING
# ============================================================
#setting paths, root should automatically fill at the base level of the reproduction folder
#if root is not working, then set the root to the base level of the repdoduction of the folder
root       = Path(__file__).resolve().parent.parent.parent
output_dir = root / "Tables and Figures"
output_dir.mkdir(parents=True, exist_ok=True)
dta_path = root / "Stata Code" / "Stata Data Landing" / "DML Cleaned Data.dta"
cache_dir = output_dir / "nuisance_cache"
script_name = Path(__file__).stem

#setting paths for data and output
dta_path = Path(dta_path)
cache_dir = Path(cache_dir)

#there is a pretty large automatic logging setup
#auto-increment version number so each run creates a new file
#tables are formatted in .txt files in the output directory
pattern = re.compile(rf"{re.escape(script_name)}_v(\d+)\.txt")
existing_versions = []
for f in output_dir.glob(f"{script_name}_v*.txt"):
    m = pattern.match(f.name)
    if m:
        existing_versions.append(int(m.group(1)))
next_version = max(existing_versions, default=0) + 1
timestamp    = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
output_file  = output_dir / f"{script_name}_v{next_version}_{timestamp}.txt"

log_file    = open(output_file, "w", encoding="utf-8")
sys.stdout  = log_file

#we include these sporadically throughout the script, they are helpful for reading results in the output log
print("=" * 80)
print(f"Script: {script_name}  |  Version: v{next_version}  |  Started: {timestamp}")
print("=" * 80, flush=True)

# ============================================================
# CONFIGURATION --- IMPORTANT!!!
# ============================================================
# THIS IS A VERY IMPORTANT STEP, CHOOSE SPECIFICATIONS CAREFULLY BEFORE RUNNING

#fold spec — pass multiple values for sensitivity analysis (e.g. [3, 5, 8]) NOTE: default for the paper is k=5
k_fold_vector = [5]

#number of repetitions NOTE: paper results use N_REP=30; start with 5 for runtime checks
N_REP = 30

#parallel workers, in general the speed of the analysis should grow roughly 
#linearly with the number of works for large rep runs
N_WORKERS = 6

#set True to re-fit all nuisance functions from scratch even if cache files exist (add a lot of time)
re_estimate_nuisance = True

#set as True if you want to calculate HTEs
HTE = True

#for the group average treatment effects (GATE), this is another way of estimating HTE, set GATE=True
#NOTE: it is not neccessary, but should be mutually exclusive with the general HTE flag 
HTE_GATE = True

#these are used throughout the script: treatment, time, and unit column names
d_col, time_col, unit_col = "any_arv_farm_loan", "wave", "hhid"

# ============================================================
# OUTCOME VECTORS
# ============================================================
#these cover the three main outcome vectors
#default for the ATE would be the core_outcomes
farm_exp_vector    = ["ln_total_input_exp", "ln_land_total_exp",
                      "ln_labor_expense_total", "ln_animal_total_exp", "ln_total_fert_kg_ha"]
consumption_vector = ["ln_food_flag", "ln_non_food_gen_consumption"]
core_outcomes      = ["ln_gen_consumption_flag", "ln_total_farm_expense"]

# --- CHOOSE OUTCOMES TO RUN ---
outcome_vars = core_outcomes + farm_exp_vector + consumption_vector 

# ============================================================
# CONTROL VARIABLES
# ============================================================
#these are the X variables fed into both nuisance functions
#NOTE: the first 19 entries (indices 0–18) are the core economic controls
#the polynomial interaction branch in ml_m_loan_clf (learners.py) assumes this count
#if you add or remove variables here, update interaction_indices in learners.py to match
explicit_x = [
    "w_farm_size_agland",               #farm size
    "w_value_crop_production",          #crop output value
    "w_value_assets",                   #household asset value
    "w_nonfarm_income",                 #nonfarm income
    "w_lvstck_holding_tlu",             #livestock holdings (TLU aka tropical livestock units)
    "ag_plot_formal_rights_hh",         #formal land tenure (at least one plot with formal rights)
    "income_shock",                     #income shock index
    "food_shock",                       #food shock index
    "price_shock",                      #price shock index
    "head_maritial_status",             #household head marital status (MARRIED==1)
    "head_age",                         #household head age
    "head_sex",                         #household head sex (MALE==1)
    "member",                           #total household members
    "adult_member",                     #adult household members
    "phone_access",                     #phone access indicator (HAS ANY PHONE==1)
    "internet_access",                  #internet access indicator (HAS ANY INTERNET==1)
    "probability_moderately_insecure",  #FIES probability (moderate food security)
    "FCS_index",                        #food consumption score
    "non_farming_loan",                 #has a non-farming loan (controls for general credit access)
]

#set learner based on length of control vector (used in polynomial L1 logit)
clf = make_ml_m_loan_clf(n_core=len(explicit_x))

# ============================================================
# LOAD DATA
# ============================================================

print(f"\nLoading data from: {dta_path.name}")
farm_exp_data = pd.read_stata(dta_path)
print(f"Loaded {len(farm_exp_data)} observations.", flush=True)

# ============================================================
# STAGE 1 — MASTER FOLD GENERATION
# ============================================================
#folds are defined at the household level before any outcome filtering
#this guarantees both wave observations for a household are always in the same fold (avoids data leak)
#and that every outcome uses exactly the same train/test splits for comparability

#copying data for fold data
_base = farm_exp_data[[unit_col, time_col, d_col]].copy()
#unit_col is household ID
_base_groups   = _base[unit_col].to_numpy()

#due to the rare tretment we stratify by "ever treated" so each fold gets treated observations
_base_y_strat  = _base.groupby(unit_col)[d_col].transform("max").astype(int).to_numpy()

#generate folds for each K and N_REP combination, consistent for each outcome and with seed==42 for reproducibility
print(f"\nGenerating folds: K={k_fold_vector}, N_REP={N_REP}...")
fold_hhids_by_K = fold_generator(_base_y_strat, _base_groups, k_fold_vector, N_REP)
print("Folds generated.", flush=True)

#============================================================
#STAGE 2A — BASE FRAME FOR LOAN NUISANCE
#============================================================
#the loan model is fit on the broadest possible clean sample
#we only drop obs that every outcome's analysis sample is a strict subset, so we can always align loan_hat to it

#this drop isn't needed for our analysis, but we are keeping it for consistency
base_frame = farm_exp_data.dropna(subset=[d_col, unit_col, time_col]).copy()

#impute X variables at the median and add missingness indicator flags
#this is a pretty common method to address missingness, although other methods could be used
base_x_cols = explicit_x.copy()
cols_with_nan_base = [c for c in base_x_cols if base_frame[c].isna().any()] #counting rows with missing values
if cols_with_nan_base: #if there are any rows with missing values loop over them
    for col in cols_with_nan_base: 
        flag_name = f"{col}_missing"
        base_frame[flag_name] = base_frame[col].isna().astype(int) #missing indicator
        base_x_cols.append(flag_name)
        base_frame[col] = base_frame[col].fillna(base_frame[col].median()) #median indicator

#drop households that don't appear in both waves, shouldn't be needed here but left in for consistency
obs_per_hh_base = base_frame.groupby(unit_col)[unit_col].transform("count")
base_frame = base_frame[obs_per_hh_base == 2].copy()

print(f"\nBase frame: {len(base_frame)} obs ({len(base_frame)//2} households)")

#build CREs
tv_x_base          = [c for c in base_x_cols if c not in {d_col, time_col, unit_col}]
tv_x_base_original = [c for c in explicit_x if c not in {d_col, time_col, unit_col}]
wave_dummies_base  = pd.get_dummies(base_frame[time_col], prefix="feT_wave", drop_first=True)
x_cre_base       = base_frame.groupby(unit_col)[tv_x_base_original].transform("mean").add_suffix("_bar")
state_dummies_base = pd.get_dummies(base_frame["state"], prefix="state", drop_first=True)
X_base = pd.concat([base_frame[tv_x_base], x_cre_base, wave_dummies_base, state_dummies_base], axis=1)

#inputs for loan nuisance estimation
base_keys      = base_frame[[unit_col, time_col]].reset_index(drop=True)
loan_true_base = base_frame[d_col].astype(int).to_numpy()

# ============================================================
# STAGE 2B — LOAN NUISANCE ESTIMATION (once, before outcome loop)
# ============================================================
#we estimate the loan nuisance on the full sample to mazimize predictive power
#and use the same predictions for all the outcomes to maintain comparability.
print("\n" + "=" * 70)
print("STAGE 2: Loan nuisance estimation")
print("=" * 70)

loan_hat_by_K, base_keys_by_K = estimate_loan_nuisance(
    X_base, loan_true_base, base_keys,
    fold_hhids_by_K, k_fold_vector, N_REP, N_WORKERS,
    re_estimate=re_estimate_nuisance,
    cache_dir=cache_dir,
    clf=clf
)

# ============================================================
# STAGE 3 — OUTCOME LOOP
# ============================================================
#this is the heavy work stage if we are running multiple outcome variables
for y_col in outcome_vars:
    #again useful for readability in output log
    print(f"\n{'='*70}")
    print(f"OUTCOME: {y_col}")
    print(f"{'='*70}")

    #throws error if outcome is not in the dataset, this should never trigger but just leaving it as defensive code
    if y_col not in farm_exp_data.columns:
        print(f"   WARNING: {y_col} not found in data. Skipping.")
        continue

    #---- DATA CLEANING ----
    #each outcome has its own missing data pattern so we subset fresh each time
    current_x_cols = explicit_x.copy()
    original_obs   = len(farm_exp_data)

    #drop observations missing the outcome value or w_farm_size_agland
    #w_farm_size_agland is required for the heterogeneous treatment effects analysis
    #so we drop it to maintain comparability with HTE but results are similar if we keep those observations
    df_clean = farm_exp_data.dropna(subset=[y_col, "w_farm_size_agland"]).copy()

    #this is greating missingness dummies and imputing at the median level
    #identical to what we did around line 195
    cols_with_nan = [c for c in current_x_cols if df_clean[c].isna().any()]
    if cols_with_nan:
        print(f"   -> Imputing {len(cols_with_nan)} variables with missing values, adding indicator flags...")
        for col in cols_with_nan:
            flag_name = f"{col}_missing"
            df_clean[flag_name] = df_clean[col].isna().astype(int)
            current_x_cols.append(flag_name)
            df_clean[col] = df_clean[col].fillna(df_clean[col].median())

    #keep only households present in BOTH waves, neccessary because of the drop above
    obs_per_hh = df_clean.groupby(unit_col)[unit_col].transform("count")
    df_clean   = df_clean[obs_per_hh == 2].copy()

    #recording output for the log file for readability
    obs_num      = len(df_clean)
    dropped_hhs  = (original_obs - obs_num) / 2
    print(f"   -> {obs_num} obs ({obs_num // 2} households), {int(dropped_hhs)} dropped households")

    # ---- TREATMENT SETUP ----
    #household level clustering and assigning treatment variable
    df_clean["hhid_cluster"] = df_clean[unit_col]  #cluster SE at household level
    cluster_cols = ["hhid_cluster"]
    df_clean["loan"] = df_clean[d_col].astype(float)

    #CRE construction
    #exclude outcome, treatment, id, time, and cluster columns from the time-varying X set
    block     = {y_col, d_col, time_col, unit_col, *cluster_cols}
    tv_x_cols = [c for c in current_x_cols if c not in block]
    tv_x_base_original = [c for c in explicit_x if c not in {d_col, time_col, unit_col}] #placeholder to avoid missingness dummies in CREs
    
    #wave FEs as dummies
    wave_dummies = pd.get_dummies(df_clean[time_col], prefix="feT_wave", drop_first=True)

    #making CRE varables
    x_means_by_unit = df_clean.groupby(unit_col)[tv_x_base_original].transform("mean").add_suffix("_bar")

    #pull it all together: X, CREs, FEs
    X_cre = pd.concat([df_clean[tv_x_cols], x_means_by_unit, wave_dummies], axis=1)
    state_dummies = pd.get_dummies(df_clean["state"], prefix="state", drop_first=True)
    #lambda function just drops duplicate columns that might have been generated, this really shuoldn't be a problem but is defensive
    X_cre = pd.concat([X_cre, state_dummies], axis=1).loc[:, lambda d: ~d.columns.duplicated()].copy()
    X_cre_cols = list(X_cre.columns)

    #HTE loan x farm size interaction
    S_col = "w_farm_size_agland"
    df_clean["S_centered"]  = df_clean[S_col]-df_clean[S_col].mean()
    df_clean["loan_x_size"] = df_clean["loan"]*df_clean["S_centered"]
    df_clean = df_clean.drop(columns=["S_centered"])
    
    #assemble the full DML dataset (outcome + treatment + ids + X) (conditional on ATE vs HTE)
    if HTE == True:
        data_for_dml_plr = pd.concat(
            [df_clean[[y_col, time_col, unit_col, "loan", "loan_x_size", "hhid_cluster"]].reset_index(drop=True),
            X_cre.reset_index(drop=True)],
            axis=1
        )
    else:
        data_for_dml_plr = pd.concat(
            [df_clean[[y_col, time_col, unit_col, "loan", "hhid_cluster"]].reset_index(drop=True),
            X_cre.reset_index(drop=True)],
            axis=1
        )
    
    # ---- STAGE 3A: OUTCOME NUISANCE ESTIMATION ----
    #estimate outcome learner for the specific outcome subsample
    #outcome_keys is used to match predictions to original values for residual estimation
    outcome_keys = df_clean[[unit_col, time_col]].reset_index(drop=True)
    y_outcome    = df_clean[y_col].to_numpy()

    #outputs outcome predictions 
    outcome_hat_by_K = estimate_outcome_nuisance(
        X_cre, y_outcome, outcome_keys,
        fold_hhids_by_K, k_fold_vector, N_REP, N_WORKERS,
        y_col=y_col,
        re_estimate=re_estimate_nuisance,
        cache_dir=cache_dir
    )

    # ==========================================
    # INNER LOOP OVER FOLD SPECIFICATIONS
    # ==========================================
    #from this point on the computational load is very light, we just take the predicted 
    #values/probabilities from stage 2 and 3 and plug them into the DML function
    #for treatment effects and canned diagnositic statistics
    for K in k_fold_vector:
        
        #header for the given outcome, fold specification, rep specification, and observations
        print(f"\n{'*'*70}")
        print(f"OUTCOME: {y_col} | K={K} | N_REP={N_REP} | N={obs_num}")
        print(f"{'*'*70}")

        # ---- STAGE 3B: ALIGN LOAN HAT TO THIS OUTCOME'S SUBSAMPLE ----
        #aligns the loan predictions with the subseted dataset
        #drops observations and reorders predictions as needed to align with the subset
        loan_hat_aligned = align_to_subsample(
            loan_hat_by_K[K],
            base_keys_by_K[K],
            df_clean[[unit_col, time_col]]
        )
        
        #making an array for HTE farm size residuals
        col_farm_size = (df_clean[S_col]-df_clean[S_col].mean()).to_numpy()
        loan_x_size_hat_aligned = loan_hat_aligned*col_farm_size[:, None]
        
        #vector of treatment variable(s)
        if HTE == True:
            d_cols_vec = ["loan", "loan_x_size"]
        else:
            d_cols_vec = ["loan"]

        
        # ---- BUILD SMPLS FOR DOUBLEML ----
        #translate households in subsample to the master hhid folds by rep and fold specification
        hh_obs = data_for_dml_plr[unit_col].to_numpy()
        smpls  = translate_folds(fold_hhids_by_K[K], hh_obs, N_REP)

        #build cluster-level fold info required by DoubleMLClusterData
        #DoubleML needs to know which households (clusters) are in each train/test split
        smpls_cluster = []
        for rep_folds in smpls: #loop through folds by rep
            rep_cluster = []
            for tr, te in rep_folds:
                rep_cluster.append([ #creates a list of household id's to use for clustering based on training or testing fold assignment
                    [np.unique(data_for_dml_plr.loc[tr, "hhid_cluster"])],
                    [np.unique(data_for_dml_plr.loc[te, "hhid_cluster"])]
                ])
            smpls_cluster.append(rep_cluster)

        # ---- DOUBLEML SETUP ----
        #both ml_l and ml_m are overridden by external predictions
        #DummyRegressor is a required placeholder, it is never actually fitted
        dml_data = DoubleMLClusterData(
            data_for_dml_plr,
            y_col=y_col,
            d_cols=d_cols_vec,
            cluster_cols=cluster_cols,
            x_cols=X_cre_cols,
            use_other_treat_as_covariate=False
        )

        #NOTE: DoubleMLPLR has a parallel argument on the fold level, 
            #we instead parallelize at the rep level
        plr = DoubleMLPLR(
            dml_data,
            ml_l=DummyRegressor(strategy="mean"),  #placeholder for external predictions
            ml_m=DummyRegressor(strategy="mean"),  #placeholder for external predictions
            n_folds=K,
            n_rep=N_REP,
            score="partialling out",
            draw_sample_splitting=False  #use the master folds manually below
        )

        #using the pre-built fold assignments
        plr.set_sample_splitting(smpls, smpls_cluster)

        # ---- EXTERNAL PREDICTIONS ----
        #pass both nuisance predictions into DoubleML directly
        #DoubleML computes residuals
        if HTE == True:
            external_predictions = {
                "loan": {
                    "ml_l": outcome_hat_by_K[K],  #E[Y|X] — (n_outcome, N_REP)
                    "ml_m": loan_hat_aligned,      #E[loan|X] — (n_outcome, N_REP)
                },
                "loan_x_size": {
                    "ml_l": outcome_hat_by_K[K],
                    "ml_m": loan_x_size_hat_aligned}  #interaction term
            }
        else:
            external_predictions = {
                "loan": {
                    "ml_l": outcome_hat_by_K[K],  #E[Y|X] — (n_outcome, N_REP)
                    "ml_m": loan_hat_aligned,      #E[loan|X] — (n_outcome, N_REP)
                }
            }
        #this is the actual fit function
        #since the learners have already been estimated this 
        #just computes residuals and runs the final OLS stage
        plr.fit(store_predictions=True, external_predictions=external_predictions)

        # ---- OUTPUT: MAIN RESULTS ----
        #prints OLS output into the log
        print("\n>>> DML Estimates:")
        print(plr.summary)

        #prints GATE if the option is collected
        #the canned GATE function from DoubleML doesn't allow rep>1
        #so we have to follow a more utilitarian approach but due to storing predictions
        #prior to fitting, this is not computationally intensive
        if HTE_GATE == True:
            df_clean["farm_size_quartile"] = pd.qcut(df_clean["w_farm_size_agland"], q=4, labels=["Q1","Q2","Q3","Q4"])
    
            #align quartile to data_for_dml_plr rows
            quartile_aligned = df_clean["farm_size_quartile"].reset_index(drop=True).values
            
            y_true = data_for_dml_plr[y_col].values
            d_true = data_for_dml_plr["loan"].values.astype(float)
            
            print("\n>>> GATEs by Farm Size Quartile:")
            for size_g in ["Q1", "Q2", "Q3", "Q4"]:
                #mask to identify quartiles
                mask = (quartile_aligned == size_g)
                
                #number of treated in each Q                
                n_treated = int(d_true[mask].sum())
                n_total   = int(mask.sum())

                gate_reps, se_reps = [], []
                for rep in range(N_REP):
                    #manually compute residuals then run OLS
                    y_resid = y_true - outcome_hat_by_K[K][:, rep]
                    d_resid = d_true - loan_hat_aligned[:, rep]
                    y_g, d_g = y_resid[mask], sm.add_constant(d_resid[mask])
                    ols = sm.OLS(y_g, d_g).fit(cov_type="cluster", cov_kwds={"groups": data_for_dml_plr["hhid_cluster"].values[mask]})
                    gate_reps.append(ols.params[1])   #coefficient on D_tilde
                    se_reps.append(ols.bse[1])

                #simple average over each rep
                gate   = np.mean(gate_reps)
                se     = np.mean(se_reps)        
                tstat  = gate / se
                print(f"  {size_g}: coef={gate:.4f}  SE={se:.4f}  t={tstat:.2f}  Treated={n_treated}  Total={n_total}", flush=True)
            
        
        # ---- OUTPUT: LEARNER DIAGNOSTICS ----
        #prints out diagnostic statistics into output log
        print("\n>>> Learner Performance:")

        #R^2
        y_true      = data_for_dml_plr[y_col].values
        y_pred_avg  = outcome_hat_by_K[K].mean(axis=1)
        print(f"    Outcome  R2  (Y ~ X):    {r2_score(y_true, y_pred_avg):.4f}")

        d_true      = data_for_dml_plr["loan"].values.astype(int)
        d_pred_avg  = loan_hat_aligned.mean(axis=1)
        print(f"    Treatment R2  (D ~ X):   {r2_score(d_true, d_pred_avg):.4f}")
        
        #AUC/AP
        print(f"    Treatment AUC (D ~ X):   {roc_auc_score(d_true, d_pred_avg):.4f}")
        print(f"    Treatment AP  (D ~ X):   {average_precision_score(d_true, d_pred_avg):.4f}")
    
        print(flush=True)

# ============================================================
# CLOSE LOG
# ============================================================
print("\n" + "=" * 80)
print("Run complete.")
print("=" * 80)

sys.stdout.flush()
log_file.close()
sys.stdout = sys.__stdout__
print(f"Output saved to:\n{output_file}")
