//this program collects the primary imported data from "Improt Wave 5.do" and "Import Wave 4.do"
//we then proceed with additional data cleaning and harmonizing of variable across survey waves
	clear all      // clears data, value labels, saved results, and programs
	set more off   // prevents output from pausing with "more"

//running pre req files
	do "${base}/Stata Control Covariate Collection and Cleaning Scripts/Import Wave 4.do"	
	do "${base}/Stata Control Covariate Collection and Cleaning Scripts/Import Wave 5.do"
	
//appending data
	use "${root}/Stata Code/Stata Data Landing/import_data_w5.dta", clear
	append using "${root}/Stata Code/Stata Data Landing/import_data_w4.dta" 
	
	//total fertilizer use statistic
	egen total_fert_kg_ha = rowtotal(w_npk_rate w_org_fert_rate w_inorg_fert_rate)
	
	//fixing some flags
		//loan status
			replace loan_status = 0 if loan_status == 2 //approved but pending distribution loands assigned nontreated
			replace loan_status = 0 if loan_status == 3 //dropping pending loan decisions 
			replace loan_status = 0 if loan_status == 4 //loan denied
		
		//sex flag (MALE==1, FEMALE==0)
			replace head_sex = 0 if head_sex == 2
			
		//maritial status
			replace head_maritial_status = 1 if inlist(head_maritial_status,1,2,3) //married (monogamous/polygamous/infomral union)
			replace head_maritial_status = 0 if inlist(head_maritial_status,4,5,6,7) //not married (divorced/separated/widowed/never married)
			
		//loan source categories - not used in core analysis but preserved for exploration by readers
				
				/* WAVE 5
				COMMERCIAL/RETAIL/MORTGAGE BANK.......................1
				SAVINGS CLUB/ASSOCIATION..............................2
				ROSCA/ASUSU/ESUSU/ADASHE/AJO/ASCA.....................3
				EMPLOYEE/UNION WELFARE FUND...........................4
				SAVINGS AND CREDIT COOPERATIVE ORGANIZATION (SACCO)...5
				MICROFINANCE BANK/INSTITUTION/COMPANIES...............6
				BURIAL SOCIETIES.....................................10
				VILLAGE SAVINGS AND LOAN ASSOCIATIONS (VSLAS)........11
				NEOBANKS (100% DIGITAL BANKS)/ MOBILE NETWORK
				OPERATORS (MNO) / MOBILE MONEY OPERATOR/AGENT........12
				LOCAL/VILLAGE MONEY LENDER .........................15
				NEIGHBOUR/FRIEND/RELATIVE/NON-HH INDIVIDUAL..........17
				NGOS.................................................18
				WOMEN GROUP/ ASSOCIATION.............................19
				VENDOR/HIRE PURCHASE.................................20
				OTHER (SPECIFY)......................................96
				*/
				
				/* WAVE 4
				1. COOPERATIVE SOCIETY
				2. SAVINGS ASSOCIATION
				3. MICRO FINANCE
				4. BANK
				5. ADASHI/ESUSU/AJO
				6. FRIENDS & fam; RELATIVES
				7. MONEY LENDERS
				8. HIRE PURCHASE
				9. OTHER (SPECIFY)
				*/
			
	//renaming more goodly
		rename (s5bq8 s5bq14) (phone_access internet_access)
	
	//loan reasoning groups
		gen loan_farming = (loan_reason==1)
		gen loan_nonfarming = (loan_reason==5)
		gen loan_misc = (loan_reason==7)
		gen loan_education = (loan_reason==8)
		gen loan_general_consumption = (loan_reason==11)
		gen loan_health = (loan_reason==12)
			
	//getting loan acceptances
		foreach v in loan_farming {
			gen approv_`v' = `v'
			replace approv_`v' = 0 if loan_status == 0
		}
		
	//winsorzing loans
	winsor2 loan_amount_recieved, replace cuts(0 99)
	
	//changing for readability
	replace w_value_assets = w_value_assets/1000
	replace w_nonfarm_income = w_nonfarm_income/1000
	replace w_value_crop_production = w_value_crop_production/1000

	//livestock dominant flag - winsorize first
	winsor2 lvstck_holding_tlu, replace cut(0 99)
	rename lvstck_holding_tlu w_lvstck_holding_tlu
	
	//renaming for clarity
	rename formal_land_rights_hh ag_plot_formal_rights_hh

	//counts for any approval for farming loans and total loan amounts
		preserve

		gen farming_loan_total_amount = loan_amount_recieved if approv_loan_farming==1
		collapse (max) any_arv_farm_loan = approv_loan_farming ///
				 (sum) farming_loan_total_amount, by(hhid wave)
		
		tempfile farming_loan_approv
		save `farming_loan_approv', replace
		
		restore
		
		merge m:1 hhid wave using `farming_loan_approv', nogen
	
	//got a nonfarming loan indicator
	preserve
		gen non_farming_loan = (loan_reason > 1 & loan_reason!=.)
		collapse (max) non_farming_loan, by(hhid wave)
		
		tempfile non_farming_loan_approv
		save `non_farming_loan_approv', replace
	restore

	merge m:1 hhid wave using `non_farming_loan_approv', nogen
	
	//saving
	save "${root}/Stata Code/Stata Data Landing/cleaned_general_data.dta", replace