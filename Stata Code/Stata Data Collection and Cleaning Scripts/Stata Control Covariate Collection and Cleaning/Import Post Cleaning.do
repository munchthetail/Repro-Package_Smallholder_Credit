// Will Hankins edit 9/16/25
	clear all      // clears data, value labels, saved results, and programs
	set more off   // prevents output from pausing with "more"
	
	local source Will

	cd "C:\Users\\`source'\\OneDrive - The Ohio State University\RA\Data\EPAR Nigeria"
	global raw_folder "C:\Users\\`source'\\OneDrive - The Ohio State University\RA\Stata\LSMS-Agricultural-Indicators-Code-main\LSMS-Agricultural-Indicators-Code-main\Nigeria GHS\Nigeria GHS Wave 4\Raw DTA files"

//running pre req files
	local files : dir "C:\Users\\`source'\\OneDrive - The Ohio State University\RA\Stata" files "Import 20*.do"
			foreach f of local files {
				if !strpos(lower("`f'"), "pulling") {
					di "Running do-file: `f'"
					do "C:\Users\\`source'\\OneDrive - The Ohio State University\RA\Stata/`f'"
				}
			}

//appending data
	use "C:\Users\\`source'\\OneDrive - The Ohio State University\RA\Data\import_data_w5_v1.dta", clear
	append using "C:\Users\\`source'\\OneDrive - The Ohio State University\RA\Data\import_data_w4_v1.dta" 
		
	//some money laundering as it were ;)
		winsor2 net_HH_assets, replace cuts(0 99) by(wave)
	
	//cluping education levels by rough categories
		recode head_edu ///
			(0 51 52 = 0) /// no schooling + religious
			(1/3 = 1) /// pre-primary (N1/N2/pre-nursery)
			(11/16 61 64 = 2) /// primary (P1–P6) + adult/post-literacy ≈ primary
			(21/23 = 3) /// junior secondary (JS1–JS3)
			(24/28 31 33 321 = 4) /// senior secondary/A-levels + secondary VTC + TCG II + Modern
			(34 35 322 = 5) /// post-sec non-degree (NCE, Nursing, tertiary VTC)
			(41 411 412 421/424 = 6) /// tertiary undergrad (poly/prof, OND/ND, HND, Univ 100–600)
			(43 = 7), gen(head_educ_0_7)

		label define ed7 ///
			0 "No/Religious" ///
			1 "Pre-primary" ///
			2 "Primary" ///
			3 "JSS (lower secondary)" ///
			4 "SSS/A-levels (upper secondary)" ///
			5 "Post-sec non-degree (NCE/Nursing/TVET)" ///
			6 "Tertiary undergrad (OND/HND/University)" ///
			7 "Graduate"
			
		label values head_educ_0_7 ed7
				
	//cleaning bank distance --- 999 == "don't know"
		rename (c5q3_bank c5q3_micro_fin c5q3_cell_retail) (bank_distance micro_fin_distance cell_retail_distance)
		replace bank_distance = . if bank_distance == 9999
		replace micro_fin_distance = . if micro_fin_distance == 9999
		replace cell_retail_distance = . if cell_retail_distance == 9999
				
		gen formal_credit_distance = (bank_distance+micro_fin_distance)/2
	
	//total fertilizer use statistic
	egen total_fert_kg_ha = rowtotal(w_npk_rate w_org_fert_rate w_inorg_fert_rate)
	
	//fixing some flags
		//loan status
			replace loan_status = 1 if loan_status == 2 //approved but pending distribution loands lumped with approved and distributed
			replace loan_status = . if loan_status == 3 //dropping pending loan decisions 
			replace loan_status = 0 if loan_status == 4 //loan denied
		
		//sex flag
			replace head_sex = 0 if head_sex == 2
			
		//maritial status
			replace head_maritial_status = 1 if inlist(head_maritial_status,1,2,3) //married
			replace head_maritial_status = 0 if inlist(head_maritial_status,4,5,6,7) //not married
			
		//loan source categories --- these cateogies could be subject to further review as we put ngo and union welfare fund into informal, its more like "less institutional" 
				
				/* WAVE 5
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
				
				/* WAVE 4
				---------------------------+-----------------------------------
					1. COOPERATIVE SOCIETY |        123       14.57       14.57
					2. SAVINGS ASSOCIATION |         78        9.24       23.82
						  3. MICRO FINANCE |        102       12.09       35.90
								   4. BANK |         94       11.14       47.04
					   5. ADASHI/ESUSU/AJO |         93       11.02       58.06
				6. FRIENDS &amp; RELATIVES |        262       31.04       89.10
						  7. MONEY LENDERS |         59        6.99       96.09
						  8. HIRE PURCHASE |          1        0.12       96.21
						9. OTHER (SPECIFY) |         32        3.79      100.00
				---------------------------+-----------------------------------
				*/
			
	//renaming more goodly
		rename (requested_loan s5bq8 s5bq14 s5bq8a__1 s5bq8a__2 s5bq8a__3 s5aq4 s5aq3a s5aq3b s5aq3c) ///
		(loan_request_relation phone_access internet_access phone_basic phone_feature phone_smart mm_access bank_linked_phone bank_notif bank_transfer)
	
	//loan reasoning groups
			gen loan_farming = (loan_reason==1)
			gen loan_nonfarming = (loan_reason==5)
			gen loan_misc = (loan_reason==7)
			gen loan_education = (loan_reason==8)
			gen loan_general_consumption = (loan_reason==11)
			gen loan_health = (loan_reason==12)
			
			gen loan_productivity_flag = inlist(loan_reason, 1,5,8)
	
	//getting loan acceptances
		local vars1 loan_farming loan_nonfarming loan_misc loan_education loan_general_consumption loan_health loan_productivity_flag
		
		foreach v of local vars1 {
			gen approv_`v' = `v'
			replace approv_`v' = 0 if loan_status == 0
		}
		
	//labor hours worked divided by harvested area
		gen w_labor_hired_HA = w_labor_hired/w_farm_area
		gen w_labor_family_HA = w_labor_family/w_farm_area
		gen w_labor_total_HA = w_labor_total/w_farm_area
	
	//applied recode
		replace applied = 0 if applied == 2
		
	//renaming for clarity
	rename formal_land_rights_hh ag_plot_formal_land_rights_hh
			
	//counts for loan apps, approvals, and lender types by hh and wave
		preserve
		collapse ///
			(max) any_approved = loan_status ///
			(max) any_applied = applied ///
			(sum) n_loans = applied ///
			(sum) n_approved = loan_status ///
			, by(hhid wave)
		gen has_loan = (n_loans>0)

		tempfile hhwave_outcomes
		save `hhwave_outcomes', replace
		restore
	
		merge m:1 hhid wave using `hhwave_outcomes', nogen
		 
	//winsorzing loans
	winsor2 loan_amount_recieved, replace cuts(0 99)
	
	//changing for readability
	replace w_total_income = w_total_income/1000
	replace w_value_assets = w_value_assets/1000
	replace w_nonfarm_income = w_nonfarm_income/1000
	replace w_value_crop_production = w_value_crop_production/1000
	
	//exponential terms
	gen w_total_income2 = w_total_income^2
	gen w_value_assets2 = w_value_assets^2
	gen w_farm_area2 = w_farm_area^2
	gen w_farm_size_agland2 = w_farm_size_agland^2

	
	//original farming area
	preserve
		keep if wave == 4
		gen w_farm_area0 = w_farm_area
		keep hhid lid wave w_farm_area0
		
		tempfile area_wave_4
		save `area_wave_4'
	restore

	merge m:1 hhid lid using  `area_wave_4', nogen
	
	//largest crop by HH
		preserve
		duplicates drop hhid wave, force
		
		collapse (sum)  w_kgs_harvest_banana w_kgs_harvest_beanc w_kgs_harvest_cassav w_kgs_harvest_cocoa ///
		w_kgs_harvest_grdnt w_kgs_harvest_maize w_kgs_harvest_millet w_kgs_harvest_rice w_kgs_harvest_sorgum ///
		w_kgs_harvest_soy w_kgs_harvest_swtptt w_kgs_harvest_yam ///
		, by(hhid)
		
		egen maxharv = rowmax(w_kgs_harvest_banana w_kgs_harvest_beanc w_kgs_harvest_cassav w_kgs_harvest_cocoa ///
		w_kgs_harvest_grdnt w_kgs_harvest_maize w_kgs_harvest_millet w_kgs_harvest_rice w_kgs_harvest_sorgum ///
		w_kgs_harvest_soy w_kgs_harvest_swtptt w_kgs_harvest_yam)

		gen top_crop = ""

		foreach crop in banana beanc cassav cocoa grdnt maize millet rice sorgum soy swtptt yam {
			
			gen flag_`crop' = w_kgs_harvest_`crop'
			
			replace top_crop = "`crop'" if maxharv==w_kgs_harvest_`crop'
			replace top_crop = "No Farming" if maxharv==0
			
			drop flag_`crop'
		}

		label var top_crop "Crop with highest harvested kg"
		
		tempfile top_crop
		save `top_crop', replace
		
		restore
		
		merge m:1 hhid using `top_crop', nogen
		
		//farmer flag
		preserve
			collapse (sum) w_kgs_harvest w_value_crop_production w_farm_area w_inorg_fert_rate w_org_fert_rate w_npk_rate ag_plot_formal_land_rights_hh w_labor_hired irrigation_flag lvstck_holding_tlu, by(hhid)
			
			gen farmer = (w_kgs_harvest>0 | w_value_crop_production>0 | w_farm_area>0 | w_inorg_fert_rate>0 | w_org_fert_rate>0 | w_npk_rate>0 | ag_plot_formal_land_rights_hh>0 | w_labor_hired>0 | irrigation_flag>0 | lvstck_holding_tlu>0)
			
			keep hhid farmer
			
			tempfile farmer_flag
			save `farmer_flag'			
		restore
		
		merge m:1 hhid using `farmer_flag', nogen
	
	//for clustering at the for granular level, aborbing space and time specific local serial correlation
		egen eawave = group(ea wave)
	
	//livestock flag
	gen livestock_flag = (lvstck_holding_tlu>0)
	
	//livestock dominant flag - winsorize first
	winsor2 lvstck_holding_tlu, replace cut(0 99)
	rename lvstck_holding_tlu w_lvstck_holding_tlu
	
	//rename so variable name fits
	rename ag_plot_formal_land_rights_hh ag_plot_formal_rights_hh
	
	gen w_value_crop_production2 = w_value_crop_production^2
	reg w_lvstck_holding_tlu c.w_value_crop_production w_value_crop_production2 if w_value_crop_production>0
	predict uhat
	
	gen livestock_dominant_flag = ((w_lvstck_holding_tlu > 6*uhat) & w_value_crop_production<2500000)
	drop uhat w_value_crop_production2
	
	
	//counts for any approval for farming loans
		preserve
		gen farming_loan_total_amount = loan_amount_recieved if approv_loan_farming==1
		collapse ///
			(max) any_arv_farm_loan = approv_loan_farming ///
			(sum) farming_loan_count = approv_loan_farming ///
			(sum) farmer_loan_count = any_approved ///
			(sum) farming_loan_total_amount ///
			, by(hhid wave)
		
		gen farmer_additional_loans = (farming_loan_count < farmer_loan_count & farming_loan_count>0)
		tempfile farming_loan_approv
		save `farming_loan_approv', replace
		restore
		
		merge m:1 hhid wave using `farming_loan_approv', nogen
	
	//more effcient way to get non_farming loans
	gen non_farming_loan = (loan_reason > 1 & loan_reason!=.)
	
	//ever had a farming loan
		preserve
		collapse (max) any_arv_farm_loan, by(hhid)
		rename any_arv_farm_loan had_farm_loan
		tempfile had_farm_loan
		save `had_farm_loan'
		restore
		
		merge m:1 hhid using `had_farm_loan', nogen
	
	//halves sections of regressions
	egen farm_size_halves = xtile(w_farm_size_agland) if ag_hh, nq(2)
	
	//ever had a farming loan
		preserve
		collapse (max) farm_size_halves, by(hhid)
		rename farm_size_halves ever_farm_size_halves
		tempfile ever_farm_size_halves
		save `ever_farm_size_halves'
		restore
		
		merge m:1 hhid using `ever_farm_size_halves', nogen
	
	//sectile
	egen farm_size_setile = xtile(w_farm_size_agland), nq(7)
	gen large_farm = (farm_size_setile == 7)
			
	winsor2 farming_loan_total_amount, cut(0 99) s(_w)
	
	rename (farming_loan_total_amount_w) (w_farming_loan_total_amount)
	
	save "C:\Users\\`source'\\OneDrive - The Ohio State University\RA\Data\cleaned_general_data.dta", replace