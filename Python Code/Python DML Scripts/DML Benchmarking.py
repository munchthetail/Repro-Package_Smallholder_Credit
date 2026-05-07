# DML Identification.py 
# THIS IS THE AVERAGE TREATMENT EFFECT (ATE) ESTIMATION SCRIPT
# NOTE: THIS SCRIPT BY NECCESSITY HAS TO RETRAIN LEARNERS OVER MANY ITERNATIONS AND
#       IS HIGHLY COMPUTATIONALLY INTENSIVE. IT CAN OFTEN TAKE OVER 24 HOURS TO RUN ON 6 CORES
# =============================================================================
# Then sensitivity to OVB script. Runs the partial linear regression model for each
# core outcome variables, dropping different numbers of controls, 
# we do this to estimate the potential impact of OVB proxied by observables 
#
# HOW TO USE:
#   1. Set k_fold_vector, N_REP, N_WORKERS to match the desired specification and hardware limitations.
#      Paper results use K=5, N_REP=30. Start with N_REP=5 to test timing.
#      Determine the number of avialable cores your CPU has
#   2. Set re_estimate_nuisance=False (default) to reuse cached nuisance predictions,
#      or True to force re-fitting from scratch.
#   3. choose which variabels you would like to test in bench_set
#
# PIPELINE STAGES:
#   Stage 1 — Generate master household-level folds (shared across all outcomes)
#   Stage 2 — Estimate loan propensity on full base sample (once, cached)
#   Stage 3 — For each outcome, we loop over estimates using different controls sets
#               recording the impact on learner performance and estimating OVB confidence intervals

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
from sklearn.dummy import DummyRegressor

#custom imports from other scripts in this project
from fold_generator import fold_generator
from helper_functions import translate_folds, align_to_subsample, save_bench_values, load_bench_values, compute_benchmark_cf, safe_drop_label
from nuisance_function_residual_est import estimate_loan_nuisance, estimate_outcome_nuisance
from learners import make_ml_m_loan_clf

# ============================================================
# OUTPUT LOGGING
# ============================================================
#setting paths, root should automatically fill at the base level of the reproduction folder
#if root is not working, then set the root to the base level of the repdoduction of the folder
root       = Path(__file__).resolve().parent.parent.parent
output_dir = root / "Python Code" / "Python Table Landing"
output_dir.mkdir(parents=True, exist_ok=True)
dta_path = root / "Stata Code" / "Stata Data Landing" / "DML Cleaned Data.dta"
cache_dir = output_dir / "nuisance_cache"
script_name = Path(__file__).stem

#setting paths for data and output
dta_path = Path(dta_path)
cache_dir = Path(cache_dir)

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
re_estimate_nuisance = False

#set as True if you want to calculate HTEs
HTE = True
d_cols_vec = ["loan", "loan_x_size"] if HTE else ["loan"]

#these are used throughout the script: treatment, time, and unit column names
d_col, time_col, unit_col = "any_arv_farm_loan", "wave", "hhid"

# ============================================================
# OUTCOME VECTORS
# ============================================================
#these cover the three main outcome vectors
#default for the ATE would be the core_outcomes
core_outcomes      = ["ln_gen_consumption_flag", "ln_total_farm_expense"]

# --- CHOOSE OUTCOMES TO RUN ---
outcome_vars = core_outcomes

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

#benchmarking variables
bench_set = [
    "",
    "head_maritial_status",
    "phone_access",
    "internet_access",
    ["head_maritial_status",
    "FCS_index",
    "probability_moderately_insecure",],
    "FCS_index",
    ["FCS_index",
     "probability_moderately_insecure"],
    "income_shock",
    "price_shock",
    "food_shock",
    ["income_shock",
    "food_shock",
    "price_shock"],
    "head_age",
    "head_sex",
    "member",
    ["head_age",
    "head_sex",
    "member"],
    "w_lvstck_holding_tlu",
    "w_value_crop_production",
    "w_value_assets",
    "w_nonfarm_income",
    ["w_value_crop_production",
    "w_value_assets",
    "w_nonfarm_income"],
    "ag_plot_formal_rights_hh"    
]

