//in this file we pull a wide variety of household characteristics 
//from the 4th survey waves, store them in temp files, then save them at the end of the document
clear all      // clears data, value labels, saved results, and programs
set more off   // prevents output from pausing with "more"

//making a head HH flag for future use
//this is used later to identify head of HH characteristics
use "${root}/Source Data/Nigeria GHS Wave 4/RAW DTA files/sect1_harvestw4.dta", clear
	keep state hhid indiv s1q3
	keep if s1q3 == 1
	drop s1q3 indiv
	
	isid hhid
	tempfile head_flag
	save `head_flag'

//HH member composition
	use "${root}/Source Data/Nigeria GHS Wave 4/RAW DTA files/sect1_harvestw4.dta", clear
		//flagging observations for household members
		gen member = 0
		replace member = 1 if s1q4a==1 | s1q8b==1
		keep if member == 1
		
		//flagging if the observation is 18+
		gen adult_member = 0 
		replace adult_member = 1 if s1q4 >= 18
				
		//summing membership for the household
		preserve
			collapse (sum) member, by(hhid)
			tempfile hh_members
			save `hh_members'		
		restore
				
		preserve
			collapse (sum) adult_member, by(hhid)
			tempfile hh_adults
			save `hh_adults'		
		restore
			
	//getting a list of distinct HHs
	keep hhid
	duplicates drop hhid, force
	
	//merging on membership statistics
	merge 1:1 hhid using `hh_members'
		keep if _merge==3
		drop _merge
	
	merge 1:1 hhid using `hh_adults'
		keep if _merge==3
		drop _merge
	
	//saving
	isid hhid
	tempfile hh_size
	save `hh_size'
	
	//this is used when calculating the FIES statistics in the R script
	preserve
		keep hhid member
		rename member weight
		save "${root}/Stata Code/Stata Data Landing/Nigeria_GHS_W4_household_weights.dta",replace
	restore
	
//pulling general demographic info about HH head
	use "${root}/Source Data/Nigeria GHS Wave 4/RAW DTA files/sect1_harvestw4.dta", clear
	keep hhid indiv s1q2 s1q3 s1q4 s1q7 s1q21 s1q27 s1q17
	keep if s1q3 == 1
	drop indiv //indiv is redundent when we keep only heads
	rename (s1q2 s1q3 s1q4 s1q7 s1q21 s1q27 s1q17) (head_sex head_relation head_age head_maritial_status head_father_edu head_monther_edu head_religion)
	
	//saving
	isid hhid
	tempfile head_demo
	save `head_demo'

//pulling income data FROM EPAR
	use "${root}/Source Data/Nigeria GHS Wave 4/final_data/Nigeria_GHS_W4_household_variables.dta", clear

	//keeping income variables 
		keep hhid ag_hh w_nonfarm_income w_value_assets formal_land_rights_hh npk_rate org_fert_rate w_inorg_fert_rate /// 
			w_value_crop_production lvstck_holding_tlu w_nonfarm_income ag_hh w_farm_size_agland
	
	//winsorizing consistently with other variables
	winsor2 npk_rate, cuts(1 99)
	winsor2 org_fert_rate, cut(1 99)
	rename (npk_rate org_fert_rate) (w_npk_rate w_org_fert_rate)
	drop npk_rate org_fert_rate
	
	//dropping one missing row
	keep if !missing(hhid)

	isid hhid
	tempfile income
	save `income'

