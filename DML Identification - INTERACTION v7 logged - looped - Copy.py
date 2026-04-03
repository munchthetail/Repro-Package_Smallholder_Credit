# Will Hankins
import os
os.environ["OMP_NUM_THREADS"] = "1"
os.environ["MKL_NUM_THREADS"] = "1"
os.environ["OPENBLAS_NUM_THREADS"] = "1"
os.environ["NUMEXPR_NUM_THREADS"] = "1"


import warnings
# Suppress specific FutureWarnings from sklearn/DoubleML
warnings.simplefilter(action='ignore', category=FutureWarning)
# Suppress DeprecationWarnings
warnings.simplefilter(action='ignore', category=DeprecationWarning)

import pandas as pd
from pathlib import Path
import numpy as np
from doubleml import DoubleMLPLR
from doubleml.data import DoubleMLClusterData
from sklearn.linear_model import LassoCV, LogisticRegression, LogisticRegressionCV, ElasticNetCV, RidgeCV, ElasticNet, Ridge
from sklearn.ensemble import RandomForestRegressor, StackingRegressor, StackingClassifier, HistGradientBoostingClassifier, HistGradientBoostingRegressor, VotingClassifier
from sklearn.pipeline import make_pipeline
from sklearn.impute import SimpleImputer
from sklearn.preprocessing import StandardScaler
from sklearn.model_selection import StratifiedGroupKFold
from sklearn.metrics import r2_score, roc_auc_score, average_precision_score, mean_squared_error
from sklearn.base import clone
from sklearn.dummy import DummyRegressor
from sklearn.preprocessing import PolynomialFeatures, FunctionTransformer
from sklearn.feature_selection import SelectKBest, f_classif, VarianceThreshold
from sklearn.compose import ColumnTransformer
from sklearn.neural_network import MLPRegressor
from sklearn.kernel_approximation import Nystroem
from joblib import Parallel, delayed

import sys
from datetime import datetime
import re

# ================================
# OUTPUT LOGGING SETUP
# ================================

OUTPUT_DIR = Path(r"C:\Users\Will\OneDrive - The Ohio State University\RA\Output\Prelim")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# Get current script name
try:
    script_name = Path(__file__).stem
except NameError:
    script_name = "interactive_session"

# Find existing versions
pattern = re.compile(rf"{re.escape(script_name)}_v(\d+)\.txt")
existing_versions = []

for f in OUTPUT_DIR.glob(f"{script_name}_v*.txt"):
    m = pattern.match(f.name)
    if m:
        existing_versions.append(int(m.group(1)))

next_version = max(existing_versions, default=0) + 1

# Optional timestamp (nice for long runs)
timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")

output_file = OUTPUT_DIR / f"{script_name}_v{next_version}_{timestamp}.txt"

# Redirect stdout
log_file = open(output_file, "w", encoding="utf-8")
sys.stdout = log_file

print("=" * 80)
print(f"Script: {script_name}")
print(f"Version: v{next_version}")
print(f"Started: {timestamp}")
print("=" * 80, flush=True)

#helper for treatment learners
def _fit_pred_one_fold(base_estimator, Xv, yv, tr_idx, te_idx, proba):
    est = clone(base_estimator)
    est.fit(Xv[tr_idx], yv[tr_idx])
    if proba:
        pred = est.predict_proba(Xv[te_idx])[:, 1]
    else:
        pred = est.predict(Xv[te_idx])
    return te_idx, pred

def crossfit_oof_preds(estimator, X, y, smpls, proba=False, n_jobs=1, backend="threading"):
    """
    OOF preds aligned with DoubleML's `smpls`.
    Returns (n_obs, n_rep).
    """
    Xv = X.to_numpy() if hasattr(X, "to_numpy") else np.asarray(X)
    yv = np.asarray(y)

    n_obs = Xv.shape[0]
    n_rep = len(smpls)
    out = np.full((n_obs, n_rep), np.nan, dtype=float)

    for r, rep_folds in enumerate(smpls):
        results = Parallel(n_jobs=n_jobs, backend=backend)(
            delayed(_fit_pred_one_fold)(estimator, Xv, yv, tr, te, proba)
            for tr, te in rep_folds
        )
        for te_idx, pred in results:
            out[te_idx, r] = pred

    if np.isnan(out).any():
        raise RuntimeError("OOF preds contain NaNs; check fold coverage.")
    return out


