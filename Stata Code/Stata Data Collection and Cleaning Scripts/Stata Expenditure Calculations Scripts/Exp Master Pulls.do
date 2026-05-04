// This file runs the subscripts that collect nonfarm expenditure data, then appends the data by wave for use in the DML data prep script.
	clear all      // clears data, value labels, saved results, and programs
	set more off   // prevents output from pausing with "more"
	
	//doing pre req files
	do "${base}/Stata Expenditure Calculations Scripts/Exp W5 Pulling All.do"
	do "${base}/Stata Expenditure Calculations Scripts/Exp W4 Pulling All.do"

	//collecting nonfarm expenditures data
	local vars food_flag gen_consumption_flag
	
	foreach v of local vars {
		preserve
			use "${root}/Stata Code/Stata Data Landing/w5_`v'_expenditures.dta", replace
			append using "${root}/Stata Code/Stata Data Landing/w4_`v'_expenditures.dta"
			
			save "${root}/Stata Code/Stata Data Landing/master_`v'_expenditures.dta", replace
		restore
	}