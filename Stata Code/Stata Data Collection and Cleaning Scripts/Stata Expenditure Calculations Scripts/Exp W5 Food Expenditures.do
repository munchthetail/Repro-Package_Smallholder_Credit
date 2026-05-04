//this collects food expenditures from wave 5 and is collected in "Exp W5 Pulling All.do"
//the food data is broadly categorized as food at home and away from home
//collected on 7 day recall and annualized for use in DML data prep script
//we also average expenditures from the post harvest and post planting surveys
	clear all      // clears data, value labels, saved results, and programs
	set more off   // prevents output from pausing with "more"
	
	//HOUSEHOLD SURVEY
		//post havest
			//food expenditures
				use "${root}/Source Data/Nigeria GHS Wave 5/Raw DTA files/sect5b_harvestw5.dta", clear
				rename (s5bq3 s5bq7a s5bq8) (quant_purchased_week last_month_pruchased last_month_paid)

				//expenditures = quantity purchased last month * (price most recently paid/units purchased) (i.e. cost per unit)
				gen item_expenditure = quant_purchased_week*(last_month_paid/last_month_pruchased)
				
				//summing by household
				collapse (sum) item_expenditure, by(hhid)
				
				//recall horizon and classifying characteristics of food expenditures
				gen days = 7
				gen item_cd = 1
				gen harvest_food = 1
				gen postplant = 0
				
				//saving
				tempfile expend_a
				save `expend_a'
			
			//food away from home
				use "${root}/Source Data/Nigeria GHS Wave 5/Raw DTA files/sect5a_harvestw5.dta", clear
				keep if s5aq1==1 //keep if made a purchase in this class
				keep hhid item_cd s5aq2
				rename s5aq2 item_expenditure
				
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
				use "${root}/Source Data/Nigeria GHS Wave 5/Raw DTA files/sect6b_plantingw5.dta", clear
				rename (s6bq3 s6bq7a s6bq8) (quant_purchased_week last_month_pruchased last_month_paid)

				//expenditures = quantity purchased last month * (price most recently paid/units purchased) (i.e. cost per unit)
				gen item_expenditure = quant_purchased_week*(last_month_paid/last_month_pruchased)
				
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
				use "${root}/Source Data/Nigeria GHS Wave 5/Raw DTA files/sect6a_plantingw5.dta", clear
				keep if s6aq1==1 //keep if made a purchase in this class
				keep hhid item_cd s6aq2
				rename s6aq2 item_expenditure
				
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
	
	//appending together
	use `expend_a', clear
	append using `expend_b'
	append using `expend_c'
	append using `expend_d'
	
	gen wave = 5
	
	//annualize expenditures & average bentween post planting and post harvest surveys
	replace item_expenditure = item_expenditure/(days/(365/2))
	
	//labeling
	label define item_lbl ///
		1 "1. Food At Home" ///
		2 "2. Food Away From Home"
	label values item_cd item_lbl
	
	//saving
	save "${root}/Stata Code/Stata Data Landing/food_expenditures_w5.dta", replace