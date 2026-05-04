//this collects food expenditures from wave 4 and is collected in "Exp W4 Pulling All.do"
//the food data is broadly categorized as food at home and away from home
//collected on 7 day recall and annualized for use in DML data prep script
//we also average expenditures from the post harvest and post planting surveys
	clear all      // clears data, value labels, saved results, and programs
	set more off   // prevents output from pausing with "more"

	//HOUSEHOLD SURVEY
		//post havest
			//food expenditures
				use "`base'/Source Data/Nigeria GHS Wave 4/RAW DTA files/sect10b_harvestw4.dta", clear
				rename (s10bq5a s10bq9a s10bq10) (quant_purchased_week last_month_pruchased last_month_paid)

				//expenditures = quantity purchased last month * (price most recently paid/units purchased) (i.e. cost per unit)
				gen item_expenditure = quant_purchased_week*(last_week_paid/last_week_pruchased)

				//summing by household
				collapse (sum) item_expenditure, by(hhid)
				
				//recall horizon and classifying characteristics of food expenditures
				gen days = 7
				gen item_cd = 1
				gen postplant = 0
				gen harvest_food = 1
				
				//saving
				tempfile expend_a
				save `expend_a'
				
			//food away from home
				use "`base'/Source Data/Nigeria GHS Wave 4/RAW DTA files/sect10a_harvestw4.dta", clear
				keep if s10aq1==1 //keep if made a purchase in this class
				keep hhid item_cd s10aq2
				rename s10aq2 item_expenditure
				
				//summing by household
				collapse (sum) item_expenditure, by(hhid)

				//recall horizon and classifying characteristics of food expenditures
				gen days = 7
				gen item_cd = 2
				gen postplant = 1
				gen harvest_food = 1
				
				//saving
				tempfile expend_b
				save `expend_b'
			
		//post planting
			//food expenditures
				use "`base'/Source Data/Nigeria GHS Wave 4/RAW DTA files/sect7b_plantingw4.dta", clear
				rename (s7bq5a s7bq9a s7bq10) (quant_purchased_week last_week_pruchased last_week_paid)

				//expenditures = quantity purchased last month * (price most recently paid/units purchased) (i.e. cost per unit)
				gen item_expenditure = quant_purchased_week*(last_week_paid/last_week_pruchased)
				
				//summing by household
				collapse (sum) item_expenditure, by(hhid)
				
				//recall horizon and classifying characteristics of food expenditures
				gen days = 7
				gen item_cd = 1
				gen postplant = 1
				gen planting_food = 1
				
				//saving
				tempfile expend_c
				save `expend_c'
				
			//food away from home
				use "`base'/Source Data/Nigeria GHS Wave 4/RAW DTA files/sect7a_plantingw4.dta", clear
				keep if s7aq1==1 //keep if made a purchase in this class
				keep hhid item_cd s7aq2
				rename s7aq2 item_expenditure
				
				//summing by household
				collapse (sum) item_expenditure, by(hhid)

				//recall horizon and classifying characteristics of food expenditures
				gen days = 7
				gen item_cd = 2
				gen postplant = 1
				gen planting_food = 1
				
				//saving
				tempfile expend_d
				save `expend_d'
	
	//PULLING TOGETHER
	use `expend_a', clear
	append using `expend_b'
	append using `expend_c'
	append using `expend_d'
	
	gen wave = 4
	
	//annualize food expenditures
	replace item_expenditure = item_expenditure/(days/(365/2))
	
	label define item_lbl ///
		1 "1. Food At Home" ///
		2 "2. Food Away From Home"
	label values item_cd item_lbl
			
	save "`base'/Stata Code/Stata Data Landing/food_expenditures_w4.dta", replace