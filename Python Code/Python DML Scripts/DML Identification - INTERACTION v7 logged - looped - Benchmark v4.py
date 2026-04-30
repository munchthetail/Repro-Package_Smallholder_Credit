# -*- coding: utf-8 -*-
"""
Created on Sat Mar 14 16:08:48 2026

@author: Will
"""

# Will Hankins
import os
os.environ["OMP_NUM_THREADS"] = "1"
os.environ["MKL_NUM_THREADS"] = "1"
os.environ["OPENBLAS_NUM_THREADS"] = "1"
os.environ["NUMEXPR_NUM_THREADS"] = "1"

import pandas as pd
from pathlib import Path
import numpy as np
from doubleml import DoubleMLPLR
from doubleml.data import DoubleMLClusterData
from sklearn.linear_model import LogisticRegression, LogisticRegressionCV, RidgeCV, ElasticNet
from sklearn.ensemble import RandomForestRegressor, StackingRegressor, StackingClassifier, HistGradientBoostingClassifier, HistGradientBoostingRegressor
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
from joblib import Parallel, delayed

import sys, re, time
from datetime import datetime


# ================================
# SMALL HELPERS
# ================================

def fmt(seconds):
    seconds = int(seconds)
    h, rem = divmod(seconds, 3600)
    m, s = divmod(rem, 60)
    return f"{h:02d}:{m:02d}:{s:02d}"

def make_drop_first_n_cols(n):
    def _drop(X):
        return X[:, n:]
    return _drop

def normalize_drop(drop):
    """Normalize drop to a list: '' → [], 'x' → ['x'], ['x','y'] → ['x','y']"""
    if isinstance(drop, list):
        return drop
    elif drop == "":
        return []
    else:
        return [drop]

def safe_drop_label(drop):
    if isinstance(drop, list):
        return "_AND_".join(sorted(drop))
    return "__base__" if drop == "" else str(drop)

def safe_outcome_label(y_col):
    return re.sub(r"[^A-Za-z0-9_]+", "_", str(y_col))

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

def _fit_pred_one_fold(base_estimator, Xv, yv, tr_idx, te_idx, proba):
    """Helper for crossfit_oof_preds — runs in worker process."""
    import warnings
    from sklearn.exceptions import ConvergenceWarning
    warnings.filterwarnings("ignore", category=ConvergenceWarning)
    est = clone(base_estimator)
    est.fit(Xv[tr_idx], yv[tr_idx])
    if proba:
        pred = est.predict_proba(Xv[te_idx])[:, 1]
    else:
        pred = est.predict(Xv[te_idx])
    return te_idx, pred

def crossfit_oof_preds(estimator, X, y, smpls, proba=False, n_jobs=1, backend="threading"):
    """OOF preds aligned with DoubleML's smpls. Returns (n_obs, n_rep)."""
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


# ================================
# BENCHMARK FILE I/O
# ================================

BENCH_DIR = Path(r"C:\Users\Will\OneDrive - The Ohio State University\RA\Data")
BENCH_DIR.mkdir(parents=True, exist_ok=True)

def bench_txt_path(K, N_REP, y_col, drop, d_name):
    drop_lbl = safe_drop_label(drop)
    y_lbl = safe_outcome_label(y_col)
    return BENCH_DIR / f"loan_hat_oof_keys_fold{K}_Rep{N_REP}_bench_values_{y_lbl}_{drop_lbl}_{d_name}.txt"

def save_bench_values(K, N_REP, y_col, drop, d_name, theta_hat, sigma2_hat, nu2_hat, var_y_hat):
    path = bench_txt_path(K, N_REP, y_col, drop, d_name)
    with open(path, "w", encoding="utf-8") as f:
        f.write(f"{y_col};{safe_drop_label(drop)};{d_name};{theta_hat};{sigma2_hat};{nu2_hat};{var_y_hat}\n")
    return path

def load_bench_values(K, N_REP, y_col, drop, d_name):
    path = bench_txt_path(K, N_REP, y_col, drop, d_name)
    if not path.exists():
        raise FileNotFoundError(f"Benchmark file not found: {path}")
    with open(path, "r", encoding="utf-8") as f:
        line = f.readline().strip()
    parts = line.split(";")
    if len(parts) != 7:
        raise ValueError(f"Expected 7 fields in {path}, got {len(parts)}")
    y_read, drop_read, d_name_read, theta, sigma2, nu2, var_y = parts
    return {
        "path": str(path),
        "y_col": y_read,
        "drop": drop_read,
        "d_name": d_name_read,
        "theta": float(theta),
        "sigma2": float(sigma2),
        "nu2": float(nu2),
        "var_y": float(var_y),
    }

