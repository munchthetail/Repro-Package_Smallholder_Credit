// Will Hankins edit 8/12/25
clear all      // clears data, value labels, saved results, and programs
set more off   // prevents output from pausing with "more"

local source Will

cd "C:\Users\\`source'\\OneDrive - The Ohio State University\RA\Data\EPAR Nigeria"
global raw_folder "C:\Users\\`source'\\OneDrive - The Ohio State University\RA\Stata\LSMS-Agricultural-Indicators-Code-main\LSMS-Agricultural-Indicators-Code-main\Nigeria GHS\Nigeria GHS Wave 5\Raw DTA files"



//ssc install tabmiss
ssc install univar

//log using "mylog.txt", text replace

//making a head HH flag for future use
use "${raw_folder}/sect1_harvestw5.dta", clear
	keep state hhid indiv s1q3 
	keep if s1q3 == 1
	drop s1q3 indiv
	
	isid hhid
	tempfile head_flag
	save `head_flag'
	
//pulling edu for indiv
	use "${raw_folder}/sect2_harvestw5.dta", clear
	keep indiv hhid s2q9
	rename s2q9 head_edu
	
	isid hhid indiv
	tempfile 11_edu
	save `11_edu'
	
//HH member composition
	use "${raw_folder}/sect1_harvestw5.dta", clear
	
		gen member = 0
		replace member = 1 if s1q4==1 | NEWMEMBER==1
		keep if member == 1
		
		gen preteen_members = 0
		replace preteen_members = 1 if s1q6 <= 12
		
		gen child_dependent_members = 0
		replace child_dependent_members = 1 if s1q6 <= 17
		
		gen adult_member = 0 
		replace adult_member = 1 if s1q6 >= 18
		
		gen adult_male_member = 0 
		replace adult_male_member = 1 if s1q6 >= 18 & s1q2==1
		
		gen male_members = 0
		replace male_members = 1 if s1q2==1
		
		preserve
			collapse (sum) member, by(hhid)
			tempfile hh_members
			save `hh_members'		
		restore
		
		preserve
			collapse (sum) preteen_members, by(hhid)
			tempfile hh_preteen
			save `hh_preteen'		
		restore
		
		preserve
			collapse (sum) child_dependent_members, by(hhid)
			tempfile hh_children
			save `hh_children'		
		restore
		
		preserve
			collapse (sum) adult_member, by(hhid)
			tempfile hh_adults
			save `hh_adults'		
		restore
		
		preserve
			collapse (sum) adult_male_member, by(hhid)
			tempfile hh_male_adults
			save `hh_male_adults'		
		restore
		
		preserve
			collapse (sum) male_members, by(hhid)
			tempfile hh_males
			save `hh_males'		
		restore
	
	keep hhid
	duplicates drop hhid, force
		
	merge 1:1 hhid using `hh_members'
		keep if _merge==3
		drop _merge
	merge 1:1 hhid using `hh_preteen'
		keep if _merge==3
		drop _merge

	merge 1:1 hhid using `hh_children'
		keep if _merge==3
		drop _merge	
		
	merge 1:1 hhid using `hh_adults'
		keep if _merge==3
		drop _merge
	
	merge 1:1 hhid using `hh_male_adults'
		keep if _merge==3
		drop _merge
	
	merge 1:1 hhid using `hh_males'
		keep if _merge==3
		drop _merge
		
	preserve
		keep hhid member
		rename member weight
		save "C:\Users\\`source'\\OneDrive - The Ohio State University\RA\Data\EPAR Nigeria\Nigeria GHS W4\final_data\Nigeria_GHS_W5_household_weights.dta",replace
	restore
		
	tempfile 12_hh_size
	save `12_hh_size'
	
//pulling general demographic info about HH head
	use "${raw_folder}/sect1_harvestw5.dta", clear
	keep hhid indiv s1q2 s1q3 s1q6 s1q16 s1q28 s1q33 s1q24
	
	keep if s1q3 == 1 
	
	//merging on edu
	merge 1:1 hhid indiv using `11_edu', generate(_m1)
		keep if _m1==3
		drop _m1
	
	drop indiv //indiv is redundent when we keep only heads
	rename (s1q2 s1q3 s1q6 s1q16 s1q28 s1q33 s1q24) (head_sex head_relation head_age head_maritial_status head_father_edu head_monther_edu head_religion)
	
	isid hhid
	tempfile 10_head_demo
	save `10_head_demo'

//pulling income data FROM EPAR
	use "C:\Users\\`source'\\OneDrive - The Ohio State University\RA\Data\EPAR Nigeria\Nigeria GHS W5\final_data\Nigeria_GHS_W5_household_variables.dta", clear

	//keeping income variables 
		keep hhid crop_income fish_income_fishing fish_income_fishfarm fishing_income livestock_income self_employment_income agwage_income nonagwage_income investment_income rental_income_buildings assistance_income rental_income_assets income_pension remittance_income transfers_income all_other_income ag_hh agactivities_hh crop_hh livestock_hh w_crop_income w_livestock_income w_fishing_income w_self_employment_income w_nonagwage_income w_agwage_income w_transfers_income w_all_other_income total_income nonfarm_income farm_income percapita_income w_total_income w_nonfarm_income w_farm_income w_percapita_income w_share_crop w_share_livestock w_share_fishing w_share_self_employment w_share_nonagwage w_share_agwage w_share_transfers w_share_all_other w_share_nonfarm w_value_assets formal_land_rights_hh w_npk_rate w_org_fert_rate w_inorg_fert_rate w_total_harv_area_banana w_total_harv_area_beanc w_total_harv_area_cassav w_total_harv_area_cocoa w_total_harv_area_grdnt w_total_harv_area_maize w_total_harv_area_millet w_total_harv_area_rice w_total_harv_area_sorgum w_total_harv_area_soy w_total_harv_area_swtptt w_total_harv_area_yam w_kgs_harvest_banana w_kgs_harvest_beanc w_kgs_harvest_cassav w_kgs_harvest_cocoa w_kgs_harvest_grdnt w_kgs_harvest_maize w_kgs_harvest_millet w_kgs_harvest_rice w_kgs_harvest_sorgum w_kgs_harvest_soy w_kgs_harvest_swtptt w_kgs_harvest_yam w_kgs_harvest w_labor_hired w_labor_family w_labor_total w_farm_area w_land_productivity w_yield_hv_maize w_yield_hv_rice w_yield_hv_sorgum w_yield_hv_millet w_yield_hv_beanc w_yield_hv_grdnt w_yield_hv_yam w_yield_hv_swtptt w_yield_hv_cassav w_yield_hv_banana w_yield_hv_cocoa w_yield_hv_soy w_value_pro_banana w_value_pro_beanc w_value_pro_cassav w_value_pro_cocoa w_value_pro_grdnt w_value_pro_maize w_value_pro_millet w_value_pro_rice w_value_pro_sorgum w_value_pro_soy w_value_pro_swtptt w_value_pro_yam value_crop_production w_value_crop_production lvstck_holding_tlu nonfarm_income w_nonfarm_income  w_labor_hired pest_rate w_pest_rate farm_size_agland ag_hh w_farm_size_agland
	//dropping one missing row and total income data
		keep if !missing(hhid)
		keep hhid total_income w_total_income w_value_assets formal_land_rights_hh w_npk_rate w_org_fert_rate w_inorg_fert_rate w_total_harv_area_banana w_total_harv_area_beanc w_total_harv_area_cassav w_total_harv_area_cocoa w_total_harv_area_grdnt w_total_harv_area_maize w_total_harv_area_millet w_total_harv_area_rice w_total_harv_area_sorgum w_total_harv_area_soy w_total_harv_area_swtptt w_total_harv_area_yam w_kgs_harvest_banana w_kgs_harvest_beanc w_kgs_harvest_cassav w_kgs_harvest_cocoa w_kgs_harvest_grdnt w_kgs_harvest_maize w_kgs_harvest_millet w_kgs_harvest_rice w_kgs_harvest_sorgum w_kgs_harvest_soy w_kgs_harvest_swtptt w_kgs_harvest_yam w_kgs_harvest w_labor_hired w_labor_family w_labor_total w_farm_area w_land_productivity  w_yield_hv_maize w_yield_hv_rice w_yield_hv_sorgum w_yield_hv_millet w_yield_hv_beanc w_yield_hv_grdnt w_yield_hv_yam w_yield_hv_swtptt w_yield_hv_cassav w_yield_hv_banana w_yield_hv_cocoa w_yield_hv_soy w_value_pro_banana w_value_pro_beanc w_value_pro_cassav w_value_pro_cocoa w_value_pro_grdnt w_value_pro_maize w_value_pro_millet w_value_pro_rice w_value_pro_sorgum w_value_pro_soy w_value_pro_swtptt w_value_pro_yam value_crop_production w_value_crop_production lvstck_holding_tlu nonfarm_income w_nonfarm_income  w_labor_hired pest_rate w_pest_rate farm_size_agland ag_hh w_farm_size_agland
		
	isid hhid
	tempfile 9_income
	save `9_income'


//flag for a household having irrigation on at least one plot
	use "${raw_folder}/sect11b1_plantingw5.dta", clear
	keep hhid s11b1q56
	collapse (max) s11b1q56, by(hhid)
	replace s11b1q56 = 0 if s11b1q56==1
	replace s11b1q56 = 1 if s11b1q56==2
	rename s11b1q56 irrigation_flag
	
	tempfile 13_irrigation
	save `13_irrigation'


