//===========================================================================
//00_master.do — Run this file from the project root to execute full pipeline
//===========================================================================

//---------------------------------------------------------------------------
//Section 0: User settings (only edit these if needed)
//---------------------------------------------------------------------------

//This sets the root to the stata file's location
    //the root should be at the base level of the repoduction file, if this isn't working, the manually set the root
    // e.g. "C:/Users/Admin/Downloads/repdocution-code-file"
global root "`c(pwd)'"

//this is used to run the rscript automatically
//if the Rscript is not on PATH, replace with full path, e.g.:
    //global Rscript "C:/Program Files/R/R-4.4.1/bin/Rscript.exe"

global Rscript "Rscript"

//---------------------------------------------------------------------------
//Section 1: Install Stata packages
//---------------------------------------------------------------------------
ssc install univar,    replace
ssc install ietoolkit, replace

//---------------------------------------------------------------------------
//Section 2: Stata data pipeline
//---------------------------------------------------------------------------
local base "${root}/Stata Code/Stata Data Collection and Cleaning Scripts"

//2.10 Import household variables (internally calls Import Wave 4 & Wave 5) and post cleaning
do "`base'/Stata Control Covariate Collection and Cleaning Scripts/Import Post Cleaning.do"

//---------------------------------------------------------------------------
//Subsection 2.11: R — FIES index (must run before Food Security)
//---------------------------------------------------------------------------
shell "${Rscript}" "${root}/R Code/FIES Index Calculation.r"

//2.2 Food security indices (FIES, FCS)
do "`base'/Stata Control Covariate Collection and Cleaning Scripts/Food Security.do"

//2.3 Shocks
do "`base'/Stata Control Covariate Collection and Cleaning Scripts/Shocks Pull.do"

//2.4 Standalone expenditure components
do "`base'/Stata Expenditure Calculations Scripts/Labor Expenses.do"
do "`base'/Stata Expenditure Calculations Scripts/Land Expenses.do"
do "`base'/Stata Expenditure Calculations Scripts/Livestock Expenses.do"
do "`base'/Stata Expenditure Calculations Scripts/Seed_Fertilizer Expenses.do"

//2.5 Consumption expenditures (internally calls W4 and W5 sub-scripts)
do "`base'/Stata Expenditure Calculations Scripts/Exp Master Pulls.do"

//2.6 Merge everything into DML-ready dataset
do "`base'/Stata Control Covariate Collection and Cleaning Scripts/DML Data Prep.do"

//3 Output tables
do "`base'/Stata Output Tables Scripts/Balance Table.do"