def compute_benchmark_cf(base_vals, short_vals):
    var_y = base_vals["var_y"]
    if var_y <= 0:
        raise ValueError("Var(Y) must be positive.")
    if not np.isclose(base_vals["var_y"], short_vals["var_y"], rtol=1e-10, atol=1e-12):
        raise ValueError(
            f"Var(Y) differs across baseline and dropped model: "
            f"{base_vals['var_y']} vs {short_vals['var_y']}"
        )
    r2_long  = 1.0 - (base_vals["sigma2"] / var_y)
    r2_short = 1.0 - (short_vals["sigma2"] / var_y)
    denom_y = 1.0 - r2_long
    if abs(denom_y) < 1e-12:
        raise ValueError("Denominator for c_y is too close to zero.")
    c_y = (r2_long - r2_short) / denom_y
    r2_alpha = short_vals["nu2"] / base_vals["nu2"]
    if r2_alpha <= 0:
        raise ValueError(f"Invalid R2_alpha={r2_alpha}")
    c_d = (1.0 - r2_alpha) / r2_alpha
    sigma2_diff = short_vals["sigma2"] - base_vals["sigma2"]
    nu2_diff    = base_vals["nu2"]    - short_vals["nu2"]
    rho_denom_sq = sigma2_diff * nu2_diff
    if rho_denom_sq > 0:
        rho = (short_vals["theta"] - base_vals["theta"]) / np.sqrt(rho_denom_sq)
        rho = float(np.clip(rho, -1.0, 1.0))
    else:
        rho = np.nan
    return {
        "c_y": c_y, "c_d": c_d, "r2_long": r2_long,
        "r2_short": r2_short, "r2_alpha": r2_alpha,
        "delta_theta": short_vals["theta"] - base_vals["theta"],
        "rho": rho,
    }


# ================================================================
# run_one_drop  —  all work for a single benchmark drop
# ================================================================

