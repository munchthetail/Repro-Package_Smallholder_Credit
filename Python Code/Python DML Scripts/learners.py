#this function contains the core learners for the DML esimtation
#we use a difference set of learners for the outcome and treatment functions due to the binary and rare nature of treatment
#compared to the continious nature of the outcomes

import numpy as np
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler, PolynomialFeatures, FunctionTransformer
from sklearn.linear_model import ElasticNet, RidgeCV, LogisticRegressionCV, LogisticRegression
from sklearn.ensemble import (RandomForestRegressor, HistGradientBoostingRegressor,
                               StackingRegressor, StackingClassifier,
                               HistGradientBoostingClassifier)
from sklearn.impute import SimpleImputer
from sklearn.compose import ColumnTransformer
from sklearn.feature_selection import SelectKBest, f_classif, VarianceThreshold
from helper_functions import drop_first_base_cols
from functools import partial

# Learners
# otucome learners
ml_l = make_pipeline(
    SimpleImputer(strategy="median", add_indicator=True),
    StandardScaler(),
    StackingRegressor(
        estimators=[
            ("enet", ElasticNet(
                alpha=0.01,       #penalty strength (lower = less regularization)
                l1_ratio=0.5,    #(0.5 = half Lasso, half Ridge)
                random_state=42, 
                max_iter=5000
            )),
            ("rf",    RandomForestRegressor(n_estimators=1000,
                                            max_features="sqrt",
                                            min_samples_leaf=5,
                                            n_jobs=1, 
                                            random_state=42)),
            ("hist_gbr_slow", HistGradientBoostingRegressor(
                max_iter=3000,        #very high iter for robustness
                learning_rate=0.005,  #fairly slow learner rate 0.01
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

def make_ml_m_loan_clf(n_core=19):
    interaction_indices = list(range(n_core))
    drop_fn = partial(drop_first_base_cols, n_base_cols=n_core)
    
    return make_pipeline(
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
                                FunctionTransformer(drop_fn, validate=False),
                                
                                # Scale and Select from the remaining pool (Interactions/Squares)
                                StandardScaler(),
                                SelectKBest(f_classif, k=20) 
                            ), interaction_indices),
                            
                            # BRANCH C: CONTROLS (State Fixed Effects, Flags, etc.)
                            # Keep everything else (Index 19+) safely passed through.
                            ("pass", "passthrough", slice(n_core, None)) 
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

ml_m_loan_clf = make_ml_m_loan_clf()
