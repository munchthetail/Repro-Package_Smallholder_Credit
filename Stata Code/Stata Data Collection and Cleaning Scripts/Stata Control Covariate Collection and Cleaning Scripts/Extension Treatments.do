//Extension treatments for each household and wave, using questionnaires sections 11L1 and a5b.
//This code is run inside "DML Data Prep.do"
//for extension services all advice topics and sources are included (including access to credit).
//PP = post-planting; PH post-harvest.
//yes establishes receipt; a zero requires all relevant items.
//across visits, a zero requires a known zero in BOTH visits

set more off
tempfile planting wave4

foreach w in 4 5 {
    //raw path and some locals for quick lookups
    local raw "${root}/Source Data/Nigeria GHS Wave `w'/Raw DTA files"
    local sources = cond(`w' == 4, 14, 15)
    local receipt = cond(`w' == 4, "sa5bq1a", "sa5bq1")

    //loading post-planting advice
    use hhid topic_cd s11l1q1 using "`raw'/sect11l1_plantingw`w'.dta", clear
    isid hhid topic_cd
    assert inrange(topic_cd, 1, 12)
    bysort hhid: assert _N == 12
    assert inlist(s11l1q1, 1, 2) | missing(s11l1q1)

    //indicator for post-planting advice
    gen byte pp_any = (s11l1q1 == 1) if inlist(s11l1q1, 1, 2)
    collapse (max) pp_any (count) n_pp_any=pp_any, by(hhid)
    replace pp_any = . if pp_any == 0 & n_pp_any < 12
    keep hhid pp_any
    save `planting', replace

    //loading post-harvest advice
    use hhid source_cd `receipt' using "`raw'/secta5b_harvestw`w'.dta", clear
    isid hhid source_cd
    assert inrange(source_cd, 1, 14) | (`w' == 5 & source_cd == 96)
    bysort hhid: assert _N == `sources'
    assert inlist(`receipt', 1, 2) | missing(`receipt')

    //indicator for post-harvest advice
    gen byte ph_any = (`receipt' == 1) if inlist(`receipt', 1, 2)
    collapse (max) ph_any (count) n_ph_any=ph_any, by(hhid)
    replace ph_any = . if ph_any == 0 & n_ph_any < `sources'
    keep hhid ph_any
    merge 1:1 hhid using `planting', nogen

    //indicator for any advice post-planting or -harvest
    gen byte ext_any_either = .
    replace ext_any_either = 1 if pp_any == 1 | ph_any == 1
    replace ext_any_either = 0 if pp_any == 0 & ph_any == 0
    rename pp_any ext_any_pp

    gen byte wave = `w'
    keep hhid wave ext_any_either ext_any_pp
    if `w' == 4 save `wave4', replace //we're just appending wave 4 to the wave 5 output below
}

append using `wave4'
sort hhid wave
label define extension_receipt 0 "No" 1 "Yes", replace
foreach v in ext_any_either ext_any_pp {
    assert inlist(`v', 0, 1) | missing(`v')
    label values `v' extension_receipt
}
label variable ext_any_either "Any agricultural advice: PP or PH"
label variable ext_any_pp "Any agricultural advice: post-planting"
save "${root}/Stata Code/Stata Data Landing/extension_treatments.dta", replace //we merge this on in the DML prep script