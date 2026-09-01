// This file collects all data sources for the analysis and does a few last data cleaning steps prior to DML processing.
	clear all      // clears data, value labels, saved results, and programs
	set more off   // prevents output from pausing with "more"
	
	//general data
		use "${root}/Stata Code/Stata Data Landing/cleaned_general_data.dta", clear

		//for pie chart
		preserve
			keep if ag_hh==1
			duplicates tag hhid, gen(tag)
			drop if tag==0
			drop tag
			replace any_loan = 0 if loan_status==0

			keep any_arv_farm_loan non_farming_loan any_loan loan_reason loan_amount_recieved

			save "${root}/Stata Code/Stata Data Landing/Pie Chart Data.dta", replace
		restore


		//droping multiple loans focusing on farming loans
		duplicates drop hhid wave, force
		
	//merge on farming expenses
		//labor expenses (human and rented animals)
		merge 1:1 hhid wave using "${root}/Stata Code/Stata Data Landing/labor_expenditure_data.dta", gen(m1)
			drop if m1==2
			drop m1
			
		//land expenses (land purchases, land rents, legal costs)
		merge 1:1 hhid wave using "${root}/Stata Code/Stata Data Landing/land_expenditure_data.dta", gen(m1)
			drop if m1==2
			drop m1
			
		//livestock expenses (animal purchases and cost of care)
		merge 1:1 hhid wave using "${root}/Stata Code/Stata Data Landing/livestock_expenditure_data.dta", gen(m1)
			drop if m1==2
			drop m1
	
		//input expenses (seeds, fertilizer, pecitcides, and machinery)
		merge 1:1 hhid wave using "${root}/Stata Code/Stata Data Landing/input_expenditure_data.dta", gen(m1)
			drop if m1==2
			drop m1

	//yearly nonfarm (total food and nonfood) expenitures
		merge 1:1 hhid wave using "${root}/Stata Code/Stata Data Landing/master_gen_consumption_flag_expenditures.dta", gen(m1)
			drop if m1==2
			drop m1 	
	
	//yearly food expenitures
		merge 1:1 hhid wave using "${root}/Stata Code/Stata Data Landing/master_food_flag_expenditures.dta", gen(m1)
			drop if m1==2
			drop m1 
					
	//shocks data
		merge 1:1 hhid wave using "${root}/Stata Code/Stata Data Landing/Shock_index_both_waves_long.dta", gen(m1)
			drop if m1==2
			drop m1
	
	//food security
	merge m:1 hhid wave using "${root}/Stata Code/Stata Data Landing/Master_Food_Security_indexs_both_waves_long.dta", gen(m1)
			keep if m1==3
			drop m1
	
	//preping data to send
	egen total_farm_expense = rowtotal(total_input_exp land_total_exp labor_expense_total animal_total_exp)
	
	//nonfood gen consumption
	gen non_food_gen_consumption = gen_consumption_flag - food_flag

	//making sure we are only holding agricultural households via EPAR defintion
	keep if ag_hh==1
	
	//keeping just the variables we need
	keep any_arv_farm_loan gen_consumption_flag total_farm_expense total_input_exp land_total_exp labor_expense_total animal_total_exp ///
				w_farm_size_agland ///  
				w_value_crop_production w_value_assets w_nonfarm_income w_lvstck_holding_tlu ///  
				ag_plot_formal_rights_hh ///
				income_shock food_shock price_shock ///
				head_maritial_status head_age head_sex member adult_member ///
				state wave hhid lender_group ///
				probability_moderately_insecure FCS_index ///
				internet_access phone_access farming_loan_total_amount ///
				non_farming_loan food_flag non_food_gen_consumption total_fert_kg_ha any_loan
	
	//remove variable labels
	ds
	foreach v of varlist `r(varlist)' {
		label variable `v' ""
	}

	//any loan
	gen ln_farm_size = log(w_farm_size_agland)
	
	//remove value labels (convert labelled numeric vars to pure numeric)
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
	
	//logged data for output	
	foreach v of varlist total_farm_expense gen_consumption_flag total_input_exp ///
	land_total_exp labor_expense_total animal_total_exp ///
	w_farm_size_agland food_flag non_food_gen_consumption ///
	total_fert_kg_ha {
		gen ln_`v' = .
		replace ln_`v' = log(`v') //if `v' > 0
	}
	
	//exporting for R
	save "${root}/Stata Code/Stata Data Landing/DML Cleaned Data.dta", replace
