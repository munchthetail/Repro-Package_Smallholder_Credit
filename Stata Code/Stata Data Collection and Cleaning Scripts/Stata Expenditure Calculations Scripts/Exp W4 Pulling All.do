//This file runs the subscripts that collect nonfarm expenditure data, then appends the data by wave for use in the DML data prep script.
	clear all      // clears data, value labels, saved results, and programs
	set more off   // prevents output from pausing with "more"

	//doing pre req files
	do "${root}/Stata Code/Stata Data Collection and Cleaning Scripts/Stata Expenditure Calculations Scripts/Exp W4 Nonfood Expenditures.do"
	do "${root}/Stata Code/Stata Data Collection and Cleaning Scripts/Stata Expenditure Calculations Scripts/Exp W4 Food Expenditures.do"

	//pulling data from pre reqs
		use "${root}/Stata Code/Stata Data Landing/food_expenditures_w4.dta", clear
		append using "${root}/Stata Code/Stata Data Landing/nonfood_expenditures_household_w4.dta"

	//grouping consumption:
			gen item_group = .
			replace item_group = 7 if inrange(item_cd, 1, 2)
			replace item_group = 11 if inrange(item_cd, 101, 105)
			replace item_group = 11 if inrange(item_cd, 301, 310)
			replace item_group = 14 if item_cd == 330
			replace item_group = 11 if inrange(item_cd, 311, 315)
			replace item_group = 9 if item_cd == 316
			replace item_group = 11 if inrange(item_cd, 317, 322)
			replace item_group = 14 if inrange(item_cd, 323, 324)
			replace item_group = 11 if item_cd == 325
			replace item_group = 6 if inrange(item_cd, 326, 328)
			replace item_group = 13 if item_cd == 329
			replace item_group = 11 if inrange(item_cd, 401, 441)
			replace item_group = 15 if item_cd == 428
			replace item_group = 10 if item_cd == 429
			replace item_group = 9 if item_cd == 430
			replace item_group = 11 if inrange(item_cd, 501, 508)
			replace item_group = 96 if item_cd == 509
			replace item_group = 9 if item_cd == 510
			replace item_group = 14 if item_cd == 511
			replace item_group = 6 if item_cd == 512
			replace item_group = 11 if item_cd == 513
			replace item_group = 96 if item_cd == 514
			replace item_group = 10 if inrange(item_cd, 515, 517)
			replace item_group = 1 if item_cd == 601
			replace item_group = 4 if inrange(item_cd, 602, 603)
			replace item_group = 2 if inrange(item_cd, 604, 605)
			replace item_group = 96 if item_cd == 606
			replace item_group = 4 if item_cd == 607
			replace item_group = 3 if item_cd == 608
			replace item_group = 4 if inrange(item_cd, 609, 610)
			replace item_group = 8 if item_cd == 701
			replace item_group = 4 if item_cd == 702
			replace item_group = 5 if item_cd == 703
			replace item_group = 12 if item_cd == 704
			replace item_group = 13 if inrange(item_cd, 705, 706)
			
		//labels
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
				
				save "${root}/Stata Code/Stata Data Landing/w4_`v'_expenditures.dta", replace
			restore
		}
