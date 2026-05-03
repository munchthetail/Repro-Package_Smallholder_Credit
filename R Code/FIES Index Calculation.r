# Utilizes the RM.weights package developed by:
# Rasch model and extensions for survey data, using Conditional Maximum likelihood (CML). 
# Carlo Cafiero, Sara Viviani, Mark Nord (2018) doi:10.1016/j.measurement.2017.10.065 

# this program was heavily based upone the documenation 1752_Manual_on_RM_Weights_Package_EN.pdf in the repduction folder

# Summary -----------------------------------------------------------------
## Section 0: Install packages
## Section 1: Data
## Section 2: Psychometric analysis
## Section 4: Standardizing to international scale

# Section 0: Install packages -----------------------------------------
#clearing output and memory
rm(list = ls())
cat("\014")

#loan neccessary packages:
load_or_install <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, repos = "https://cloud.r-project.org")
  }
  library(pkg, character.only = TRUE)
}

packages <- c("haven", "dplyr", "RM.weights", "here")
invisible(lapply(packages, load_or_install))

#set directory at current file path for ease of use
#IF THIS IS NOT FUNCITONING CORRECTLY, replace the file directory at the root of the replication package
  # e.g. setwd("C:/Users/Admin/Downloads/replication_package")
setwd(here::here())

# Section 1: Data ------------------------------------------------------------

# source data and HH weights from EPAR for FIES theta calibartion
w4_raw <- read_dta("Source Data/Nigeria GHS Wave 4/Raw DTA files/sect12_harvestw4.dta")
w5_raw <- read_dta("Source Data/Nigeria GHS Wave 5/Raw DTA files/sect7_harvestw5.dta")

w4_weights <- read_dta("`base'/Stata Code/Stata Data Landing/Nigeria_GHS_W4_household_weights.dta")
w5_weights <- read_dta("`base'/Stata Code/Stata Data Landing/Nigeria_GHS_W5_household_weights.dta")

w4_raw <- inner_join(w4_raw, w4_weights, by = "hhid", relationship = "one-to-one")
w5_raw <- inner_join(w5_raw, w5_weights, by = "hhid", relationship = "one-to-one")


#loading relavent variables from questionaires
fies_vars_w4 <- grep("^s12q8[a-h]$", names(w4_raw), value = TRUE)
fies_vars_w5 <- grep("^s7q1[a-h]$", names(w5_raw), value = TRUE)

#recoding data --- the data is natively in 1==YES 2==NO
rec01 <- function(x) ifelse(x == 1, 1, 0)

for (var in fies_vars_w4){
  w4_raw[[var]] <- rec01(w4_raw[[var]])
}
for (var in fies_vars_w5){
  w5_raw[[var]] <- rec01(w5_raw[[var]])
}

#preping the FIES data and corresponding weights
XX.wave4 <- w4_raw[,fies_vars_w4]
wt.wave4 <- w4_raw$weight

XX.wave5 <- w5_raw[,fies_vars_w5]
wt.wave5 <- w5_raw$weight

# Section 2: Psychometric analysis ----------------------------------------------------------------
# this is the main function of the RM.weights package, 
  #we Section 3 standardizes to the international standard for intertemporal comparability
rr.wave4 = RM.w(XX.wave4,wt.wave4, country = "Nigeria_W4")
rr.wave5 = RM.w(XX.wave5,wt.wave5, country = "Nigeria_W5")

# Section 3: automatic equating to 2014-2015 global standard
# VoH 2014-2015 global standard 
#see equating.fun documentation in 1752_Manual_on_RM_Weights_Package_EN (page 27)
b.tot=c(-1.2590036, -0.8991436, -1.0876362,  0.4163556, -0.2506451,  0.4466926,  0.8065710, 1.8268093)

#exporting equated weights to each country
#in all honesty the choice to use 0.5 was made early in the process and is not strongly justified
eq.wave4 <- equating.fun(rr.wave4, st = b.tot, tol = 0.5)
eq.wave5 <- equating.fun(rr.wave5, st = b.tot, tol = 0.5)

#pulling out shift and scale
shift_w4 <- as.numeric(eq.wave4$shift)
scale_w4 <- as.numeric(eq.wave4$scale)

shift_w5 <- as.numeric(eq.wave5$shift)
scale_w5 <- as.numeric(eq.wave5$scale)

#this is the big part, actually rescaling
theta_perRS_w4 <- shift_w4 + scale_w4 * rr.wave4$a    
theta_perRS_w5 <- shift_w5 + scale_w5 * rr.wave5$a
se_perRS_w4    <- abs(scale_w4) * rr.wave4$se.a
se_perRS_w5    <- abs(scale_w5) * rr.wave5$se.a

#now compute the probability assignment of moderately severe (ate less due to food insecurity) and severe (didn't eat because of food insecurity)
#these are just pulled form the 1752_Manual_on_RM_Weights_Package_EN.pdf default settings
sthresh_global <- c(modsev = -0.25)

#raw scores just used for indexing each household by their raw score
rv.wave4 <- rowSums(XX.wave4, na.rm = TRUE)
rv.wave5 <- rowSums(XX.wave5, na.rm = TRUE)

#calculates probability of moderate food insecurity or greater
  #not, we don't include severe food insecurity because is was highly correlated with moderate but had much less variance
make_probs <- function(raw_scores, theta_perRS, se_perRS, thresholds) {
  se_perRS <- pmax(se_perRS, 1e-8)  # guard against zero SE
  z_mod <- (thresholds["modsev"] - theta_perRS) / se_perRS
  
  p_mod_perRS <- 1 - pnorm(z_mod)   #P(>=mod)
  
  data.frame(
    p_mod = p_mod_perRS[raw_scores + 1]
  )
}

#making dataframes for export
w4_with_probs <- data.frame(
  wave = 4,
  hhid = w4_raw$hhid,
  make_probs(
    raw_scores  = rv.wave4,
    theta_perRS = theta_perRS_w4,
    se_perRS    = se_perRS_w4,
    thresholds  = sthresh_global
  )
)

w5_with_probs <- data.frame(
  wave = 5,
  hhid = w5_raw$hhid,
  make_probs(
    raw_scores  = rv.wave5,
    theta_perRS = theta_perRS_w5,
    se_perRS    = se_perRS_w5,
    thresholds  = sthresh_global
  )
)

#combining dataframes for export
fies_long <- rbind(w4_with_probs, w5_with_probs)

#save data
write.csv(fies_long, "R Code/R Data Landing/household_probs_long.csv", row.names = FALSE)
