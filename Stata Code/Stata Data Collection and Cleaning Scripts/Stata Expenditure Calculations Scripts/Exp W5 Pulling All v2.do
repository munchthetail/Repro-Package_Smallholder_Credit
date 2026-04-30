// Will Hankins edit 9/16/25
	clear all      // clears data, value labels, saved results, and programs
	set more off   // prevents output from pausing with "more"
	cd "C:\Users\Will\OneDrive - The Ohio State University\RA\Data\EPAR Nigeria"
		
	//doing pre req files
		local files : dir "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata" files "Exp W5 *.do"
		foreach f of local files {
			if !strpos(lower("`f'"), "pulling") {
				di "Running do-file: `f'"
				do "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata/`f'"
			}
		}
		
	//normalize for CPI --- we could make this more granular if we want
		//prices are indexed to January 2019 so only need deflator for wave 5 data
		//import excel using "C:\Users\Will\OneDrive - The Ohio State University\RA\Data\Nigeria CPI\Nigeria CPI Data.xlsx", sheet("Indx 2019") firstrow clear
		//keep if Month=="January" & Year==2024
		//scalar deflator = AllItems[1]
		
	//pulling data from pre reqs
		use "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\food_expenditures_w5.dta", clear
		append using "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\agricultural_expenditures_household_w5.dta"
		append using "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\nonfood_expenditures_household_w5.dta"

	//grouping consumption:
			gen item_group = .
			replace item_group = 11 if item_cd == 101
			replace item_group = 11 if item_cd == 102
			replace item_group = 11 if item_cd == 103
			replace item_group = 11 if item_cd == 104
			replace item_group = 11 if item_cd == 105
			replace item_group = 11 if item_cd == 201
			replace item_group = 11 if item_cd == 202
			replace item_group = 11 if item_cd == 203
			replace item_group = 11 if item_cd == 204
			replace item_group = 11 if item_cd == 205
			replace item_group = 11 if item_cd == 206
			replace item_group = 11 if item_cd == 207
			replace item_group = 11 if item_cd == 208
			replace item_group = 11 if item_cd == 209
			replace item_group = 11 if item_cd == 210
			replace item_group = 11 if item_cd == 211
			replace item_group = 14 if item_cd == 212
			replace item_group = 11 if item_cd == 213
			replace item_group = 11 if item_cd == 214
			replace item_group = 11 if item_cd == 215
			replace item_group = 11 if item_cd == 327
			replace item_group = 11 if item_cd == 216
			replace item_group = 11 if item_cd == 217
			replace item_group = 11 if item_cd == 218
			replace item_group = 11 if item_cd == 219
			replace item_group = 11 if item_cd == 220
			replace item_group = 11 if item_cd == 221
			replace item_group = 9 if item_cd == 222
			replace item_group = 9 if item_cd == 223
			replace item_group = 11 if item_cd == 224
			replace item_group = 11 if item_cd == 225
			replace item_group = 11 if item_cd == 226
			replace item_group = 11 if item_cd == 227
			replace item_group = 11 if item_cd == 229
			replace item_group = 11 if item_cd == 230
			replace item_group = 11 if item_cd == 232
			replace item_group = 11 if item_cd == 233
			replace item_group = 11 if item_cd == 234
			replace item_group = 11 if item_cd == 235
			replace item_group = 11 if item_cd == 236
			replace item_group = 11 if item_cd == 237
			replace item_group = 11 if item_cd == 238
			replace item_group = 14 if item_cd == 239
			replace item_group = 14 if item_cd == 240
			replace item_group = 14 if item_cd == 241
			replace item_group = 14 if item_cd == 242
			replace item_group = 14 if item_cd == 243
			replace item_group = 11 if item_cd == 244
			replace item_group = 6 if item_cd == 245
			replace item_group = 6 if item_cd == 246
			replace item_group = 11 if item_cd == 247
			replace item_group = 6 if item_cd == 248
			replace item_group = 11 if item_cd == 249
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
			replace item_group = 11 if item_cd == 311
			replace item_group = 11 if item_cd == 312
			replace item_group = 11 if item_cd == 313
			replace item_group = 11 if item_cd == 314
			replace item_group = 11 if item_cd == 315
			replace item_group = 11 if item_cd == 316
			replace item_group = 11 if item_cd == 317
			replace item_group = 11 if item_cd == 318
			replace item_group = 11 if item_cd == 319
			replace item_group = 11 if item_cd == 320
			replace item_group = 11 if item_cd == 321
			replace item_group = 11 if item_cd == 322
			replace item_group = 11 if item_cd == 323
			replace item_group = 11 if item_cd == 324
			replace item_group = 11 if item_cd == 325
			replace item_group = 11 if item_cd == 326
			replace item_group = 11 if item_cd == 328
			replace item_group = 11 if item_cd == 329
			replace item_group = 11 if item_cd == 330
			replace item_group = 11 if item_cd == 331
			replace item_group = 11 if item_cd == 332
			replace item_group = 11 if item_cd == 333
			replace item_group = 11 if item_cd == 334
			replace item_group = 11 if item_cd == 335
			replace item_group = 11 if item_cd == 336
			replace item_group = 11 if item_cd == 337
			replace item_group = 11 if item_cd == 338
			replace item_group = 11 if item_cd == 339
			replace item_group = 11 if item_cd == 340
			replace item_group = 11 if item_cd == 341
			replace item_group = 11 if item_cd == 342
			replace item_group = 11 if item_cd == 343
			replace item_group = 11 if item_cd == 344
			replace item_group = 11 if item_cd == 345
			replace item_group = 11 if item_cd == 346
			replace item_group = 11 if item_cd == 347
			replace item_group = 11 if item_cd == 348
			replace item_group = 11 if item_cd == 349
			replace item_group = 11 if item_cd == 350
			replace item_group = 11 if item_cd == 351
			replace item_group = 11 if item_cd == 352
			replace item_group = 15 if item_cd == 353
			replace item_group = 10 if item_cd == 354
			replace item_group = 9 if item_cd == 355
			replace item_group = 9 if item_cd == 356
			replace item_group = 9 if item_cd == 357
			replace item_group = 15 if item_cd == 358
			replace item_group = 15 if item_cd == 359
			replace item_group = 11 if item_cd == 360
			replace item_group = 11 if item_cd == 361
			replace item_group = 11 if item_cd == 362
			replace item_group = 9 if item_cd == 363
			replace item_group = 8 if item_cd == 364
			replace item_group = 11 if item_cd == 365
			replace item_group = 8 if item_cd == 401
			replace item_group = 11 if item_cd == 402
			replace item_group = 5 if item_cd == 403
			replace item_group = 12 if item_cd == 404
			replace item_group = 13 if item_cd == 405
			replace item_group = 6 if item_cd == 406
			replace item_group = 9 if item_cd == 407
			replace item_group = 7 if item_cd == 1
			replace item_group = 7 if item_cd == 2
			replace item_group = 1 if item_cd == 501
			replace item_group = 4 if item_cd == 502
			replace item_group = 4 if item_cd == 503
			replace item_group = 2 if item_cd == 504
			replace item_group = 2 if item_cd == 505
			replace item_group = 96 if item_cd == 506
			replace item_group = 4 if item_cd == 507
			replace item_group = 3 if item_cd == 508
			replace item_group = 4 if item_cd == 509
			replace item_group = 4 if item_cd == 510
			
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
			
			gen harvest_food_flag = (harvest_food == 1 & food_flag)
			
			gen planting_food_flag = (planting_food == 1 & food_flag)
			
			gen gen_consumption_flag = inlist(item_group,7,11)
			
			gen essential_flag = inlist(item_group,7,9,13,16) // we could trim this down to include seed purchases and land rents (not land buys or fertilizer purchases)
		
		//breaking out farm expenditures by subcategory
			
		
		//normalize to daily expense
			//replace item_expenditure = item_expenditure/days
			// droping this it just seems to be causing more issues than solutions, just comparing like to like seems better
		//collapsing
					

			collapse (sum) item_expenditure ,by(hhid wave item_group productivity_flag farm_exp_flag nonfarm_business_exp_flag food_flag gen_consumption_flag essential_flag harvest_food_flag planting_food_flag)
			
		//winsorizing within item group
		winsor2 item_expenditure, replace cuts(0 99) by(item_group)
		save "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\w5_item_group_expenditures_master.dta",replace
		
		local vars productivity_flag farm_exp_flag nonfarm_business_exp_flag food_flag gen_consumption_flag essential_flag harvest_food_flag planting_food_flag
		
		foreach v of local vars {
			preserve
				collapse (sum) item_expenditure ,by(hhid `v' wave)
				
				reshape wide item_expenditure, i(hhid wave) j(`v')
				rename (item_expenditure0 item_expenditure1) (non_`v' `v')
				
				save "C:\Users\Will\OneDrive - The Ohio State University\RA\Stata\Stata Data\w5_`v'_expenditures.dta", replace
			restore
		}