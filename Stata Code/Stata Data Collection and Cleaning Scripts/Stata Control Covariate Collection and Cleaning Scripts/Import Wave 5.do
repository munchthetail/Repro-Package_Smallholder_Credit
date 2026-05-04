//in this file we pull a wide variety of household characteristics 
//from the 4th survey waves, store them in temp files, then save them at the end of the document
clear all      // clears data, value labels, saved results, and programs
set more off   // prevents output from pausing with "more"


//making a head HH flag for future use
//this is used later to identify head of HH characteristics
use "${root}/Source Data/Nigeria GHS Wave 5/RAW DTA files/sect1_harvestw5.dta", clear
	keep state hhid indiv s1q3 
	keep if s1q3 == 1
	drop s1q3 indiv
	
	isid hhid
	tempfile head_flag
	save `head_flag'
	
//HH member composition
	use "${root}/Source Data/Nigeria GHS Wave 5/RAW DTA files/sect1_harvestw5.dta", clear
		
	//flagging observations for household members
	gen member = 0
	replace member = 1 if s1q4==1 | NEWMEMBER==1
	keep if member == 1
	
	//flagging if the observation is 18+
	gen adult_member = 0 
	replace adult_member = 1 if s1q6 >= 18
	
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

	preserve
		keep hhid member
		rename member weight
		save "${root}/Stata Code/Stata Data Landing/Nigeria_GHS_W5_household_weights.dta",replace
	restore
	
//pulling general demographic info about HH head
	use "${root}/Source Data/Nigeria GHS Wave 5/RAW DTA files/sect1_harvestw5.dta", clear
	keep hhid indiv s1q2 s1q3 s1q6 s1q16 s1q28 s1q33 s1q24
	keep if s1q3 == 1 
	drop indiv //indiv is redundent when we keep only heads
	rename (s1q2 s1q3 s1q6 s1q16 s1q28 s1q33 s1q24) (head_sex head_relation head_age head_maritial_status head_father_edu head_monther_edu head_religion)
	
	isid hhid
	tempfile head_demo
	save `head_demo'

//pulling income data FROM EPAR
	use "${root}/Source Data/Nigeria GHS Wave 5/final_data/Nigeria_GHS_W5_household_variables.dta", clear

	//keeping income variables 
		keep hhid ag_hh w_nonfarm_income w_value_assets formal_land_rights_hh w_npk_rate w_org_fert_rate w_inorg_fert_rate /// 
			w_value_crop_production lvstck_holding_tlu w_nonfarm_income ag_hh w_farm_size_agland

	//dropping one missing row 
	keep if !missing(hhid)
		
	isid hhid
	tempfile income
	save `income'

//pulling data on phone ownership and internet access
	use "${root}/Source Data/Nigeria GHS Wave 5/RAW DTA files/sect5b_plantingw5.dta", clear
	keep hhid s5bq8 s5bq14
	
	//recoding (NO==2 -> NO==0)
	foreach v of varlist s5bq8 s5bq14 {
		replace `v' = 0 if `v' == 2
	}
	
	//checking if the household had a phone or internet access respectively
	collapse (max) s5bq8 s5bq14, by(hhid)
	
	isid hhid
	tempfile phone_type
	save `phone_type'
	
//pulling HH that didn't attempt to get loans
	use "${root}/Source Data/Nigeria GHS Wave 5/RAW DTA files/sect5c1_plantingw5.dta" if s5cq1 == 2, clear
	gen lid = 0
	gen wave = 5
	rename s5cq1 applied
	tempfile no_loan 
	save `no_loan'
	
