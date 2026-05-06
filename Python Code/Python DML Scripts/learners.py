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


#outcome learners: elastic net, RF, GB w/ Ridge meta learner
ml_l = make_pipeline(
    StandardScaler(),
    #ensemble consists of elastic net, RF, GB --- 
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
                max_depth=8,          #deeper trees to catch complex interactions
                min_samples_leaf=15,
                l2_regularization=0.1, #slight regularization to prevent overfitting
                random_state=42
            )),
        ],
        final_estimator=RidgeCV(),
        n_jobs=1
    )
)

#treatment learners: GB classifier and poly-logistic lasso w/ logisitc meta-learner
#we define this as a function so that we can change the number of terms 
    #to include in the polynomial interaction generation based on the number of controls
def make_ml_m_loan_clf(n_core=19):
    interaction_indices = list(range(n_core))
    drop_fn = partial(drop_first_base_cols, n_base_cols=n_core)
    #ensemble consists of Poly-Logit w/ L1, 
    return make_pipeline(
        StandardScaler(),
        StackingClassifier( 
            estimators=[
                ("logit_poly", make_pipeline(
                    #this sequence makes all the interactyion terms up to degree==3
                    ColumnTransformer(
                        transformers=[
                            ("originals", "passthrough", interaction_indices),
                            #keeps the best 20, NOTE: keeping 20 was based on computational overhead limitations, more would be fine in theory
                            ("poly_select", make_pipeline(
                                #(Linear + Interactions + Squares + Cubes)
                                PolynomialFeatures(degree=3, include_bias=False, interaction_only=False),
                                
                                #drop the original controls so we are just selecting from interaction terms
                                FunctionTransformer(drop_fn, validate=False),
                                
                                #scale and s from the remaining pool
                                StandardScaler(),
                                SelectKBest(f_classif, k=20) 
                            ), interaction_indices),
                            
                            #combines selected variables with original controls 
                            ("pass", "passthrough", slice(n_core, None)) 
                        ]
                    ),
                    VarianceThreshold(),
                    StandardScaler(),
                    LogisticRegressionCV(
                        penalty='l1', 
                        solver='liblinear',
                        class_weight='balanced',    #set inside of ensemble to balanced to blow up signals for the meta-learner
                        scoring='roc_auc',
                        Cs=10,            
                        cv=2,            #cv is fine within the training fold itself
                        tol=0.01,        #relatively loose to relax convergence speed due to hardware limitations
                        max_iter=10000,   
                        n_jobs=1,        
                        random_state=42
                    )
                )),
                ("hist_gbr", HistGradientBoostingClassifier(
                    max_iter=3000,
                    learning_rate=0.005,
                    class_weight='balanced', #set inside of ensemble to balanced to blow up signals for the meta-learner
                    max_depth=None,          
                    max_leaf_nodes=15,       #deep targeted branches for rare events
                    min_samples_leaf=10,                     
                    l2_regularization=0.1,   #avoid some overfitting with some regularization
                    random_state=42
                ))
            ],
            final_estimator=LogisticRegression(class_weight=None),
            stack_method='predict_proba', #set to sample propensity to properly scale the powerful signals from stacked learners
            cv=2,
            n_jobs=1
        )
    )

#set the learner for use in the main script (when passing the learner it can't be a function with arguments)
ml_m_loan_clf = make_ml_m_loan_clf()
