// Will Hankins edit 9/16/25
	clear all      // clears data, value labels, saved results, and programs
	set more off   // prevents output from pausing with "more"
	cd "C:\Users\Will\OneDrive - The Ohio State University\RA\Data\EPAR Nigeria"
	global raw_folder "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\LSMS-Agricultural-Indicators-Code-main\LSMS-Agricultural-Indicators-Code-main\Nigeria GHS\Nigeria GHS Wave 5\Raw DTA files"
	
	//HOUSEHOLD SURVEY
		//post havest
			//food expenditures
				use "${raw_folder}/sect5b_harvestw5.dta", clear
				
				//keep hhid item_cd s5bq3 s5bq7a s5bq8
				//NOTE: there is a problem that people report purchases last month but provide no niara for purchases last week
					// the solution may be to create estimated consumption based on average prices by region but lets not do that unless needed since we would be guessing prices
				rename (s5bq3 s5bq7a s5bq8) (quant_purchased_month last_week_pruchased last_week_paid)
				gen item_expenditure = quant_purchased_month*(last_week_paid/last_week_pruchased)
				
				collapse (sum) item_expenditure, by(hhid)
				
				gen days = 7
				gen item_cd = 1
				gen harvest_food = 1
				gen postplant = 0
				
				tempfile expend_a
				save `expend_a'
			
			//food away from home
				use "${raw_folder}/sect5a_harvestw5.dta", clear
				keep if s5aq1==1
				keep hhid item_cd s5aq2
				rename s5aq2 item_expenditure
				
				collapse (sum) item_expenditure, by(hhid)
				gen days = 7
				gen item_cd = 2
				gen postplant = 1
				gen harvest_food = 1
				
				tempfile expend_b
				save `expend_b'
				
		//post planting
			//food expenditures
				use "${raw_folder}/sect6b_plantingw5.dta", clear
				rename (s6bq3 s6bq7a s6bq8) (quant_purchased_month last_week_pruchased last_week_paid)
				gen item_expenditure = quant_purchased_month*(last_week_paid/last_week_pruchased)
				
				collapse (sum) item_expenditure, by(hhid)
				
				gen days = 7
				gen item_cd = 1
				gen postplant = 1
				gen planting_food = 1
				
				tempfile expend_c
				save `expend_c'
				
			//food away from home
				use "${raw_folder}/sect6a_plantingw5.dta", clear
				keep if s6aq1==1
				keep hhid item_cd s6aq2
				rename s6aq2 item_expenditure
				
				collapse (sum) item_expenditure, by(hhid)
				gen days = 7
				gen item_cd = 2
				gen postplant = 1
				gen planting_food = 1
				
				tempfile expend_d
				save `expend_d'
	
	//PULLING TOGETHER
	use `expend_a', clear
	append using `expend_b'
	append using `expend_c'
	append using `expend_d'
	
	gen wave = 5
	
	//annualize expenditures
	replace item_expenditure = item_expenditure/(days/(365/2))
	
	label define item_lbl ///
		1 "1. Food At Home" ///
		2 "2. Food Away From Home"
	label values item_cd item_lbl
			
	save "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\food_expenditures_w5.dta", replace