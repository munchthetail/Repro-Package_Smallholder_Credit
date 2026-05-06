//this script produces the balance table in the appendix
	clear all      // clears data, value labels, saved results, and programs
	set more off   // prevents output from pausing with "more"
	
	use "${root}/Stata Code/Stata Data Landing/DML Cleaned Data.dta", clear
	
	//adjust to DML model
	//keep observations found in both waves
	drop if w_farm_size_agland == .
	duplicates tag hhid, gen(tag)
	drop if tag==0
	drop tag
	
	local x w_farm_size_agland w_value_crop_production w_value_assets w_nonfarm_income w_lvstck_holding_tlu ag_plot_formal_rights_hh ///
		 income_shock food_shock price_shock ///
		 head_maritial_status head_age head_sex member adult_member phone_access internet_access probability_moderately_insecure FCS_index non_farming_loan
	
	
	iebaltab `x', grpvar(any_arv_farm_loan) ///
    vce(robust) ///
    rowvarlabels ///
    format(%9.3f) ///
    savetex("${root}/Tables and Figures/balance_table.tex") replace