# ============================================================
# LOAD DATA
# ============================================================

farm_exp_data = pd.read_stata(dta_path)

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
fold_hhids_by_K = fold_generator(_base_y_strat, _base_groups, k_fold_vector, N_REP)

#============================================================
#STAGE 2A — BASE FRAME FOR LOAN NUISANCE
#============================================================

#looping over benchmark set
for drops in bench_set:
    #reset and drop benchmark variables
    explicit_x_copy = explicit_x.copy()
    explicit_x_copy = [x for x in explicit_x_copy if x not in drops]

    #dropped variables for proper cache of predictions
    bench_drops = "_".join(drops) if isinstance(drops, list) else drops
    
    #number of new controls
    clf = make_ml_m_loan_clf(n_core=len(explicit_x_copy))
    
    #the loan model is fit on the broadest possible clean sample
    #we only drop obs that every outcome's analysis sample is a strict subset, so we can always align loan_hat to it

    #this drop isn't needed for our analysis, but we are keeping it for consistency
    base_frame = farm_exp_data.dropna(subset=[d_col, unit_col, time_col]).copy()

    #impute X variables at the median and add missingness indicator flags
    #this is a pretty common method to address missingness, although other methods could be used
    base_x_cols = explicit_x_copy.copy()
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

    #build CREs
    tv_x_base          = [c for c in base_x_cols if c not in {d_col, time_col, unit_col}]
    tv_x_base_original = [c for c in explicit_x_copy if c not in {d_col, time_col, unit_col}]
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

    loan_hat_by_K, base_keys_by_K = estimate_loan_nuisance(
        X_base, loan_true_base, base_keys,
        fold_hhids_by_K, k_fold_vector, N_REP, N_WORKERS,
        re_estimate=re_estimate_nuisance,
        cache_dir=cache_dir,
        bench_drops=bench_drops,
        clf=clf
    )

# ============================================================
# STAGE 3 — OUTCOME LOOP
# ============================================================
    #this is the heavy work stage if we are running multiple outcome variables
    for y_col in outcome_vars:

        #throws error if outcome is not in the dataset, this should never trigger but just leaving it as defensive code
        if y_col not in farm_exp_data.columns:
            print(f"   WARNING: {y_col} not found in data. Skipping.")
            continue

        #---- DATA CLEANING ----
        #each outcome has its own missing data pattern so we subset fresh each time
        current_x_cols = explicit_x_copy.copy()
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

        # ---- TREATMENT SETUP ----
        #household level clustering and assigning treatment variable
        df_clean["hhid_cluster"] = df_clean[unit_col]  #cluster SE at household level
        cluster_cols = ["hhid_cluster"]
        df_clean["loan"] = df_clean[d_col].astype(float)

        #CRE construction
        #exclude outcome, treatment, id, time, and cluster columns from the time-varying X set
        block     = {y_col, d_col, time_col, unit_col, *cluster_cols}
        tv_x_cols = [c for c in current_x_cols if c not in block]
        tv_x_base_original = [c for c in explicit_x_copy if c not in {d_col, time_col, unit_col}] #placeholder to avoid missingness dummies in CREs
        
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
            cache_dir=cache_dir,
            bench_drops=bench_drops
        )

        # ==========================================
        # INNER LOOP OVER FOLD SPECIFICATIONS
        # ==========================================
        #from this point on the computational load is very light, we just take the predicted 
        #values/probabilities from stage 2 and 3 and plug them into the DML function
        #for treatment effects and canned diagnositic statistics
        for K in k_fold_vector:
            
            # ---- STAGE 3B: ALIGN LOAN HAT TO THIS OUTCOME'S SUBSAMPLE ----
            #aligns the loan predictions with the subseted dataset
            #drops observations and reorders predictions as needed to align with the subset
            loan_hat_aligned = align_to_subsample(
                loan_hat_by_K[K],
                base_keys_by_K[K],
                df_clean[[unit_col, time_col]]
            )
            
            #making an array for HTE farm size residuals
            S_centered = (df_clean[S_col] - df_clean[S_col].mean()).to_numpy()
            loan_x_size_hat_aligned = loan_hat_aligned*S_centered[:,None]
            
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
            #stores sample outcome varaince, residual variances (outcome/treatment), and treatment effects by (benchmark, outcome, fold spec)
            var_y = float(np.var(data_for_dml_plr[y_col].values, ddof=0))
            for d_idx, d_name in enumerate(d_cols_vec):
                theta_hat  = float(np.asarray(plr.coef).reshape(-1)[d_idx]) #treatment effects
                sigma2_hat = float(np.mean(np.asarray(plr.sensitivity_elements["sigma2"])[0, :, d_idx])) #outcome residual variance
                nu2_hat    = float(np.mean(np.asarray(plr.sensitivity_elements["nu2"])[0, :, d_idx])) #treatment residual variance
                print(f"    [{d_name}] theta={theta_hat:.4f}  sigma2={sigma2_hat:.4f}  nu2={nu2_hat:.4f}") #store in a .txt for later
                save_bench_values(K, N_REP, y_col, drops, d_name, theta_hat, sigma2_hat, nu2_hat, var_y, cache_dir=cache_dir)

