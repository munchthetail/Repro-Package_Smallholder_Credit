######### Code for the implementation of ######### 
######### the VoH methodology to calculate ######### 
######### prevalence of food insecurity ######### 
######### based on the food insecurity scales data ######### 
# Summary -----------------------------------------------------------------
## Section 0: Install packages
## Section 1: Data
## Section 2: Psychometric analysis
## Section 3: Save outputs
## Section 4: Descriptives
## Section 5: Probabilistic assignment
## Section 6: Prevalence comparison between two countries
## Section 7: automatic equating

# Section 0: Install packages -----------------------------------------
# The R package for the implementation of the VoH methodology
# is called "RM.weights" and it is available on CRAN (R packages' repository),
# starting from R version 3.2. 

rm(list = ls())
cat("\014")
setwd("C:/Users/Will/OneDrive - The Ohio State University/RA/Stata/RCode")

#install.packages("RM.weights")
library(haven)
library(dplyr)
library(RM.weights)

# Section 1: Data ------------------------------------------------------------
# Inside the package, four sample datasets are saved, named
# data.FAO_country1, data.FAO_country2, data.FAO_country3,
# data.FAO_country4
# Below you can find some instructions on how to handle these datasets

### Attach the datasets
path_w5 <- "C:/Users/Will/OneDrive - The Ohio State University/RA/Stata/LSMS-Agricultural-Indicators-Code-main/LSMS-Agricultural-Indicators-Code-main/Nigeria GHS/Nigeria GHS Wave 5/Raw DTA files/sect7_harvestw5.dta"
path_w4 <- "C:/Users/Will/OneDrive - The Ohio State University/RA/Stata/LSMS-Agricultural-Indicators-Code-main/LSMS-Agricultural-Indicators-Code-main/Nigeria GHS/Nigeria GHS Wave 4/Raw DTA files/sect12_harvestw4.dta"
out_dir <- "C:/Users/Will/OneDrive - The Ohio State University/RA/Data/EPAR Nigeria/FIES_outputs"

w4_raw <- read_dta(path_w4)
w5_raw <- read_dta(path_w5)

w4_weights <- read_dta("C:/Users/Will/OneDrive - The Ohio State University/RA/Data/EPAR Nigeria/Nigeria GHS W4/final_data/Nigeria_GHS_W4_household_weights.dta")
w5_weights <- read_dta("C:/Users/Will/OneDrive - The Ohio State University/RA/Data/EPAR Nigeria/Nigeria GHS W4/final_data/Nigeria_GHS_W5_household_weights.dta")

w4_raw <- inner_join(w4_raw, w4_weights, by = "hhid", relationship = "one-to-one")

w5_raw <- inner_join(w5_raw, w5_weights, by = "hhid", relationship = "one-to-one")

#helper to recode data
rec01 <- function(x) ifelse(x == 1, 1, 0)

fies_vars_w4 <- grep("^s12q8[a-h]$", names(w4_raw), value = TRUE)
fies_vars_w5 <- grep("^s7q1[a-h]$", names(w5_raw), value = TRUE)

for (var in fies_vars_w4){
  w4_raw[[var]] <- rec01(w4_raw[[var]])
}

for (var in fies_vars_w5){
  w5_raw[[var]] <- rec01(w5_raw[[var]])
}

### Saving the FIES data and corresponding weights
XX.wave4 <- w4_raw[,fies_vars_w4, drop = FALSE]
wt.wave4 <- w4_raw$weight

XX.wave5 <- w5_raw[,fies_vars_w5]
wt.wave5 <- w5_raw$weight

### Calculate raw scores (number of yes for each individual to the 8 questions)
rv.wave4=rowSums(XX.wave4)
rv.wave5=rowSums(XX.wave5)

### Number of items (questions) of the FIES
k = ncol(XX.wave4)

# Section 2: Psychometric analysis ----------------------------------------------------------------
rr.wave4 = RM.w(XX.wave4,wt.wave4, country = "Nigeria_W4")
rr.wave5 = RM.w(XX.wave5,wt.wave5, country = "Nigeria_W5")