//pulling assets
//NOTE PLAUSIBLE TYPE IN DATA ENTRY FOR hhid 169150 --- vehicle assets valued very highly 17000000 ~ $11081 maybe drop --- by far largest net asset HH
	use "${raw_folder}/sect10_plantingw5.dta", clear
	keep hhid item_cd s10q1a s10q2 s10q3 /*s10q4_1 who owns item*/ s10q5 s10q6 /*s10q7 does it run on petrol*/
	keep if s10q1a == 1 //owned status
	//keep if s10q3 == 1 //maybe worth including 1==HH ownership 2==indiv ownership
	
	gen tot_worth = s10q2*s10q6
	
	//net asset calc
		collapse (sum) tot_worth , by(hhid)
		rename tot_worth net_HH_assets
		drop if hhid == 169150 //looks erronious subject to further cleaning
	
	isid hhid
	tempfile 8_net_assets
	save `8_net_assets'

//pull land credit access
	use "${raw_folder}/sectc4c_plantingw5.dta", clear
	keep lga ea /*cluster_id*/ csource_cd c4q5 c4q6 c4q7 c4q9 c4q10 c4q12 c4q13 c4q15 c4q16
	
	//making coding more clear
		tostring csource_cd, gen(csource_cd_str) format(%9.0g)
		replace csource_cd_str = "_c_from_bank" 				if csource_cd == 1
		replace csource_cd_str = "_c_from_coop"        			if csource_cd == 2
		replace csource_cd_str = "_c_from_savings_group"   		if csource_cd == 3
		replace csource_cd_str = "_c_from_money_lenders"		if csource_cd == 4
		drop csource_cd
		rename csource_cd_str csource_cd
	
	//reshaping
		reshape wide c4q5 c4q6 c4q7 c4q9 c4q10 c4q12 c4q13 c4q15 c4q16, i(lga ea) j(csource_cd, string)
	
	isid lga ea
	tempfile 7_credit_source
	save `7_credit_source'

