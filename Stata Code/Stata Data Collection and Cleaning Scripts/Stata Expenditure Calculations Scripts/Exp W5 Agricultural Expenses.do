// Will Hankins edit 9/16/25
	clear all      // clears data, value labels, saved results, and programs
	set more off   // prevents output from pausing with "more"
	cd "C:\Users\Will\OneDrive - The Ohio State University\RA\Data\EPAR Nigeria"
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
					egen item_expenditure = rowtotal(land_legal_titling_expense land_purchase_cost land_rent payment_in_kind_eqivalent_rent share_crop_value_in_kind_expense)
					
					collapse (sum) item_expenditure (max) days, by(hhid)
					gen postplant = 1
					gen item_cd = 501 
					keep if item_expenditure!=0
					drop if days==. //dropping people with alternative payment schedules that cannot be accurately classified under a given day schedule
					
				tempfile expend_a
				save `expend_a'
				
			//labor expensitures 
				use "${raw_folder}/sect11c1b_plantingw5.dta", clear
					keep if s11c1q2_1 == 1
					keep hhid plotid s11c1q3_1 s11c1q4_1 s11c1q6_1
					rename (s11c1q3_1 s11c1q4_1 s11c1q6_1) (number_hired ave_days_hired ave_cost_per_worker_per_day)
					gen item_expenditure = number_hired*ave_days_hired*ave_cost_per_worker_per_day
					
					collapse (sum) item_expenditure, by(hhid)
					
					gen item_cd = 502

					gen postplant = 1
					gen days = 365
					
					keep hhid item_expenditure days postplant item_cd
					
					tempfile expend_b
					save `expend_b'
					
			//seed expenditures --- purchase of seeds expenses
				use "${raw_folder}/sect11e1_plantingw5.dta", clear
					keep hhid s11eq11
					rename s11eq11 item_expenditure
					
					collapse (sum) item_expenditure, by(hhid)
					gen days = 365
					gen item_cd = 503

					gen postplant = 1
					
					tempfile expend_c
					save `expend_c'
					
			//seed expenditures --- transportation expenses for seeds aquisition
				use "${raw_folder}/sect11e2_plantingw5.dta", clear
					keep hhid s11eq16 s11eq17
					egen item_expenditure = rowtotal(s11eq16 s11eq17)
					
					collapse (sum) item_expenditure, by(hhid)
					gen days = 365
					gen item_cd = 503

					gen postplant = 1
					
					tempfile expend_d
					save `expend_d'
					
			//animal expenditures purchases
				use "${raw_folder}/sect11i_plantingw5.dta", clear
					keep hhid animal_cd s11iq18
					rename (s11iq18) (item_expenditure)
					gen days = .
					replace days = 365 if inrange(animal_cd,101,112)
					replace days = 365/4 if inrange(animal_cd,113,118)
					replace days = 365 if inrange(animal_cd,120,123)
					
					collapse (sum) item_expenditure (max) days, by(hhid)
					gen item_cd = 504

					gen postplant = 1
					
					tempfile expend_e
					save `expend_e'
					
			//animal expenditures maintenance 
				use "${raw_folder}/sect11j_plantingw5.dta", clear
					keep hhid livestock_cd s11jq9 s11jq11 s11jq14 s11jq18 s11jq20 s11jq22 s11jq24
					rename (s11jq9 s11jq11 s11jq14 s11jq18 s11jq20 s11jq22 s11jq24) (vaccination other_vet water feed hired_help damages_paid other_costs)
					egen item_expenditure = rowtotal(vaccination other_vet water feed hired_help damages_paid other_costs)
					
					collapse (sum) item_expenditure, by(hhid)
					gen days = 365
					gen item_cd = 505

					gen postplant = 1
					
					tempfile expend_f
					save `expend_f'
					
			//extension services
				use "${raw_folder}/sect11l2_plantingw5.dta", clear
					keep hhid source_cd s11l2q8 
					rename s11l2q8 item_expenditure
					
					collapse (sum) item_expenditure, by(hhid)
					gen days = 365
					gen item_cd = 506

					gen postplant = 1
					
					tempfile expend_g
					save `expend_g'
					
					
	//Harvest
		//agricultural survey			
			//labor expensitures - PREHARVEST
				use "${raw_folder}/secta2b_harvestw5.dta", clear
					keep if sa2bq1_1 == 1
					keep hhid plotid sa2bq2_1 sa2bq3_1 sa2bq5_1
					rename (sa2bq2_1 sa2bq3_1 sa2bq5_1) (number_hired ave_days_hired ave_cost_per_worker_per_day)
					gen item_expenditure = number_hired*ave_days_hired*ave_cost_per_worker_per_day
					
					collapse (sum) item_expenditure, by(hhid)
					
					gen item_cd = 507

					gen postplant = 0
					gen days = 365
										
					tempfile expend_h
					save `expend_h'
					
			//input expenses - animal rental cost
				use "${raw_folder}/secta11c2_harvestw5.dta", clear
					keep hhid plotid s11c2q17 s11c2q18
					rename (s11c2q17 s11c2q18) (animal_rent animal_feed)
					egen item_expenditure = rowtotal(animal_rent animal_feed)
					
					collapse (sum) item_expenditure, by(hhid)
					gen days = 365
					gen item_cd = 508

					gen postplant = 0
					
					tempfile expend_i
					save `expend_i'
					
			//input expenditures namely fertilizer and machinery purchase
				use "${raw_folder}/secta11c3_harvestw5.dta", clear
					keep hhid inputid s11c3q5 s11c3q11
					rename (s11c3q5 s11c3q11) (input_purchase input_rent)
					egen item_expenditure = rowtotal(input_purchase input_rent)
					
					collapse (sum) item_expenditure, by(hhid)
					gen days = 365
					gen item_cd = 509

					gen postplant = 0
					
					tempfile expend_j
					save `expend_j'
					
			//input expenditures namely fertilizer and machinery purchase  --- transportation expenses
				use "${raw_folder}/secta11c3q12_harvestw5.dta", clear			
					keep hhid s11c3q12
					rename s11c3q12 item_expenditure
					
					collapse (sum) item_expenditure, by(hhid)
					gen days = 365
					gen item_cd = 509

					gen postplant = 0
					
					tempfile expend_k
					save `expend_k'
					
			//labor expensitures - PREHARVEST
				use "${raw_folder}/sectaphl2_harvestw5.dta", clear
					keep if phl_q02_1 == 1
					keep hhid cropcode phl_q03_1 phl_q04_1 phl_q06_1
					rename (phl_q03_1 phl_q04_1 phl_q06_1) (number_hired ave_days_hired ave_cost_per_worker_per_day)
					gen item_expenditure = number_hired*ave_days_hired*ave_cost_per_worker_per_day
					
					collapse (sum) item_expenditure, by(hhid)
					
					gen item_cd = 510 

					gen postplant = 0
					gen days = 365
										
					tempfile expend_l
					save `expend_l'
			
			
	//pulling docs
	use `expend_a', clear
	append using `expend_b'
	append using `expend_c'
	append using `expend_d'
	append using `expend_e'
	append using `expend_f'
	append using `expend_g'
	append using `expend_h'
	append using `expend_i'
	append using `expend_j'
	append using `expend_k'
	append using `expend_l'
	
	label define item_lbl ///
		501 "501. Land Expenditures" ///
		502 "502. Hired Agricultural Worker Pay" ///
		503 "503. Purchased Seed Cost" ///
		504 "504. Animal Purchases" ///
		505 "505. Livestock Upkeep Expenses" ///
		506 "506. Purchased Extension/Advice Services" ///
		507 "507. Hired Agricultural Worker Pay Pre Harvest" ///
		508 "508. Rented Animal Input Expenses" ///
		509 "509. Fertilizer Purchase" ///
		510 "510. Hired Agricultural Worker Pay Post Harvest"
		
	label values item_cd item_lbl
	
	gen wave = 5
	
	save "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\agricultural_expenditures_household_w5.dta", replace
			
					
					
				