# --- HELPER FOR DIAGNOSTICS ---
def get_flat_pred(pred_data, d_index=None):
    """Handles DoubleML 3D prediction arrays (Obs, Reps, Treatments)"""
    arr = np.array(pred_data)
    if arr.ndim == 3:
        if d_index is not None:
            return arr[:, :, d_index].mean(axis=1)
        return arr[:, :, 0].mean(axis=1)
    if arr.ndim == 2:
        return arr.mean(axis=1)
    return arr

# for keeping vlaues in the nuisance function
def drop_first_19_cols(X):
    # This removes the first 19 columns (the linear terms) from the matrix
    # leaving only the interactions and higher-order terms.
    return X[:, 19:]

# --- CONFIGURATION ---
dta_path = Path("C:/Users/Will/OneDrive - The Ohio State University/RA/Data/DML Cleaned Data.dta")

farm_exp_vector = ["ln_total_farm_expense", "ln_total_input_exp", "ln_land_total_exp", "ln_labor_expense_total", "ln_animal_total_exp"]

consumption_vector = ["ln_gen_consumption_flag", "ln_food_flag", "ln_non_food_gen_consumption"]

input_vector = ["ln_seed_exp", "ln_fertilizer_exp", "ln_pecticide_exp", "ln_fert_pest_mach_tran_exp", "ln_fert_pest_total_exp", "ln_non_seed_total_input_exp"] # only 50 observations "ln_machine_exp", 

input_use_vector = ["ln_total_fert_kg_ha", "ln_w_pest_rate", "ln_w_org_fert_rate", "ln_w_labor_hired_HA"]

food_seasons = ["ln_harvest_food_flag", "ln_planting_food_flag"]

outcome_vars = ["ln_gen_consumption_flag"] #,"ln_total_farm_expense"] #consumption_vector + farm_exp_vector + input_use_vector + input_vector #+ food_seasons