//pull land price
	use "${raw_folder}/sectc4b_plantingw5.dta", clear
	keep lga ea /*cluster_id*/ c4q4a c4q4b c4q4c c4q4d
	
	isid lga ea
	tempfile 6_land_price
	save `6_land_price'

//pulling land access
	use "${raw_folder}/sectc4a_plantingw5.dta", clear
	keep lga ea /*cluster_id*/ tenure_cd c4q1 c4q2 c4q3
	
	//making coding more clear
		tostring tenure_cd, gen(tenure_cd_str) format(%9.0g)
		replace tenure_cd_str = "_have_land_w_rights" 			if tenure_cd == 1
		replace tenure_cd_str = "_have_land_wo_rights"        	if tenure_cd == 2
		replace tenure_cd_str = "_use_commons"   				if tenure_cd == 3
		replace tenure_cd_str = "_allow_others_pct_harv"		if tenure_cd == 4
		replace tenure_cd_str = "_rent_fixed_price"        		if tenure_cd == 5
		replace tenure_cd_str = "_right_to_sell"   				if tenure_cd == 6
		replace tenure_cd_str = "_can_inherit_bequeath_land"   	if tenure_cd == 7
		drop tenure_cd
		rename tenure_cd_str tenure_cd
	
	//reshaping
		reshape wide c4q1 c4q2 c4q3, i(lga ea) j(tenure_cd, string)
	
	isid lga ea
	tempfile 5_land_ownership
	save `5_land_ownership'