# ============================================================
# SAVING BENCHMARK DATA TO CSV
# ============================================================
#collects sample outcome varaince, residual variances (outcome/treatment), and treatment effects by (benchmark, outcome, fold spec)
#follows closely from https://docs.doubleml.org/stable/guide/sensitivity.html
ci_rows = []
for K in k_fold_vector:
    for y_col in outcome_vars:
        for d_name in d_cols_vec:

            #grab baseline values where we didn't drop anything
            base = load_bench_values(K, N_REP, y_col, drop="", d_name=d_name, cache_dir=cache_dir)

            for drop in bench_set:
                #loops over all benchmark output and compares it to baseline i.e. base
                short = load_bench_values(K, N_REP, y_col, drop=drop, d_name=d_name, cache_dir=cache_dir)
                cf    = compute_benchmark_cf(base, short)
                product = cf["c_y"] * cf["c_d"] * base["sigma2"] * base["nu2"]
                bias_adv = np.sqrt(product) if product >= 0 else np.nan
                bias_emp = abs(cf["rho"]) * bias_adv if (not np.isnan(cf["rho"]) and not np.isnan(bias_adv)) else np.nan
                ci_rows.append({
                    "outcome":           y_col,
                    "treatment":         d_name,
                    "K":                 K,
                    "dropped":           safe_drop_label(drop),
                    "theta":             base["theta"],
                    "sigma2":            short["sigma2"] if drop != "" else base["sigma2"],
                    "nu2":               short["nu2"]    if drop != "" else base["nu2"],
                    "var_y":             base["var_y"],
                    "R2_long":           cf["r2_long"],
                    "R2_short":          cf["r2_short"],
                    "R2_alpha":          cf["r2_alpha"],
                    "delta_theta":       cf["delta_theta"],
                    "c_y":               cf["c_y"],
                    "c_d":               cf["c_d"],
                    "rho":               cf["rho"],
                    "bound_lower_adv":   base["theta"] - bias_adv,
                    "bound_upper_adv":   base["theta"] + bias_adv,
                    "bound_lower_emp":   base["theta"] - bias_emp,
                    "bound_upper_emp":   base["theta"] + bias_emp,
                })
pd.DataFrame(ci_rows).to_csv(output_dir / f"benchmark_CI_K{k_fold_vector[0]}_R{N_REP}.csv", index=False)