// Will Hankins edit 9/16/25
	clear all      // clears data, value labels, saved results, and programs
	set more off   // prevents output from pausing with "more"
	cd "C:\Users\Will\OneDrive - The Ohio State University\RA\Data\EPAR Nigeria"
	
	//doing pre req files
		do "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Exp W5 Pulling All v2.do"
		do "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Exp W4 Pulling All v2.do"
	
	//pulling master data
		use "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\w5_item_group_expenditures_master.dta", clear
		append using "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\w4_item_group_expenditures_master.dta"
		
		export delimited using "C:\Users\Will\OneDrive - The Ohio State University\RA\Data\Random Stats\Consumtion Statistics.csv", replace
		
		save "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\master_item_group_expenditures.dta", replace
		
	//spending groups
		local vars productivity_flag farm_exp_flag nonfarm_business_exp_flag food_flag gen_consumption_flag essential_flag harvest_food_flag planting_food_flag
		
		foreach v of local vars {
			preserve
				use "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\w5_`v'_expenditures.dta", replace
				append using "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\w4_`v'_expenditures.dta"
				
				save "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\master_`v'_expenditures.dta", replace
			restore
		}