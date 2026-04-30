// Will Hankins edit 8/12/25
	clear all      // clears data, value labels, saved results, and programs
	set more off   // prevents output from pausing with "more"
	cd "C:\Users\Will\OneDrive - The Ohio State University\RA\Data\EPAR Nigeria"
	global raw_folder "C:\Users\Will\OneDrive - The Ohio State University\RA\Admin\LSMS-Agricultural-Indicators-Code-main\LSMS-Agricultural-Indicators-Code-main\Nigeria GHS\Nigeria GHS Wave 5\Raw DTA files"
	
	//general data
		use "C:\Users\Will\OneDrive - The Ohio State University\RA\Data\cleaned_general_data.dta", clear
	
		//droping multiple loans focusing on farming loans
		duplicates drop hhid wave, force
		
	//merge on farming expenses
		//labor expenses (human and rented animals)
		merge 1:1 hhid wave using "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\labor_expenditure_data.dta", gen(m1)
			drop if m1==2
			drop m1
			
		//land expenses (land purchases, land rents, legal costs)
		merge 1:1 hhid wave using "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\land_expenditure_data.dta", gen(m1)
			drop if m1==2
			drop m1
			
		//livestock expenses (animal purchases and cost of care)
		merge 1:1 hhid wave using "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\livestock_expenditure_data.dta", gen(m1)
			drop if m1==2
			drop m1
	
		//input expenses (seeds, fertilizer, pecitcides, and machinery)
		merge 1:1 hhid wave using "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\input_expenditure_data.dta", gen(m1)
			drop if m1==2
			drop m1
	
	//yearly food expenitures
		merge 1:1 hhid wave using "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\master_gen_consumption_flag_expenditures.dta", gen(m1)
			drop if m1==2
			drop m1 
	
	//yearly food expenitures
		merge 1:1 hhid wave using "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\master_planting_food_flag_expenditures.dta", gen(m1)
			drop if m1==2
			drop m1 
	
	//yearly food expenitures
		merge 1:1 hhid wave using "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\master_harvest_food_flag_expenditures.dta", gen(m1)
			drop if m1==2
			drop m1 
	
	
	//yearly food expenitures
		merge 1:1 hhid wave using "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\master_food_flag_expenditures.dta", gen(m1)
			drop if m1==2
			drop m1 
			
		//nonfood gen consumption
		gen non_food_gen_consumption = gen_consumption_flag - food_flag
	
	//ACLED Data
		merge 1:1 hhid wave using "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\ACLED HHID Conflict Data.dta", gen(m1)
			drop if m1==2
			drop m1
	
	//shocks data
		merge 1:1 hhid wave using "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\Shock_index_both_waves_long.dta", gen(m1)
			drop if m1==2
			drop m1
	
	//food security
	merge m:1 hhid wave using "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\Master_Food_Security_indexs_both_waves_long.dta", gen(m1)
			keep if m1==3
			drop m1
	
	//crop share of harvest area
	local vars w_total_harv_area_banana w_total_harv_area_beanc w_total_harv_area_cassav w_total_harv_area_cocoa w_total_harv_area_grdnt ///
		w_total_harv_area_maize w_total_harv_area_millet w_total_harv_area_rice w_total_harv_area_sorgum ///
		w_total_harv_area_soy w_total_harv_area_swtptt w_total_harv_area_yam
		
	foreach v of local vars{
		
		
		gen `v'_share = `v'/w_farm_area
		
		replace `v'_share=0 if `v'_share==.
		
	}
	
	//preping data to send
	egen total_farm_expense = rowtotal(total_input_exp land_total_exp labor_expense_total animal_total_exp)
	
	keep if ag_hh==1
	
	keep ag_plot_formal_rights_hh farming_loan_total_amount gen_consumption_flag total_farm_expense total_input_exp land_total_exp labor_expense_total animal_total_exp harvest_food_flag planting_food_flag ///
				any_arv_farm_loan any_approved any_applied ///
				w_farm_size_agland w_farm_size_agland2 w_farm_area w_farm_area2 ///  
				w_value_crop_production w_value_assets w_nonfarm_income ///
				 w_lvstck_holding_tlu ///  
				ag_plot_formal_rights_hh ///
				income_shock food_shock price_shock ///
				head_maritial_status head_age head_sex head_educ_0_7 member adult_member ///
				state wave hhid eawave ea ///
				probability_moderately_insecure probability_severly_insecure FCS_index HDDS_index ///
				fatal_* *_share ///
				internet_access bank_distance micro_fin_distance phone_access farming_loan_total_amount ///
				farm_size_halves total_fert_kg_ha w_pest_rate w_org_fert_rate large_farm state ///
				non_farming_loan food_flag non_food_gen_consumption ///
				seed_exp fertilizer_exp pecticide_exp machine_exp fert_pest_mach_transport_exp  fert_pest_total_exp  non_seed_total_input_exp ///
				total_fert_kg_ha w_pest_rate w_org_fert_rate w_labor_hired_HA ///
				 w_kgs_harvest_banana w_kgs_harvest_beanc w_kgs_harvest_cassav w_kgs_harvest_cocoa w_kgs_harvest_grdnt ///
				 w_kgs_harvest_maize w_kgs_harvest_millet w_kgs_harvest_rice w_kgs_harvest_sorgum w_kgs_harvest_soy w_kgs_harvest_swtptt w_kgs_harvest_yam ///
				 lender_group lender_type
	
	egen consumption_production = rowtotal(w_kgs_harvest_cassav w_kgs_harvest_maize w_kgs_harvest_millet w_kgs_harvest_sorgum w_kgs_harvest_swtptt w_kgs_harvest_yam w_kgs_harvest_banana w_kgs_harvest_rice)
	
	egen non_consumption_production = rowtotal(w_kgs_harvest_beanc w_kgs_harvest_cocoa w_kgs_harvest_grdnt)
	
	replace consumption_production = consumption_production/w_farm_size_agland
	replace non_consumption_production = non_consumption_production/w_farm_size_agland
	
	gen food_ratio = non_consumption_production/consumption_production
	
	rename fert_pest_mach_transport fert_pest_mach_tran_exp
	
	// Remove variable labels
	ds
	foreach v of varlist `r(varlist)' {
		label variable `v' ""
	}

	// Remove value labels (convert labelled numeric vars to pure numeric)
	foreach v of varlist _all {
		local lbl : value label `v'
		if "`lbl'" != "" {
			label values `v'
		}
	}
	
	//drop label defintions
	label drop _all
	
	//keep observations found in both waves
	duplicates tag hhid, gen(tag)
	drop if tag==0
	drop tag
	
	//interaction term
	gen loanxw_farm_size = w_farm_size_agland*any_arv_farm_loan
	
	//logged data for output	
	foreach v of varlist total_farm_expense gen_consumption_flag total_input_exp ///
	land_total_exp labor_expense_total animal_total_exp ///
	w_farm_size_agland w_farm_size_agland2 food_flag non_food_gen_consumption ///
	seed_exp fertilizer_exp pecticide_exp machine_exp fert_pest_mach_tran_exp fert_pest_total_exp non_seed_total_input_exp ///
	total_fert_kg_ha w_pest_rate w_org_fert_rate w_labor_hired_HA ///
	consumption_production non_consumption_production food_ratio harvest_food_flag planting_food_flag{

		* 1. Zero-use indicator
		
		quietly sum `v'
		
		gen `v'_zero = (`v' == 0)

		* 2. Log variable
		//gen ln_`v' = (`v'-r(mean))/r(sd)
		
		gen ln_`v' = .
		replace ln_`v' = log(`v') //if `v' > 0
		//replace ln_`v' = 0        if `v' == 0
	}
	
	//getting stuff for robustness checks
	preserve
		xtile land_quartile = w_farm_size_agland if wave == 4, nq(4)
		xtile land_tertile = w_farm_size_agland if wave == 4, nq(3)
		xtile land_halve = w_farm_size_agland if wave == 4, nq(2)
		xtile land_q5 = w_farm_size_agland if wave == 4, nq(5)
		gen large_farm_dummy = (land_q5 == 5)
		keep if wave == 4
		keep hhid land_quartile land_tertile land_halve large_farm_dummy
		
		tempfile tiles
		save `tiles'
	restore
	
	merge m:1 hhid using `tiles', nogen
	
	
	//exporting for R
	save "C:\Users\Will\OneDrive - The Ohio State University\RA\Data\DML Cleaned Data.dta", replace
	