def run_one_drop(drop, farm_exp_data, explicit_x, outcome_vars,
                 k_fold_vector, N_REP, fold_hhids_by_K,
                 ml_l, d_col, time_col, unit_col,
                 BENCH_DIR, log_dir):
    """
    Runs the full DML pipeline for one drop specification.
    Writes results to a per-drop log file. Returns the log path.
    Called in parallel across drops via joblib.
    """
    # --- Suppress warnings inside worker process ---
    import warnings
    from sklearn.exceptions import ConvergenceWarning
    warnings.simplefilter(action='ignore', category=FutureWarning)
    warnings.simplefilter(action='ignore', category=DeprecationWarning)
    warnings.filterwarnings("ignore", category=ConvergenceWarning)

    drop_lbl = safe_drop_label(drop)
    log_path = log_dir / f"drop_{drop_lbl}.txt"
    log_f = open(log_path, "w", encoding="utf-8")
    
    drop_start = time.time()
    print(f"[START] drop={drop_lbl}", file=sys.stderr, flush=True)

    try:
        # --- Build covariate list for this drop ---
        explicit_x_dup = explicit_x.copy()
        for d in normalize_drop(drop):
            explicit_x_dup.remove(d)
        
        # so learners know how many variables to use
        n_core = len(explicit_x_dup)
        
        # ==========================================
        # OUTCOME LOOP
        # ==========================================
        for y_col in outcome_vars:
            print(f"\n{'='*70}", file=log_f)
            print(f"OUTCOME: {y_col}", file=log_f)
            print(f"{'='*70}", file=log_f)

            if y_col not in farm_exp_data.columns:
                continue

            current_x_cols = explicit_x_dup.copy()

            # --- Data cleaning ---
            original_obs = obs_num = len(farm_exp_data)
            needed = [y_col]
            df_clean = farm_exp_data.dropna(subset=needed).copy()
            
            cols_with_nan = [c for c in current_x_cols if df_clean[c].isna().any()]
            if cols_with_nan:
                print(f"   -> Found missing data in {len(cols_with_nan)} variables. Imputing & Flagging...", file=log_f)
                for col in cols_with_nan:
                    flag_name = f"{col}_missing"
                    df_clean[flag_name] = df_clean[col].isna().astype(int)
                    current_x_cols.append(flag_name)
                    median_val = df_clean[col].median()
                    df_clean[col] = df_clean[col].fillna(median_val)
                        
            
            obs_per_hh = df_clean.groupby(unit_col)[unit_col].transform("count")
            df_clean = df_clean[obs_per_hh == 2].copy()

            obs_num = len(df_clean)
            droped_hhs = (original_obs - obs_num) / 2
            print(f"   -> Observations after balancing: {len(df_clean)} ({len(df_clean)//2} households), {droped_hhs} Dropped Households", file=log_f)

            df_clean["hhid_cluster"] = df_clean["hhid"]
            cluster_cols = ["hhid_cluster"]
            block = {y_col, d_col, time_col, unit_col, *cluster_cols}
            tv_x_cols = [c for c in current_x_cols if c not in block]
            df_clean["loan"] = df_clean[d_col].astype(float)
            
            S_col = "w_farm_size_agland"
            df_clean["S_centered"] = df_clean[S_col] - df_clean[S_col].mean()
            df_clean["loan"]        = df_clean[d_col].astype(float)
            df_clean["loan_x_size"] = df_clean["loan"] * df_clean["S_centered"]
            d_cols_vec = ["loan","loan_x_size"]

            # FE / CRE
            wave_dummies = pd.get_dummies(df_clean[time_col], prefix="feT_wave", drop_first=True)
            x_means_by_unit = df_clean.groupby(unit_col)[tv_x_cols].transform("mean").add_suffix("_bar")
            X_cre = pd.concat([df_clean[tv_x_cols], x_means_by_unit, wave_dummies], axis=1)
            state_dummies = pd.get_dummies(df_clean["state"], prefix="state", drop_first=True)
            X_cre = pd.concat([X_cre, state_dummies], axis=1).loc[:, lambda d: ~d.columns.duplicated()].copy()
            X_cre_cols = list(X_cre.columns)

            data_for_dml_plr = pd.concat([
                df_clean[[y_col, time_col, unit_col, "loan", "loan_x_size", "hhid_cluster"]].reset_index(drop=True),
                X_cre.reset_index(drop=True)
            ], axis=1)

            hh_groups_obs = data_for_dml_plr[unit_col].to_numpy()

            for K in k_fold_vector:
                dml_workers = 1

                # --- Sample splitting on FULL sample (for treatment learner) ---
                smpls, smpls_cluster = [], []
                hh = hh_groups_obs
                fold_hhids_rep = fold_hhids_by_K[K]

                for rep in range(N_REP):
                    folds_rep = []
                    folds_cluster_rep = []
                    for k in range(K):
                        te_mask = np.isin(hh, fold_hhids_rep[rep][k])
                        te = np.where(te_mask)[0].astype(int)
                        tr = np.where(~te_mask)[0].astype(int)
                        if te.size == 0 or tr.size == 0:
                            raise RuntimeError(
                                f"Empty train/test fold: outcome={y_col}, K={K}, rep={rep}, fold={k}."
                            )
                        folds_rep.append((tr, te))
                        folds_cluster_rep.append([
                            [np.unique(data_for_dml_plr.loc[tr, "hhid_cluster"])],
                            [np.unique(data_for_dml_plr.loc[te, "hhid_cluster"])]
                        ])
                    smpls.append(folds_rep)
                    smpls_cluster.append(folds_cluster_rep)

                # --- Treatment nuisance on FULL sample ---
                X_mat = data_for_dml_plr[X_cre_cols]
                loan_true = data_for_dml_plr["loan"].astype(int).to_numpy()

                npy_path = BENCH_DIR / f"loan_hat_oof_fold{K}_Rep{N_REP}_bench_{drop_lbl}.npy"
                pq_path  = BENCH_DIR / f"loan_hat_oof_keys_fold{K}_Rep{N_REP}_bench_{drop_lbl}.parquet"

                if not npy_path.exists() and y_col == "ln_gen_consumption_flag":
                    loan_hat = crossfit_oof_preds(
                        make_ml_m_loan_clf(n_core), X_mat, loan_true, smpls,
                        proba=True, n_jobs=dml_workers, backend="loky"
                    )
                    np.save(npy_path, loan_hat)
                    df_clean[["hhid", "wave"]].reset_index(drop=True).to_parquet(pq_path, index=False)
                elif npy_path.exists():
                    loan_hat_oof = np.load(npy_path)
                    keys_base = pd.read_parquet(pq_path)
                    base_idx = pd.MultiIndex.from_frame(keys_base[["hhid", "wave"]])
                    pos = pd.Series(np.arange(len(keys_base)), index=base_idx)
                    cur_idx = pd.MultiIndex.from_frame(df_clean[["hhid", "wave"]])
                    row_pos = pos.reindex(cur_idx)
                    if row_pos.isna().any():
                        raise ValueError("Some (hhid, wave) in df_clean not found in saved loan_hat_oof keys.")
                    loan_hat = loan_hat_oof[row_pos.astype(int).to_numpy(), :]
                    assert loan_hat.shape[0] == len(df_clean)
                else:
                    raise RuntimeError(f"loan_hat cache missing and y_col={y_col} is not the full sample — run consumption first.")

                # ==============================================
                # SUBSET: drop imputed farm size before DML
                # ==============================================
                farmsize_flag = "w_farm_size_agland_missing"
                if farmsize_flag in data_for_dml_plr.columns:
                    has_farmsize = data_for_dml_plr[farmsize_flag].values == 0
                    data_for_dml_sub = data_for_dml_plr[has_farmsize].reset_index(drop=True)
                    loan_hat_sub = loan_hat[has_farmsize, :]
                    X_cre_cols_sub = [c for c in X_cre_cols
                                     if c != farmsize_flag and c != f"{farmsize_flag}_bar"]

                    # Rebuild splits on subset
                    hh_sub = data_for_dml_sub[unit_col].to_numpy()
                    smpls_sub, smpls_cluster_sub = [], []
                    for rep in range(N_REP):
                        folds_rep, folds_cluster_rep = [], []
                        for k in range(K):
                            te_mask = np.isin(hh_sub, fold_hhids_rep[rep][k])
                            te = np.where(te_mask)[0].astype(int)
                            tr = np.where(~te_mask)[0].astype(int)
                            if te.size == 0 or tr.size == 0:
                                raise RuntimeError(
                                    f"Empty fold after farmsize subset: y={y_col}, K={K}, rep={rep}, fold={k}."
                                )
                            folds_rep.append((tr, te))
                            folds_cluster_rep.append([
                                [np.unique(data_for_dml_sub.loc[tr, "hhid_cluster"])],
                                [np.unique(data_for_dml_sub.loc[te, "hhid_cluster"])]
                            ])
                        smpls_sub.append(folds_rep)
                        smpls_cluster_sub.append(folds_cluster_rep)

                    obs_num = len(data_for_dml_sub)
                    print(f"   -> Dropped {has_farmsize.sum()} obs with imputed farm size, {obs_num} remain", file=log_f)
                else:
                    data_for_dml_sub = data_for_dml_plr
                    loan_hat_sub = loan_hat
                    X_cre_cols_sub = X_cre_cols
                    smpls_sub, smpls_cluster_sub = smpls, smpls_cluster

                # ==============================================
                # DML on CLEAN subset only
                # ==============================================
                print(f"\n{'*'*70}", file=log_f)
                print(f"OUTCOME: {y_col} --- Drops: {drop_lbl} --- Folds: {K} --- n_reps: {N_REP} --- Observations: {obs_num}", file=log_f)
                print(f"{'*'*70}", file=log_f)

                dml_data = DoubleMLClusterData(
                    data_for_dml_sub,
                    y_col=y_col, d_cols=d_cols_vec,
                    cluster_cols=cluster_cols, x_cols=X_cre_cols_sub,
                    use_other_treat_as_covariate=False
                )

                plr = DoubleMLPLR(
                    dml_data, ml_l=ml_l,
                    ml_m=DummyRegressor(strategy="mean"),
                    n_folds=K, n_rep=N_REP,
                    score="partialling out",
                    draw_sample_splitting=False
                )

                plr.set_sample_splitting(smpls_sub, smpls_cluster_sub)

                # Center S using the FULL df_clean mean (same constant used when
                # building data_for_dml_sub["loan_x_size"] back in df_clean), so
                # the treatment column and its external prediction agree on μ.
                # This preserves cross-subsample comparability of θ̂.
                S_mean_full = df_clean[S_col].mean()
                S_centered_vec = (data_for_dml_sub[S_col].to_numpy() - S_mean_full).reshape(-1, 1)
                loan_x_size_hat = loan_hat_sub * S_centered_vec

                # Cross-fit ml_l ONCE — Y~X is identical for both treatments
                # (use_other_treat_as_covariate=False), so DoubleML would
                # otherwise refit the heavy stacking ensemble per treatment.
                X_mat_sub = data_for_dml_sub[X_cre_cols_sub]
                y_true_sub = data_for_dml_sub[y_col].values.ravel()
                y_hat_sub = crossfit_oof_preds(
                    ml_l, X_mat_sub, y_true_sub, smpls_sub,
                    proba=False, n_jobs=dml_workers, backend="loky"
                )

                external_predictions = {
                    "loan":        {"ml_m": loan_hat_sub,    "ml_l": y_hat_sub},
                    "loan_x_size": {"ml_m": loan_x_size_hat, "ml_l": y_hat_sub},
                }

                plr.fit(n_jobs_cv=dml_workers,
                        store_predictions=True,
                        external_predictions=external_predictions)

                # --- All diagnostics use data_for_dml_sub from here ---

                # --- OUTPUT 1: MAIN COEFFICIENTS ---
                print(plr.summary, file=log_f)

                # --- OUTPUT 2: LEARNER PERFORMANCE ---
                print("\n>>> Learner Performance:", file=log_f)
                preds = plr.predictions
                y_true = data_for_dml_sub[y_col].values.ravel()
                y_pred = get_flat_pred(preds['ml_l'])
                print(f"    Outcome Learner R2 (Y ~ X):        {r2_score(y_true, y_pred):.4f}", file=log_f)

                for i, d_name in enumerate(d_cols_vec):
                    d_true = data_for_dml_sub[d_name].values.ravel()
                    d_pred = get_flat_pred(preds['ml_m'], d_index=i)
                    print(f"    Treatment Learner R2 ({d_name} ~ X): {r2_score(d_true, d_pred):.4f}", file=log_f)

                    if d_name == "loan" or set(np.unique(d_true[~np.isnan(d_true)])).issubset({0, 1}):
                        try:
                            auc = roc_auc_score(d_true, d_pred)
                            ap  = average_precision_score(d_true, d_pred)
                            print(f"        AUC (loan ~ X):                 {auc:.4f}", file=log_f)
                            print(f"        AP  (loan ~ X):                 {ap:.4f}", file=log_f)
                        except ValueError as e:
                            print(f"        AUC/AP not defined: {e}", file=log_f)

                    if d_name == "loan_x_size":
                        rmse_all = np.sqrt(mean_squared_error(d_true, d_pred))
                        print(f"        RMSE (loan_x_size ~ X):         {rmse_all:.4f}", file=log_f)
                        if "loan" in data_for_dml_sub.columns:
                            mask_treated = data_for_dml_sub["loan"].values.ravel() == 1
                            if mask_treated.sum() > 5:
                                rmse_tr = np.sqrt(mean_squared_error(d_true[mask_treated], d_pred[mask_treated]))
                                r2_tr   = r2_score(d_true[mask_treated], d_pred[mask_treated])
                                print(f"        Treated-only RMSE:              {rmse_tr:.4f}", file=log_f)
                                print(f"        Treated-only R2:                {r2_tr:.4f}", file=log_f)

                # --- OUTPUT 3: ROBUSTNESS ---
                print("\n>>> Sensitivity Analysis:", file=log_f)
                try:
                    plr.sensitivity_analysis(cf_y=0.04, cf_d=0.03, null_hypothesis=0.0)
                    print(plr.sensitivity_summary, file=log_f)
                except Exception as e:
                    print(f"    Sensitivity analysis skipped (Error: {e})", file=log_f)

                # --- OUTPUT 4: KEY DML ELEMENTS ---
                print("\n>>> Key DML Elements:", file=log_f)
                var_y_hat = float(np.var(data_for_dml_plr[y_col].values.ravel(), ddof=0))
                for d_idx, d_name in enumerate(d_cols_vec):
                    print(f"\n    Treatment: {d_name}", file=log_f)
                    try:
                        theta_hat  = float(np.asarray(plr.coef).reshape(-1)[d_idx])
                        sigma2_hat = float(np.mean(np.asarray(plr.sensitivity_elements["sigma2"])[0, :, d_idx]))
                        nu2_hat    = float(np.mean(np.asarray(plr.sensitivity_elements["nu2"])[0, :, d_idx]))
                        print(f"    Estimated Treatment Effect (theta):          {theta_hat:.6f}", file=log_f)
                        print(f"    Outcome Residual Variance (sigma^2):        {sigma2_hat:.6f}", file=log_f)
                        print(f"    Second Moment of Riesz Representer (nu^2):  {nu2_hat:.6f}", file=log_f)
                        print(f"    Outcome Variance Var(Y):                    {var_y_hat:.6f}", file=log_f)
                    except Exception as e:
                        print(f"    Could not retrieve sensitivity elements for {d_name}: {e}", file=log_f)
                        theta_hat, sigma2_hat, nu2_hat = np.nan, np.nan, np.nan

                    # --- SAVE BENCHMARK VALUES ---
                    try:
                        file_path = save_bench_values(
                            K=K, N_REP=N_REP, y_col=y_col, drop=drop, d_name=d_name,
                            theta_hat=theta_hat, sigma2_hat=sigma2_hat,
                            nu2_hat=nu2_hat, var_y_hat=var_y_hat
                        )
                        print(f"    Benchmark values saved to: {file_path}", file=log_f)
                    except Exception as e:
                        print(f"    Could not save benchmark values for {d_name}: {e}", file=log_f)

    except Exception as e:
        print(f"\n!!! FATAL ERROR in drop={drop_lbl}: {e}", file=log_f)
        import traceback
        traceback.print_exc(file=log_f)

    finally:
        elapsed = time.time() - drop_start
        print(f"\n--- drop={drop_lbl} finished in {fmt(elapsed)} ---", file=log_f)
        log_f.flush()
        log_f.close()
        print(f"[DONE]  drop={drop_lbl} in {fmt(elapsed)}", file=sys.stderr, flush=True)

    return log_path