quantile.seq <- c(0,.01,.02,.05,.10,.25,.50,.75,.90,.95,.98,.99,1)
qvals <- quantile(rr.wave4$q.infit, probs = quantile.seq, na.rm = TRUE)
qtheor <- quantile(rr.wave4$q.infit.theor, probs = quantile.seq, na.rm = TRUE)
plot(quantile.seq, qvals, type = "b",
     xlab = "Quantiles", ylab = "Observed vs Theoretical infit",
     ylim = c(0, 6))
lines(quantile.seq, qtheor, type = "b", col = 2)
legend("topleft", legend = c("Observed", "Theoretical"),
       col = c(1, 2), lty = 1, pch = 1)

#  Section 6: Prevalence comparison between two countries ----------------------------
## NOTE: Corresponding calculation can be found in the excel file
## Equating.xlsx
## Item severities for country 1 and 2
b1 = rr.wave4$b
b2 = rr.wave5$b
b1.std = b1/sd(b1)
b2.std = b2/sd(b2)

## Tolerance (maximum difference to consider items to be common)
tol = 0.5
## Defining common items based on item severity difference
diff.mat = abs(b1.std - b2.std)
comm.mat = rep(FALSE, length(diff.mat))
comm.mat[diff.mat < tol] = TRUE
names(comm.mat) = colnames(XX.wave4)
comm.mat
# FALSE=unique, TRUE=common items

## Defining a metric based on mean and standard deviation of common items
## in both countries
mean.comm = c(mean(b1.std[comm.mat]), mean(b2.std[comm.mat]))
sd.comm = c(sd(b1.std[comm.mat]), sd(b2.std[comm.mat]))
# Cells F14 and G14 in Excel
mean.comm
# Cells F15 and G15 in Excel
sd.comm

## New standardized item severities
b.1.std.new = (b1.std * sd.comm[1]) + mean.comm[1]
b.2.std.new = (b2.std * sd.comm[2]) + mean.comm[2]
# Cells M3:M10 and N3:N10 in Excel
cbind(b.1.std.new, b.2.std.new)
# Graph
plot(b.1.std.new, b.2.std.new, pch = 5, col = "blue",xlab = "Country1", 
     ylab = "Country2", xlim = c(-3,3),ylim=c(-3,3))
abline(c(0,1))
text(b.1.std.new, b.2.std.new, colnames(XX.wave4), cex = 0.6, pos=2)
points(b.1.std.new[!comm.mat], b.2.std.new[!comm.mat], col = 2, pch = 5)

## Calculate comparable prevalences
## Report thresholds to the metric of common items
int1=mean.comm[1]
slop1=sd.comm[1]/sd(b1)
int2=mean.comm[2]
slop2=sd.comm[2]/sd(b2)
# Cells B18-C18 in Excel
c(int1, int2)
# Cells B19-C19 in Excel
c(slop1, slop2)

sthresh = c(-0.25, 1.81)
sthesh.new1 = (sthresh - int1)/slop1
sthesh.new2 = (sthresh - int2)/slop2
## Prevalence calculated on equated thresholds
pp.wave4 = prob.assign(rr.wave4, sthres = sthesh.new1)$sprob
pp.wave5 = prob.assign(rr.wave5, sthres = sthesh.new2)$sprob
# Comparable prevalence of Moderate or severe and Severe FI in country1
pp.wave4
# Comparable prevalence of Moderate or severe and Severe FI in country2
pp.wave5

# Section 7: automatic equating to 2014-2015 global standard
# VoH 2014-2015 global standard
b.tot=c(-1.2590036, -0.8991436, -1.0876362,  0.4163556, -0.2506451,  0.4466926,  0.8065710, 1.8268093)
# Equating of country 1 to the global standard
ee=equating.fun(rr.wave4, st=b.tot, tol=0.5)
# Equated prevalence rates
ee$prevs*100
# Correlation between common items
ee$cor.comm.items
# Producing a plot of the item severities
ee=equating.fun(rr.wave4, st=b.tot, tol=0.5, plot=T)
# The plot will be saved as a pdf called "Equating_plot.pdf" file in the working directory