//getting loan data and with descriptive details for classifying the loans as agricultural credit (more processing in the "Import Post Cleaning.do" file)
//this is are most important source of data for the analysis, we merge everthing else onto this data
	use "${root}/Source Data/Nigeria GHS Wave 5/RAW DTA files/sect5c2_plantingw5.dta", clear
	keep lid zone state sector lga ea hhid lid s5cq1 s5cq4 s5cq5 s5cq6 s5cq12 s5cq2b
	rename (s5cq5 s5cq6 s5cq12 s5cq2b s5cq1 s5cq4) (requested_loan loan_status loan_amount_recieved lender_type applied loan_reason)
	
	//aligning loan request reason with the questions available from the wave 5 survey
	gen temp = 0
	replace temp = 1 if inlist(loan_reason,1,2,3,4) //this is farming imput expenses 
	replace temp = 7 if inlist(loan_reason,6,10,12,13,14,16,96) // large bucket containing misc other expenses which translate poorly across wave questionairres
	replace temp = 11 if inlist(loan_reason,7,11) // other household consumption - note "BUY FARM TOOLS/IMPLEMENTS" does not fit well into wave 4 questions and is placed in other bucket
	replace temp = 12 if inlist(loan_reason,9) // health
	
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
		gen lender_group = .
		//Formal (regulated financial institutions)
		replace lender_group = 3 if inlist(lender_type, 1, 6, 12,18)

		//Semi-formal (registered orgs, non-banks)
		replace lender_group = 2 if inlist(lender_type, 5, 4, 20)

		//Informal (community, interpersonal, or vendor credit)
		replace lender_group = 1 if inlist(lender_type, 2, 3, 10, 11, 15, 17, 19, 96)

		//Label categories for clarity
		label define lender_group_lbl 1 "Informal" 2 "Semi-formal" 3 "Formal"
		label values lender_group lender_group_lbl
						
		//maping money lender type to the more general wave 4 categories for beter comparison
			capture label drop lender_type_w4_lbl
			label define lender_type_w4_lbl ///
				1 "COOPERATIVE SOCIETY" ///
				2 "SAVINGS ASSOCIATION" ///
				3 "MICRO FINANCE" ///
				4 "BANK" ///
				5 "ADASHI/ESUSU/AJO" ///
				6 "FRIENDS & RELATIVES" ///
				7 "MONEY LENDERS" ///
				8 "HIRE PURCHASE" ///
				9 "OTHER (SPECIFY)"

			//create mapped variable
			capture drop lender_type_w4
			gen byte lender_type_w4 = . 
			label values lender_type_w4 lender_type_w4_lbl
			label var lender_type_w4 "Wave 5 lender_type mapped to Wave 4 categories"

		//BANK (comm/retail/mortgage) + Neobanks/MNO/mobile money → BANK
			replace lender_type_w4 = 4 if inlist(lender_type, 1, 18, 12)

		//savings-type groups -> SAVINGS ASSOCIATION
		//(e.g. savings club/association, burial societies, women groups)
			replace lender_type_w4 = 2 if inlist(lender_type, 2, 10, 11, 19)

		//e.g. esusu/ajo -> adashi/esusu/ajo
			replace lender_type_w4 = 5 if lender_type == 3

		//cooperative-type groups -> cooperative society
		//(e.g. employee/union welfare funds; SACCOs)
			replace lender_type_w4 = 1 if inlist(lender_type, 4, 5)

		//microfinance -> micro finance
			replace lender_type_w4 = 3 if lender_type == 6

		//local/village money lender -> money lenders
			replace lender_type_w4 = 7 if lender_type == 15

		//neighbour/friend/relative/non-HH individual -> friends & relatives
			replace lender_type_w4 = 6 if lender_type == 17

		//vendor/hire purchase -> hire purchase
			replace lender_type_w4 = 8 if lender_type == 20

		//NGOs & other -> others
			replace lender_type_w4 = 9 if inlist(lender_type, 96)
			
		drop lender_type
		rename lender_type_w4 lender_type

	gen wave = 5
	
	//appending to non loan applciations for a complete dataset
	append using `no_loan'
	
	
	merge m:1 hhid using `head_flag', gen(m1)
		keep if m1==3
		drop m1
		
	merge m:1 hhid using `phone_type', gen(m1)
		keep if m1==3
		drop m1
	
	//7 observations lost in this merge --- investigate further!!!
	merge m:1 hhid using `income', gen(m1)
		keep if m1==3
		drop m1
	
	merge m:1 hhid using `head_demo', gen(m1)
		keep if m1==3
		drop m1
		
	merge m:1 hhid using `hh_size', gen(m1)
		keep if m1==3
		drop m1
		
	save "${root}/Stata Code/Stata Data Landing/import_data_w5.dta", replace