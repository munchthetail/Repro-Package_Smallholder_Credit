//this file collects data from both the post harvest and post planting surveys on livestock expenses 
//(animal purchases and cost of care) and is collected in "Exp Master Pulls.do"
	clear all      // clears data, value labels, saved results, and programs
	set more off   // prevents output from pausing with "more"
	
	//Wave 5
	//Post Planting
		//agricultural survey
			//animal expenditures maintenance 
			//annual			
				use "${root}/Source Data/Nigeria GHS Wave 5/RAW DTA files/sect11j_plantingw5.dta", clear
					keep hhid livestock_cd s11jq9 s11jq11 s11jq14 s11jq18 s11jq20 s11jq22 s11jq24
					rename (s11jq9 s11jq11 s11jq14 s11jq18 s11jq20 s11jq22 s11jq24) (vaccination other_vet water feed hired_help damages_paid other_costs)
					egen animal_main_exp = rowtotal(vaccination other_vet water feed hired_help damages_paid other_costs)
					
					//summing by household
					collapse (sum) animal_main_exp, by(hhid)
					
					tempfile animal_w5_1
					save `animal_w5_1'
					
			//animal expenditures purchases
			//annual
				use "${root}/Source Data/Nigeria GHS Wave 5/RAW DTA files/sect11i_plantingw5.dta", clear
					keep hhid animal_cd s11iq18
					rename (s11iq18) (animal_exp)
					//based on survey questions
					gen days = .
					replace days = 365 if inrange(animal_cd,101,112)
					replace days = 365/4 if inrange(animal_cd,113,118)
					replace days = 365 if inrange(animal_cd,120,123)
					
					replace animal_exp = animal_exp/(days/365) //annualize

					//summing by household
					collapse (sum) animal_exp, by(hhid)
					
					merge 1:1 hhid using `animal_w5_1', nogen
				
				//winsorizing consistent with many other variabels in the analysis
				winsor2 animal_exp animal_main_exp, replace cut(0 99)
				
				egen animal_total_exp = rowtotal( animal_exp animal_main_exp)
				gen wave = 5
				
				//saving
				tempfile animal_w5
				save `animal_w5'
	
	//Wave 4
	//Post Planting
		//agricultural survey
			//animal expenditures maintenance 
			//annual
				use "${root}/Source Data/Nigeria GHS Wave 4/RAW DTA files/sect11j_plantingw4.dta", clear
					keep hhid livestock_cd s11jq6 s11jq8 s11jq13 s11jq17 s11jq19 s11jq21 s11jq23
					rename (s11jq6 s11jq8 s11jq13 s11jq17 s11jq19 s11jq21 s11jq23) (vaccination other_vet water feed hired_help damages_paid other_costs)
					egen animal_main_exp = rowtotal(vaccination other_vet water feed hired_help damages_paid other_costs)
					
					//summing by household
					collapse (sum) animal_main_exp, by(hhid)
					
					tempfile animal_w4_1
					save `animal_w4_1'
					
			//animal expenditures purchases
			//annual
				use "${root}/Source Data/Nigeria GHS Wave 4/RAW DTA files/sect11i_plantingw4.dta", clear
					keep hhid animal_cd s11iq11
					rename (s11iq11) (animal_exp)
					//based on survey questions
					gen days = .
					replace days = 365 if inrange(animal_cd,101,112)
					replace days = 365/4 if inrange(animal_cd,113,118)
					replace days = 365 if inrange(animal_cd,120,123)
					
					replace animal_exp = animal_exp/(days/365) //annualize
					//summing by household
					collapse (sum) animal_exp, by(hhid)
					
					merge 1:1 hhid using `animal_w4_1', nogen
					
				//winsorizing consistent with many other variabels in the analysis
				winsor2 animal_exp animal_main_exp, replace cut(0 99)
				
				egen animal_total_exp = rowtotal(animal_exp animal_main_exp)
				gen wave = 4
				
		//appending with post harvest data
		append using `animal_w5'
		
		//saving full dataset
		save "${root}/Stata Code/Stata Data Landing/livestock_expenditure_data.dta", replace
		