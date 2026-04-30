// Will Hankins edit 8/12/25
	clear all      // clears data, value labels, saved results, and programs
	set more off   // prevents output from pausing with "more"
	cd "C:\Users\Will\OneDrive - The Ohio State University\RA\Data\EPAR Nigeria"
	
	//Food Insecurty Experience Scale FIES
			import delimited "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\RCode\household_probs_long.csv", clear
			drop p_mod_only
			rename (p_mod p_sev) (probability_moderately_insecure probability_severly_insecure)
			
			//weighted summary statistics
			bysort wave: summarize probability_moderately_insecure probability_severly_insecure [aw = weight]
			drop weight
			
			//density plots for visual
			twoway (kdensity probability_severly_insecure if wave==4, bwidth(.1)) ///
			   (kdensity probability_severly_insecure if wave==5, bwidth(.1)), ///
			   legend(label(1 "Wave 4") label(2 "Wave 5")) ///
			   title("Distribution of Pr(Severely Food Insecure)")
			
			twoway (kdensity probability_moderately_insecure if wave==4, bwidth(.1)) ///
			   (kdensity probability_moderately_insecure if wave==5, bwidth(.1)), ///
			   legend(label(1 "Wave 4") label(2 "Wave 5")) ///
			   title("Distribution of P(Moderately Food Insecure)")

			save "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\fies_index_both_waves_long.dta", replace
			
			//reshaping for saving it wide
			reshape wide probability_moderately_insecure probability_severly_insecure, i(hhid) j(wave)
						
			save "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\fies_index_both_waves_wide.dta", replace
		
	//Food Consumption Score (FCS)
		//wave 5
			global raw_folder "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\LSMS-Agricultural-Indicators-Code-main\LSMS-Agricultural-Indicators-Code-main\Nigeria GHS\Nigeria GHS Wave 5\Raw DTA files"
			//last section of food consumption is exactly what we need presubably by design
			use "${raw_folder}/sect5c_harvestw5.dta", clear
			
			replace item_cd = 1 if item_cd==2
			drop if inlist(item_cd,6,11,12) //not core categories spices and beverages
			
			collapse (max) s5cq8, by(hhid item_cd)
			gen weight = 2
			replace weight = 3 if item_cd==3
			replace weight = 1 if item_cd==4
			replace weight = 1 if item_cd==7
			replace weight = 4 if item_cd==5
			replace weight = 4 if item_cd==8
			replace weight = 0.5 if item_cd==10
			replace weight = 0.5 if item_cd==9
			
			gen weighted_consumption = s5cq8*weight
			
			collapse (sum) weighted_consumption, by(hhid)
			
			rename weighted_consumption FCS_index
			hist FCS_index
			
			gen wave = 5
				
			tempfile w5_fcs
			save `w5_fcs'
			
		//wave 4
			global raw_folder "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\LSMS-Agricultural-Indicators-Code-main\LSMS-Agricultural-Indicators-Code-main\Nigeria GHS\Nigeria GHS Wave 4\Raw DTA files"
			//last section of food consumption is exactly what we need presubably by design
			use "${raw_folder}/sect10c_harvestw4.dta", clear
			
			replace item_cd = 1 if item_cd==2
			drop if inlist(item_cd,6,11) //not core categories spices and beverages
			
			collapse (max) s10cq8, by(hhid item_cd)
			gen weight = 2
			replace weight = 3 if item_cd==3
			replace weight = 1 if item_cd==4
			replace weight = 1 if item_cd==7
			replace weight = 4 if item_cd==5
			replace weight = 4 if item_cd==8
			replace weight = 0.5 if item_cd==10
			replace weight = 0.5 if item_cd==9
			
			gen weighted_consumption = s10cq8*weight
			
			collapse (sum) weighted_consumption, by(hhid)
			
			rename weighted_consumption FCS_index
			hist FCS_index
			
			gen wave = 4
				
			append using `w5_fcs'
			
			twoway (kdensity FCS_index if wave==4, lcolor(blue) lpattern(solid)) ///
		   (kdensity FCS_index if wave==5, lcolor(red)  lpattern(dash)), ///
		   legend(label(1 "Wave 4") label(2 "Wave 5")) ///
		   title("Density of FCS score by wave") ///
		   ytitle("Density") xtitle("Score")

			
			save "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\FCS_index_both_waves_long.dta", replace
			
			reshape wide FCS_index, i(hhid) j(wave)
			
			rename (FCS_index4 FCS_index5) (FCS_inx_wave_4 FCS_inx_wave_5)
			
			save "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\FCS_index_both_waves_wide.dta", replace
			
	//Household Dietary Diversity Score (HDDS)
		//NOTE: this is supposed to be 24 hour recall but we're limited to 7 days so that's what well be doing
		//wave 5	
		global raw_folder "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\LSMS-Agricultural-Indicators-Code-main\LSMS-Agricultural-Indicators-Code-main\Nigeria GHS\Nigeria GHS Wave 5\Raw DTA files"
			//have to go more granualr for this one
			use "${raw_folder}/sect5b_harvestw5.dta", clear
			gen food_group = "NA"
			replace food_group = "Cereals" if inrange(item_cd,10,23)
			replace food_group = "Roots and Tubers" if inrange(item_cd,30,38)
			replace food_group = "Vegtables" if inrange(item_cd,70,79)
			replace food_group = "Fruits" if inrange(item_cd,60,69) | item_cd == 601
			replace food_group = "Meats" if inrange(item_cd,80,82) | inrange(item_cd,90,96)
			replace food_group = "Fish or Seafood" if inrange(item_cd,100,107)
			replace food_group = "Eggs" if inrange(item_cd,83,85)
			replace food_group = "Pulses, Legumes, Nuts" if inrange(item_cd,40,48)
			replace food_group = "Milk and Dairy Products" if inrange(item_cd,110,115)
			replace food_group = "Oils and Fats" if inrange(item_cd,50,56)
			replace food_group = "Surgar/Honey" if inrange(item_cd,130,133)
			replace food_group = "Miscellaneous" if inrange(item_cd,141,148)
			
			replace s5bq1 = 0 if s5bq1==2
			drop if food_group=="NA"
			
			collapse (max) s5bq1, by(hhid food_group)
			
			collapse (sum) s5bq1, by(hhid)
			
			rename s5bq1 HDDS_index
			
			//quiet sum HDDS_index, detail
			//scalar m = r(mean)
			//scalar s = r(sd)
			//replace HDDS_index = HDDS_index/r(mean)
			//replace HDDS_index = HDDS_index/r(sd)
			
			gen wave = 5
				
			tempfile w5_hdds
			save `w5_hdds'
			
		//wave 5	
		global raw_folder "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\LSMS-Agricultural-Indicators-Code-main\LSMS-Agricultural-Indicators-Code-main\Nigeria GHS\Nigeria GHS Wave 4\Raw DTA files"
			//have to go more granualr for this one
			use "${raw_folder}/sect10b_harvestw4.dta", clear
			gen food_group = "NA"
			replace food_group = "Cereals" if inrange(item_cd,10,23)
			replace food_group = "Roots and Tubers" if inrange(item_cd,30,38)
			replace food_group = "Vegtables" if inrange(item_cd,70,79)
			replace food_group = "Fruits" if inrange(item_cd,60,69) | item_cd == 601
			replace food_group = "Meats" if inrange(item_cd,80,82) | inrange(item_cd,90,96)
			replace food_group = "Fish or Seafood" if inrange(item_cd,100,107)
			replace food_group = "Eggs" if inrange(item_cd,83,85)
			replace food_group = "Pulses, Legumes, Nuts" if inrange(item_cd,40,48)
			replace food_group = "Milk and Dairy Products" if inrange(item_cd,110,115)
			replace food_group = "Oils and Fats" if inrange(item_cd,50,56)
			replace food_group = "Surgar/Honey" if inrange(item_cd,130,133)
			replace food_group = "Miscellaneous" if inrange(item_cd,141,148)
			
			replace s10bq1 = 0 if s10bq1==2
			drop if food_group=="NA"
			
			collapse (max) s10bq1, by(hhid food_group)
			
			collapse (sum) s10bq1, by(hhid)
			
			rename s10bq1 HDDS_index
			
			gen wave = 4
			
			append using `w5_hdds'
			
			twoway (kdensity HDDS_index if wave==4, lcolor(blue) lpattern(solid) bwidth(1)) ///
			   (kdensity HDDS_index if wave==5, lcolor(red)  lpattern(dash) bwidth(1)), ///
			   legend(label(1 "Wave 4") label(2 "Wave 5")) ///
			   title("Density of HDDS score by wave") ///
			   ytitle("Density") xtitle("Score")
			
			save "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\HDDS_index_both_waves_long.dta", replace
			
			reshape wide HDDS_index, i(hhid) j(wave)
			
			rename (HDDS_index4 HDDS_index5) (HDDS_index_wave_4 HDDS_index_wave_5)
			
			save "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\HDDS_index_both_waves_wide.dta", replace
			
			
	//pulling data
		use "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\fies_index_both_waves_wide.dta", clear
		merge 1:1 hhid using "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\FCS_index_both_waves_wide.dta", nogen
		merge 1:1 hhid using "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\HDDS_index_both_waves_wide.dta", nogen
		
		save "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\Master_Food_Security_indexs_both_waves_wide.dta",replace
		
		use "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\fies_index_both_waves_long.dta", clear
		merge 1:1 hhid wave using "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\FCS_index_both_waves_long.dta", nogen
		merge 1:1 hhid wave using "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\HDDS_index_both_waves_long.dta", gen(_merge)
			keep if _merge==3
			drop _merge 
			
		save "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\Master_Food_Security_indexs_both_waves_long.dta",replace
		
		
			
		
		
			
			
			
			