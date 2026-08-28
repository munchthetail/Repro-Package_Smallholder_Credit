clear all      // clears data, value labels, saved results, and programs
set more off   // prevents output from pausing with "more"

use "${root}/Stata Code/Stata Data Landing/DML Cleaned Data.dta", clear

//from https://github.com/sergiocorreia/reghdfe#install
//needed package
//cap ado uninstall reghdfe
//ssc install reghdfe

//compile ftools to prevent errors if you already had an older version installed:
//ftools, compile 
//mata: mata mlib index

//drop missing land and unpaired HHs
	keep if w_farm_size_agland !=.
	duplicates tag hhid, gen(tag)
	drop if tag==0
	drop tag

//storing output fucntion
	capture program drop store_coef
	program define store_coef
		args filehandle HTE_flag
		
		if `HTE_flag' == 0 {
			local coef1 = e(b)[1,1]
			local se1   = sqrt(e(V)[1,1])
			local t1 = `coef1' / `se1'
			local p1 = 2 * ttail(e(df_r), abs(`t1'))
			local adj_r = e(r2_a)
			local wi_adj_r2 = e(r2_a_within)
			
			file write `filehandle' "  loan" _col(30) ///
				%9.6f (`coef1') "  " %9.6f (`se1') "  " ///
				%7.4f (`t1') "  " %7.4f (`p1') "  " ///
				%9.6f (`adj_r') "  " %9.6f (`wi_adj_r2') _n 
		}

		if `HTE_flag' == 1 {
			local hte_coef1 = e(b)[1,2]
			local hte_se1   = sqrt(e(V)[2,2])
			local hte_t1 = `hte_coef1' / `hte_se1'
			local hte_p1 = 2 * ttail(e(df_r), abs(`hte_t1'))
		
			local hte_coef2 = e(b)[1,5]
			local hte_se2   = sqrt(e(V)[5,5])
			local hte_t2 = `hte_coef2' / `hte_se2'
			local hte_p2 = 2 * ttail(e(df_r), abs(`hte_t2'))
			
			local adj_r = e(r2_a)
			local wi_adj_r2 = e(r2_a_within)

			file write `filehandle' "  loan (at mean size)" _col(30) ///
				%9.6f (`hte_coef1') "  " %9.6f (`hte_se1') "  " ///
				%7.4f (`hte_t1') "  " %7.4f (`hte_p1') "  " ///
				%9.6f (`adj_r') "  " %9.6f (`wi_adj_r2') _n 

			file write `filehandle' "  loan_x_size" _col(30) ///
				%9.6f (`hte_coef2') "  " %9.6f (`hte_se2') "  " ///
				%7.4f (`hte_t2') "  " %7.4f (`hte_p2') "  " ///
				%9.6f (`adj_r') "  " %9.6f (`wi_adj_r2') _n 
		}
	end
	
//median interpolation to mimic what DML does
	local miss_dums ""
	
	foreach v of varlist w_value_crop_production w_value_assets w_nonfarm_income ///
		w_lvstck_holding_tlu ag_plot_formal_rights_hh ///
		income_shock food_shock price_shock ///
		head_maritial_status head_age head_sex ///
		member adult_member ///
		phone_access internet_access ///
		probability_moderately_insecure FCS_index non_farming_loan {
		
		quietly count if missing(`v')
		if r(N) > 0 {
			quietly summarize `v', detail
			gen byte miss_`v' = missing(`v')
			replace `v' = r(p50) if missing(`v')
			dis "`v'"
		local miss_dums `miss_dums' miss_`v'
		}
	}

//open output file
local today = subinstr("$S_DATE"," ","_",.)
local now   = subinstr("$S_TIME",":","",.)

//file open outfile using "C:/Users/Will/Documents/GitHub/2nd-Year-Paper/Tables and Figures/TWFE_coefficients_`today'_`now'.txt", write replace
file open outfile using "${root}/Tables and Figures/TWFE_coefficients_`today'_`now'.txt", write replace
file write outfile _n "======================================================================" _n
file write outfile "RUN: $S_DATE $S_TIME" _n
file write outfile "======================================================================" _n

//regressions
	//BASELINE
		scalar def baseline = 0
		
		foreach v of varlist ln_gen_consumption_flag ln_total_farm_expense{
			preserve
			
				drop if `v'== .
				duplicates tag hhid, gen(tag)
				drop if tag==0
				drop tag
				
				quiet sum w_farm_size_agland, detail
				gen centered_w_farm_size_agland = w_farm_size_agland - `r(mean)'
					
				reghdfe `v' any_arv_farm_loan centered_w_farm_size_agland ///
					w_value_crop_production w_value_assets w_nonfarm_income ///
					w_lvstck_holding_tlu ag_plot_formal_rights_hh ///
					income_shock food_shock price_shock ///
					head_maritial_status head_age head_sex ///
					member adult_member ///
					phone_access internet_access ///
					probability_moderately_insecure FCS_index non_farming_loan ///
					`miss_dums' i.state, ///
					absorb(hhid wave) vce(cluster hhid) 
				
				file write outfile _n "======================================================================" _n
				file write outfile "OUTCOME: `v' | MODEL: Baseline TWFE" _n
				file write outfile "  N = `e(N)' | Clusters = `e(N_clust)'" _n
				file write outfile "======================================================================" _n
				file write outfile "  " _col(30) "coef       std err     t       P>|t|     adj-R2       within-adj-R2" _n
				file write outfile "**********************************************************************" _n
				store_coef outfile 0
				
			restore
			}
			
	//HETEROGENIOUS BASELINE EFFECTS
		scalar def baseline = 1
		
		foreach v of varlist ln_gen_consumption_flag ln_total_farm_expense{
			preserve
			
				drop if `v'== .
				duplicates tag hhid, gen(tag)
				drop if tag==0
				drop tag
				
				quiet sum w_farm_size_agland, detail
				gen centered_w_farm_size_agland = w_farm_size_agland - `r(mean)'
					
				reghdfe `v' any_arv_farm_loan##c.centered_w_farm_size_agland ///
					w_value_crop_production w_value_assets w_nonfarm_income ///
					w_lvstck_holding_tlu ag_plot_formal_rights_hh ///
					income_shock food_shock price_shock ///
					head_maritial_status head_age head_sex ///
					member adult_member ///
					phone_access internet_access ///
					probability_moderately_insecure FCS_index non_farming_loan ///
					`miss_dums' i.state, ///
					absorb(hhid wave) vce(cluster hhid) 
								
				file write outfile _n "======================================================================" _n
				file write outfile "OUTCOME: `v' | MODEL: Heterogeneous Baseline TWFE" _n
				file write outfile "  N = `e(N)' | Clusters = `e(N_clust)'" _n
				file write outfile "======================================================================" _n
				file write outfile "  " _col(30) "coef       std err     t       P>|t|     adj-R2       within-adj-R2" _n
				file write outfile "**********************************************************************" _n
				store_coef outfile "`v'" "het_baseline" "any_arv_farm_loan" "loan (at mean size)"
				store_coef outfile 1
					
			restore
			}
			
	//HETEROGENIOUS FARM  EFFECTS
		foreach v of varlist ln_total_input_exp ln_land_total_exp ln_labor_expense_total ln_animal_total_exp ln_total_fert_kg_ha{
			preserve
			
				drop if `v'== .
				duplicates tag hhid, gen(tag)
				drop if tag==0
				drop tag
				
				quiet sum w_farm_size_agland, detail
				gen centered_w_farm_size_agland = w_farm_size_agland - `r(mean)'
					
				reghdfe `v' any_arv_farm_loan##c.centered_w_farm_size_agland ///
					w_value_crop_production w_value_assets w_nonfarm_income ///
					w_lvstck_holding_tlu ag_plot_formal_rights_hh ///
					income_shock food_shock price_shock ///
					head_maritial_status head_age head_sex ///
					member adult_member ///
					phone_access internet_access ///
					probability_moderately_insecure FCS_index non_farming_loan ///
					`miss_dums' i.state, ///
					absorb(hhid wave) vce(cluster hhid) 
				
				file write outfile _n "======================================================================" _n
				file write outfile "OUTCOME: `v' | MODEL: Heterogeneous Baseline TWFE" _n
				file write outfile "  N = `e(N)' | Clusters = `e(N_clust)'" _n
				file write outfile "======================================================================" _n
				file write outfile "  " _col(30) "coef       std err     t       P>|t|     adj-R2       within-adj-R2" _n
				file write outfile "**********************************************************************" _n
				store_coef outfile "`v'" "het_baseline" "any_arv_farm_loan" "loan (at mean size)"
				store_coef outfile 1
			
			restore
			}
			
	//HETEROGENIOUS NONFARM  EFFECTS
		foreach v of varlist ln_food_flag ln_non_food_gen_consumption{
			preserve
			
				drop if `v'== .
				duplicates tag hhid, gen(tag)
				drop if tag==0
				drop tag
				
				quiet sum w_farm_size_agland, detail
				gen centered_w_farm_size_agland = w_farm_size_agland - `r(mean)'
					
				reghdfe `v' any_arv_farm_loan##c.centered_w_farm_size_agland ///
					w_value_crop_production w_value_assets w_nonfarm_income ///
					w_lvstck_holding_tlu ag_plot_formal_rights_hh ///
					income_shock food_shock price_shock ///
					head_maritial_status head_age head_sex ///
					member adult_member ///
					phone_access internet_access ///
					probability_moderately_insecure FCS_index non_farming_loan ///
					`miss_dums' i.state, ///
					absorb(hhid wave) vce(cluster hhid) 
				
				file write outfile _n "======================================================================" _n
				file write outfile "OUTCOME: `v' | MODEL: Heterogeneous Baseline TWFE" _n
				file write outfile "  N = `e(N)' | Clusters = `e(N_clust)'" _n
				file write outfile "======================================================================" _n
				file write outfile "  " _col(30) "coef       std err     t       P>|t|     adj-R2       within-adj-R2" _n
				file write outfile "**********************************************************************" _n
				store_coef outfile 1

			restore
			}
	
//any loan
	//BASELINE
		scalar def baseline = 0
		
		foreach v of varlist ln_gen_consumption_flag ln_total_farm_expense{
			preserve
			
				drop if `v'== .
				duplicates tag hhid, gen(tag)
				drop if tag==0
				drop tag
				
				quiet sum w_farm_size_agland, detail
				gen centered_w_farm_size_agland = w_farm_size_agland - `r(mean)'
					
				reghdfe `v' any_loan centered_w_farm_size_agland ///
					w_value_crop_production w_value_assets w_nonfarm_income ///
					w_lvstck_holding_tlu ag_plot_formal_rights_hh ///
					income_shock food_shock price_shock ///
					head_maritial_status head_age head_sex ///
					member adult_member ///
					phone_access internet_access ///
					probability_moderately_insecure FCS_index ///
					`miss_dums' i.state, ///
					absorb(hhid wave) vce(cluster hhid) 
				
				file write outfile _n "======================================================================" _n
				file write outfile "OUTCOME: `v' | MODEL: Baseline TWFE" _n
				file write outfile "  N = `e(N)' | Clusters = `e(N_clust)'" _n
				file write outfile "======================================================================" _n
				file write outfile "  " _col(30) "coef       std err     t       P>|t|     adj-R2       within-adj-R2" _n
				file write outfile "**********************************************************************" _n
				store_coef outfile 0
				
			restore
			}
			
	//HETEROGENIOUS BASELINE EFFECTS
		scalar def baseline = 1
		
		foreach v of varlist ln_gen_consumption_flag ln_total_farm_expense{
			preserve
			
				drop if `v'== .
				duplicates tag hhid, gen(tag)
				drop if tag==0
				drop tag
				
				quiet sum w_farm_size_agland, detail
				gen centered_w_farm_size_agland = w_farm_size_agland - `r(mean)'
					
				reghdfe `v' any_loan##c.centered_w_farm_size_agland ///
					w_value_crop_production w_value_assets w_nonfarm_income ///
					w_lvstck_holding_tlu ag_plot_formal_rights_hh ///
					income_shock food_shock price_shock ///
					head_maritial_status head_age head_sex ///
					member adult_member ///
					phone_access internet_access ///
					probability_moderately_insecure FCS_index ///
					`miss_dums' i.state, ///
					absorb(hhid wave) vce(cluster hhid) 
								
				file write outfile _n "======================================================================" _n
				file write outfile "OUTCOME: `v' | MODEL: Heterogeneous Baseline TWFE" _n
				file write outfile "  N = `e(N)' | Clusters = `e(N_clust)'" _n
				file write outfile "======================================================================" _n
				file write outfile "  " _col(30) "coef       std err     t       P>|t|     adj-R2       within-adj-R2" _n
				file write outfile "**********************************************************************" _n
				store_coef outfile "`v'" "het_baseline" "any_arv_farm_loan" "loan (at mean size)"
				store_coef outfile 1
					
			restore
			}

	//HETEROGENIOUS FARM  EFFECTS
		foreach v of varlist ln_total_input_exp ln_land_total_exp ln_labor_expense_total ln_animal_total_exp ln_total_fert_kg_ha{
			preserve
			
				drop if `v'== .
				duplicates tag hhid, gen(tag)
				drop if tag==0
				drop tag
				
				quiet sum w_farm_size_agland, detail
				gen centered_w_farm_size_agland = w_farm_size_agland - `r(mean)'
					
				reghdfe `v' any_loan##c.centered_w_farm_size_agland ///
					w_value_crop_production w_value_assets w_nonfarm_income ///
					w_lvstck_holding_tlu ag_plot_formal_rights_hh ///
					income_shock food_shock price_shock ///
					head_maritial_status head_age head_sex ///
					member adult_member ///
					phone_access internet_access ///
					probability_moderately_insecure FCS_index ///
					`miss_dums' i.state, ///
					absorb(hhid wave) vce(cluster hhid) 
				
				file write outfile _n "======================================================================" _n
				file write outfile "OUTCOME: `v' | MODEL: Heterogeneous Baseline TWFE" _n
				file write outfile "  N = `e(N)' | Clusters = `e(N_clust)'" _n
				file write outfile "======================================================================" _n
				file write outfile "  " _col(30) "coef       std err     t       P>|t|     adj-R2       within-adj-R2" _n
				file write outfile "**********************************************************************" _n
				store_coef outfile "`v'" "het_baseline" "any_arv_farm_loan" "loan (at mean size)"
				store_coef outfile 1
			
			restore
			}
			
	//HETEROGENIOUS NONFARM  EFFECTS
		foreach v of varlist ln_food_flag ln_non_food_gen_consumption{
			preserve
			
				drop if `v'== .
				duplicates tag hhid, gen(tag)
				drop if tag==0
				drop tag
				
				quiet sum w_farm_size_agland, detail
				gen centered_w_farm_size_agland = w_farm_size_agland - `r(mean)'
					
				reghdfe `v' any_loan##c.centered_w_farm_size_agland ///
					w_value_crop_production w_value_assets w_nonfarm_income ///
					w_lvstck_holding_tlu ag_plot_formal_rights_hh ///
					income_shock food_shock price_shock ///
					head_maritial_status head_age head_sex ///
					member adult_member ///
					phone_access internet_access ///
					probability_moderately_insecure FCS_index ///
					`miss_dums' i.state, ///
					absorb(hhid wave) vce(cluster hhid) 
				
				file write outfile _n "======================================================================" _n
				file write outfile "OUTCOME: `v' | MODEL: Heterogeneous Baseline TWFE" _n
				file write outfile "  N = `e(N)' | Clusters = `e(N_clust)'" _n
				file write outfile "======================================================================" _n
				file write outfile "  " _col(30) "coef       std err     t       P>|t|     adj-R2       within-adj-R2" _n
				file write outfile "**********************************************************************" _n
				store_coef outfile 1

			restore
			}
	
	file close outfile
	display "Coefficients written to TWFE_coefficients.txt"

//residuals for scatter plot
	preserve
			
		drop if ln_total_farm_expense== .
		duplicates tag hhid, gen(tag)
		drop if tag==0
		drop tag
		
		quiet sum w_farm_size_agland, detail
		gen centered_w_farm_size_agland = w_farm_size_agland - `r(mean)'
			
		reghdfe ln_total_farm_expense centered_w_farm_size_agland ///
			w_value_crop_production w_value_assets w_nonfarm_income ///
			w_lvstck_holding_tlu ag_plot_formal_rights_hh ///
			income_shock food_shock price_shock ///
			head_maritial_status head_age head_sex ///
			member adult_member ///
			phone_access internet_access ///
			probability_moderately_insecure FCS_index non_farming_loan ///
			`miss_dums' i.state, ///
			absorb(hhid wave) vce(cluster hhid) residuals(TWFE_residuals)
		
		keep hhid wave w_farm_size_agland TWFE_residuals 
		save "${root}/Stata Code/Stata Data Landing/TWFE_farm_residuals.dta", replace
	restore

//residuals for scatter plot
	preserve
			
		drop if ln_gen_consumption_flag== .
		duplicates tag hhid, gen(tag)
		drop if tag==0
		drop tag
		
		quiet sum w_farm_size_agland, detail
		gen centered_w_farm_size_agland = w_farm_size_agland - `r(mean)'
			
		reghdfe ln_gen_consumption_flag centered_w_farm_size_agland ///
			w_value_crop_production w_value_assets w_nonfarm_income ///
			w_lvstck_holding_tlu ag_plot_formal_rights_hh ///
			income_shock food_shock price_shock ///
			head_maritial_status head_age head_sex ///
			member adult_member ///
			phone_access internet_access ///
			probability_moderately_insecure FCS_index non_farming_loan ///
			`miss_dums' i.state, ///
			absorb(hhid wave) vce(cluster hhid) residuals(TWFE_residuals)
		
		keep hhid wave w_farm_size_agland TWFE_residuals 
		save "${root}/Stata Code/Stata Data Landing/TWFE_con_residuals.dta", replace
	restore

//residuals for scatter plot
	preserve
			
		drop if ln_total_fert_kg_ha== .
		duplicates tag hhid, gen(tag)
		drop if tag==0
		drop tag
		
		quiet sum w_farm_size_agland, detail
		gen centered_w_farm_size_agland = w_farm_size_agland - `r(mean)'
			
		reghdfe ln_total_fert_kg_ha centered_w_farm_size_agland ///
			w_value_crop_production w_value_assets w_nonfarm_income ///
			w_lvstck_holding_tlu ag_plot_formal_rights_hh ///
			income_shock food_shock price_shock ///
			head_maritial_status head_age head_sex ///
			member adult_member ///
			phone_access internet_access ///
			probability_moderately_insecure FCS_index non_farming_loan ///
			`miss_dums' i.state, ///
			absorb(hhid wave) vce(cluster hhid) residuals(TWFE_residuals)
		
		keep hhid wave w_farm_size_agland TWFE_residuals 
		save "${root}/Stata Code/Stata Data Landing/TWFE_fert_residuals.dta", replace
	restore