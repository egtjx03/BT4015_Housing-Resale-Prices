# ==============================================================================
# HDB SPATIAL ANALYSIS - AVERAGE NEAREST NEIGHBOR (ANN) WITH MONTE CARLO
# Project: BT4015 Housing Resale Prices
# Purpose: Test if HDB transaction locations are clustered, random, or dispersed
# ==============================================================================

# Load required libraries
library(sf)
library(dplyr)
library(spatstat)
library(ggplot2)

# Set working directory
setwd("/Users/zr/Code/Projects/BT4015_Housing-Resale-Prices")

# Create output directories
dir.create("HDB/outputs", showWarnings = FALSE, recursive = TRUE)
dir.create("HDB/figures", showWarnings = FALSE, recursive = TRUE)

cat("=== AVERAGE NEAREST NEIGHBOR ANALYSIS ===\n")
cat("Purpose: Test spatial pattern of HDB transaction locations\n\n")

# ==============================================================================
# STEP 1: LOAD AND FILTER DATA
# ==============================================================================

cat("STEP 1: Loading and filtering HDB data...\n")

# Load HDB transaction data
hdb_data <- st_read("Datasets/transactions_with_lonlat.geojson", quiet = TRUE)
cat(sprintf("  Loaded %d total transactions\n", nrow(hdb_data)))

# Extract year from month field
hdb_data$year <- substr(hdb_data$month, 1, 4)

# Filter for 4 ROOM and 2024 only
hdb_filtered <- hdb_data %>%
  filter(flat_type == "4 ROOM", year == "2024")

cat(sprintf("  Filtered to %d 4-ROOM transactions in 2024\n", nrow(hdb_filtered)))

# Transform to SVY21 (EPSG:3414) for accurate distance calculations
hdb_svy21 <- st_transform(hdb_filtered, crs = 3414)

# ==============================================================================
# STEP 2: PREPARE DATA FOR SPATSTAT
# ==============================================================================

cat("\nSTEP 2: Converting to spatstat point pattern...\n")

# Extract coordinates
coords <- st_coordinates(hdb_svy21)

# Define study area (bounding box)
bbox <- st_bbox(hdb_svy21)
win <- owin(xrange = c(bbox["xmin"], bbox["xmax"]),
            yrange = c(bbox["ymin"], bbox["ymax"]))

# Create point pattern object
hdb_ppp <- ppp(x = coords[, 1], 
               y = coords[, 2], 
               window = win)

cat(sprintf("  Created point pattern with %d points\n", hdb_ppp$n))
cat(sprintf("  Study area: %.0f x %.0f meters\n", 
            diff(range(coords[, 1])), 
            diff(range(coords[, 2]))))

# ==============================================================================
# STEP 3: CALCULATE OBSERVED ANN STATISTIC
# ==============================================================================

cat("\nSTEP 3: Calculating observed Average Nearest Neighbor distance...\n")

# Calculate nearest neighbor distances
nn_distances <- nndist(hdb_ppp)

# Calculate mean nearest neighbor distance (observed)
observed_ann <- mean(nn_distances)

cat(sprintf("  Observed mean nearest neighbor distance: %.2f meters\n", observed_ann))
cat(sprintf("  Min nearest neighbor distance: %.2f meters\n", min(nn_distances)))
cat(sprintf("  Max nearest neighbor distance: %.2f meters\n", max(nn_distances)))

# ==============================================================================
# STEP 4: MONTE CARLO SIMULATION (999 iterations)
# ==============================================================================

cat("\nSTEP 4: Running Monte Carlo simulation (999 iterations)...\n")
cat("  This may take a few minutes...\n")

set.seed(42)  # For reproducibility
n_simulations <- 999

# Storage for simulated ANN values
simulated_ann <- numeric(n_simulations)

# Progress reporting
progress_interval <- 100

for (i in 1:n_simulations) {
  # Generate random point pattern with same number of points
  random_ppp <- rpoispp(lambda = hdb_ppp$n / area(win), win = win, nsim = 1)
  
  # Calculate ANN for random pattern
  simulated_ann[i] <- mean(nndist(random_ppp))
  
  # Progress update
  if (i %% progress_interval == 0) {
    cat(sprintf("    Completed %d/%d simulations\n", i, n_simulations))
  }
}

cat(sprintf("  Completed all %d simulations\n", n_simulations))

# ==============================================================================
# STEP 5: STATISTICAL TESTING
# ==============================================================================

cat("\nSTEP 5: Statistical analysis...\n")

# Calculate expected ANN under Complete Spatial Randomness (CSR)
expected_ann <- mean(simulated_ann)

# Calculate standard deviation
sd_ann <- sd(simulated_ann)

# Calculate z-score
z_score <- (observed_ann - expected_ann) / sd_ann

# Calculate p-value (two-tailed test)
# Count how many simulated values are as extreme as observed
p_value <- (sum(abs(simulated_ann - expected_ann) >= abs(observed_ann - expected_ann)) + 1) / (n_simulations + 1)

