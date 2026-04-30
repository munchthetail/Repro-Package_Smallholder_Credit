// Will Hankins edit 9/16/25
	clear all      // clears data, value labels, saved results, and programs
	set more off   // prevents output from pausing with "more"

	
	//Wave 5
	global raw_folder "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\LSMS-Agricultural-Indicators-Code-main\LSMS-Agricultural-Indicators-Code-main\Nigeria GHS\Nigeria GHS Wave 5\Raw DTA files"

		//Post Planting
			//agricultural survey
				//labor expensitures 
				
				//annual
				
					use "${raw_folder}/sect11c1b_plantingw5.dta", clear
						keep if s11c1q2_1 == 1
						keep hhid plotid s11c1q3_1 s11c1q4_1 s11c1q6_1
						rename (s11c1q3_1 s11c1q4_1 s11c1q6_1) (number_hired ave_days_hired ave_cost_per_worker_per_day)
						gen pp_labor = number_hired*ave_days_hired*ave_cost_per_worker_per_day
						
						collapse (sum) pp_labor, by(hhid)
						
						tempfile pp_labor_w5
						save `pp_labor_w5'
						
		//post harvest
			//agricultural survey
				//input expenses - animal rental cost
				
				//annual
				
					use "${raw_folder}/secta11c2_harvestw5.dta", clear
						keep hhid plotid s11c2q17 s11c2q18
						rename (s11c2q17 s11c2q18) (animal_rent animal_feed)
						egen animal_labor = rowtotal(animal_rent animal_feed)
						
						collapse (sum) animal_labor, by(hhid)
						
						tempfile animal_labor_w5
						save `animal_labor_w5'
						
				//labor expensitures - PREHARVEST
				
				//annual
				
					use "${raw_folder}/secta2b_harvestw5.dta", clear
						keep if sa2bq1_1 == 1
						keep hhid plotid sa2bq2_1 sa2bq3_1 sa2bq5_1
						rename (sa2bq2_1 sa2bq3_1 sa2bq5_1) (number_hired ave_days_hired ave_cost_per_worker_per_day)
						gen ph_labor = number_hired*ave_days_hired*ave_cost_per_worker_per_day
						
						collapse (sum) ph_labor, by(hhid)
								
						
						merge 1:1 hhid using `pp_labor_w5', nogen
						merge 1:1 hhid using `animal_labor_w5', nogen
						
						gen wave=5
						
						tempfile labor_w5
						save `labor_w5'
						
				
					
	//Wave 4
	global raw_folder "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\LSMS-Agricultural-Indicators-Code-main\LSMS-Agricultural-Indicators-Code-main\Nigeria GHS\Nigeria GHS Wave 4\Raw DTA files"
		
	//Post Planting
		//agricultural survey
			//labor expensitures 
			
			//annual
			
					use "${raw_folder}/sect11c1b_plantingw4.dta", clear
						keep if s11c1q2a == 1
						keep hhid plotid s11c1q2 s11c1q3 s11c1q4
						rename (s11c1q2 s11c1q3 s11c1q4) (number_hired ave_days_hired ave_cost_per_worker_per_day)
						gen pp_labor = number_hired*ave_days_hired*ave_cost_per_worker_per_day
						
						collapse (sum) pp_labor, by(hhid)
						
						tempfile pp_labor_w4
						save `pp_labor_w4'
						
	//Harvest
		//agricultural survey	
			//input expenses - animal rental cost
			
			//annual
			
				use "${raw_folder}/secta11c2_harvestw4.dta", clear
					keep hhid plotid s11c2q23 s11c2q25
					rename (s11c2q23 s11c2q25) (animal_rent animal_feed)
					egen animal_labor = rowtotal(animal_rent animal_feed)
					
					collapse (sum) animal_labor, by(hhid)
					
					tempfile animal_labor_w4
					save `animal_labor_w4'
					
			//labor expensitures
			
			//annual
			
				use "${raw_folder}/secta2b_harvestw4.dta", clear
					keep if sa2bq2a == 1
					keep hhid plotid sa2bq2 sa2bq3 sa2bq4
					rename (sa2bq2 sa2bq3 sa2bq4) (number_hired ave_days_hired ave_cost_per_worker_per_day)
					gen ph_labor = number_hired*ave_days_hired*ave_cost_per_worker_per_day
					
					collapse (sum) ph_labor, by(hhid)

					merge 1:1 hhid using `pp_labor_w4', nogen			
					merge 1:1 hhid using `animal_labor_w4', nogen
					
					gen wave = 4
					
					
	//combine them
		append using `labor_w5'
		
		winsor2 ph_labor pp_labor animal_labor, replace cut(0 99) by(wave)
		
		egen labor_expense_total = rowtotal(ph_labor pp_labor animal_labor)
		egen labor_expense_human = rowtotal(ph_labor pp_labor)
		
		//for charts
		//collapse (sum) ph_labor pp_labor labor_expense_total animal_labor, by(wave)
		
	save "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\labor_expenditure_data.dta", replace