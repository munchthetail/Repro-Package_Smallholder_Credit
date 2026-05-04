//this section collects survey responses from the post harvest "SECTION 15A: ECONOMIC SHOCKS" (wave 4) and "SECTION 12: ECONOMIC SHOCKS" (wave 5)
	//our index attemps to balance the prevalence of reported shocks with their recency, 
	//for our purposes we collect data from the two years preceeding the survey but exlcude reporting shocks 3 years prior to the survey
		//for example, if the survey was conducted in 2024, then we consider shocks occuring in 2023 and 2024
		//the purpose of this is to focus on household access to credit and expenditure patterns being driven by immediate events rather than GE effects years later

	//NOTE the shocks included in the wave 4 and 5 surveys did not perfectly align, we worked to harmonize the categories across waves
	clear all      // clears data, value labels, saved results, and programs
	set more off   // prevents output from pausing with "more"

	//wave 5
		use "${root}/Source Data/Nigeria GHS Wave 5/RAW DTA files/sect12_harvestw5.dta", clear
			
			//classifying shocks into four broad categories
			gen byte food_shock = inlist(shock_cd, 1, 2, 3, 4, 5, 6, 7, 8, 16, 22, 24)
			gen byte income_shock = inlist(shock_cd, 9,10,11, 12, 13,14,15,17,18,19,21,28)
			gen byte price_shock = inlist(shock_cd, 22,23,24,25,26)
			//we include this but it is not utilized in the analysis because of its difficulty to classify (e.g. category: Kidnapping/Abudction for ransom)
			//gen byte other_shock = inlist(shock_cd, 20,27,96)
			
			//keeping shocks from the last two years
			gen recent_flag = (s12q3>=1) if s12q3 < .
			
			//weighing shocks by their recency (i.e. recent_flag==2 if from 2024 and recent_flag==1 if from 2023)
			replace food_shock = food_shock*recent_flag
			replace income_shock = income_shock*recent_flag
			replace price_shock = price_shock*recent_flag
			
			//summing shocks for aggregate household metric
			collapse (sum) food_shock income_shock price_shock, by(hhid)
			
			gen wave = 5
			
			//savings
			tempfile shock_w5
			save `shock_w5'
			
	//wave 4
		use "${root}/Source Data/Nigeria GHS Wave 4/RAW DTA files/sect15a_harvestw4.dta", clear
			keep hhid shock_cd s15aq1 s15aq2 s15aq3a s15aq3b s15aq3c
			rename (s15aq1 s15aq2 s15aq3a s15aq3b s15aq3c) (been_shocked shock_frequency year_2017 year_2018 year_2019)
			
			//classifying shocks into four broad categories`
			gen byte food_shock = inlist(shock_cd,9,10,12,13,14,15,16,17,18,20)
			gen byte income_shock = inlist(shock_cd, 1,2,3,4,5,6,7,8,9,11,21)
			gen byte price_shock = inlist(shock_cd, 18,19,20)
			//we include this but it is not utilized in the analysis because of its difficulty to classify (e.g. category: Kidnapping/Hijacking/robbery/assault)
			//gen byte other_shock = inlist(shock_cd, 22)
			
			//keeping shocks from the last two years
			gen recent_flag = (year_2019==1 | year_2018==1) if year_2019 < . | year_2018 < .
			
			//keeping only recent shocks
			replace food_shock = food_shock*recent_flag
			replace income_shock = income_shock*recent_flag
			replace price_shock = price_shock*recent_flag
			
			//weighing shocks by their recency (i.e. recent_flag==2 if from 2019 and recent_flag==1 if from 2018)
			gen recency = 0
			replace recency = 1 if year_2018==1
			replace recency = 2 if year_2019==1

			//summing shocks for aggregate household metric
			collapse (sum) food_shock income_shock price_shock, by(hhid)
			
			gen wave = 4
			append using `shock_w5'

	//saving
	save "${root}/Stata Code/Stata Data Landing/Shock_index_both_waves_long.dta", replace