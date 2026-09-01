//this file creates physical labor and herbicide outcomes without changing existing expenditure data
	clear all
	set more off

//small helper: turn the hired worker rosters into person-days
	capture program drop build_hired_days
	program define build_hired_days
		args phase flag1 workers1 days1 flag2 workers2 days2 flag3 workers3 days3

		foreach g in 1 2 3 {
			//only an explicit yes contributes days; no and routed skips contribute zero
			gen double person_days_`g' = 0
			replace person_days_`g' = `workers`g'' * `days`g'' if `flag`g'' == 1 & !missing(`workers`g'', `days`g'')
		}

		gen byte unresolved_labor = (`flag1' == 1 & missing(`workers1', `days1')) | ///
			(`flag2' == 1 & missing(`workers2', `days2')) | ///
			(`flag3' == 1 & missing(`workers3', `days3'))
		egen plot_person_days = rowtotal(person_days_1 person_days_2 person_days_3)
		collapse (sum) `phase'_person_days=plot_person_days ///
			(max) `phase'_labor_missing=unresolved_labor, by(hhid)
	end

//Wave 4 planting labor: men, women, and children
	use "${root}/Source Data/Nigeria GHS Wave 4/Raw DTA files/sect11c1b_plantingw4.dta", clear
		keep hhid s11c1q2a s11c1q2 s11c1q3 s11c1q5a s11c1q5 s11c1q6 s11c1q8a s11c1q8 s11c1q9
		build_hired_days planting s11c1q2a s11c1q2 s11c1q3 s11c1q5a s11c1q5 s11c1q6 s11c1q8a s11c1q8 s11c1q9
		tempfile planting_w4
		save `planting_w4'

//Wave 4 harvest labor
	use "${root}/Source Data/Nigeria GHS Wave 4/Raw DTA files/secta2b_harvestw4.dta", clear
		keep hhid sa2bq2a sa2bq2 sa2bq3 sa2bq5a sa2bq5 sa2bq6 sa2bq8a sa2bq8 sa2bq9
		build_hired_days harvest sa2bq2a sa2bq2 sa2bq3 sa2bq5a sa2bq5 sa2bq6 sa2bq8a sa2bq8 sa2bq9
		merge 1:1 hhid using `planting_w4', nogen
		gen wave = 4
		tempfile labor_w4
		save `labor_w4'

//Wave 5 planting labor
	use "${root}/Source Data/Nigeria GHS Wave 5/Raw DTA files/sect11c1b_plantingw5.dta", clear
		keep hhid s11c1q2_1 s11c1q3_1 s11c1q4_1 s11c1q2_2 s11c1q3_2 s11c1q4_2 s11c1q2_3 s11c1q3_3 s11c1q4_3
		build_hired_days planting s11c1q2_1 s11c1q3_1 s11c1q4_1 s11c1q2_2 s11c1q3_2 s11c1q4_2 s11c1q2_3 s11c1q3_3 s11c1q4_3
		tempfile planting_w5
		save `planting_w5'

//Wave 5 harvest labor
	use "${root}/Source Data/Nigeria GHS Wave 5/Raw DTA files/secta2b_harvestw5.dta", clear
		keep hhid sa2bq1_1 sa2bq2_1 sa2bq3_1 sa2bq1_2 sa2bq2_2 sa2bq3_2 sa2bq1_3 sa2bq2_3 sa2bq3_3
		build_hired_days harvest sa2bq1_1 sa2bq2_1 sa2bq3_1 sa2bq1_2 sa2bq2_2 sa2bq3_2 sa2bq1_3 sa2bq2_3 sa2bq3_3
		merge 1:1 hhid using `planting_w5', nogen
		gen wave = 5
		append using `labor_w4'

//add the cultivated-area denominator and herbicide rate from EPAR
	preserve
		use "${root}/Source Data/Nigeria GHS Wave 4/epar_data/Nigeria_GHS_W4_household_variables.dta", clear
		keep hhid ag_hh farm_area herb_rate labor_hired
		drop if missing(hhid)
		keep if ag_hh == 1
		drop ag_hh
		gen wave = 4
		tempfile epar_w4
		save `epar_w4'
	restore

	preserve
		use "${root}/Source Data/Nigeria GHS Wave 5/epar_data/Nigeria_GHS_W5_household_variables.dta", clear
		keep hhid ag_hh farm_area herb_rate labor_hired
		drop if missing(hhid)
		keep if ag_hh == 1
		drop ag_hh
		gen wave = 5
		append using `epar_w4'
		isid hhid wave
		tempfile epar_inputs
		save `epar_inputs'
	restore

	//EPAR provides the household-wave universe; absent conditional labor rosters contribute zero
	merge 1:1 hhid wave using `epar_inputs', keep(2 3) nogen
	replace planting_person_days = 0 if missing(planting_person_days)
	replace harvest_person_days = 0 if missing(harvest_person_days)
	replace planting_labor_missing = 0 if missing(planting_labor_missing)
	replace harvest_labor_missing = 0 if missing(harvest_labor_missing)

	egen hired_person_days = rowtotal(planting_person_days harvest_person_days)
	replace hired_person_days = . if planting_labor_missing == 1 | harvest_labor_missing == 1
	//the EPAR level is not used, but its binary support catches any unresolved roster conflict
	replace hired_person_days = . if !missing(labor_hired) & labor_hired > 0 & hired_person_days == 0
	gen byte any_hired_labor = hired_person_days > 0 if !missing(hired_person_days)

//Wave 5 phone-round files are not available, so flag mixed-mode labor and inputs separately
	preserve
		use "${root}/Source Data/Nigeria GHS Wave 5/Raw DTA files/secta_harvestw5.dta", clear
		keep hhid mm_labor mm_inputs
		isid hhid
		gen byte mixed_mode_labor = mm_labor == 1
		gen byte mixed_mode_herbicide = mm_inputs == 1
		keep hhid mixed_mode_labor mixed_mode_herbicide
		tempfile mixed_mode
		save `mixed_mode'
	restore

	merge m:1 hhid using `mixed_mode', keep(1 3) nogen
	replace mixed_mode_labor = 0 if wave == 4
	replace mixed_mode_herbicide = 0 if wave == 4
	replace mixed_mode_labor = 1 if wave == 5 & missing(mixed_mode_labor)
	replace mixed_mode_herbicide = 1 if wave == 5 & missing(mixed_mode_herbicide)

//construct the physical outcomes without changing the main analysis sample
	gen double hired_person_days_ha = hired_person_days / farm_area if farm_area > 0
	gen double herbicide_kg_ha = herb_rate
	replace any_hired_labor = . if mixed_mode_labor == 1
	replace hired_person_days = . if mixed_mode_labor == 1
	replace hired_person_days_ha = . if mixed_mode_labor == 1
	replace herbicide_kg_ha = . if mixed_mode_herbicide == 1

	//apply the same upper-tail rule by wave while retaining all household-wave rows
	winsor2 hired_person_days hired_person_days_ha herbicide_kg_ha, replace cuts(0 99) by(wave)
	keep hhid wave farm_area mixed_mode_labor mixed_mode_herbicide ///
		any_hired_labor hired_person_days hired_person_days_ha herbicide_kg_ha
	isid hhid wave
	save "${root}/Stata Code/Stata Data Landing/physical_input_outcomes.dta", replace