# ================================================================
# CONFIGURATION
# ================================================================

dta_path = Path("C:/Users/Will/OneDrive - The Ohio State University/RA/Data/DML Cleaned Data.dta")

outcome_vars = ["ln_gen_consumption_flag", "ln_total_farm_expense"]

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

bench_set = [
    "",
    "ag_plot_formal_rights_hh" ,
    "FCS_index",
    "w_value_assets",
    "member",
    ["head_age",
    "head_sex",
    "member"],
    "w_value_crop_production",
    ["w_value_crop_production",
    "w_value_assets",
    "w_nonfarm_income"]  
]

# ================================
# LEARNERS
# ================================

# Outcome learner
ml_l = make_pipeline(
    StandardScaler(),
    StackingRegressor(
        estimators=[
            ("enet", ElasticNet(
                alpha=0.01, l1_ratio=0.5, random_state=42, max_iter=5000
            )),
            ("rf", RandomForestRegressor(
                n_estimators=1000, max_features="sqrt",
                min_samples_leaf=5, n_jobs=1, random_state=42
            )),
            ("hist_gbr_slow", HistGradientBoostingRegressor(
                max_iter=3000, learning_rate=0.005, max_depth=8,
                min_samples_leaf=15, l2_regularization=0.1, random_state=42
            )),
        ],
        final_estimator=RidgeCV(),
        n_jobs=1
    )
)

