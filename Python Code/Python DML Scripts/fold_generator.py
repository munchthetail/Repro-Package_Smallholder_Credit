#this script generates the fold assignments for the DML procedure. We use stratified group k-fold to ensure that:
#  - each fold has a similar distribution of the treatment variable (stratification)

from sklearn.model_selection import StratifiedGroupKFold
import numpy as np

def fold_generator(_base_y_strat, _base_groups, k_fold_vector, N_REP):
    #dictionary fold_hhids_by_K[K][rep][k] = np.array of hhids in test fold k for repetition rep
    #only relavent as a dictionary if K is a non singluar vector
    fold_hhids_by_K = {}
    
    for K in k_fold_vector:
        reps = []
        for rep in range(N_REP):
            sgkf = StratifiedGroupKFold(n_splits=K, shuffle=True, random_state=42 + rep) #args: fold #, randomize, seed
            fold_list = []
            for _, test_fold in sgkf.split(np.zeros(len(_base_y_strat)), _base_y_strat, _base_groups): #args: number of obs, stratification on treatment, stratification on household
                fold_list.append(np.unique(_base_groups[test_fold]))  #hhids in fold k
            reps.append(fold_list) #appends lists of HHs in the testing group for this fold
        fold_hhids_by_K[K] = reps #list of lists of HHs by fold # (e..g K=[3,5,8])
    return fold_hhids_by_K