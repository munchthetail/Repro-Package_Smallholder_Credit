// Will Hankins edit 9/16/25
	clear all      // clears data, value labels, saved results, and programs
	set more off   // prevents output from pausing with "more"
	cd "C:\Users\Will\OneDrive - The Ohio State University\RA\Data\EPAR Nigeria"
	global raw_folder "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\LSMS-Agricultural-Indicators-Code-main\LSMS-Agricultural-Indicators-Code-main\Nigeria GHS\Nigeria GHS Wave 5\Raw DTA files"
	
	
	//Post Harvest
		//household survey
			//general expenditures
				//7 day horizon
					use "${raw_folder}/sect6a_harvestw5.dta", clear
					keep hhid item_cd s6q1 s6q2
					gen days = 7
					gen postplant = 0
					rename (s6q1 s6q2) (purchased item_expenditure)
					keep if purchased == 1
					drop purchased
					
					tempfile expend_a
					save `expend_a'
				
				//month horizon
					use "${raw_folder}/sect6b_harvestw5.dta", clear
					keep hhid item_cd s6q3 s6q4
					gen days = 365/12
					gen postplant = 0
					rename (s6q3 s6q4) (purchased item_expenditure)
					keep if purchased == 1
					drop purchased
					
					tempfile expend_b
					save `expend_b'
					
				//year horizon
					use "${raw_folder}/sect6c_harvestw5.dta", clear
					keep hhid item_cd s6q5 s6q6
					gen days = 365
					gen postplant = 0
					rename (s6q5 s6q6) (purchased item_expenditure)
					keep if purchased == 1
					drop purchased
					tempfile expend_c
					save `expend_c'
				
			//harvest: educations post harvest (no pre harvest amount) 22/23 school year --- calling this an annual expense level
				use "${raw_folder}/sect2_harvestw5.dta", clear
				keep hhid s2q23a s2q23b s2q23c s2q23d s2q23e s2q23f s2q23g s2q23h s2q23i s2q23j s2q23k s2q23l s2q23m s2q23n s2q23o s2q23p s2q23q s2q23r s2q23bt
				egen item_expenditure = rowtotal(s2q23a-s2q23bt)
				
				collapse (sum) item_expenditure, by(hhid)
				gen item_cd = 401 //education aggregate fees per household
				gen days = 365
				gen postplant = 0
				
				tempfile expend_d
				save `expend_d'
				
			//harvest: childcare expenses child <= 7
				use "${raw_folder}/sect2c_harvestw5.dta", clear
				rename s2cq5g item_expenditure
				
				collapse (sum) item_expenditure, by(hhid)
				gen item_cd = 402
				gen days = 7
				gen postplant = 0
				
				tempfile expend_e
				save `expend_e'
				
			//harvest: non farm enterprise expenses -- business expenses
				use "${raw_folder}/sect8b_harvestw5.dta", clear
				
				keep hhid s8q31a s8q31b s8q31c s8q31d s8q31e s8q31f s8q31g s8q31i s8q31j
				egen item_expenditure = rowtotal(s8q31a-s8q31j)
				
				collapse (sum) item_expenditure, by(hhid)
				gen item_cd = 403
				gen days = 365/12
				gen postplant = 0
				
				tempfile expend_f
				save `expend_f'
				
			//harvest: non farm enterprise expenses -- debt service 
				use "${raw_folder}/sect8b_harvestw5.dta", clear

				gen item_expenditure = 12*s8q31h + s8q19 //total payment on debts for business last 12 months
				
				collapse (sum) item_expenditure, by(hhid)
				gen item_cd = 404
				gen days = 365
				gen postplant = 0
				
				tempfile expend_g
				save `expend_g'
				
			//harvest: housing expenses -- rent s9q39 
				use "${raw_folder}/sect9_harvestw5.dta", clear
				keep hhid s9q5a s9q5b
				gen days = 365
				replace days = 365/12 if s9q5b == 1
				gen item_expenditure = s9q5a
				collapse (sum) item_expenditure, by(hhid days)
				gen postplant = 0
				gen item_cd = 405
				 
				tempfile expend_h
				save `expend_h'
				
			//harvest: housing expenses -- utilities  
				use "${raw_folder}/sect9_harvestw5.dta", clear
				keep hhid s9q39
				gen item_expenditure = s9q39
				
				collapse (sum) item_expenditure, by(hhid)
				gen item_cd = 406
				gen days = 30
				gen postplant = 0
				
				tempfile expend_i
				save `expend_i'
		
	//Post Planting
		//household survey
			//planting: general expenditures
				//7 day horizon
					use "${raw_folder}/sect7a_plantingw5.dta", clear
					keep hhid item_cd s7q1 s7q2
					gen days = 7
					gen postplant = 1
					rename (s7q1 s7q2) (purchased item_expenditure)
					keep if purchased == 1
					drop purchased
					
					tempfile expend_j
					save `expend_j'
				
				//month horizon
					use "${raw_folder}/sect7b_plantingw5.dta", clear
					keep hhid item_cd s7q3 s7q4
					gen days = 365/12
					gen postplant = 1
					rename (s7q3 s7q4) (purchased item_expenditure)
					keep if purchased == 1
					drop purchased
					
					tempfile expend_k
					save `expend_k'
					
				//year horizon
					use "${raw_folder}/sect7c_plantingw5.dta", clear
					keep hhid item_cd s7q5 s7q6
					gen days = 365
					gen postplant = 1
					rename (s7q5 s7q6) (purchased item_expenditure)
					keep if purchased == 1
					drop purchased
					
					tempfile expend_l
					save `expend_l'
				
			//planting: health expenses --- this might overlap with expenses from section 7c so I will exclude it from the final figures
				use "${raw_folder}/sect3_plantingw5.dta", clear
								
				egen item_expenditure = rowtotal(s3q12 s3q13 s3q17 s3q17a s3q20 s3q32)
				
				collapse (sum) item_expenditure, by(hhid)
				gen item_cd = 407
				gen days = 28
				gen postplant = 1
				
				tempfile expend_m
				save `expend_m'
		
		
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
	append using `expend_m'
	
	gen wave = 5
	
	//annualize expenditures
	replace item_expenditure = item_expenditure/(days/365)
	
	save "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\nonfood_expenditures_household_w5.dta", replace