//pulling data on community infrastructure ie do they have local lending options
	use "${raw_folder}/sectc5_plantingw5.dta", clear
	
	keep lga ea /*cluster_id*/ infra_code c5q1 c5q3 c5q4 c5q5 c5q6b
	keep if inlist(infra_code, 214, 219, 220)
	
	//making coding more clear
		tostring infra_code, gen(infra_code_str) format(%9.0g)
		replace infra_code_str = "_cell_retail" if infra_code == 214
		replace infra_code_str = "_bank"        if infra_code == 219
		replace infra_code_str = "_micro_fin"   if infra_code == 220
		drop infra_code
		rename infra_code_str infra_code
		
	//reshaping
		reshape wide c5q1 c5q3 c5q4 c5q5 c5q6b, i(lga ea) j(infra_code, string)
	
	isid lga ea
	tempfile 4_infra
	save `4_infra'

//pulling data on phone owning
//OPTION: we could merge this onto section 1, to only keep HEADs instead of collapsing the entire family
	use "${raw_folder}/sect5b_plantingw5.dta", clear
	keep hhid /*indiv*/ s5bq8 s5bq8a__* s5bq14 s5bq15__*
	
	foreach v of varlist s5bq8 s5bq8a__* s5bq14 s5bq15__*{
		replace `v' = 0 if `v' == 2
	}
	
	//define the variables
		ds s5bq8 s5bq8a__* s5bq14 s5bq15__*
		local phonevars `r(varlist)'
	
	//build the collapse command
		local sumlist
		local cntlist
		foreach v of local phonevars {
			local sumlist `sumlist' `v'
			local cntlist `cntlist' n_`v'=`v'
		}
	
	//run collapse
		collapse (max) `sumlist' (count) `cntlist', by(hhid)
	
	//restore . if all values missing in a HH
		foreach v of local phonevars {
			di as txt  `v'
			replace `v' = . if n_`v' == 0
			replace `v'  = 1 if `v'  > 0 & !missing(`v')
			drop n_`v'
		}
	
	isid hhid
	tempfile 3_phone_type
	save `3_phone_type'

