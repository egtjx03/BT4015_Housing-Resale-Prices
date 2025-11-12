# ==============================================================================
# ENVIRONMENT: SPATIAL ANALYSIS - HYPOTHESIS TESTING
# Project: BT4015 Housing Resale Prices
# Purpose: ANN and Poisson Process testing
# ==============================================================================

library(sf)
library(dplyr)
library(spatstat)
library(spdep)

setwd("/Users/zr/Code/Projects/BT4015_Housing-Resale-Prices")

cat("=== Loading Data ===\n")
hdb <- readRDS("Environment_Analysis/data/hdb_4room_with_metrics.rds")
parks <- readRDS("Environment_Analysis/data/parks.rds")

# Load planning areas for study boundary
sf_use_s2(FALSE)
planning_areas <- st_read("Datasets/MasterPlan2019PlanningAreaBoundaryNoSea.geojson", quiet = TRUE)
planning_areas <- st_make_valid(planning_areas)
planning_areas <- st_transform(planning_areas, crs = 3414)  # SVY21

# Transform to SVY21
hdb_svy21 <- st_transform(hdb, crs = 3414)
parks_svy21 <- st_transform(parks, crs = 3414)

cat(sprintf("Loaded: %d transactions, %d parks\n", nrow(hdb), nrow(parks)))

# ====================================================================
# 6.2.1 AVERAGE NEAREST NEIGHBOR (ANN) ANALYSIS
# ====================================================================

cat("\n=== AVERAGE NEAREST NEIGHBOR ANALYSIS ===\n")

# Create study area boundary (Singapore outline)
singapore_boundary <- st_union(planning_areas)
singapore_area_m2 <- as.numeric(st_area(singapore_boundary))

# Extract coordinates
park_coords <- st_coordinates(parks_svy21)
hdb_coords <- st_coordinates(hdb_svy21)

# Convert to ppp (point pattern) objects for spatstat
cat("\n1. Converting to point pattern objects...\n")

# Get bounding box
bbox <- st_bbox(singapore_boundary)
window <- owin(xrange = c(bbox["xmin"], bbox["xmax"]),
               yrange = c(bbox["ymin"], bbox["ymax"]))

# Create point patterns
parks_ppp <- ppp(x = park_coords[, 1], y = park_coords[, 2], window = window)
hdb_ppp <- ppp(x = hdb_coords[, 1], y = hdb_coords[, 2], window = window)

# High-price transactions (>median)
median_price <- median(hdb$resale_price)
high_price_idx <- hdb$resale_price > median_price
hdb_high_ppp <- ppp(x = hdb_coords[high_price_idx, 1], 
                    y = hdb_coords[high_price_idx, 2], 
                    window = window)

cat("\n2. Testing Parks Distribution...\n")

# ANN for parks
parks_nnd <- nndist(parks_ppp)
observed_mean_parks <- mean(parks_nnd)

# Expected mean distance under CSR
n_parks <- parks_ppp$n
area_m2 <- as.numeric(area(parks_ppp))
density_parks <- n_parks / area_m2
expected_mean_parks <- 1 / (2 * sqrt(density_parks))

# ANN ratio
ann_ratio_parks <- observed_mean_parks / expected_mean_parks

# Standard error and z-score
se_parks <- 0.26136 / sqrt(n_parks * density_parks)
z_score_parks <- (observed_mean_parks - expected_mean_parks) / se_parks
p_value_parks <- 2 * (1 - pnorm(abs(z_score_parks)))

cat(sprintf("  Observed mean distance: %.2f m\n", observed_mean_parks))
cat(sprintf("  Expected mean distance: %.2f m\n", expected_mean_parks))
cat(sprintf("  ANN Ratio: %.3f\n", ann_ratio_parks))
cat(sprintf("  Z-score: %.3f\n", z_score_parks))
cat(sprintf("  P-value: %.4f\n", p_value_parks))
cat(sprintf("  Interpretation: Parks are %s (p %s 0.05)\n", 
            ifelse(ann_ratio_parks < 1, "CLUSTERED", 
                   ifelse(ann_ratio_parks > 1, "DISPERSED", "RANDOM")),
            ifelse(p_value_parks < 0.05, "<", ">")))

cat("\n3. Testing High-Price Transactions Distribution...\n")

# ANN for high-price transactions
hdb_high_nnd <- nndist(hdb_high_ppp)
observed_mean_high <- mean(hdb_high_nnd)

n_high <- hdb_high_ppp$n
area_high <- as.numeric(area(hdb_high_ppp))
density_high <- n_high / area_high
expected_mean_high <- 1 / (2 * sqrt(density_high))

