//this file collects data from both the post harvest and post planting surveys on input expenses 
//(fertilizer, seeds, and machinery) and is collected in "Exp Master Pulls.do"
	clear all      // clears data, value labels, saved results, and programs
	set more off   // prevents output from pausing with "more"

	//Wave 5
	//Post Planting
		//agricultural survey
			//seed expenditures --- purchase of seeds expenses
			//annual
			use "${root}/Source Data/Nigeria GHS Wave 5/Raw DTA files/sect11e1_plantingw5.dta", clear
				keep hhid s11eq11
				rename s11eq11 item_expenditure
				
				//summing by household
				collapse (sum) item_expenditure, by(hhid)
				
				//saving
				tempfile seed_w5_1
				save `seed_w5_1'
					
			//seed expenditures --- transportation expenses for seeds aquisition
			//annual
				use "${root}/Source Data/Nigeria GHS Wave 5/Raw DTA files/sect11e2_plantingw5.dta", clear
					keep hhid s11eq16 s11eq17
					egen item_expenditure = rowtotal(s11eq16 s11eq17)
					
					//summing by household
					collapse (sum) item_expenditure, by(hhid)
					
					//appending with seed purchase expenses
					append using `seed_w5_1'
					rename item_expenditure seed_exp
					
					//summing by household
					collapse (sum) seed_exp, by(hhid)
				
					//saving
					tempfile seed_w5
					save `seed_w5'
				
		//Harvest
			//agricultural survey
				//input expenditures namely fertilizer and machinery purchase  --- transportation expenses
				//annual
					use "${root}/Source Data/Nigeria GHS Wave 5/Raw DTA files/secta11c3q12_harvestw5.dta", clear			
						keep hhid s11c3q12
						rename s11c3q12 fert_pest_mach_transport_exp
						
						//summing by household
						collapse (sum) fert_pest_mach_transport_exp, by(hhid)
						
						//saving
						tempfile trans_input_w5
						save `trans_input_w5'
				
				//input expenditures namely fertilizer and machinery purchase
				//annual
					use "${root}/Source Data/Nigeria GHS Wave 5/Raw DTA files/secta11c3_harvestw5.dta", clear
						keep hhid inputid s11c3q5 s11c3q11
						rename (s11c3q5 s11c3q11) (input_purchase input_rent)
						
						egen fert_mach_pecticide_exp = rowtotal(input_purchase input_rent)

						//summing by household
						collapse (sum) fert_mach_pecticide_exp, by(hhid)
						
						//merging with transportation expenses and seed expenses
						merge 1:1 hhid using `trans_input_w5', nogen
						merge 1:1 hhid using `seed_w5', nogen
						
						gen wave = 5
						
						//saving
						tempfile input_w5
						save `input_w5'
			
	//Wave 4
	//Post Planting
		//agricultural survey
			//seed expenditures --- purchase of seeds expenses
			//annual
			use "${root}/Source Data/Nigeria GHS Wave 4/Raw DTA files/sect11e1_plantingw4.dta", clear
				keep hhid s11eq21
				rename s11eq21 item_expenditure
				
				//summing by household
				collapse (sum) item_expenditure, by(hhid)
				

				tempfile seed_w4_1
				save `seed_w4_1'
			
			//seed expenditures --- transportation expenses for seeds aquisition
			//annual
			use "${root}/Source Data/Nigeria GHS Wave 4/Raw DTA files/sect11e2_plantingw4.dta", clear
				keep hhid s11eq12 s11eq19
				egen item_expenditure = rowtotal(s11eq12 s11eq19)
				
				//summing by household
				collapse (sum) item_expenditure, by(hhid)
				
				//appending with seed purchase expenses
				append using `seed_w4_1'
				rename item_expenditure seed_exp
				
				//summing by household
				collapse (sum) seed_exp, by(hhid)
				
				//saving
				tempfile seed_w4
				save `seed_w4'
			
	//Harvest
		//agricultural survey
			//input expenditures namely fertilizer and machinery purchase  --- transportation expenses
			//annual
			use "${root}/Source Data/Nigeria GHS Wave 4/Raw DTA files/secta11c3q12_harvestw4.dta", clear			
				keep hhid s11c3q12
				rename s11c3q12 fert_pest_mach_transport_exp
				
				//summing by household
				collapse (sum) fert_pest_mach_transport_exp, by(hhid)
				
				//saving
				tempfile input_w4_1
				save `input_w4_1'
				
			//input expenditures namely fertilizer and machinery purchase
			//annual
				use "${root}/Source Data/Nigeria GHS Wave 4/Raw DTA files/secta11c3_harvestw4.dta", clear
					keep hhid inputid s11c3q5 s11c3q10
					rename (s11c3q5 s11c3q10) (input_purchase input_rent)
					
					egen fert_mach_pecticide_exp = rowtotal(input_purchase input_rent)

					//summing by household
					collapse (sum) fert_mach_pecticide_exp, by(hhid)
					
					//merging with transportation expenses and seed expenses					
					merge 1:1 hhid using `input_w4_1', nogen
					merge 1:1 hhid using `seed_w4', nogen
					
					gen wave = 4
			
			//appending with wave 5 data
			append using `input_w5'
			
			//winsorizing consistent with many other variabels in the analysis
			winsor2 seed_exp fert_mach_pecticide_exp fert_pest_mach_transport_exp, replace cut(0 99) by(wave)
			
			egen total_input_exp = rowtotal(seed_exp fert_mach_pecticide_exp fert_pest_mach_transport_exp)
	
	//saving
	save "${root}/Stata Code/Stata Data Landing/input_expenditure_data.dta", replace