# Treatment learner
def make_ml_m_loan_clf(n_core):
    interaction_indices = list(range(n_core))
    return make_pipeline( 
        StandardScaler(),
        StackingClassifier(
            estimators=[
                ("logit_poly", make_pipeline(
                    SimpleImputer(strategy="median"),
                    ColumnTransformer(
                        transformers=[
                            ("originals", "passthrough", interaction_indices),
                            ("poly_select", make_pipeline(
                                PolynomialFeatures(degree=3, include_bias=False, interaction_only=False),
                                FunctionTransformer(make_drop_first_n_cols(n_core), validate=False),
                                StandardScaler(),
                                SelectKBest(f_classif, k=40)
                            ), interaction_indices),
                            ("pass", "passthrough", slice(n_core, None))
                        ]
                    ),
                    VarianceThreshold(),
                    StandardScaler(),
                    LogisticRegressionCV(
                        penalty='l1', solver='liblinear',
                        class_weight='balanced', scoring='roc_auc',
                        Cs=10, cv=2, tol=0.01, max_iter=10000,
                        n_jobs=1, random_state=42
                    )
                )),
                ("hist_gbr", HistGradientBoostingClassifier(
                    max_iter=3000, learning_rate=0.005,
                    class_weight='balanced',
                    max_depth=None, max_leaf_nodes=15,
                    min_samples_leaf=10, l2_regularization=0.1,
                    random_state=42
                ))
            ],
            final_estimator=LogisticRegression(class_weight=None),
            stack_method='predict_proba',
            cv=2, n_jobs=1
        )
    )


