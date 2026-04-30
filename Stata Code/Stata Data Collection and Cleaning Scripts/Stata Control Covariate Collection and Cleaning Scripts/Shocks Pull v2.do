// Will Hankins edit 8/12/25
	clear all      // clears data, value labels, saved results, and programs
	set more off   // prevents output from pausing with "more"
	cd "C:\Users\Will\OneDrive - The Ohio State University\RA\Data\EPAR Nigeria"
	

	//We're building a economic shock index === years since shock (22=0,23=1,24=2) + (loss of income == 1) + (decrease in assets == 1) summed over all 29 shock categories
	//the above would be idea but wave 4 has a more limited dataset so we will just sum shocks over years of recency (frequency of shocks * year (2 for current year / 1 for prior year))
	//wave 5
	global raw_folder "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\LSMS-Agricultural-Indicators-Code-main\LSMS-Agricultural-Indicators-Code-main\Nigeria GHS\Nigeria GHS Wave 5\Raw DTA files"
		use "${raw_folder}/sect12_harvestw5.dta", clear
			
			gen byte food_shock = inlist(shock_cd, 1, 2, 3, 4, 5, 6, 7, 8, 16, 22, 24)
			gen byte income_shock = inlist(shock_cd, 9,10,11, 12, 13,14,15,17,18,19,21,28)
			gen byte price_shock = inlist(shock_cd, 22,23,24,25,26)
			gen byte other_shock = inlist(shock_cd, 20,27,96)
			
			gen recent_flag = (s12q3>=1) if s12q3 < .
			
			replace food_shock = food_shock*recent_flag
			replace income_shock = income_shock*recent_flag
			replace price_shock = price_shock*recent_flag
			replace other_shock = other_shock*recent_flag
			
			rename (s12q2 s12q3 s12q4a s12q4b) (been_shocked most_recent_shock lost_income lost_assets)

			replace most_recent_shock = most_recent_shock
			gen shock_index = been_shocked*most_recent_shock
			
			collapse (sum) shock_index food_shock income_shock price_shock other_shock, by(hhid)
			
			quiet sum shock_index, detail
			scalar sd = r(sd)
			replace shock_index = shock_index/sd
			
			gen shock_flag = 0
			replace shock_flag = 1 if shock_index>0
			 
			gen wave = 5
			
			tempfile shock_w5
			save `shock_w5'
			
	//wave 4
	global raw_folder "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\LSMS-Agricultural-Indicators-Code-main\LSMS-Agricultural-Indicators-Code-main\Nigeria GHS\Nigeria GHS Wave 4\Raw DTA files"
		use "${raw_folder}/sect15a_harvestw4.dta", clear
			keep hhid shock_cd s15aq1 s15aq2 s15aq3a s15aq3b s15aq3c
			rename (s15aq1 s15aq2 s15aq3a s15aq3b s15aq3c) (been_shocked shock_frequency year_2017 year_2018 year_2019)
			
			gen food_shock = 0
			replace food_shock = 1 if inlist(shock_cd,9,10,12,13,14,15,16,17,18,20)
			gen byte income_shock = inlist(shock_cd, 1,2,3,4,5,6,7,8,9,11,21)
			gen byte price_shock = inlist(shock_cd, 18,19,20)
			gen byte other_shock = inlist(shock_cd, 22)
			
			gen recent_flag = (year_2019==1 | year_2018==1) if year_2019 < . | year_2018 < .
			
			replace food_shock = food_shock*recent_flag
			replace income_shock = income_shock*recent_flag
			replace price_shock = price_shock*recent_flag
			replace other_shock = other_shock*recent_flag
			
			gen recency = 0
			replace recency = 1 if year_2018==1
			replace recency = 2 if year_2019==1

			gen shock_index = recency*shock_frequency
			
			collapse (sum) shock_index food_shock income_shock price_shock other_shock, by(hhid)
			quiet sum shock_index, detail
			scalar sd = r(sd)
			replace shock_index = shock_index/sd
			
			gen shock_flag = 0
			replace shock_flag = 1 if shock_index>0
			
			gen wave = 4
			
			append using `shock_w5'
			
			sort wave
			by wave: summarize shock_index food_shock income_shock price_shock other_shock
			
			//by gender of head
				twoway (kdensity food_shock if wave==4, lcolor(blue) lpattern(solid) bwidth(.3)) ///
				   (kdensity food_shock if wave==5, lcolor(red)  lpattern(dash) bwidth(.3)), ///
				   legend(label(1 "Wave 4") label(2 "Wave 5")) ///
				   title("Density of Food Shocks by wave") ///
				   ytitle("Density") xtitle("Shocks")
				   
				twoway (kdensity income_shock if wave==4, lcolor(blue) lpattern(solid) bwidth(.3)) ///
				   (kdensity income_shock if wave==5, lcolor(red)  lpattern(dash) bwidth(.3)), ///
				   legend(label(1 "Wave 4") label(2 "Wave 5")) ///
				   title("Density of Income Shocks by wave") ///
				   ytitle("Density") xtitle("Shocks")
				
				twoway (kdensity price_shock if wave==4, lcolor(blue) lpattern(solid) bwidth(.3)) ///
				   (kdensity price_shock if wave==5, lcolor(red)  lpattern(dash) bwidth(.3)), ///
				   legend(label(1 "Wave 4") label(2 "Wave 5")) ///
				   title("Density of Price Shocks by wave") ///
				   ytitle("Density") xtitle("Shocks")
			
			//by college attended
				twoway (kdensity food_shock if wave==4, lcolor(blue) lpattern(solid) bwidth(.3)) ///
				   (kdensity food_shock if wave==5, lcolor(red)  lpattern(dash) bwidth(.3)), ///
				   legend(label(1 "Wave 4") label(2 "Wave 5")) ///
				   title("Density of Food Shocks by wave") ///
				   ytitle("Density") xtitle("Shocks")
				   
				twoway (kdensity income_shock if wave==4, lcolor(blue) lpattern(solid) bwidth(.3)) ///
				   (kdensity income_shock if wave==5, lcolor(red)  lpattern(dash) bwidth(.3)), ///
				   legend(label(1 "Wave 4") label(2 "Wave 5")) ///
				   title("Density of Income Shocks by wave") ///
				   ytitle("Density") xtitle("Shocks")
				
				twoway (kdensity price_shock if wave==4, lcolor(blue) lpattern(solid) bwidth(.3)) ///
				   (kdensity price_shock if wave==5, lcolor(red)  lpattern(dash) bwidth(.3)), ///
				   legend(label(1 "Wave 4") label(2 "Wave 5")) ///
				   title("Density of Price Shocks by wave") ///
				   ytitle("Density") xtitle("Shocks")
			
				
	//saving
	save "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\Shock_index_both_waves_long.dta", replace
	