// Will Hankins edit 8/12/25
	clear all      // clears data, value labels, saved results, and programs
	set more off   // prevents output from pausing with "more"
	cd "C:\Users\Will\OneDrive - The Ohio State University\RA\Data\EPAR Nigeria"
	global raw_folder "C:\Users\Will\OneDrive - The Ohio State University\RA\Admin\LSMS-Agricultural-Indicators-Code-main\LSMS-Agricultural-Indicators-Code-main\Nigeria GHS\Nigeria GHS Wave 5\Raw DTA files"
	
	ssc install ietoolkit, replace
	
	use "C:\Users\Will\OneDrive - The Ohio State University\RA\Data\DML Cleaned Data.dta", clear
	
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
    savetex("balance_table.tex") replace