#exporting equated weights to each country
eq.wave4 <- equating.fun(rr.wave4, st = b.tot, tol = 0.5)
eq.wave5 <- equating.fun(rr.wave5, st = b.tot, tol = 0.5)

theta_w4 <- rr.wave4$a    # household θ (raw, on Wave 4 metric)
theta_w5 <- rr.wave5$a    # household θ (raw, on Wave 5 metric)

#raw score
rv.wave4 <- rowSums(XX.wave4, na.rm = TRUE)
rv.wave5 <- rowSums(XX.wave5, na.rm = TRUE)

#pulling out shift and scale
shift_w4 <- as.numeric(eq.wave4$shift); scale_w4 <- as.numeric(eq.wave4$scale)
shift_w5 <- as.numeric(eq.wave5$shift); scale_w5 <- as.numeric(eq.wave5$scale)

#this is the big part, actually rescaling
theta_perRS_w4 <- shift_w4 + scale_w4 * rr.wave4$a    
theta_perRS_w5 <- shift_w5 + scale_w5 * rr.wave5$a
se_perRS_w4    <- abs(scale_w4) * rr.wave4$se.a
se_perRS_w5    <- abs(scale_w5) * rr.wave5$se.a

#setting up to pair onto raw data
theta_w4_eq_byhh <- theta_perRS_w4[ rv.wave4 + 1 ]
theta_w5_eq_byhh <- theta_perRS_w5[ rv.wave5 + 1 ]
se_w4_eq_byhh    <- se_perRS_w4[ rv.wave4 + 1 ]
se_w5_eq_byhh    <- se_perRS_w5[ rv.wave5 + 1 ]

#pairing onto raw data and merging
df_w4_theta <- data.frame(
  hhid          = w4_raw$hhid,
  wave          = 4,
  theta_equated = theta_w4_eq_byhh,
  se_equated    = se_w4_eq_byhh
)

df_w5_theta <- data.frame(
  hhid          = w5_raw$hhid,
  wave          = 5,
  theta_equated = theta_w5_eq_byhh,
  se_equated    = se_w5_eq_byhh
)

theta_equated_both <- rbind(df_w4_theta, df_w5_theta)

write.csv(theta_equated_both, "theta_equated_by_hhid.csv", row.names = FALSE)

# now compute the probability assignment of moderately severe (ate less due to food insecurity) and severe (didn't eat because of food insecurity)
sthresh_global <- c(modsev = -0.25, severe = 1.81)

make_probs <- function(raw_scores, theta_perRS, se_perRS, thresholds) {
  se_perRS <- pmax(se_perRS, 1e-8)  # guard against zero SE
  z_mod <- (thresholds["modsev"] - theta_perRS) / se_perRS
  z_sev <- (thresholds["severe"] - theta_perRS) / se_perRS
  
  p_mod_perRS <- 1 - pnorm(z_mod)   # P(Mod-or-Sev)
  p_sev_perRS <- 1 - pnorm(z_sev)   # P(Severe)
  p_mod_only  <- p_mod_perRS - p_sev_perRS  # P(Moderate only)
  
  data.frame(
    p_mod = p_mod_perRS[raw_scores + 1],
    p_sev = p_sev_perRS[raw_scores + 1],
    p_mod_only = p_mod_only[raw_scores + 1]
  )
}

# Add wave identifiers to each data frame
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

# Combine both waves into one long dataset
fies_long <- rbind(w4_with_probs, w5_with_probs)

# Optional: include survey weights if you want them downstream
fies_long$weight <- c(w4_raw$weight, w5_raw$weight)

# Check structure
head(fies_long)

# Save if desired
write.csv(fies_long, "household_probs_long.csv", row.names = FALSE)
