#this script provides a lot of the supporting scaffolding to the other python scripts 

import numpy as np
import pandas as pd
from joblib import Parallel, delayed
from sklearn.base import clone

# ============================================================
# CROSS-FITTING (rep-level parallelism)
# ============================================================

def _compute_one_rep(r, base_estimator, Xv, yv, rep_folds, proba):
    #runs all K folds for a single rep sequentially inside one worker process
    # doing folds sequentially per rep lets each parallel job be a complete, independent unit
    n_obs = Xv.shape[0]
    out_rep = np.full(n_obs, np.nan, dtype=float)
    for tr_idx, te_idx in rep_folds: #gets the training and testing indexes for model fitting
        est = clone(base_estimator)  #need a fresh clone learner copy per fold to store output without overlap
        est.fit(Xv[tr_idx], yv[tr_idx]) 
        #the next step is out of sample (out of fold i.e. oof) predictions
        #this is important as it specifies that we are generating probabilities of treatment when proba==TRUE (for loans)
        #where for outcomes we generate predictions of continious outcomes proba==FALSE
        if proba:
            pred = est.predict_proba(Xv[te_idx])[:, 1]
        else:
            pred = est.predict(Xv[te_idx])
        out_rep[te_idx] = pred
    return r, out_rep


def crossfit_oof_preds(estimator, X, y, smpls, proba=False, n_jobs=1, backend="loky"):
    #NOTE: THIS IS THEY KEY AREA WE PALLELIZE n_jobs, 
        #we intentionally parallelize at a higher level and parallelizing here could over subscribe cores
    #this is a central function to our estimation process, here we use fold assignments to make out of sample predictions
    
    #making dataframes into arrays
    Xv = X.to_numpy() if hasattr(X, "to_numpy") else np.asarray(X)
    yv = np.asarray(y)
    #initializes output array e.g. REP=30, observastion=6000 -> (6000,30)
    n_obs = Xv.shape[0]
    n_rep = len(smpls)
    out = np.full((n_obs, n_rep), np.nan, dtype=float)

    #NOTE: this is the key parallelization step
    results = Parallel(n_jobs=n_jobs, backend=backend)(
        delayed(_compute_one_rep)(r, estimator, Xv, yv, smpls[r], proba)
        for r in range(n_rep)
    )
    #fills output array
    for r, rep_preds in results:
        out[:, r] = rep_preds
    return out


# ============================================================
# FOLD TRANSLATION
# ============================================================

def translate_folds(fold_hhids_rep, hh_array, N_REP):
    #converts household-level fold assignments in fold_hhids_rep from fold generation 
    #to row indexes as training (tr) or testing (te) in the nuisance function 
    #during cross-fitting in the
    smpls = []
    for rep in range(N_REP):
        rep_folds = []
        for fold_hhids in fold_hhids_rep[rep]: #grabs a list of households assigned to testing for each rep
            te_mask = np.isin(hh_array, fold_hhids) #true/false hhid list for test fold
            te = np.where(te_mask)[0].astype(int) #assginns test households
            tr = np.where(~te_mask)[0].astype(int) #assigns training households
            
            rep_folds.append((tr, te)) #adds a tuple containing two arrays for indexing observations as train or test
        smpls.append(rep_folds) #appens full list of assignments fora given rep
    return smpls #returns smpls[rep][fold] = (training index, testing index)

# ============================================================
# LOAN HAT ALIGNMENT
# ============================================================

def align_to_subsample(loan_hat_full, base_keys, sub_keys):
    #maps a (n_base_obs, n_rep) loan_hat array computed on the full base sample
    #to the row ordering of a specific outcome subsample, matched by (hhid, wave)
    #this lets every outcome reuse the same loan estimates without re-fitting
    #maximizing predictive power and enhancing stability across outcome analysis in a
    #manner analogous to GATE
    
    #i.e. base_keys operates as a crosswalk from full sample predictions to the subsample
    
    #formalizes key for the dataframe as hhid and wave
    base_idx = pd.MultiIndex.from_frame(base_keys[["hhid", "wave"]])
    #basically making a sortable dictionary ID'd by hhid wave
    pos = pd.Series(np.arange(len(base_keys)), index=base_idx)
    #doing the same for the outcome subset (combined with the above we have a crosswalk)
    cur_idx = pd.MultiIndex.from_frame(sub_keys[["hhid", "wave"]])
    #crosswalk
    row_pos = pos.reindex(cur_idx)
    #returns the loan predictions indexed to the subset's ordering
    return loan_hat_full[row_pos.astype(int).to_numpy(), :]


# ============================================================
# PIPELINE HELPER (used inside learners.py)
# ============================================================

def drop_first_base_cols(X, n_base_cols=19):
    #forces baseline controls to be included in poly-logit lasso learner 
    return X[:, n_base_cols:]

# ============================================================
# DIAGNOSTIC HELPERS FOR BENCHMARKING
# ============================================================

#this just makes a savable name for caching data when benchmarking
def safe_drop_label(drop):
    if isinstance(drop, list):
        return "_AND_".join(sorted(drop))
    return "__base__" if drop == "" else str(drop)

#this caches benchmark data for later use
def save_bench_values(K, N_REP, y_col, drop, d_name, theta, sigma2, nu2, var_y, cache_dir):
    y_safe = y_col.replace("/", "_").replace(" ", "_")
    drop_lbl = safe_drop_label(drop)
    path = cache_dir / f"bench_{y_safe}_{d_name}_K{K}_R{N_REP}_{drop_lbl}.txt"
    with open(path, "w") as f:
        f.write(f"{y_col};{drop_lbl};{d_name};{theta};{sigma2};{nu2};{var_y}\n")

#this retrieves benchmark data for the final csv document
def load_bench_values(K, N_REP, y_col, drop, d_name, cache_dir):
    y_safe = y_col.replace("/", "_").replace(" ", "_")
    drop_lbl = safe_drop_label(drop)
    path = cache_dir / f"bench_{y_safe}_{d_name}_K{K}_R{N_REP}_{drop_lbl}.txt"
    parts = open(path).readline().strip().split(";")
    return {"theta": float(parts[3]), "sigma2": float(parts[4]),
            "nu2": float(parts[5]), "var_y": float(parts[6])}

#this computes the neccessary input for the confidence intervals, used for exporting to the csv file
#more detail can be found at https://docs.doubleml.org/stable/guide/sensitivity.html
def compute_benchmark_cf(base, short):
    r2_long  = 1.0 - (base["sigma2"]  / base["var_y"])
    r2_short = 1.0 - (short["sigma2"] / base["var_y"])  #same var y denominator
    c_y      = (r2_long - r2_short) / (1.0 - r2_long)
    r2_alpha = short["nu2"] / base["nu2"]
    c_d = (1.0 - r2_alpha) / r2_alpha if r2_alpha > 0 else np.nan
    c_d = c_d if (not np.isnan(c_d) and c_d >= 0) else np.nan
    denom_sq = (short["sigma2"] - base["sigma2"]) * (base["nu2"] - short["nu2"])
    rho = float(np.clip((short["theta"] - base["theta"]) / np.sqrt(denom_sq), -1, 1)) \
          if denom_sq > 0 else np.nan
    return {"c_y": c_y, "c_d": c_d, "r2_long": r2_long, "r2_short": r2_short,
            "r2_alpha": r2_alpha, "delta_theta": short["theta"] - base["theta"], "rho": rho}