//pulling access to money apps
	use "${raw_folder}/sect5a1_plantingw5.dta", clear
	keep hhid /*indiv*/ s5aq4 s5aq3a s5aq3b s5aq3c

	//collapsing by HH, retaining if anybody in the HH answered in the affirmative
	//OPTION: we could merge this onto section 1, to only keep HEADs instead of collapsing the entire family
		foreach v in s5aq4 s5aq3a s5aq3b s5aq3c{
			replace `v' = 0 if `v' == 2
		}

		collapse (max) s5aq4 s5aq3a s5aq3b s5aq3c ///
				 (count) n_s5aq4=s5aq4 n_s5aq3a=s5aq3a n_s5aq3b=s5aq3b n_s5aq3c=s5aq3c, by(hhid)

		replace s5aq4  = . if n_s5aq4  == 0
		replace s5aq3a = . if n_s5aq3a == 0
		replace s5aq3b = . if n_s5aq3b == 0
		replace s5aq3c = . if n_s5aq3c == 0
		
		replace s5aq4  = 1 if s5aq4  > 0 & !missing(s5aq4)
		replace s5aq3a = 1 if s5aq3a > 0 & !missing(s5aq3a)
		replace s5aq3b = 1 if s5aq3b > 0 & !missing(s5aq3b)
		replace s5aq3c = 1 if s5aq3c > 0 & !missing(s5aq3c)

		drop n_s5aq4 n_s5aq3a n_s5aq3b n_s5aq3c
		
		isid hhid
		tempfile 2_mobile_phones
		save `2_mobile_phones'
	
//pulling HH that didn't attempt to get loans
	use "${raw_folder}/sect5c1_plantingw5.dta" if s5cq1 == 2, clear
	gen lid = 0
	gen wave = 5
	rename s5cq1 applied
	tempfile 1_no_loan 
	save `1_no_loan'
	