explicit_x = [
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

# Learners
# otucome learners
ml_l = make_pipeline(
    #SimpleImputer(strategy="median", add_indicator=True),
    StandardScaler(),
    StackingRegressor(
        estimators=[
            ("enet", ElasticNet(
                alpha=0.01,       # FIXED penalty strength (Lower = less regularization)
                l1_ratio=0.5,    # FIXED mix (0.5 = Half Lasso, Half Ridge)
                random_state=42, 
                max_iter=5000
            )),
            ("rf",    RandomForestRegressor(n_estimators=1000,
                                            max_features="sqrt",
                                            min_samples_leaf=5,
                                            n_jobs=1, 
                                            random_state=42)),
            ("hist_gbr_slow", HistGradientBoostingRegressor(
                max_iter=3000,        # INCREASED from 550
                learning_rate=0.005,  # DECREASED from 0.01 (slower = better)
                max_depth=8,          # Deeper trees to catch complex interactions
                min_samples_leaf=15,
                l2_regularization=0.1,# Slight regularization to prevent overfitting
                random_state=42
            )),
        ],
        final_estimator=RidgeCV(),
        n_jobs=1
    )
)

# treatment learners --- GBR for the binary, RF and lasso 
# --- Classifier for loan: P(loan=1|X) ---
# will be passed through linearly.
interaction_indices = list(range(19))

ml_m_loan_clf = make_pipeline(
    SimpleImputer(strategy="median", add_indicator=True),
    StandardScaler(),
    StackingClassifier( # CHANGED: From Single Classifier to Stacking
        estimators=[
            ("logit_poly", make_pipeline(
                SimpleImputer(strategy="median"), 
                
                # --- THE SPLIT STRATEGY ---
                ColumnTransformer(
                    transformers=[
                        # BRANCH A: GUARANTEED ORIGINALS
                        # Always keep the 19 core economic vars linear and un-dropped.
                        ("originals", "passthrough", interaction_indices),
                        
                        # BRANCH B: SELECTED INTERACTIONS
                        # Generate 3rd degree polys, drop the linear copies, keep best 20.
                        ("poly_select", make_pipeline(
                            # Generate everything (Linear + Interactions + Squares + Cubes)
                            PolynomialFeatures(degree=3, include_bias=False, interaction_only=False),
                            
                            # CRITICAL STEP: Drop the first 19 linear columns so we don't duplicate Branch A
                            FunctionTransformer(drop_first_19_cols, validate=False),
                            
                            # Scale and Select from the remaining pool (Interactions/Squares)
                            StandardScaler(),
                            SelectKBest(f_classif, k=20) 
                        ), interaction_indices),
                        
                        # BRANCH C: CONTROLS (State Fixed Effects, Flags, etc.)
                        # Keep everything else (Index 19+) safely passed through.
                        ("pass", "passthrough", slice(19, None)) 
                    ]
                ),
                # -----------------------------

                VarianceThreshold(),
                StandardScaler(),
                
                LogisticRegressionCV(
                    penalty='l1', 
                    solver='liblinear',
                    class_weight='balanced',
                    scoring='roc_auc',
                    Cs=10,            
                    cv=2, 
                    tol=0.01,        # Loose tolerance for speed
                    max_iter=10000,   
                    n_jobs=1,        
                    random_state=42
                )
            )),
            ("hist_gbr", HistGradientBoostingClassifier(
                max_iter=3000,
                learning_rate=0.005,
                # CHANGE 1: Enable Balanced Weights (Standard GBM can't do this easily)
                class_weight='balanced', 
                # CHANGE 2: Grow "Best-First" trees, not fixed depth
                max_depth=None,          
                max_leaf_nodes=15,       # Allows deep, targeted branches for rare events
                # CHANGE 3: Allow smaller leaves to catch rare loans
                min_samples_leaf=10,                     
                l2_regularization=0.1,
                random_state=42
            ))
        ],
        final_estimator=LogisticRegression(class_weight=None),
        stack_method='predict_proba',
        cv=2,
        n_jobs=1
    )
)

# Load Data
farm_exp_data = pd.read_stata(dta_path)
X_cols = explicit_x 
k_fold_vector = [5] #[3,5,8]
N_REP = 1
N_WORKERS = 6
d_col, time_col, unit_col = "any_arv_farm_loan", "wave", "hhid"

# ============================================================
# MASTER FOLDS (HHID-level, outcome-agnostic)
#   - Ensures both wave observations for a household stay together
#   - Same household fold assignment used for every outcome
# ============================================================
d_col_master, time_col_master, unit_col_master = "any_arv_farm_loan", "wave", "hhid"

# Base frame for defining folds: NO Y needed
_base = farm_exp_data[[unit_col_master, time_col_master, d_col_master]].copy()

# Keep only households that appear twice (your 2-wave panel)
_base = _base[_base.groupby(unit_col_master)[unit_col_master].transform("count") == 2].copy()

_base = _base.dropna(subset=[unit_col_master, time_col_master, d_col_master]).copy()

_base_groups = _base[unit_col_master].to_numpy()
# Stratify households by "ever treated" (max loan across the two waves)
_base_y_strat = _base.groupby(unit_col_master)[d_col_master].transform("max").astype(int).to_numpy()

# fold_hhids_by_K[K][rep][k] = np.array of HHIDs in test fold k for repetition rep
fold_hhids_by_K = {}

for K in k_fold_vector:
    reps = []
    for rep in range(N_REP):
        sgkf = StratifiedGroupKFold(n_splits=K, shuffle=True, random_state=42 + rep)
        fold_list = []
        for _, te in sgkf.split(np.zeros(len(_base_y_strat)), _base_y_strat, _base_groups):
            fold_list.append(np.unique(_base_groups[te]))  # HHIDs in fold k
        reps.append(fold_list)
    fold_hhids_by_K[K] = reps


# ==========================================
# MAIN LOOP
# ==========================================
for y_col in outcome_vars:
    print(f"\n{'='*70}")
    print(f"OUTCOME: {y_col}")
    print(f"{'='*70}")

    if y_col not in farm_exp_data.columns:
        continue
    
    #rename to make sure we don't change anything
    current_x_cols = explicit_x.copy()
    
    #data cleaning dropping observations
    original_obs = obs_num = len(farm_exp_data)
    needed = [y_col] #, "w_farm_size_agland"
    df_clean = farm_exp_data.dropna(subset=needed).copy()
    
    # adding indicators for imputed variables
    cols_with_nan = [c for c in current_x_cols if df_clean[c].isna().any()]

    if cols_with_nan:
        print(f"   -> Found missing data in {len(cols_with_nan)} variables. Imputing & Flagging...")
        
        for col in cols_with_nan:
            # A. Create the Missing Indicator (1 if missing, 0 otherwise)
            flag_name = f"{col}_missing"
            df_clean[flag_name] = df_clean[col].isna().astype(int)
            
            # B. Add this new flag to the control list so DoubleML uses it
            current_x_cols.append(flag_name)
            
            # C. Fill the original missing value with the median
            median_val = df_clean[col].median()
            df_clean[col] = df_clean[col].fillna(median_val)
    
    #removing households with only one observation    
    obs_per_hh = df_clean.groupby(unit_col)[unit_col].transform("count")
    df_clean = df_clean[obs_per_hh == 2].copy()
    
    obs_num = len(df_clean)
    droped_hhs = (original_obs - obs_num)/2
    print(f"   -> Observations after balancing: {len(df_clean)} ({len(df_clean)//2} households), {droped_hhs} Dropped Households")
    
    
    df_clean["hhid_cluster"] = df_clean["hhid"]
    cluster_cols = ["hhid_cluster"]
    block = {y_col, d_col, time_col, unit_col, *cluster_cols}
    tv_x_cols = [c for c in current_x_cols if c not in block]
    df_clean["loan"] = df_clean[d_col].astype(float)
    
    # ---- Treatments & interaction (center S on analysis sample) ----
    S_col = "w_farm_size_agland"
    df_clean["S_centered"] = df_clean[S_col] - df_clean[S_col].mean()
    
    df_clean["loan"]         = df_clean[d_col].astype(float)  # 0/1 as float
    df_clean["loan_x_size"]  = df_clean["loan"] * df_clean["S_centered"]
    d_cols_vec = ["loan" ]#, "loan_x_size"
    
    # FE / CRE
    wave_dummies = pd.get_dummies(df_clean[time_col], prefix="feT_wave", drop_first=True)
    x_means_by_unit = df_clean.groupby(unit_col)[tv_x_cols].transform("mean").add_suffix("_bar")
    
    X_cre = pd.concat([df_clean[tv_x_cols], x_means_by_unit, wave_dummies], axis=1)
    state_dummies = pd.get_dummies(df_clean["state"], prefix="state", drop_first=True)
    X_cre = pd.concat([X_cre, state_dummies], axis=1).loc[:, lambda d: ~d.columns.duplicated()].copy()
    X_cre_cols = list(X_cre.columns)

    data_for_dml_plr = pd.concat([df_clean[[y_col, time_col, unit_col, "loan" , "hhid_cluster"]].reset_index(drop=True), #, "loan_x_size"
                                  X_cre.reset_index(drop=True)], axis=1)
    
    # Folds
    hh_groups_obs = data_for_dml_plr[unit_col].to_numpy()
    
    for K in k_fold_vector:
        
        dml_workers = min(N_WORKERS, K)
        
        print(f"\n{'*'*70}")
        print(f"OUTCOME: {y_col} --- Folds: {K} --- n_reps: {N_REP} --- Observations: {obs_num}")
        print(f"{'*'*70}")
               
        # DoubleML
        dml_data = DoubleMLClusterData(data_for_dml_plr, 
                                       y_col=y_col, 
                                       d_cols=d_cols_vec, 
                                       cluster_cols=cluster_cols, 
                                       x_cols=X_cre_cols,
                                       use_other_treat_as_covariate=False)
        
        plr = DoubleMLPLR(dml_data, 
                          ml_l=ml_l, 
                          ml_m=DummyRegressor(strategy="mean"), 
                          n_folds=K, 
                          n_rep=N_REP, 
                          score="partialling out",
                          draw_sample_splitting=False)
    
        # loanding sample splits
        # Sample Splitting (subset MASTER folds to this outcome's sample)
        smpls, smpls_cluster = [], []
        
        hh = hh_groups_obs  # array of household ids aligned to current data_for_dml_plr rows
        fold_hhids_rep = fold_hhids_by_K[K]  # [rep][fold] -> test HHIDs
        
        for rep in range(plr.n_rep):
            folds_rep = []
            folds_cluster_rep = []
        
            for k in range(K):
                te_mask = np.isin(hh, fold_hhids_rep[rep][k])
                te = np.where(te_mask)[0].astype(int)
                tr = np.where(~te_mask)[0].astype(int)
        
                # If this triggers, reduce K (e.g., drop 8 for that outcome)
                if te.size == 0 or tr.size == 0:
                    raise RuntimeError(
                        f"Empty train/test fold after outcome subsetting: outcome={y_col}, K={K}, rep={rep}, fold={k}. "
                        f"Try smaller K."
                    )
        
                folds_rep.append((tr, te))
                folds_cluster_rep.append([
                    [np.unique(data_for_dml_plr.loc[tr, "hhid_cluster"])],
                    [np.unique(data_for_dml_plr.loc[te, "hhid_cluster"])]
                ])
        
            smpls.append(folds_rep)
            smpls_cluster.append(folds_cluster_rep)
        
        plr.set_sample_splitting(smpls, smpls_cluster)
        
                
        # getting values for treatment estimates
        # --- external nuisance predictions for ml_m (treatment models) ---
        X_mat = data_for_dml_plr[X_cre_cols]
        loan_true = data_for_dml_plr["loan"].astype(int).to_numpy()
        
        # 1) Cross-fitted propensity score for loan
        
        #basically, this makes sure the loan nuisance learner always use the full population for the best estimates, 
        #then uses that estimate consistently across all other DML functions
        if y_col == "ln_gen_consumption_flag":
            loan_hat = crossfit_oof_preds(ml_m_loan_clf, 
                                          X_mat, 
                                          loan_true, 
                                          smpls, 
                                          proba=True,
                                          n_jobs=dml_workers, 
                                          backend="loky")
            
            np.save(fr"C:/Users/Will/OneDrive - The Ohio State University/RA/Data/loan_hat_oof_fold{K}_Rep{N_REP}_temp.npy", loan_hat)
            
            df_clean[["hhid", "wave"]].reset_index(drop=True).to_parquet(
                fr"C:/Users/Will/OneDrive - The Ohio State University/RA/Data/loan_hat_oof_keys_fold{K}_Rep{N_REP}_temp.parquet",
                index=False
            )
        else:
            
            loan_hat_oof = np.load(fr"C:/Users/Will/OneDrive - The Ohio State University/RA/Data/loan_hat_oof_fold{K}_Rep{N_REP}_temp.npy")
            keys_base = pd.read_parquet(fr"C:/Users/Will/OneDrive - The Ohio State University/RA/Data/loan_hat_oof_keys_fold{K}_Rep{N_REP}_temp.parquet")   
            
            # Build mapping from (hhid, wave) -> row position in base loan_hat_oof
            base_idx = pd.MultiIndex.from_frame(keys_base[["hhid", "wave"]])
            pos = pd.Series(np.arange(len(keys_base)), index=base_idx)
        
            cur_idx = pd.MultiIndex.from_frame(df_clean[["hhid", "wave"]])
            row_pos = pos.reindex(cur_idx)
        
            if row_pos.isna().any():
                raise ValueError("Some (hhid, wave) in df_clean are not found in saved loan_hat_oof keys.")
        
            loan_hat = loan_hat_oof[row_pos.astype(int).to_numpy(), :]
            
            assert loan_hat.shape[0] == len(df_clean)

        # 2) Cross-fitted E[loan_x_size|X] = S_centered(X) * E[loan|X]
        #    Recreate S_centered with the SAME mean used in df_clean construction.
        S_mean = df_clean[S_col].mean()
        S_centered_vec = (data_for_dml_plr[S_col].to_numpy() - S_mean).reshape(-1, 1)
        loan_x_size_hat = loan_hat * S_centered_vec   # (n_obs, n_rep)
        
        external_predictions = {
            "loan": {"ml_m": loan_hat}#,
            #"loan_x_size": {"ml_m": loan_x_size_hat},
        }
        
        # Fit
        plr.fit(n_jobs_cv=dml_workers, 
                store_predictions=True, 
                external_predictions=external_predictions)
        
        # --- OUTPUT 1: MAIN COEFFICIENTS ---
        print(plr.summary)
    
        # --- OUTPUT 2: LEARNER PERFORMANCE ---
        
        print("\n>>> Learner Performance:")
        preds = plr.predictions
        
        # Outcome (continuous) diagnostics
        y_true = data_for_dml_plr[y_col].values.ravel()
        y_pred = get_flat_pred(preds['ml_l'])
        print(f"    Outcome Learner R2 (Y ~ X):        {r2_score(y_true, y_pred):.4f}")
        
        # Treatment diagnostics
        for i, d_name in enumerate(d_cols_vec):
            d_true = data_for_dml_plr[d_name].values.ravel()
            d_pred = get_flat_pred(preds['ml_m'], d_index=i)
        
            # Keep your existing R2 for all treatments (works fine for continuous; for binary it's less informative)
            print(f"    Treatment Learner R2 ({d_name} ~ X): {r2_score(d_true, d_pred):.4f}")
        
            # Extra diagnostics by treatment type
            # 1) Binary loan: AUC + Average Precision (AP)
            if d_name == "loan" or set(np.unique(d_true[~np.isnan(d_true)])).issubset({0, 1}):
                try:
                    auc = roc_auc_score(d_true, d_pred)  # d_pred can be any score; doesn't need to be in [0,1]
                    ap  = average_precision_score(d_true, d_pred)
                    print(f"        AUC (loan ~ X):                 {auc:.4f}")
                    print(f"        AP  (loan ~ X):                 {ap:.4f}")
                except ValueError as e:
                    # happens if d_true has only one class
                    print(f"        AUC/AP not defined: {e}")
        
            # 2) Interaction / semi-continuous: RMSE (and optional RMSE among treated)
            if d_name == "loan_x_size":
                rmse_all = np.sqrt(mean_squared_error(d_true, d_pred))
                print(f"        RMSE (loan_x_size ~ X):         {rmse_all:.4f}")
        
                # Optional but very informative: performance among treated only (loan==1)
                if "loan" in data_for_dml_plr.columns:
                    mask_treated = data_for_dml_plr["loan"].values.ravel() == 1
                    if mask_treated.sum() > 5:
                        rmse_tr = np.sqrt(mean_squared_error(d_true[mask_treated], d_pred[mask_treated]))
                        r2_tr   = r2_score(d_true[mask_treated], d_pred[mask_treated])
                        print(f"        Treated-only RMSE:              {rmse_tr:.4f}")
                        print(f"        Treated-only R2:                {r2_tr:.4f}")
                        
        # --- OUTPUT 3: ROBUSTNESS ---
        print("\n>>> Sensitivity Analysis:")
        try:
            plr.sensitivity_analysis(cf_y=0.04, cf_d=0.03, null_hypothesis=0.0)
            print(plr.sensitivity_summary)
    
        except Exception as e:
            print(f"    Sensitivity analysis skipped (Error: {e})")
            
            


print("=" * 80)
print("Run completed.")
print("=" * 80)

sys.stdout.flush()
log_file.close()
sys.stdout = sys.__stdout__

print(f"Output saved to:\n{output_file}")