# ANN Ratio (R)
# R < 1: Clustered
# R ≈ 1: Random
# R > 1: Dispersed
ann_ratio <- observed_ann / expected_ann

cat(sprintf("\n--- RESULTS ---\n"))
cat(sprintf("  Observed ANN: %.2f meters\n", observed_ann))
cat(sprintf("  Expected ANN (CSR): %.2f meters\n", expected_ann))
cat(sprintf("  Standard Deviation: %.2f meters\n", sd_ann))
cat(sprintf("  Z-Score: %.4f\n", z_score))
cat(sprintf("  P-Value: %.4f\n", p_value))
cat(sprintf("  ANN Ratio (R): %.4f\n", ann_ratio))

# Interpretation
if (p_value < 0.05) {
  if (ann_ratio < 1) {
    interpretation <- "CLUSTERED (significantly)"
    explanation <- "HDB transactions are significantly clustered - locations are closer together than random"
  } else {
    interpretation <- "DISPERSED (significantly)"
    explanation <- "HDB transactions are significantly dispersed - locations are more spread out than random"
  }
  significance <- "SIGNIFICANT"
} else {
  interpretation <- "RANDOM (not significant)"
  explanation <- "HDB transactions show random spatial pattern - no significant clustering or dispersion"
  significance <- "NOT SIGNIFICANT"
}

cat(sprintf("\n  Spatial Pattern: %s\n", interpretation))
cat(sprintf("  Statistical Significance: %s at α=0.05\n", significance))
cat(sprintf("  Interpretation: %s\n", explanation))

# ==============================================================================
# STEP 6: VISUALIZATION
# ==============================================================================

cat("\nSTEP 6: Creating visualizations...\n")

# Create histogram of Monte Carlo simulation results
hist_data <- data.frame(simulated_ann = simulated_ann)

p_histogram <- ggplot(hist_data, aes(x = simulated_ann)) +
  geom_histogram(bins = 50, fill = "lightblue", color = "black", alpha = 0.7) +
  geom_vline(xintercept = observed_ann, color = "red", linetype = "dashed", linewidth = 1.2) +
  geom_vline(xintercept = expected_ann, color = "blue", linetype = "dashed", linewidth = 1.2) +
  annotate("text", x = observed_ann, y = Inf, 
           label = sprintf("Observed: %.1fm", observed_ann),
           vjust = 2, hjust = -0.1, color = "red", fontface = "bold", size = 4) +
  annotate("text", x = expected_ann, y = Inf, 
           label = sprintf("Expected: %.1fm", expected_ann),
           vjust = 2, hjust = 1.1, color = "blue", fontface = "bold", size = 4) +
  labs(
    title = "Average Nearest Neighbor Analysis - Monte Carlo Simulation",
    subtitle = sprintf("4-Room HDB Transactions 2024 | %d simulations | Z-score: %.2f, p-value: %.4f",
                      n_simulations, z_score, p_value),
    x = "Mean Nearest Neighbor Distance (meters)",
    y = "Frequency",
    caption = sprintf("Pattern: %s | ANN Ratio: %.4f", interpretation, ann_ratio)
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 10),
    plot.caption = element_text(size = 11, hjust = 0.5, face = "bold"),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )

ggsave("HDB/figures/ann_monte_carlo_histogram.png", p_histogram,
       width = 12, height = 8, dpi = 300, bg = "white")

cat("  Saved: ann_monte_carlo_histogram.png\n")

# ==============================================================================
# STEP 7: SAVE RESULTS
# ==============================================================================

cat("\nSTEP 7: Saving results...\n")

# Create results dataframe
results <- data.frame(
  Test = "Average Nearest Neighbor (ANN)",
  N_Transactions = nrow(hdb_filtered),
  Observed_ANN_m = observed_ann,
  Expected_ANN_m = expected_ann,
  SD_ANN_m = sd_ann,
  ANN_Ratio = ann_ratio,
  Z_Score = z_score,
  P_Value = p_value,
  N_Simulations = n_simulations,
  Significance = significance,
  Spatial_Pattern = interpretation,
  Interpretation = explanation
)

write.csv(results, "HDB/outputs/ann_results.csv", row.names = FALSE)
cat("  Saved: ann_results.csv\n")

# ==============================================================================
# SUMMARY
# ==============================================================================

cat("\n=== ANALYSIS COMPLETE ===\n")
cat("Results saved to:\n")
cat("  - HDB/outputs/ann_results.csv\n")
cat("  - HDB/figures/ann_monte_carlo_histogram.png\n")
cat("\nKey Finding:\n")
cat(sprintf("  %s\n", explanation))
cat(sprintf("  Z-Score: %.4f | P-Value: %.4f | ANN Ratio: %.4f\n", z_score, p_value, ann_ratio))