//appending and merging

	use "${raw_folder}/sect5c2_plantingw5.dta", clear
	keep lid zone state sector lga ea hhid lid s5cq1 s5cq4 s5cq5 s5cq6 s5cq12 s5cq2b
	rename (s5cq5 s5cq6 s5cq12 s5cq2b s5cq1 s5cq4) (requested_loan loan_status loan_amount_recieved lender_type applied loan_reason)
	
	//aligning loan request reason with the questions available from the wave 4 survey
	gen temp = 0
	replace temp = 1 if inlist(loan_reason,1,2,3,4) //this is farming imput expenses 
	replace temp = 7 if inlist(loan_reason,6,10,12,13,14,16,96) // large bucket containing misc other expenses which translate poorly across wave questionairres
	replace temp = 11 if inlist(loan_reason,7,11) // other household consumption - note "BUY FARM TOOLS/IMPLEMENTS" does not fit well into wave 4 questions and is placed in other bucket
	replace temp = 12 if inlist(loan_reason,9) // health
	
	replace loan_reason = temp if temp != 0
	drop temp
	
	label define loan_reason_lbl ///
		1  "1. Farming input" ///
		5  "5. Non Farm Business" ///
		7  "7. Misc - Large bucket of remaining expenses" ///
		8  "8. Education" ///
		11 "11. Other household consumption" ///
		12 "12. Health"

	label values loan_reason loan_reason_lbl
	
	//aligning lender type with wave 4 options
		gen lender_group = .
		//Formal (regulated financial institutions)
		replace lender_group = 3 if inlist(lender_type, 1, 6, 12,18)

		//Semi-formal (registered orgs, non-banks)
		replace lender_group = 2 if inlist(lender_type, 5, 4, 20)

		//Informal (community, interpersonal, or trader credit)
		replace lender_group = 1 if inlist(lender_type, 2, 3, 10, 11, 15, 17, 19, 96)

		//Label categories for clarity
		label define lender_group_lbl 1 "Informal" 2 "Semi-formal" 3 "Formal"
		label values lender_group lender_group_lbl
		
				/*	
				COMMERCIAL/RETAIL/MORTGAGE BANK.......................1
				SAVINGS CLUB/ASSOCIATION..............................2
				ROSCA/ASUSU/ESUSU/ADASHE/AJO/ASCA.....................3
				EMPLOYEE/UNION WELFARE FUND...........................4
				SAVINGS AND CREDIT COOPERATIVE ORGANIZATION (SACCO)...5
				MICROFINANCE BANK/INSTITUTION/COMPANIES...............6
				BURIAL SOCIETIES.....................................10
				VILLAGE SAVINGS AND LOAN ASSOCIATIONS (VSLAS)........11
				NEOBANKS (100% DIGITAL BANKS)/ MOBILE NETWORK
				OPERATORS (MNO) / MOBILE MONEY OPERATOR/AGENT........12
				LOCAL/VILLAGE MONEY LENDER .........................15
				NEIGHBOUR/FRIEND/RELATIVE/NON-HH INDIVIDUAL..........17
				NGOS.................................................18
				WOMEN GROUP/ ASSOCIATION.............................19
				VENDOR/HIRE PURCHASE.................................20
				OTHER (SPECIFY)......................................96
				*/
				
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

			* Create mapped variable
			capture drop lender_type_w4
			gen byte lender_type_w4 = . 
			label values lender_type_w4 lender_type_w4_lbl
			label var lender_type_w4 "Wave 5 lender_type mapped to Wave 4 categories"

		//BANK (comm/retail/mortgage) + Neobanks/MNO/mobile money → BANK
			replace lender_type_w4 = 4 if inlist(lender_type, 1, 18, 12)

		//Savings-type groups → SAVINGS ASSOCIATION
		//(Savings club/association, burial societies, VSLAs, women groups)
			replace lender_type_w4 = 2 if inlist(lender_type, 2, 10, 11, 19)

		//ROSCA / ESUSU / AJO / ADASHE / ASCA → ADASHI/ESUSU/AJO
			replace lender_type_w4 = 5 if lender_type == 3

		//Cooperative-type groups → COOPERATIVE SOCIETY
		//(Employee/union welfare funds; SACCOs)
			replace lender_type_w4 = 1 if inlist(lender_type, 4, 5)

		//Microfinance → MICRO FINANCE
			replace lender_type_w4 = 3 if lender_type == 6

		//Local/village money lender → MONEY LENDERS
			replace lender_type_w4 = 7 if lender_type == 15

		//Neighbour/friend/relative/non-HH individual → FRIENDS & RELATIVES
			replace lender_type_w4 = 6 if lender_type == 17

		//Vendor/hire purchase → HIRE PURCHASE
			replace lender_type_w4 = 8 if lender_type == 20

		//NGOs and OTHER → OTHER (SPECIFY)
			replace lender_type_w4 = 9 if inlist(lender_type, 96)
			
		drop lender_type
		rename lender_type_w4 lender_type

	gen wave = 5
	
	append using `1_no_loan' //we can append none-applicants if we want
	
	//merge m:1 hhid using `head_flag'
	
	
	merge m:1 hhid using `2_mobile_phones', generate(_m1)
		keep if _m1==3
		drop _m1
		
	merge m:1 hhid using `3_phone_type', generate(_m2)
		keep if _m2==3
		drop _m2
	
	//56 observations lost in this merge --- investigate further!!!
	merge m:1 lga ea using `4_infra', generate(_m3)
		keep if _m3!=2
		drop _m3
	
	merge m:1 lga ea using `5_land_ownership', generate(_m4)
		keep if _m4==3
		drop _m4
	
	merge m:1 lga ea using `6_land_price', generate(_m5)
		keep if _m5==3
		drop _m5
	
	merge m:1 lga ea using `7_credit_source', generate(_m6)
		keep if _m6==3
		drop _m6
	
	merge m:1 hhid using `8_net_assets', generate(_m7)
		keep if _m7==3
		drop _m7
	
	//7 observations lost in this merge --- investigate further!!!
	merge m:1 hhid using `9_income', generate(_m8)
		keep if _m8==3
		drop _m8
	
	merge m:1 hhid using `10_head_demo', generate(_m9)
		keep if _m9==3
		drop _m9
		
	merge m:1 hhid using `12_hh_size', gen(_m12)
		keep if _m12==3
		drop _m12
		
	merge m:1 hhid using `13_irrigation', gen(_m13)
		keep if _m13!=2
		drop _m13
		
	save "C:\Users\\`source'\\OneDrive - The Ohio State University\RA\Data\import_data_w5_v1.dta", replace






//log close