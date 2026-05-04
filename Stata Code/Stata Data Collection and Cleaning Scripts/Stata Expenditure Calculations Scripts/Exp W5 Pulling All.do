//This file runs the subscripts that collect nonfarm expenditure data, then appends the data by wave for use in the DML data prep script.
	clear all      // clears data, value labels, saved results, and programs
	set more off   // prevents output from pausing with "more"
		
	//doing pre req files
	do "${root}/Stata Code/Stata Data Collection and Cleaning Scripts/Stata Expenditure Calculations Scripts/Exp W5 Nonfood Expenditures.do"
	do "${root}/Stata Code/Stata Data Collection and Cleaning Scripts/Stata Expenditure Calculations Scripts/Exp W5 Food Expenditures.do"
		
	//pulling data from pre reqs
		use "${root}/Stata Code/Stata Data Landing/food_expenditures_w5.dta", clear
		append using "${root}/Stata Code/Stata Data Landing/nonfood_expenditures_household_w5.dta"

	//grouping consumption as it relates to spending categories based on 
		//categories used in classifying loan purpose in the questionaire:
		//we keep all the codes in order for easy of reading
			//some of these categories are not explicitly used but are left in to inform the reader regarding farm expenses classifications
		gen item_group = .
		replace item_group = 7 if item_cd == 1
		replace item_group = 7 if item_cd == 2
		replace item_group = 11 if inrange(item_cd, 101, 105)
		replace item_group = 11 if inrange(item_cd, 201,221)
		replace item_group = 9 if inrange(item_cd, 222,223)
		replace item_group = 11 if inrange(item_cd, 224,238)
		replace item_group = 14 if inrange(item_cd, 239,243)
		replace item_group = 11 if item_cd == 244
		replace item_group = 6 if inrange(item_cd, 245, 246)
		replace item_group = 11 if item_cd == 247
		replace item_group = 6 if item_cd == 248
		replace item_group = 11 if item_cd == 249
		replace item_group = 11 if inrange(item_cd, 301, 352)
		replace item_group = 15 if item_cd == 353
		replace item_group = 10 if item_cd == 354
		replace item_group = 9 if inrange(item_cd, 355, 357)
		replace item_group = 15 if inrange(item_cd, 358, 359)
		replace item_group = 11 if inrange(item_cd, 360,362)
		replace item_group = 9 if item_cd == 363
		replace item_group = 8 if item_cd == 364
		replace item_group = 11 if item_cd == 365
		replace item_group = 8 if item_cd == 401
		replace item_group = 11 if item_cd == 402
		replace item_group = 5 if item_cd == 403
		replace item_group = 12 if item_cd == 404
		replace item_group = 13 if item_cd == 405
		replace item_group = 6 if item_cd == 406
		replace item_group = 9 if item_cd == 407
		replace item_group = 1 if item_cd == 501
		replace item_group = 4 if inrange(item_cd, 502,503)
		replace item_group = 2 if inrange(item_cd, 504,505)
		replace item_group = 96 if item_cd == 506
		replace item_group = 4 if item_cd == 507
		replace item_group = 3 if item_cd == 508
		replace item_group = 4 if inrange(item_cd, 509,510)
			
		//labels based on loan purpose from credit module (for this script only 7 an 11 are relavent)
		//individual farm expense scripts handle expenditures which would be classified 1-4
		label define item_group_lbl ///
			1  "BUY LAND" ///
			2  "BUY LIVESTOCK" ///
			3  "BUY FARM TOOLS/IMPLEMENTS" ///
			4  "BUY FARM INPUTS (SEEDS, FERTILIZER)" ///
			5  "PURCHASE OF INPUTS/ WORKING CAPITAL FOR NONFARM BUSINESS" ///
			6  "HOUSE CONSTRUCTION/PURCHASE/REPAIRS/IMPROVEMENT" ///
			7  "BUY FOOD STUFF" ///
			8  "PAY FOR EDUCATION EXPENSES" ///
			9  "PAY FOR HEALTH EXPENSES" ///
			10 "PAY FOR CEREMONIES EXPENSES" ///
			11 "BUY OTHER NON-FOOD CONSUMPTION GOODS/SERVICES" ///
			12 "REPAY OTHER DEBTS" ///
			13 "PAY HOUSE RENT" ///
			14 "VEHICLE REPAIR, MAINTENANCE OR PURCHASE" ///
			15 "HOLIDAYS" ///
			16 "PAYMENT FOR RANSOM" ///
			96 "OTHER (SPECIFY)"
			
		label values item_group item_group_lbl
		
		//higher level use classes	
		gen food_flag = (item_group == 7)
		gen gen_consumption_flag = inlist(item_group,7,11)
					
		//collecting data by nonfarm food and nonfarm total expenditures
		foreach v in food_flag gen_consumption_flag{
			preserve
				collapse (sum) item_expenditure ,by(hhid `v' wave)
				
				reshape wide item_expenditure, i(hhid wave) j(`v')
				rename (item_expenditure0 item_expenditure1) (non_`v' `v')
				
				save "${root}/Stata Code/Stata Data Landing/w5_`v'_expenditures.dta", replace
			restore
		}