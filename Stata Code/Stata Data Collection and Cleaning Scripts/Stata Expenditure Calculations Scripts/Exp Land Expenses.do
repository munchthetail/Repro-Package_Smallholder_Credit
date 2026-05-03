// Will Hankins edit 9/16/25
	clear all      // clears data, value labels, saved results, and programs
	set more off   // prevents output from pausing with "more"

	
	//Wave 5
	global raw_folder "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\LSMS-Agricultural-Indicators-Code-main\LSMS-Agricultural-Indicators-Code-main\Nigeria GHS\Nigeria GHS Wave 5\Raw DTA files"

	//Post Planting
		//agricultural survey
			//land expensitures
				use "${raw_folder}/sect11b1_plantingw5.dta", clear
				
				keep hhid plotid s11b1q3 s11b1q5 s11b1q11 s11b1q20 s11b1q21 s11b1q22 s11b1q23 s11b1q30 s11b1q21_os s11b1q23_os
				rename (s11b1q3 s11b1q5 s11b1q11 s11b1q20 s11b1q21 s11b1q22 s11b1q23 s11b1q30 s11b1q21_os s11b1q23_os) /// 
					(land_purchase_dt land_purchase_cost land_legal_titling_expense land_rent rent_period payment_in_kind_eqivalent_rent PIKE_period share_crop_value_in_kind_expense rent_period_other PIKE_period_other)
				
				replace land_purchase_dt = . if land_purchase_dt==9999 //IDK reponse
				replace land_purchase_cost=0 if land_purchase_dt<2022 | land_purchase_dt==.
				replace land_legal_titling_expense=0 if land_purchase_dt<2022 | land_purchase_dt==.
				 
				 
				//NOTE: for the purpose of days calculation, we assume dry/wet season covers roughly 6 months, for the purpose of sharecropping, we assume the payment covers 1 year
				//land purchse
					gen days_sum1 = .
					replace days_sum1 = 365/2 if land_purchase_dt==2023
					replace days_sum1 = 365+365/2 if land_purchase_dt==2022

					gen year_converter = .
					replace year_converter = days_sum1/365
					//replace land_purchase_cost = land_purchase_cost/year_converter if year_converter>1 & !missing(land_purchase_cost) & !missing(year_converter)
					//replace land_legal_titling_expense = land_legal_titling_expense/year_converter if year_converter>1 & !missing(land_legal_titling_expense) & !missing(year_converter)
					replace days_sum1 = days_sum1/year_converter if year_converter>1  & !missing(year_converter)
				
				//renting
					gen days_sum2 = .
					replace days_sum2 = 365 if rent_period == 1
					replace days_sum2 = 365/2 if inlist(rent_period,2,3,4)
					// couldn't define for this period --- NO FIX TIME  OR YEARS  DEPENDING  WHEN THE OWNER  WILL REFUND THE AMOUNTS. 
						// PENDING WHEN IT WILL BE COLLECTED
						// PENDING WHEN IT IS ASKED BACK
						// NO FIXED PERIODS   DEPENDING  WHEN MONEY  IS AVAILABLE.
					replace days_sum2 = 365*1.6 if rent_period_other == "1 .6"
					replace days_sum2 = 365*10 if rent_period_other == "10 YEARS"
					replace days_sum2 = 365*15 if rent_period_other == "15"
					replace days_sum2 = 365*2 if rent_period_other == "2 YEARS"
					replace days_sum2 = 365*2 if rent_period_other == "2 YEARS."
					replace days_sum2 = 365*2 if rent_period_other == "2YEARS."
					replace days_sum2 = 365*2 if rent_period_other == "2YEARS."
					replace days_sum2 = 365*2 if rent_period_other == "TWO YEARS"
					replace days_sum2 = 365*2 if rent_period_other == "EVERY TWO YEARS"
					replace days_sum2 = 365/2*3 if rent_period_other == "3 RAINY SEASONS"
					replace days_sum2 = 365*3 if rent_period_other == "3 YEARS"
					replace days_sum2 = 365*3 if rent_period_other == "3 YEARS."
					replace days_sum2 = 365*3 if rent_period_other == "FOR 3 YEARS"
					replace days_sum2 = 365*3 if rent_period_other == "THREE YEARS"
					replace days_sum2 = 365*4 if rent_period_other == "4 YEARS"
					replace days_sum2 = 365*4 if rent_period_other == "4 YEARS PERIOD"
					replace days_sum2 = 365*4 if rent_period_other == "4YEARS"
					replace days_sum2 = 365*4 if rent_period_other == "FOUR YEARS"
					replace days_sum2 = 365*5 if rent_period_other == "5"
					replace days_sum2 = 365*5 if rent_period_other == "5 YEARS"
					replace days_sum2 = 365*5 if rent_period_other == "FIVE FARMING SEASONS"
					replace days_sum2 = 365*6 if rent_period_other == "6 YEARS"
					replace days_sum2 = 365 if rent_period_other == "FOR THE PLANTING AND HARVEST PERIOD."
					
					replace year_converter = .
					replace year_converter = days_sum2/365
					replace land_rent = land_rent/year_converter if !missing(year_converter)
					replace days_sum2 = days_sum2/year_converter if !missing(year_converter)				
				
				//payment in kind and sharecropping
					gen days_sum3 = .
					replace days_sum3 = 365 if PIKE_period == 1
					replace days_sum3 = 365/2 if inlist(PIKE_period,2,3,4)
					replace year_converter = .
					replace year_converter = days_sum3/365
					replace payment_in_kind_eqivalent_rent = payment_in_kind_eqivalent_rent/year_converter if !missing(year_converter)
					
					
					gen days_sum4 = .
					replace days_sum4 = 365 if share_crop_value_in_kind_expense != . & share_crop_value_in_kind_expense != 0
					replace year_converter = .
					replace year_converter = days_sum4/365
					replace share_crop_value_in_kind_expense = share_crop_value_in_kind_expense/year_converter if !missing(year_converter)
					
				//pulling data together for one variable of expenditures on land
					egen days = rowmax(days_*)
					egen land_rent_total = rowtotal(land_rent payment_in_kind_eqivalent_rent share_crop_value_in_kind_expense)
					egen land_purchase_titling = rowtotal(land_legal_titling_expense land_purchase_cost)
					
					winsor2 land_rent_total land_purchase_titling, replace cut(0 99)
					
					collapse (sum) land_rent_total land_purchase_titling (max) days, by(hhid)
					gen land_total_exp = land_rent_total + land_purchase_titling 
					
					gen wave=5
					drop if days==. & land_total_exp!=0 //dropping people with alternative payment schedules that cannot be accurately classified under a given day schedule
					drop days
					
				tempfile land_w5
				save `land_w5'
						
	//Wave 4
	global raw_folder "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\LSMS-Agricultural-Indicators-Code-main\LSMS-Agricultural-Indicators-Code-main\Nigeria GHS\Nigeria GHS Wave 4\Raw DTA files"
	
	//Post Planting
		//agricultural survey
			//land expensitures
				use "${raw_folder}/sect11b1_plantingw4.dta", clear
				keep hhid plotid s11b1q3 s11b1q5 s11b1q8a s11b1q13 s11b1q13a s11b1q14 s11b1q14a  s11b1q14b1 s11b1q13a_os // s11b1q23_os Other category for PIKE doesn't seems to be in data set resulting in 2 observations dropped
				drop if s11b1q14a==5
				rename (s11b1q3 s11b1q5 s11b1q8a s11b1q13 s11b1q13a s11b1q14 s11b1q14a  s11b1q14b1 s11b1q13a_os) /// 
					(land_purchase_dt land_purchase_cost land_legal_titling_expense land_rent rent_period payment_in_kind_eqivalent_rent PIKE_period share_crop_value_in_kind_expense rent_period_other)
				
				replace land_purchase_dt = . if land_purchase_dt==9999 //IDK reponse
				replace land_purchase_cost=0 if land_purchase_dt<2017 | land_purchase_dt==.
				replace land_legal_titling_expense=0 if land_purchase_dt<2017| land_purchase_dt==.
				 
				//NOTE: for the purpose of days calculation, we assume dry/wet season covers roughly 6 months, for the purpose of sharecropping, we assume the payment covers 1 year
				//land purchse
					gen days_sum1 = .
					replace days_sum1 = 365/2 if land_purchase_dt==2018
					replace days_sum1 = 365+365/2 if land_purchase_dt==2017

					gen year_converter = .
					replace year_converter = days_sum1/365
					replace days_sum1 = days_sum1/year_converter if year_converter>1  & !missing(year_converter)
				
				//renting
					gen days_sum2 = .
					replace days_sum2 = 365 if rent_period == 1
					replace days_sum2 = 365/2 if inlist(rent_period,2,3,4)
					// couldn't define for this period --- NO FIX TIME  OR YEARS  DEPENDING  WHEN THE OWNER  WILL REFUND THE AMOUNTS. 
						// PENDING WHEN IT WILL BE COLLECTED
						// PENDING WHEN IT IS ASKED BACK
						// NO FIXED PERIODS   DEPENDING  WHEN MONEY  IS AVAILABLE.
					replace days_sum2 = 365*1.6 if rent_period_other == "1 .6"
					replace days_sum2 = 365*10 if rent_period_other == "10 YEARS"
					replace days_sum2 = 365*15 if rent_period_other == "15"
					replace days_sum2 = 365*2 if rent_period_other == "2 YEARS"
					replace days_sum2 = 365*2 if rent_period_other == "2 YEARS."
					replace days_sum2 = 365*2 if rent_period_other == "2YEARS."
					replace days_sum2 = 365*2 if rent_period_other == "2YEARS."
					replace days_sum2 = 365*2 if rent_period_other == "TWO YEARS"
					replace days_sum2 = 365*2 if rent_period_other == "EVERY TWO YEARS"
					replace days_sum2 = 365/2*3 if rent_period_other == "3 RAINY SEASONS"
					replace days_sum2 = 365*3 if rent_period_other == "3 YEARS"
					replace days_sum2 = 365*3 if rent_period_other == "3 YEARS."
					replace days_sum2 = 365*3 if rent_period_other == "FOR 3 YEARS"
					replace days_sum2 = 365*3 if rent_period_other == "THREE YEARS"
					replace days_sum2 = 365*4 if rent_period_other == "4 YEARS"
					replace days_sum2 = 365*4 if rent_period_other == "4 YEARS PERIOD"
					replace days_sum2 = 365*4 if rent_period_other == "4YEARS"
					replace days_sum2 = 365*4 if rent_period_other == "FOUR YEARS"
					replace days_sum2 = 365*5 if rent_period_other == "5"
					replace days_sum2 = 365*5 if rent_period_other == "5 YEARS"
					replace days_sum2 = 365*5 if rent_period_other == "FIVE FARMING SEASONS"
					replace days_sum2 = 365*6 if rent_period_other == "6 YEARS"
					replace days_sum2 = 365 if rent_period_other == "FOR THE PLANTING AND HARVEST PERIOD."
					
					replace year_converter = .
					replace year_converter = days_sum2/365
					replace land_rent = land_rent/year_converter if !missing(year_converter)
					replace days_sum2 = days_sum2/year_converter if !missing(year_converter)				
				
				//payment in kind and sharecropping
					gen days_sum3 = .
					replace days_sum3 = 365 if PIKE_period == 1
					replace days_sum3 = 365/2 if inlist(PIKE_period,2,3,4)
					replace year_converter = .
					replace year_converter = days_sum3/365
					replace payment_in_kind_eqivalent_rent = payment_in_kind_eqivalent_rent/year_converter if !missing(year_converter)
					
					gen days_sum4 = .
					replace days_sum4 = 365 if share_crop_value_in_kind_expense != . & share_crop_value_in_kind_expense != 0
					replace year_converter = .
					replace year_converter = days_sum4/365
					replace share_crop_value_in_kind_expense = share_crop_value_in_kind_expense/year_converter if !missing(year_converter)
					
				//pulling data together for one variable of expenditures on land
					egen days = rowmax(days_*)
					egen land_rent_total = rowtotal(land_rent payment_in_kind_eqivalent_rent share_crop_value_in_kind_expense)
					egen land_purchase_titling = rowtotal(land_legal_titling_expense land_purchase_cost)
										
					collapse (sum) land_rent_total land_purchase_titling (max) days, by(hhid)
					
					winsor2 land_rent_total land_purchase_titling, replace cut(0 99)
					
					gen land_total_exp = land_rent_total + land_purchase_titling 
					
					gen wave=4
					
					drop if days==. & land_total_exp!=0 //dropping people with alternative payment schedules that cannot be accurately classified under a given day schedule
					drop days
					
				append using `land_w5'

	save "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\land_expenditure_data.dta", replace