//pulling data on phone ownership and internet access
	use "${root}/Source Data/Nigeria GHS Wave 4/RAW DTA files/sect4b_plantingw4.dta", clear	
	keep hhid s4bq8 s4bq14
	rename (s4bq8 s4bq14) (s5bq8 s5bq14) //renaming to be consistent w/ Wave 5
	
	//recoding (NO==2 -> NO==0)
	foreach v of varlist s5bq8 s5bq14{
		replace `v' = 0 if `v' == 2
	}
	
	//checking if the household had a phone or internet access respectively
	collapse (max) s5bq8 s5bq14, by(hhid)
	
	isid hhid
	tempfile phone_type
	save `phone_type'

//pulling HH that didn't attempt to get loans
	use "${root}/Source Data/Nigeria GHS Wave 4/RAW DTA files/sect4c1_plantingw4.dta" if s4cq1 == 2, clear
	rename s4cq1 applied
	gen wave = 4
	gen lid = 0
	tempfile no_loan 
	save `no_loan'
	
//getting loan data and with descriptive details for classifying the loans as agricultural credit (more processing in the "Import Post Cleaning.do" file)
//this is are most important source of data for the analysis, we merge everthing else onto this data
	use "${root}/Source Data/Nigeria GHS Wave 4/RAW DTA files/sect4c2_plantingw4.dta", clear
	gen s4cq1 = 1 //applied for a loan
	
	keep lid zone state sector lga ea hhid lid s4cq1 s4cq4 s4cq19 s4cq20 s4cq26 s4cq2b
	rename (s4cq1 s4cq4 s4cq19 s4cq20 s4cq26 s4cq2b) (s5cq1 s5cq4 s5cq5 s5cq6 s5cq12 s5cq2b) //this is just a consistency step with wave 5 (not strictly neccessary)
	rename (s5cq5 s5cq6 s5cq12 s5cq2b s5cq1 s5cq4) (requested_loan loan_status loan_amount_recieved lender_type applied loan_reason)
	gen wave = 4
	
	//aligning loan request reason with the questions available from the wave 5 survey
	gen temp = 0
	replace temp = 1 if inlist(loan_reason,1,2,3,4) //this is farming input expenses - note "BUY FARM TOOLS/IMPLEMENTS" does not fit well into wave 4 questions and is placed in other bucket
	replace temp = 5 if inlist(loan_reason,5,6) //non farm business expenses
	replace temp = 7 if inlist(loan_reason,7,9,10,13) // large bucket containing misc other expenses which translate poorly across wave questionairres
	
	replace loan_reason = temp if temp != 0
	drop temp
	
	label define loan_reason_lbl ///
		1  "1. Farming input" /// this is the critical classificaiton that we use
		5  "5. Non Farm Business" ///
		7  "7. Misc - Large bucket of remaining expenses" ///
		8  "8. Education" ///
		11 "11. Other household consumption" ///
		12 "12. Health"

	label values loan_reason loan_reason_lbl
	
	//match classifications --- not directly used in analysis but provides information on loan composition 
		capture drop lender_group
		gen byte lender_group = .

		//Formal (banks & microfinance as per Wave 4 instrument usage)
		replace lender_group = 3 if inlist(lender_type, 4, 3)

		//Semi-formal (registered non-bank)
		replace lender_group = 2 if inlist(lender_type, 8,1)   // Cooperative society

		//Informal (community/interpersonal/vendor credit)
		replace lender_group = 1 if inlist(lender_type, 2, 5, 6, 7, 9)

		label define lender_group_lbl 1 "Informal" 2 "Semi-formal" 3 "Formal"
		label values lender_group lender_group_lbl
	
	//appending to non loan applciations for a complete dataset
	append using `no_loan' 
	
	//FINAL SECTION: this merges on all the other datasets we've created
	merge m:1 hhid using `head_flag', gen(m1)
		keep if m1==3
		drop m1
		
	merge m:1 hhid using `phone_type', gen(m1)
		keep if m1==3
		drop m1
	
	merge m:1 hhid using `income', gen(m1)
		keep if m1==3
		drop m1
	
	merge m:1 hhid using `head_demo', gen(m1)
		keep if m1==3
		drop m1
		
	merge m:1 hhid using `hh_size', gen(_m10)
		keep if _m10==3
		drop _m10
	
	save "${root}/Stata Code/Stata Data Landing/import_data_w4.dta", replace