# ================================
# LOAD DATA & BUILD MASTER FOLDS
# ================================

farm_exp_data = pd.read_stata(dta_path)
k_fold_vector = [5]
N_REP = 15
N_WORKERS = 6
d_col, time_col, unit_col = "any_arv_farm_loan", "wave", "hhid"
d_cols_vec = ["loan", "loan_x_size"]

# Master folds (HHID-level, outcome-agnostic)
_base = farm_exp_data[[unit_col, time_col, d_col]].copy()
_base = _base[_base.groupby(unit_col)[unit_col].transform("count") == 2].copy()
_base = _base.dropna(subset=[unit_col, time_col, d_col]).copy()

_base_groups  = _base[unit_col].to_numpy()
_base_y_strat = _base.groupby(unit_col)[d_col].transform("max").astype(int).to_numpy()

fold_hhids_by_K = {}
for K in k_fold_vector:
    reps = []
    for rep in range(N_REP):
        sgkf = StratifiedGroupKFold(n_splits=K, shuffle=True, random_state=42 + rep)
        fold_list = []
        for _, te in sgkf.split(np.zeros(len(_base_y_strat)), _base_y_strat, _base_groups):
            fold_list.append(np.unique(_base_groups[te]))
        reps.append(fold_list)
    fold_hhids_by_K[K] = reps


# ================================
# OUTPUT LOGGING SETUP
# ================================

OUTPUT_DIR = Path(__file__).parent
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

try:
    script_name = Path(__file__).stem
except NameError:
    script_name = "interactive_session"

pattern = re.compile(rf"{re.escape(script_name)}_v(\d+)\.txt")
existing_versions = []
for f in OUTPUT_DIR.glob(f"{script_name}_v*.txt"):
    m = pattern.match(f.name)
    if m:
        existing_versions.append(int(m.group(1)))

next_version = max(existing_versions, default=0) + 1
timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
output_file = OUTPUT_DIR / f"{script_name}_v{next_version}_{timestamp}.txt"

# Per-drop log directory
drop_log_dir = OUTPUT_DIR / f"{script_name}_v{next_version}_drop_logs"
drop_log_dir.mkdir(parents=True, exist_ok=True)

