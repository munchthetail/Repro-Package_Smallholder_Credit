// Will Hankins edit 9/16/25
	clear all      // clears data, value labels, saved results, and programs
	set more off   // prevents output from pausing with "more"

	
	//Wave 5
	global raw_folder "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\LSMS-Agricultural-Indicators-Code-main\LSMS-Agricultural-Indicators-Code-main\Nigeria GHS\Nigeria GHS Wave 5\Raw DTA files"

	//Post Planting
		//agricultural survey
			//seed expenditures --- purchase of seeds expenses
			
			//annual
			
				use "${raw_folder}/sect11e1_plantingw5.dta", clear
					keep hhid s11eq11
					rename s11eq11 item_expenditure
					
					collapse (sum) item_expenditure, by(hhid)
					
					tempfile seed_w5_1
					save `seed_w5_1'
					
			//seed expenditures --- transportation expenses for seeds aquisition
			
			//annual
			
				use "${raw_folder}/sect11e2_plantingw5.dta", clear
					keep hhid s11eq16 s11eq17
					egen item_expenditure = rowtotal(s11eq16 s11eq17)
					
					collapse (sum) item_expenditure, by(hhid)

					append using `seed_w5_1'
					
					rename item_expenditure seed_exp
					
					collapse (sum) seed_exp, by(hhid)

				tempfile seed_w5
				save `seed_w5'
				
		//Harvest
			//agricultural survey
				//input expenditures namely fertilizer and machinery purchase  --- transportation expenses
				
				//annual
				
					use "${raw_folder}/secta11c3q12_harvestw5.dta", clear			
						keep hhid s11c3q12
						rename s11c3q12 fert_pest_mach_transport_exp
						
						collapse (sum) fert_pest_mach_transport_exp, by(hhid)
						
						tempfile input_w5_1
						save `input_w5_1'
				
				//input expenditures namely fertilizer and machinery purchase
				
				//annual
				
					use "${raw_folder}/secta11c3_harvestw5.dta", clear
						keep hhid inputid s11c3q5 s11c3q11
						rename (s11c3q5 s11c3q11) (input_purchase input_rent)
						
						reshape wide input_purchase input_rent, i(hhid) j(inputid)
						
						egen fertilizer_exp = rowtotal(input_purchase1 input_purchase2 input_purchase3 input_purchase4)
						
						egen pecticide_exp = rowtotal( input_purchase5 input_purchase6)
						
						egen machine_exp_purchase = rowtotal( input_purchase7 input_purchase8)
						egen machine_exp_rent = rowtotal( input_rent7 input_rent8)
						egen machine_exp = rowtotal(machine_exp_purchase machine_exp_rent)
						
						collapse (sum) *_ex*, by(hhid)
						
						merge 1:1 hhid using `input_w5_1', nogen
						
						merge 1:1 hhid using `seed_w5', nogen
						
						gen wave = 5
						
			tempfile input_w5
			save `input_w5'
			
	//Wave 4
	global raw_folder "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\LSMS-Agricultural-Indicators-Code-main\LSMS-Agricultural-Indicators-Code-main\Nigeria GHS\Nigeria GHS Wave 4\Raw DTA files"

	//Post Planting
		//agricultural survey
			//seed expenditures --- purchase of seeds expenses
			
			//annual
			
				use "${raw_folder}/sect11e1_plantingw4.dta", clear
					keep hhid s11eq21
					rename s11eq21 item_expenditure
					
					collapse (sum) item_expenditure, by(hhid)
					
					tempfile seed_w4_1
					save `seed_w4_1'
			
			//seed expenditures --- transportation expenses for seeds aquisition
			
			//annual
			
				use "${raw_folder}/sect11e2_plantingw4.dta", clear
					keep hhid s11eq12 s11eq19
					egen item_expenditure = rowtotal(s11eq12 s11eq19)
					
					collapse (sum) item_expenditure, by(hhid)

					append using `seed_w4_1'
					
					rename item_expenditure seed_exp
					
					collapse (sum) seed_exp, by(hhid)

				tempfile seed_w4
				save `seed_w4'
			
	//Harvest
		//agricultural survey
			//input expenditures namely fertilizer and machinery purchase  --- transportation expenses
			
			//annual
			
				use "${raw_folder}/secta11c3q12_harvestw4.dta", clear			
					keep hhid s11c3q12
					rename s11c3q12 fert_pest_mach_transport_exp
					
					collapse (sum) fert_pest_mach_transport_exp, by(hhid)
					
					tempfile input_w4_1
					save `input_w4_1'
				
			//input expenditures namely fertilizer and machinery purchase
			
			//annual
			
				use "${raw_folder}/secta11c3_harvestw4.dta", clear
					keep hhid inputid s11c3q5 s11c3q10
					rename (s11c3q5 s11c3q10) (input_purchase input_rent)
					
					reshape wide input_purchase input_rent, i(hhid) j(inputid)
					
					egen fertilizer_exp = rowtotal(input_purchase1 input_purchase2 input_purchase3 input_purchase4)
					
					egen pecticide_exp = rowtotal( input_purchase5 input_purchase6)
					
					egen machine_exp_purchase = rowtotal( input_purchase7 input_purchase8)
					egen machine_exp_rent = rowtotal( input_rent7 input_rent8)
					egen machine_exp = rowtotal(machine_exp_purchase machine_exp_rent)
					
					collapse (sum) *_ex*, by(hhid)
					
					merge 1:1 hhid using `input_w4_1', nogen
					
					merge 1:1 hhid using `seed_w4', nogen
					
					gen wave = 4
					
			append using `input_w5'
			
			winsor2 seed_exp fertilizer_exp pecticide_exp machine_exp, replace cut(0 99) by(wave)
			
			egen total_input_exp = rowtotal(seed_exp fertilizer_exp pecticide_exp machine_exp)
			egen non_seed_total_input_exp = rowtotal(fertilizer_exp pecticide_exp machine_exp)
			egen fert_pest_total_exp = rowtotal(fertilizer_exp pecticide_exp)
								
	save "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\input_expenditure_data.dta", replace