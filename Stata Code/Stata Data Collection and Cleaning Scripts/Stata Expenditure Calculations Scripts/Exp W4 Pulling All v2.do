// Will Hankins edit 9/16/25
	clear all      // clears data, value labels, saved results, and programs
	set more off   // prevents output from pausing with "more"
	cd "C:\Users\Will\OneDrive - The Ohio State University\RA\Data\EPAR Nigeria"
	
	//doing pre req files
		//doing pre req files
		local files : dir "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata" files "Exp W4 *.do"
		foreach f of local files {
			if !strpos(lower("`f'"), "pulling") {
				di "Running do-file: `f'"
				do "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata/`f'"
			}
		}
		
	//pulling data from pre reqs
		use "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\food_expenditures_w4.dta", clear
		append using "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\agricultural_expenditures_household_w4.dta"
		append using "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\nonfood_expenditures_household_w4.dta"

	//grouping consumption:
			gen item_group = .
			replace item_group = 11 if item_cd == 101
			replace item_group = 11 if item_cd == 102
			replace item_group = 11 if item_cd == 103
			replace item_group = 11 if item_cd == 104
			replace item_group = 11 if item_cd == 105
			replace item_group = 11 if item_cd == 301
			replace item_group = 11 if item_cd == 302
			replace item_group = 11 if item_cd == 303
			replace item_group = 11 if item_cd == 304
			replace item_group = 11 if item_cd == 305
			replace item_group = 11 if item_cd == 306
			replace item_group = 11 if item_cd == 307
			replace item_group = 11 if item_cd == 308
			replace item_group = 11 if item_cd == 309
			replace item_group = 11 if item_cd == 310
			replace item_group = 14 if item_cd == 330
			replace item_group = 11 if item_cd == 311
			replace item_group = 11 if item_cd == 312
			replace item_group = 11 if item_cd == 313
			replace item_group = 11 if item_cd == 314
			replace item_group = 11 if item_cd == 315
			replace item_group = 9 if item_cd == 316
			replace item_group = 11 if item_cd == 317
			replace item_group = 11 if item_cd == 318
			replace item_group = 11 if item_cd == 319
			replace item_group = 11 if item_cd == 320
			replace item_group = 11 if item_cd == 321
			replace item_group = 11 if item_cd == 322
			replace item_group = 14 if item_cd == 323
			replace item_group = 14 if item_cd == 324
			replace item_group = 11 if item_cd == 325
			replace item_group = 6 if item_cd == 326
			replace item_group = 6 if item_cd == 327
			replace item_group = 6 if item_cd == 328
			replace item_group = 13 if item_cd == 329
			replace item_group = 11 if item_cd == 401
			replace item_group = 11 if item_cd == 402
			replace item_group = 11 if item_cd == 403
			replace item_group = 11 if item_cd == 404
			replace item_group = 11 if item_cd == 405
			replace item_group = 11 if item_cd == 406
			replace item_group = 11 if item_cd == 407
			replace item_group = 11 if item_cd == 408
			replace item_group = 11 if item_cd == 409
			replace item_group = 11 if item_cd == 410
			replace item_group = 11 if item_cd == 411
			replace item_group = 11 if item_cd == 431
			replace item_group = 11 if item_cd == 412
			replace item_group = 11 if item_cd == 413
			replace item_group = 11 if item_cd == 414
			replace item_group = 11 if item_cd == 415
			replace item_group = 11 if item_cd == 416
			replace item_group = 11 if item_cd == 432
			replace item_group = 11 if item_cd == 417
			replace item_group = 11 if item_cd == 418
			replace item_group = 11 if item_cd == 419
			replace item_group = 11 if item_cd == 420
			replace item_group = 11 if item_cd == 421
			replace item_group = 11 if item_cd == 433
			replace item_group = 11 if item_cd == 434
			replace item_group = 11 if item_cd == 435
			replace item_group = 11 if item_cd == 422
			replace item_group = 11 if item_cd == 423
			replace item_group = 11 if item_cd == 424
			replace item_group = 11 if item_cd == 425
			replace item_group = 11 if item_cd == 426
			replace item_group = 11 if item_cd == 427
			replace item_group = 11 if item_cd == 436
			replace item_group = 11 if item_cd == 437
			replace item_group = 11 if item_cd == 438
			replace item_group = 11 if item_cd == 439
			replace item_group = 11 if item_cd == 440
			replace item_group = 11 if item_cd == 441
			replace item_group = 15 if item_cd == 428
			replace item_group = 10 if item_cd == 429
			replace item_group = 9 if item_cd == 430
			replace item_group = 11 if item_cd == 501
			replace item_group = 11 if item_cd == 502
			replace item_group = 11 if item_cd == 503
			replace item_group = 11 if item_cd == 504
			replace item_group = 11 if item_cd == 505
			replace item_group = 11 if item_cd == 506
			replace item_group = 11 if item_cd == 507
			replace item_group = 11 if item_cd == 508
			replace item_group = 96 if item_cd == 509
			replace item_group = 9 if item_cd == 510
			replace item_group = 14 if item_cd == 511
			replace item_group = 6 if item_cd == 512
			replace item_group = 11 if item_cd == 513
			replace item_group = 96 if item_cd == 514
			replace item_group = 10 if item_cd == 515
			replace item_group = 10 if item_cd == 516
			replace item_group = 10 if item_cd == 517
			replace item_group = 7 if item_cd == 1
			replace item_group = 7 if item_cd == 2
			replace item_group = 1 if item_cd == 601
			replace item_group = 4 if item_cd == 602
			replace item_group = 4 if item_cd == 603
			replace item_group = 2 if item_cd == 604
			replace item_group = 2 if item_cd == 605
			replace item_group = 96 if item_cd == 606
			replace item_group = 4 if item_cd == 607
			replace item_group = 3 if item_cd == 608
			replace item_group = 4 if item_cd == 609
			replace item_group = 4 if item_cd == 610
			replace item_group = 8 if item_cd == 701
			replace item_group = 4 if item_cd == 702
			replace item_group = 5 if item_cd == 703
			replace item_group = 12 if item_cd == 704
			replace item_group = 13 if item_cd == 705
			replace item_group = 13 if item_cd == 706
			
		//labels
		label define item_group_lbl ///
			1  "BUY LAND" ///
			2  "BUY LIVESTOCK" ///
			3  "BUY FARM TOOLS/IMPLEMENTS" ///
			4  "BUY FARM INPUTS (SEEDS, FERTILIZER)" ///
			5  "PURCHASE OF INPUTS/ WORKING CAPITAL FOR NONFARM BUSINESS" ///
			6  "HOUSE CONSTRUCTION/PURCHASE/REPAIRS/IMPROVEMENT" ///
			7  "BUY FOOD STUFF" ///
			8  "PAY FOR EDUCATION EXPENSES" ///
			9  "PAY FOR HEALTH EXPENSES" ///
			10 "PAY FOR CEREMONIES EXPENSES" ///
			11 "BUY OTHER NON-FOOD CONSUMPTION GOODS/SERVICES" ///
			12 "REPAY OTHER DEBTS" ///
			13 "PAY HOUSE RENT" ///
			14 "VEHICLE REPAIR, MAINTENANCE OR PURCHASE" ///
			15 "HOLIDAYS" ///
			16 "PAYMENT FOR RANSOM" ///
			96 "OTHER (SPECIFY)"
			
		label values item_group item_group_lbl

		//higher level use classes
			gen productivity_flag = inlist(item_group, 1,2,3,4,5,8)
			
			gen farm_exp_flag = inlist(item_group,1,2,3,4)
			
			gen nonfarm_business_exp_flag = inlist(item_group,5)
			
			gen food_flag = (item_group == 7)
			
			//gen harvest_food_flag = (harvest_food == 1 & food_flag)
			
			//gen planting_food_flag = (planting_food == 1 & food_flag)
			
			gen gen_consumption_flag = inlist(item_group,7,11)
			
			gen essential_flag = inlist(item_group,7,9,13,16) // we could trim this down to include seed purchases and land rents (not land buys or fertilizer purchases)
		
		//normalize to daily expense
			//replace item_expenditure = item_expenditure/days
			// droping this it just seems to be causing more issues than solutions, just comparing like to like seems better
		//collapsing
		
		
			collapse (sum) item_expenditure ,by(hhid wave item_group productivity_flag farm_exp_flag nonfarm_business_exp_flag food_flag gen_consumption_flag essential_flag harvest_food_flag planting_food_flag)
		
		//winsorizing within item group
			winsor2 item_expenditure, replace cuts(0 99) by(item_group)
		
		save "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\w4_item_group_expenditures_master.dta",replace
		
		local vars productivity_flag farm_exp_flag nonfarm_business_exp_flag food_flag gen_consumption_flag essential_flag harvest_food_flag planting_food_flag
		
		foreach v of local vars {
			preserve
				collapse (sum) item_expenditure ,by(hhid `v' wave)
				
				reshape wide item_expenditure, i(hhid wave) j(`v')
				rename (item_expenditure0 item_expenditure1) (non_`v' `v')
				
				save "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\w4_`v'_expenditures.dta", replace
			restore
		}