# Master log (redirect stdout)
log_file = open(output_file, "w", encoding="utf-8")
real_stdout = sys.stdout
sys.stdout = log_file

print("=" * 80)
print(f"Script: {script_name}")
print(f"Version: v{next_version}")
print(f"Started: {timestamp}")
print(f"Drops: {len(bench_set)} | Workers: {N_WORKERS} | N_REP: {N_REP}")
print("=" * 80, flush=True)


# ================================================================
# PARALLEL DISPATCH
# ================================================================

try:
    loop_start = time.time()
    n_parallel = min(len(bench_set), N_WORKERS)

    print(f"Launching {len(bench_set)} drops across {n_parallel} workers...",
          file=sys.stderr, flush=True)

    log_paths = Parallel(n_jobs=n_parallel, backend="loky")(
        delayed(run_one_drop)(
            drop, farm_exp_data, explicit_x, outcome_vars,
            k_fold_vector, N_REP, fold_hhids_by_K,
            ml_l, d_col, time_col, unit_col,
            BENCH_DIR, drop_log_dir
        )
        for drop in bench_set
    )

    elapsed = time.time() - loop_start
    print(f"\nAll drops completed in {fmt(elapsed)}",
          file=sys.stderr, flush=True)

    # ================================
    # MERGE PER-DROP LOGS INTO MASTER
    # ================================
    for lp in log_paths:
        with open(lp, "r", encoding="utf-8") as f:
            print(f.read())

    # ================================
    # POST-LOOP BENCHMARK SUMMARY
    # ================================
    print("\n" + "=" * 80)
    print("POST-LOOP BENCHMARK SUMMARY")
    print("=" * 80)

    for K in k_fold_vector:
        print(f"\nK = {K}, N_REP = {N_REP}")
        for y_col in outcome_vars:
            for d_name in d_cols_vec:
                print(f"\nOutcome: {y_col}  |  Treatment: {d_name}")
                try:
                    base_vals = load_bench_values(K=K, N_REP=N_REP, y_col=y_col, drop="", d_name=d_name)
                    print(f"  Baseline loaded from: {base_vals['path']}")
                except Exception as e:
                    print(f"  Could not load baseline for {y_col} / {d_name}: {e}")
                    continue
                for drop in bench_set:
                    try:
                        short_vals = load_bench_values(K=K, N_REP=N_REP, y_col=y_col, drop=drop, d_name=d_name)
                        out     = compute_benchmark_cf(base_vals, short_vals)
                        theta   = base_vals["theta"]
                        product = out["c_y"] * out["c_d"] * base_vals["sigma2"] * base_vals["nu2"]
                        rho     = out["rho"]

                        print(f"    Dropped variable: {safe_drop_label(drop)}")
                        print(f"        theta:              {theta:.6f}")

                        if product < 0:
                            print(f"        bound:              [not defined — c_y*c_d < 0, not a confounder]")
                        else:
                            bias_adversarial = np.sqrt(product)
                            print(f"        bound lower (rho=1):    {theta - bias_adversarial:.6f}")
                            print(f"        bound upper (rho=1):    {theta + bias_adversarial:.6f}")
                            if np.isnan(rho):
                                print(f"        rho (empirical):    [undefined — denominator non-positive]")
                            else:
                                bias_empirical = abs(rho) * bias_adversarial
                                print(f"        rho (empirical):    {rho:.4f}")
                                print(f"        bound lower (emp rho):  {theta - bias_empirical:.6f}")
                                print(f"        bound upper (emp rho):  {theta + bias_empirical:.6f}")

                        print(f"        c_y:                {out['c_y']:.6f}")
                        print(f"        c_d:                {out['c_d']:.6f}")
                        print(f"        delta_theta:        {out['delta_theta']:.6f}")
                        print(f"        R2_long:            {out['r2_long']:.6f}")
                        print(f"        R2_short:           {out['r2_short']:.6f}")
                        print(f"        R2_alpha:           {out['r2_alpha']:.6f}")

                    except Exception as e:
                        print(f"    Could not compute benchmark values for drop={safe_drop_label(drop)}: {e}")
                    
    # ================================
    # SAVE BENCHMARK RESULTS TO CSV
    # ================================
    for K in k_fold_vector:
        for y_col in outcome_vars:
            for d_name in d_cols_vec:
                try:
                    base_vals = load_bench_values(K=K, N_REP=N_REP, y_col=y_col, drop="", d_name=d_name)
                except Exception:
                    continue

                param_names = [
                    "theta", "sigma2", "nu2", "var_y",
                    "c_y", "c_d", "rho",
                    "delta_theta", "R2_long", "R2_short", "R2_alpha",
                    "bound_lower_adv", "bound_upper_adv",
                    "bound_lower_emp", "bound_upper_emp",
                ]

                csv_data = {"parameter": param_names}

                for drop in bench_set:
                    col_label = safe_drop_label(drop)
                    try:
                        short_vals = load_bench_values(K=K, N_REP=N_REP, y_col=y_col, drop=drop, d_name=d_name)
                        out = compute_benchmark_cf(base_vals, short_vals)
                        theta = base_vals["theta"]
                        product = out["c_y"] * out["c_d"] * base_vals["sigma2"] * base_vals["nu2"]
                        rho = out["rho"]

                        if product >= 0:
                            bias_adv = np.sqrt(product)
                            bias_emp = abs(rho) * bias_adv if not np.isnan(rho) else np.nan
                        else:
                            bias_adv = np.nan
                            bias_emp = np.nan

                        csv_data[col_label] = [
                            theta,
                            base_vals["sigma2"] if drop == "" else short_vals["sigma2"],
                            base_vals["nu2"] if drop == "" else short_vals["nu2"],
                            base_vals["var_y"],
                            out["c_y"],
                            out["c_d"],
                            rho,
                            out["delta_theta"],
                            out["r2_long"],
                            out["r2_short"],
                            out["r2_alpha"],
                            theta - bias_adv if not np.isnan(bias_adv) else np.nan,
                            theta + bias_adv if not np.isnan(bias_adv) else np.nan,
                            theta - bias_emp if not np.isnan(bias_emp) else np.nan,
                            theta + bias_emp if not np.isnan(bias_emp) else np.nan,
                        ]
                    except Exception as e:
                        csv_data[col_label] = [np.nan] * len(param_names)
                        print(f"    CSV: skipped drop={col_label} for {y_col}/{d_name}: {e}")

                csv_df = pd.DataFrame(csv_data)
                y_lbl = safe_outcome_label(y_col)
                csv_path = OUTPUT_DIR / f"benchmark_K{K}_Rep{N_REP}_{y_lbl}_{d_name}.csv"
                csv_df.to_csv(csv_path, index=False)
                print(f"\n>>> Benchmark CSV saved to: {csv_path}")
            
    # ================================
    # SAVE CONFIDENCE INTERVAL CSV
    # ================================
    ci_rows = []
    for K in k_fold_vector:
        for y_col in outcome_vars:
            for d_name in d_cols_vec:
                try:
                    base_vals = load_bench_values(K=K, N_REP=N_REP, y_col=y_col, drop="", d_name=d_name)
                except Exception:
                    continue
                for drop in bench_set:
                    row = {
                        "outcome": y_col,
                        "treatment": d_name,
                        "K": K,
                        "dropped_variable": safe_drop_label(drop),
                        "theta": np.nan,
                        "rho": np.nan,
                        "ci_lower_conservative": np.nan,
                        "ci_upper_conservative": np.nan,
                        "ci_lower_empirical": np.nan,
                        "ci_upper_empirical": np.nan,
                    }
                    try:
                        short_vals = load_bench_values(K=K, N_REP=N_REP, y_col=y_col, drop=drop, d_name=d_name)
                        out = compute_benchmark_cf(base_vals, short_vals)
                        theta = base_vals["theta"]
                        product = out["c_y"] * out["c_d"] * base_vals["sigma2"] * base_vals["nu2"]
                        rho = out["rho"]
                        row["theta"] = theta
                        row["rho"] = rho
                        if product >= 0:
                            bias_adv = np.sqrt(product)
                            row["ci_lower_conservative"] = theta - bias_adv
                            row["ci_upper_conservative"] = theta + bias_adv
                            if not np.isnan(rho):
                                bias_emp = abs(rho) * bias_adv
                                row["ci_lower_empirical"] = theta - bias_emp
                                row["ci_upper_empirical"] = theta + bias_emp
                    except Exception as e:
                        print(f"    CI CSV: skipped drop={safe_drop_label(drop)} for {y_col}/{d_name}: {e}")
                    ci_rows.append(row)

    ci_df = pd.DataFrame(ci_rows)
    ci_csv_path = OUTPUT_DIR / f"benchmark_CI_K{k_fold_vector[0]}_Rep{N_REP}.csv"
    ci_df.to_csv(ci_csv_path, index=False)
    print(f"\n>>> Confidence interval CSV saved to: {ci_csv_path}")

    print("=" * 80)
    print("Run completed.")
    print("=" * 80)

    # --- SAVE SCRIPT SNAPSHOT FOR REPRODUCIBILITY ---
    print("\n" + "=" * 80)
    print("SCRIPT SNAPSHOT")
    print("=" * 80)
    try:
        with open(__file__, "r", encoding="utf-8") as src:
            print(src.read())
    except Exception as e:
        print(f"Could not save script snapshot: {e}")
    print("=" * 80)

finally:
    sys.stdout.flush()
    log_file.close()
    sys.stdout = sys.__stdout__
    print(f"Output saved to:\n{output_file}")