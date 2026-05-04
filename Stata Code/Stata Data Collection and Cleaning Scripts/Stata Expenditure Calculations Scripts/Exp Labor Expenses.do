//this file collects data from both the post harvest and post planting surveys on labor expenses 
//(wages and animal labor costs) and is collected in "Exp Master Pulls.do"
	clear all      // clears data, value labels, saved results, and programs
	set more off   // prevents output from pausing with "more"

	
	//Wave 5
	//Post Planting
		//agricultural survey
			//labor expensitures 
			//annual
			use "${root}/Source Data/Nigeria GHS Wave 5/RAW DTA files/sect11c1b_plantingw5.dta", clear
				keep if s11c1q2_1 == 1
				keep hhid plotid s11c1q3_1 s11c1q4_1 s11c1q6_1
				rename (s11c1q3_1 s11c1q4_1 s11c1q6_1) (number_hired ave_days_hired ave_cost_per_worker_per_day)

				//labor expenses = number of workers hired * average days hired * average cost per worker per day
				gen pp_labor = number_hired*ave_days_hired*ave_cost_per_worker_per_day
				
				//summing by household
				collapse (sum) pp_labor, by(hhid)
				
				//saving
				tempfile pp_labor_w5
				save `pp_labor_w5'
						
		//post harvest
			//agricultural survey
				//input expenses - animal rental cost
				//annual
				use "${root}/Source Data/Nigeria GHS Wave 5/RAW DTA files/secta11c2_harvestw5.dta", clear
					keep hhid plotid s11c2q17 s11c2q18
					rename (s11c2q17 s11c2q18) (animal_rent animal_feed)
					egen animal_labor = rowtotal(animal_rent animal_feed)
					
					//summing by household
					collapse (sum) animal_labor, by(hhid)
					
					//saving
					tempfile animal_labor_w5
					save `animal_labor_w5'
						
				//labor expensitures - PREHARVEST
				//annual
				use "${root}/Source Data/Nigeria GHS Wave 5/RAW DTA files/secta2b_harvestw5.dta", clear
					keep if sa2bq1_1 == 1
					keep hhid plotid sa2bq2_1 sa2bq3_1 sa2bq5_1
					rename (sa2bq2_1 sa2bq3_1 sa2bq5_1) (number_hired ave_days_hired ave_cost_per_worker_per_day)

					//labor expenses = number of workers hired * average days hired * average cost per worker per day
					gen ph_labor = number_hired*ave_days_hired*ave_cost_per_worker_per_day
					
					//summing by household
					collapse (sum) ph_labor, by(hhid)
					
					//merging with post planting labor expenses and animal labor expenses
					merge 1:1 hhid using `pp_labor_w5', nogen
					merge 1:1 hhid using `animal_labor_w5', nogen
					
					gen wave=5
					
					tempfile labor_w5
					save `labor_w5'
								
	//Wave 4
	//Post Planting
		//agricultural survey
			//labor expensitures 
			//annual
			use "${root}/Source Data/Nigeria GHS Wave 4/RAW DTA files/sect11c1b_plantingw4.dta", clear
				keep if s11c1q2a == 1
				keep hhid plotid s11c1q2 s11c1q3 s11c1q4
				rename (s11c1q2 s11c1q3 s11c1q4) (number_hired ave_days_hired ave_cost_per_worker_per_day)

				//labor expenses = number of workers hired * average days hired * average cost per worker per day
				gen pp_labor = number_hired*ave_days_hired*ave_cost_per_worker_per_day
				
				//summing by household
				collapse (sum) pp_labor, by(hhid)
				
				//saving
				tempfile pp_labor_w4
				save `pp_labor_w4'
						
	//Harvest
		//agricultural survey	
			//input expenses - animal rental cost
			//annual
			use "${root}/Source Data/Nigeria GHS Wave 4/RAW DTA files/secta11c2_harvestw4.dta", clear
				keep hhid plotid s11c2q23 s11c2q25
				rename (s11c2q23 s11c2q25) (animal_rent animal_feed)
				egen animal_labor = rowtotal(animal_rent animal_feed)
				
				//summing by household
				collapse (sum) animal_labor, by(hhid)
				
				//saving
				tempfile animal_labor_w4
				save `animal_labor_w4'
				
			//labor expensitures
			//annual
			use "${root}/Source Data/Nigeria GHS Wave 4/RAW DTA files/secta2b_harvestw4.dta", clear
				keep if sa2bq2a == 1
				keep hhid plotid sa2bq2 sa2bq3 sa2bq4
				rename (sa2bq2 sa2bq3 sa2bq4) (number_hired ave_days_hired ave_cost_per_worker_per_day)
				
				//labor expenses = number of workers hired * average days hired * average cost per worker per day
				gen ph_labor = number_hired*ave_days_hired*ave_cost_per_worker_per_day
				
				//summing by household
				collapse (sum) ph_labor, by(hhid)
				
				//merging with post planting labor expenses and animal labor expenses
				merge 1:1 hhid using `pp_labor_w4', nogen			
				merge 1:1 hhid using `animal_labor_w4', nogen
				
				gen wave = 4
					
					
	//combine everthing
	append using `labor_w5'
	
	//winsorizing consistent with many other variabels in the analysis
	winsor2 ph_labor pp_labor animal_labor, replace cut(0 99) by(wave)
	
	//total labor expenses including animal and hired labor
	egen labor_expense_total = rowtotal(ph_labor pp_labor animal_labor)

	//saving
	save "${root}/Stata Code/Stata Data Landing/labor_expenditure_data.dta", replace