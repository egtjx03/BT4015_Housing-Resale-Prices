# ==============================================================================
# AMENITIES HYPOTHESIS TESTING
# Project: BT4015 Housing Resale Prices
# Purpose: Test if amenity factors have significant effect on prices
# ==============================================================================

library(sf)
library(dplyr)

setwd("/Users/zr/Code/Projects/BT4015_Housing-Resale-Prices")

cat("=== Loading Data ===\n")
hdb <- readRDS("Environment_Analysis/data/hdb_4room_with_metrics.rds")

cat(sprintf("Loaded: %d transactions\n", nrow(hdb)))

# ====================================================================
# HYPOTHESIS TESTING FOR AMENITY FACTORS
# ====================================================================

cat("\n=== SETTING UP HYPOTHESIS TESTS ===\n")
cat("H0: Amenity factor has NO effect on price (β = 0)\n")
cat("H1: Amenity factor HAS effect on price (β ≠ 0)\n")
cat("\nUsing multiple linear regression with t-tests for each coefficient\n")

# Prepare data (drop geometry, handle missing values)
hdb_df <- hdb %>%
  st_drop_geometry() %>%
  mutate(remaining_lease_years = as.numeric(gsub(" years.*", "", remaining_lease)))

# ====================================================================
# DEMONSTRATION USING AVAILABLE GREEN SPACE DATA
# (Replace with actual amenity distances when available)
# ====================================================================

cat("\n=== TESTING GREEN SPACE FACTORS (Demonstration) ===\n")

# Fit regression model with green space factors + control variables
model <- lm(resale_price ~ 
              dist_to_park_m +              # Distance to park
              dist_to_connector_m +         # Distance to connector  
              parks_within_1km +            # Number of parks nearby
              connector_length_1km +        # Connector accessibility
              floor_area_sqm +              # Control: flat size
              remaining_lease_years,        # Control: remaining lease
            data = hdb_df)

# Extract results
model_summary <- summary(model)
coefs <- model_summary$coefficients

cat("\nModel Summary:\n")
print(model_summary)

# ====================================================================
# CREATE HYPOTHESIS TESTING RESULTS TABLE
# ====================================================================

cat("\n=== CREATING HYPOTHESIS TEST RESULTS TABLE ===\n")

# Extract relevant statistics for each amenity factor
amenity_factors <- c("dist_to_park_m", "dist_to_connector_m", "parks_within_1km", "connector_length_1km")
amenity_names <- c("Distance to Park", "Distance to Park Connector", 
                   "Parks within 1km", "Park Connector Length (1km)")

results_table <- data.frame(
  Amenity_Factor = amenity_names,
  Coefficient = coefs[amenity_factors, "Estimate"],
  Std_Error = coefs[amenity_factors, "Std. Error"],
  t_Statistic = coefs[amenity_factors, "t value"],
  p_Value = coefs[amenity_factors, "Pr(>|t|)"],
  Significant = ifelse(coefs[amenity_factors, "Pr(>|t|)"] < 0.05, "Yes", "No"),
  Decision = ifelse(coefs[amenity_factors, "Pr(>|t|)"] < 0.05, 
                   "Reject H0 (Has effect)", 
                   "Accept H0 (No effect)"),
  Effect_Direction = ifelse(coefs[amenity_factors, "Estimate"] > 0, "Positive", "Negative")
)

# Add significance stars
results_table$Significance_Level <- case_when(
  results_table$p_Value < 0.001 ~ "***",
  results_table$p_Value < 0.01 ~ "**",
  results_table$p_Value < 0.05 ~ "*",
  TRUE ~ "ns"
)

cat("\nHYPOTHESIS TESTING RESULTS:\n")
print(results_table)

# Save results
write.csv(results_table, 
          "Environment_Analysis/outputs/amenities_hypothesis_testing.csv",
          row.names = FALSE)

cat("\n=== CREATING PRESENTATION-READY TABLE ===\n")

# Simplified table for presentation
presentation_table <- results_table %>%
  select(Amenity_Factor, Coefficient, p_Value, Decision, Effect_Direction) %>%
  mutate(
    Coefficient = sprintf("%.2f", Coefficient),
    p_Value = ifelse(p_Value < 0.001, "<0.001", sprintf("%.4f", p_Value)),
    Result = paste0(Decision, " (", Effect_Direction, ")")
  ) %>%
  select(Amenity_Factor, Coefficient, p_Value, Result)

cat("\nPRESENTATION TABLE:\n")
print(presentation_table)

write.csv(presentation_table,
          "Environment_Analysis/outputs/hypothesis_testing_presentation.csv",
          row.names = FALSE)

# ====================================================================
# TEMPLATE FOR ACTUAL AMENITIES
# ====================================================================

cat("\n=== TEMPLATE FOR WHEN AMENITY DATA IS AVAILABLE ===\n")
cat("\nOnce you have distance data for actual amenities, use this model:\n\n")
cat("model <- lm(resale_price ~ \n")
cat("              dist_to_hawker +         # Distance to nearest hawker center\n")
cat("              dist_to_polyclinic +     # Distance to nearest polyclinic\n")
cat("              dist_to_school +         # Distance to nearest school\n")
cat("              dist_to_supermarket +    # Distance to nearest supermarket\n")
cat("              dist_to_sports +         # Distance to nearest sports facility\n")
cat("              dist_to_parking +        # Distance to nearest parking\n")
cat("              floor_area_sqm +         # Control variable\n")
cat("              remaining_lease_years,   # Control variable\n")
cat("            data = hdb_df)\n\n")

# Create example template table with expected structure
template_amenities <- c(
  "Hawker Center",
  "Polyclinic", 
  "Primary School",
  "Supermarket",
  "Sports Facility",
  "Parking"
)

template_table <- data.frame(
  Amenity = template_amenities,
  Hypothesis_Test = rep("H0: β = 0 vs H1: β ≠ 0", 6),
  Decision = rep("[To be filled after analysis]", 6),
  P_Value = rep("[Calculate from regression]", 6),
  Interpretation = rep("[Significant/Not Significant]", 6)
)

cat("\nTEMPLATE TABLE STRUCTURE:\n")
print(template_table)

write.csv(template_table,
          "Environment_Analysis/outputs/amenities_testing_template.csv",
          row.names = FALSE)

cat("\n=== MODEL SUMMARY STATISTICS ===\n")
cat(sprintf("Overall Model R²: %.4f\n", model_summary$r.squared))
cat(sprintf("Adjusted R²: %.4f\n", model_summary$adj.r.squared))
cat(sprintf("F-statistic: %.2f (p-value: %.4e)\n", 
            model_summary$fstatistic[1], 
            pf(model_summary$fstatistic[1], 
               model_summary$fstatistic[2], 
               model_summary$fstatistic[3], 
               lower.tail = FALSE)))

cat("\n=== ANALYSIS COMPLETE ===\n")
cat("Generated:\n")
cat("  1. Full hypothesis testing results (all statistics)\n")
cat("  2. Presentation-ready table (simplified)\n")
cat("  3. Template for actual amenity testing\n")

