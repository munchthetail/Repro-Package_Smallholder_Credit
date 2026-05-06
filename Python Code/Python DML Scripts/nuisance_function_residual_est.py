#this script uses the learners to generate predictions for the nuisance functions
#we then output the residuals to feed into the plr dml function
#residuals are stored in arrays

#both functions produce cross-fitted out-of-fold predictions
#external_predictions, bypassing DoubleML's own internal cross-fitting loop

import numpy as np
import pandas as pd
from pathlib import Path
from helper_functions import crossfit_oof_preds, translate_folds
from learners import ml_l, ml_m_loan_clf


def estimate_loan_nuisance(X_base, loan_true, base_keys,
                           fold_hhids_by_K, k_fold_vector, N_REP, N_WORKERS,
                           re_estimate=False, cache_dir=None, bench_drops="", clf=None):
    """
    NOTE:
    X_base          : all the control variabels include controls in explicit_x, CREs, and FEs
    loan_true       : loan indicator (0/1)
    base_keys       : a key used to match learner output back by (hhid, wave) for getting residuals
    fold_hhids_by_K : the specific households in the prediction fold for a given repetition
    k_fold_vector   : list of fold specificiations (e.g, [5] or [3,5,8])
    N_REP           : number of repetitions
    N_WORKERS       : parallel workers (one job per rep)
    re_estimate     : we set this at the top of the DML Identification.py, if True, re-fit even if done before
    cache_dir       : the location to store predictions 
    bench_drops     : the variables dropped during benchmarking
    clf             : changes based on the number of control variables used
    
    Returns:
    loan_hat_by_K   : {np.array (n_base, N_REP)}, numpy array of loan propensity score predictions for a fold spec
    base_keys_by_K  : {dataframe [hhid, wave]}, the key used to match predictions to original values for residuals
    """
    
    #intializing
    loan_hat_by_K  = {}
    base_keys_by_K = {}

    if clf is None:
        clf = ml_m_loan_clf
       
    #used for fold assignments
    hh_array = base_keys["hhid"].to_numpy()

    for K in k_fold_vector: #looping over fold specifications
        #file paths for this particular K/N_REP combination
        hat_path  = Path(cache_dir) / f"loan_hat_K{K}_R{N_REP}{bench_drops}.npy"       if cache_dir else None
        keys_path = Path(cache_dir) / f"loan_keys_K{K}_R{N_REP}{bench_drops}.parquet"  if cache_dir else None

        #load old predictions if they exists and we chose re_estimate=False
        if (not re_estimate) and hat_path and hat_path.exists():
            print(f"   [loan nuisance K={K}] Loading cached predictions from {hat_path.name}")
            loan_hat_by_K[K]  = np.load(hat_path)
            base_keys_by_K[K] = pd.read_parquet(keys_path)
            continue

        #translate household-level fold assignments into row indices
        smpls = translate_folds(fold_hhids_by_K[K], hh_array, N_REP)

        #run cross-fitted propensity estimation, parallelized at the rep level, 
        #returns estiamted loan propensities as a 2D array that is (households, reps)
        loan_hat = crossfit_oof_preds(
            clf, X_base, loan_true, smpls,
            proba=True, n_jobs=N_WORKERS, backend="loky"
        )

        #stors predictions
        loan_hat_by_K[K]  = loan_hat
        base_keys_by_K[K] = base_keys.reset_index(drop=True) #reset key for dropped observations to match loan_hat

        #saving predictions for later use
        if cache_dir:
            Path(cache_dir).mkdir(parents=True, exist_ok=True)
            np.save(hat_path, loan_hat)
            base_keys_by_K[K].to_parquet(keys_path, index=False)

    return loan_hat_by_K, base_keys_by_K


def estimate_outcome_nuisance(X_outcome, y_outcome, outcome_keys,
                              fold_hhids_by_K, k_fold_vector, N_REP, N_WORKERS,
                              y_col, re_estimate=False, cache_dir=None, bench_drops=""):
    """
    NOTE:
    
    X_outcome       : DataFrame (n_outcome, controls), all the control variabels include controls in explicit_x, CREs, and FEs
    y_outcome       : array (n_outcome,), outcome of interest
    outcome_keys    : DataFrame [hhid, wave], the key used to align predictions with original data
    fold_hhids_by_K : the specific households in the prediction fold for a given repetition
    k_fold_vector   : list of fold specificiations (e.g, [5] or [3,5,8])
    N_REP           : number of repetitions
    N_WORKERS       : parallel workers (one job per rep)
    re_estimate     : we set this at the top of the DML Identification.py, if True, re-fit even if done before
    cache_dir       : the location to store predictions 
    bench_drops     : the variables dropped during benchmarking

    Returns:
    outcome_hat_by_K : array (n_outcome, N_REP), predicted outcomes by rep
    """
    
    #initializing
    outcome_hat_by_K = {}
    hh_array = outcome_keys["hhid"].to_numpy()

    #make sure outcome name is good for saving document
    y_safe = y_col.replace("/", "_").replace(" ", "_")
    
    for K in k_fold_vector:
                
        #saving location for the given K/REP combination
        hat_path = Path(cache_dir) / f"outcome_hat_{y_safe}_K{K}_R{N_REP}{bench_drops}.npy" if cache_dir else None

        #load old predictions if they exists and we chose re_estimate=False
        if (not re_estimate) and hat_path and hat_path.exists():
            print(f"   [outcome nuisance {y_col} K={K}] Loading cached predictions from {hat_path.name}")
            outcome_hat_by_K[K] = np.load(hat_path)
            continue

        #translate household-level fold assignments into row indices
        smpls = translate_folds(fold_hhids_by_K[K], hh_array, N_REP)

        #run cross-fitted propensity estimation, parallelized at the rep level, 
        #returns estiamted loan propensities as a 2D array that is (households, reps)
        outcome_hat = crossfit_oof_preds(
            ml_l, X_outcome, y_outcome, smpls,
            proba=False, n_jobs=N_WORKERS, backend="loky"
        )

        #stors predictions
        outcome_hat_by_K[K] = outcome_hat

        #saving predictions for later use
        if cache_dir:
            Path(cache_dir).mkdir(parents=True, exist_ok=True)
            np.save(hat_path, outcome_hat)
            print(f"   [outcome nuisance {y_col} K={K}] Saved to {hat_path.name}")

    return outcome_hat_by_K