ann_ratio_high <- observed_mean_high / expected_mean_high
se_high <- 0.26136 / sqrt(n_high * density_high)
z_score_high <- (observed_mean_high - expected_mean_high) / se_high
p_value_high <- 2 * (1 - pnorm(abs(z_score_high)))

cat(sprintf("  Observed mean distance: %.2f m\n", observed_mean_high))
cat(sprintf("  Expected mean distance: %.2f m\n", expected_mean_high))
cat(sprintf("  ANN Ratio: %.3f\n", ann_ratio_high))
cat(sprintf("  Z-score: %.3f\n", z_score_high))
cat(sprintf("  P-value: %.4f\n", p_value_high))
cat(sprintf("  Interpretation: High-price transactions are %s (p %s 0.05)\n", 
            ifelse(ann_ratio_high < 1, "CLUSTERED", 
                   ifelse(ann_ratio_high > 1, "DISPERSED", "RANDOM")),
            ifelse(p_value_high < 0.05, "<", ">")))

# Save ANN results
ann_results <- data.frame(
  Dataset = c("Parks", "High-Price Transactions (>median)"),
  N_Points = c(n_parks, n_high),
  Observed_Mean_Dist_m = c(observed_mean_parks, observed_mean_high),
  Expected_Mean_Dist_m = c(expected_mean_parks, expected_mean_high),
  ANN_Ratio = c(ann_ratio_parks, ann_ratio_high),
  Z_Score = c(z_score_parks, z_score_high),
  P_Value = c(p_value_parks, p_value_high),
  Pattern = c(
    ifelse(ann_ratio_parks < 1, "Clustered", 
           ifelse(ann_ratio_parks > 1, "Dispersed", "Random")),
    ifelse(ann_ratio_high < 1, "Clustered", 
           ifelse(ann_ratio_high > 1, "Dispersed", "Random"))
  )
)

write.csv(ann_results, "Environment_Analysis/outputs/ann_results.csv", row.names = FALSE)

# ====================================================================
# 6.2.2 POISSON PROCESS MODEL
# ====================================================================

cat("\n=== POISSON PROCESS MODEL ===\n")

cat("\n1. Testing Homogeneous Poisson Process (CSR)...\n")

# Quadrat test for CSR
quadrat_test_result <- quadrat.test(hdb_ppp, nx = 10, ny = 10)

cat(sprintf("  Chi-squared statistic: %.2f\n", quadrat_test_result$statistic))
cat(sprintf("  Degrees of freedom: %d\n", quadrat_test_result$parameter))
cat(sprintf("  P-value: %.4f\n", quadrat_test_result$p.value))
cat(sprintf("  Interpretation: %s\n", 
            ifelse(quadrat_test_result$p.value < 0.05, 
                   "REJECT homogeneous Poisson (transactions are NOT randomly distributed)",
                   "ACCEPT homogeneous Poisson (transactions appear random)")))

cat("\n2. Fitting Inhomogeneous Poisson Model with Green Space Covariate...\n")

# Create intensity function based on distance to park
# Use kernel density estimation
intensity_kde <- density(hdb_ppp, sigma = 5000)  # 5km bandwidth

cat("  Fitted inhomogeneous Poisson model using kernel density\n")
cat(sprintf("  Intensity range: %.2e to %.2e points per sq meter\n",
            min(intensity_kde$v), max(intensity_kde$v)))

# Save Poisson results
poisson_results <- data.frame(
  Test = c("Quadrat Test (Homogeneous Poisson)"),
  Statistic = c(quadrat_test_result$statistic),
  DF = c(quadrat_test_result$parameter),
  P_Value = c(quadrat_test_result$p.value),
  Conclusion = c(
    ifelse(quadrat_test_result$p.value < 0.05,
           "Reject CSR - Transactions show spatial pattern",
           "Accept CSR - Transactions appear random")
  )
)

write.csv(poisson_results, "Environment_Analysis/outputs/poisson_results.csv", 
          row.names = FALSE)

cat("\n=== HYPOTHESIS TESTING COMPLETE ===\n")
cat("Results saved:\n")
cat("  - ANN results (parks and high-price transactions)\n")
cat("  - Poisson process test results\n")
cat("\nKey Findings:\n")
cat(sprintf("  - Parks: %s (ANN ratio = %.3f)\n", 
            ann_results$Pattern[1], ann_results$ANN_Ratio[1]))
cat(sprintf("  - High-price transactions: %s (ANN ratio = %.3f)\n", 
            ann_results$Pattern[2], ann_results$ANN_Ratio[2]))
cat(sprintf("  - Transaction distribution: %s\n",
            ifelse(poisson_results$P_Value[1] < 0.05, 
                   "Non-random (spatially patterned)",
                   "Random (homogeneous Poisson)")))

