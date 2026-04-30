// Will Hankins edit 9/16/25
	clear all      // clears data, value labels, saved results, and programs
	set more off   // prevents output from pausing with "more"
	cd "C:\Users\Will\OneDrive - The Ohio State University\RA\Data\EPAR Nigeria"
	global raw_folder "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\LSMS-Agricultural-Indicators-Code-main\LSMS-Agricultural-Indicators-Code-main\Nigeria GHS\Nigeria GHS Wave 4\Raw DTA files"
	
	//Post Harvest
		//household survey
			//general expenditures
				//7 day horizon
					use "${raw_folder}/sect11a_harvestw4.dta", clear
					keep hhid item_cd s11aq1 s11aq2
					gen days = 7
					gen postplant = 0
					rename (s11aq1 s11aq2) (purchased item_expenditure)
					keep if purchased == 1
					drop purchased
					
					tempfile expend_a
					save `expend_a'
				
				//month horizon
					use "${raw_folder}/sect11b_harvestw4.dta", clear
					keep hhid item_cd s11bq3 s11bq4
					gen days = 365/12
					gen postplant = 0
					rename (s11bq3 s11bq4) (purchased item_expenditure)
					keep if purchased == 1
					drop purchased
					
					tempfile expend_b
					save `expend_b'
					
				//6 month horizon
					use "${raw_folder}/sect11c_harvestw4.dta", clear
					keep hhid item_cd s11cq5 s11cq6
					gen days = 365/2
					gen postplant = 0
					rename (s11cq5 s11cq6) (purchased item_expenditure)
					keep if purchased == 1
					drop purchased
					
					tempfile expend_c
					save `expend_c'
					
				//year horizon
					use "${raw_folder}/sect11d_harvestw4.dta", clear
					keep hhid item_cd s11dq7 s11dq8
					gen days = 365
					gen postplant = 0
					rename (s11dq7 s11dq8) (purchased item_expenditure)
					keep if purchased == 1
					drop purchased
					
					tempfile expend_d
					save `expend_d'
				
			//harvest: educations post harvest (no pre harvest amount) 22/23 school year --- calling this an annual expense level
				use "${raw_folder}/sect2_harvestw4.dta", clear
				keep hhid s2aq23aa s2aq23ab s2aq23ac s2aq23ad s2aq23ae s2aq23bg s2aq23bh s2aq23bi s2aq23bj s2aq23bf s2aq23bk s2aq23bl s2aq23bm s2aq23bn s2aq23bo s2aq23bp s2aq23bq s2aq23br s2aq23bs s2aq23bt
				
				//convert monthly into annuals
					replace s2aq23aa = s2aq23aa*12
					replace s2aq23ab = s2aq23ab*12
					replace s2aq23ac = s2aq23ac*12
					replace s2aq23ad = s2aq23ad*12
					replace s2aq23ae = s2aq23ae*12
				
				egen item_expenditure = rowtotal(s2aq23bt-s2aq23bs)
				
				collapse (sum) item_expenditure, by(hhid)
				gen item_cd = 701 //education aggregate fees per household
				gen days = 365
				gen postplant = 0
				
				tempfile expend_e
				save `expend_e'
				
			//harvest: childcare expenses child <= 7
			
			//NOTE: THIS MODULE IS ONLY INCLUDED IN THE WAVE 5 SURVEY RESULTS SO SHOULD PROBABLY BE EXCLUDED ANALYSIS
				// it could be convered in non-food expenitures under "Domestic services"
				
			//harvest: non farm enterprise expenses -- business expenses
				use "${raw_folder}/sect9b_harvestw4.dta", clear
				keep hhid s9q28a s9q28b s9q28c s9q28d s9q28e s9q28f s9q28g s9q28i s9q28j
				egen item_expenditure = rowtotal(s9q28a-s9q28j)
				
				collapse (sum) item_expenditure, by(hhid)
				gen item_cd = 703
				gen days = 365/12
				gen postplant = 0
				
				tempfile expend_f
				save `expend_f'
				
			//harvest: non farm enterprise expenses -- debt service 
				use "${raw_folder}/sect9b_harvestw4.dta", clear
				keep hhid s9q22 s9q28h 
				gen item_expenditure = 12*s9q28h + s9q22 //extrapolating monthy expense of loan interest to full year to match yearly loan repayment amount, will be normalized by days count later
				
				gen item_cd = 704
				gen days = 365
				gen postplant = 0
				
				tempfile expend_g
				save `expend_g'
				
			//harvest: housing expenses -- rent
				//NOTE: This section only exists in the non-food expensiture section of the wave 4 survey
				
			//harvest: housing expenses -- utilities  
				//NOTE: This section only exists in the non-food expensiture section of the wave 4 survey
					//electric and water expenses aren't broken out by household utilities vs other bills, maybe would be good to move electricity to housing rent costs
						//if so we should also move electric to the same category in W5
		
	//Post Planting
		//household survey
			//planting: general expenditures
				//7 day horizon
					use "${raw_folder}/sect8a_plantingw4.dta", clear
					keep hhid item_cd s8q1 s8q2
					gen days = 7
					gen postplant = 1
					rename (s8q1 s8q2) (purchased item_expenditure)
					keep if purchased == 1
					drop purchased
					
					tempfile expend_h
					save `expend_h'
				
				//month horizon
					use "${raw_folder}/sect8b_plantingw4.dta", clear
					keep hhid item_cd s8q3 s8q4
					gen days = 365/12
					gen postplant = 1
					rename (s8q3 s8q4) (purchased item_expenditure)
					keep if purchased == 1
					drop purchased
					
					tempfile expend_i
					save `expend_i'
					
				//6 month horizon
					use "${raw_folder}/sect8c_plantingw4.dta", clear
					keep hhid item_cd s8q5 s8q6
					gen days = 365/2
					gen postplant = 1
					rename (s8q5 s8q6) (purchased item_expenditure)
					keep if purchased == 1
					drop purchased
					
					tempfile expend_j
					save `expend_j'
					
				//year horizon
					//they have annual horizon in post harvest but not post planting 
			
			//planting: housing expenses -- rent s9q39 
				use "${raw_folder}/sect11_plantingw4.dta", clear
				keep hhid s11q4a s11q4b
				gen days = 365
				replace days = 365/12 if s11q4b == 1
				gen item_expenditure = s11q4a
				collapse (sum) item_expenditure, by(hhid days)
				gen postplant = 0
				gen item_cd = 705
				 
				tempfile expend_k
				save `expend_k'
				
			//planting: housing expenses -- utilities  
				use "${raw_folder}/sect11_plantingw4.dta", clear
				keep hhid s11q69
				gen item_expenditure = s11q69
				
				collapse (sum) item_expenditure, by(hhid)
				gen item_cd = 706
				gen days = 30
				gen postplant = 0
				
				tempfile expend_l
				save `expend_l'
				
			//planting: health expenses --- this might overlap with expenses from section 7c so I will exclude it from the final figures
				//this section only exists in the wave 5 survey
		
		
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
	
	gen wave = 4
	
	//annualize expenditures
	replace item_expenditure = item_expenditure/(days/365)
	
	save "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\nonfood_expenditures_household_w4.dta", replace