# ==============================================================================
# HDB SPATIAL ANALYSIS - GEOGRAPHICALLY WEIGHTED REGRESSION (GWR)
# Project: BT4015 Housing Resale Prices
# Purpose: Model spatially-varying effects of amenities, accessibility, and 
#          environment on HDB resale prices
# ==============================================================================

# Load required libraries
library(sf)
library(dplyr)
library(GWmodel)
library(ggplot2)
library(viridis)
library(scales)
library(tidyr)

# Set working directory
setwd("/Users/zr/Code/Projects/BT4015_Housing-Resale-Prices")

# Create output directories
dir.create("HDB/outputs", showWarnings = FALSE, recursive = TRUE)
dir.create("HDB/figures", showWarnings = FALSE, recursive = TRUE)

cat("=== GEOGRAPHICALLY WEIGHTED REGRESSION (GWR) ANALYSIS ===\n")
cat("Purpose: Model how amenities/accessibility/environment affect HDB prices\n")
cat("         across different locations in Singapore\n\n")

# ==============================================================================
# STEP 1: LOAD AND FILTER HDB DATA
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
# STEP 2: LOAD ALL AMENITY/ACCESSIBILITY/ENVIRONMENT DATASETS
# ==============================================================================

cat("\nSTEP 2: Loading spatial datasets...\n")

# Amenities (6)
cat("  Loading amenities...\n")
hawker_centers <- st_read("Datasets/amenities/HawkerCentresGEOJSON.geojson", quiet = TRUE) %>%
  st_transform(crs = 3414)
cat(sprintf("    - Hawker Centers: %d\n", nrow(hawker_centers)))

schools <- st_read("Datasets/amenities/Schools_information_with_loc.geojson", quiet = TRUE) %>%
  st_transform(crs = 3414)
cat(sprintf("    - Schools: %d\n", nrow(schools)))

clinics <- st_read("Datasets/amenities/CHASClinics.geojson", quiet = TRUE) %>%
  st_transform(crs = 3414)
cat(sprintf("    - Clinics: %d\n", nrow(clinics)))

supermarkets <- st_read("Datasets/amenities/SupermarketsGEOJSON.geojson", quiet = TRUE) %>%
  st_transform(crs = 3414)
cat(sprintf("    - Supermarkets: %d\n", nrow(supermarkets)))

sports_facilities <- st_read("Datasets/amenities/SportSGSportFacilitiesGEOJSON.geojson", quiet = TRUE) %>%
  st_transform(crs = 3414)
cat(sprintf("    - Sports Facilities: %d\n", nrow(sports_facilities)))

parking_lots <- st_read("Datasets/amenities/URAParkingLotGEOJSON.geojson", quiet = TRUE) %>%
  st_transform(crs = 3414)
cat(sprintf("    - Parking Lots: %d\n", nrow(parking_lots)))

# Accessibility (2)
cat("  Loading accessibility data...\n")
mrt_stations <- st_read("Datasets/accessbilities/LTAMRTStationExitGEOJSON.geojson", quiet = TRUE) %>%
  st_transform(crs = 3414)
cat(sprintf("    - MRT Station Exits: %d\n", nrow(mrt_stations)))

bus_stops <- st_read("Datasets/accessbilities/LTABusStop.geojson", quiet = TRUE) %>%
  st_transform(crs = 3414)
cat(sprintf("    - Bus Stops: %d\n", nrow(bus_stops)))

# Environment (2)
cat("  Loading environment data...\n")
parks <- st_read("Datasets/amenities/NParksParksandNatureReserves.geojson", quiet = TRUE) %>%
  st_transform(crs = 3414)
cat(sprintf("    - Parks & Nature Reserves: %d\n", nrow(parks)))

park_connectors <- st_read("Datasets/amenities/G_MP08_PK_CONECTR_LI.shp", quiet = TRUE) %>%
  st_transform(crs = 3414)
cat(sprintf("    - Park Connectors: %d\n", nrow(park_connectors)))

cat("\n  All datasets loaded successfully!\n")

# ==============================================================================
# STEP 3: CALCULATE SPATIAL METRICS FOR EACH HDB TRANSACTION
# ==============================================================================

cat("\nSTEP 3: Calculating spatial metrics (distance + count within 1km)...\n")
cat("  This may take several minutes...\n\n")

# Function to calculate distance to nearest feature
calc_distance_to_nearest <- function(points, features, feature_name) {
  cat(sprintf("  Calculating distance to nearest %s...\n", feature_name))
  distances <- st_distance(points, features)
  nearest_dist <- apply(distances, 1, min)
  return(as.numeric(nearest_dist))
}

# Function to count features within specified buffer distance
calc_count_within_buffer <- function(points, features, buffer_dist, feature_name) {
  cat(sprintf("  Counting %s within %dm...\n", feature_name, buffer_dist))
  buffer <- st_buffer(points, dist = buffer_dist)
  counts <- lengths(st_intersects(buffer, features))
  return(counts)
}

# Calculate metrics for all datasets with specific buffer distances
# Buffer distances based on typical walking distances for each amenity type

# AMENITIES
# Hawker Centers (500m buffer - 5-7 min walk)
hdb_svy21$dist_hawker_m <- calc_distance_to_nearest(hdb_svy21, hawker_centers, "Hawker Centers")
hdb_svy21$count_hawker_500m <- calc_count_within_buffer(hdb_svy21, hawker_centers, 500, "Hawker Centers")

# Schools (1000m buffer - important for families)
hdb_svy21$dist_school_m <- calc_distance_to_nearest(hdb_svy21, schools, "Schools")
hdb_svy21$count_school_1km <- calc_count_within_buffer(hdb_svy21, schools, 1000, "Schools")

# Clinics (800m buffer - 10 min walk)
hdb_svy21$dist_clinic_m <- calc_distance_to_nearest(hdb_svy21, clinics, "Clinics")
hdb_svy21$count_clinic_800m <- calc_count_within_buffer(hdb_svy21, clinics, 800, "Clinics")

# Supermarkets (400m buffer - quick errands)
hdb_svy21$dist_supermarket_m <- calc_distance_to_nearest(hdb_svy21, supermarkets, "Supermarkets")
hdb_svy21$count_supermarket_400m <- calc_count_within_buffer(hdb_svy21, supermarkets, 400, "Supermarkets")

# Sports Facilities (2000m buffer - less frequent use)
hdb_svy21$dist_sports_m <- calc_distance_to_nearest(hdb_svy21, sports_facilities, "Sports Facilities")
hdb_svy21$count_sports_2km <- calc_count_within_buffer(hdb_svy21, sports_facilities, 2000, "Sports Facilities")

# Parking Lots (200m buffer - immediate vicinity)
hdb_svy21$dist_parking_m <- calc_distance_to_nearest(hdb_svy21, parking_lots, "Parking Lots")
hdb_svy21$count_parking_200m <- calc_count_within_buffer(hdb_svy21, parking_lots, 200, "Parking Lots")

# ACCESSIBILITY
# MRT Stations (800m buffer - 10 min walk)
hdb_svy21$dist_mrt_m <- calc_distance_to_nearest(hdb_svy21, mrt_stations, "MRT Stations")
hdb_svy21$count_mrt_800m <- calc_count_within_buffer(hdb_svy21, mrt_stations, 800, "MRT Stations")

# Bus Stops (200m buffer - immediate access)
hdb_svy21$dist_bus_m <- calc_distance_to_nearest(hdb_svy21, bus_stops, "Bus Stops")
hdb_svy21$count_bus_200m <- calc_count_within_buffer(hdb_svy21, bus_stops, 200, "Bus Stops")

# ENVIRONMENT
# Parks (1000m buffer - recreational distance)
hdb_svy21$dist_park_m <- calc_distance_to_nearest(hdb_svy21, parks, "Parks")
hdb_svy21$count_park_1km <- calc_count_within_buffer(hdb_svy21, parks, 1000, "Parks")

# Park Connectors (200m buffer - line features, use length within buffer)
cat("  Calculating distance to nearest Park Connector...\n")
hdb_svy21$dist_connector_m <- as.numeric(st_distance(hdb_svy21, st_union(park_connectors)))

cat("  Calculating Park Connector length within 200m...\n")
buffer_200m <- st_buffer(hdb_svy21, dist = 200)
connector_union <- st_union(park_connectors)

# Calculate connector length for each buffer individually
hdb_svy21$connector_length_200m <- sapply(1:nrow(buffer_200m), function(i) {
  intersect_result <- suppressWarnings(st_intersection(connector_union, buffer_200m[i, ]))
  if (length(intersect_result) == 0 || st_is_empty(intersect_result)) {
    return(0)
  } else {
    return(as.numeric(st_length(intersect_result)))
  }
})

cat("\n  All spatial metrics calculated!\n")

# ==============================================================================
# STEP 4: PREPARE DATA FOR MODELING
# ==============================================================================

cat("\nSTEP 4: Preparing data for modeling...\n")

# Extract remaining lease as numeric (years)
hdb_svy21$remaining_lease_years <- as.numeric(gsub(" years.*", "", hdb_svy21$remaining_lease))

# Select variables for modeling
model_vars <- c(
  "resale_price",
  # Distance variables (10)
  "dist_hawker_m", "dist_school_m", "dist_clinic_m", "dist_supermarket_m",
  "dist_sports_m", "dist_parking_m", "dist_mrt_m", "dist_bus_m",
  "dist_park_m", "dist_connector_m",
  # Count variables with specific buffer distances (10)
  "count_hawker_500m", "count_school_1km", "count_clinic_800m", "count_supermarket_400m",
  "count_sports_2km", "count_parking_200m", "count_mrt_800m", "count_bus_200m",
  "count_park_1km", "connector_length_200m",
  # Control variables
  "floor_area_sqm", "remaining_lease_years"
)

# Create modeling dataset (remove NAs)
model_data <- hdb_svy21 %>%
  st_drop_geometry() %>%
  select(all_of(model_vars)) %>%
  na.omit()

cat(sprintf("  Model dataset: %d observations\n", nrow(model_data)))
cat(sprintf("  Total predictors: %d (20 spatial + 2 control variables)\n", length(model_vars) - 1))

# Check for any remaining issues
if (any(is.na(model_data))) {
  cat("  WARNING: Some NA values remain\n")
}

# Add coordinates back for spatial modeling
model_coords <- st_coordinates(hdb_svy21)[complete.cases(
  st_drop_geometry(hdb_svy21)[, model_vars]), ]

model_data_sp <- cbind(model_data, model_coords)
coordinates(model_data_sp) <- ~X+Y

cat("  Data prepared for GWR\n")

# ==============================================================================
# STEP 5: FIT GLOBAL OLS MODEL (BASELINE)
# ==============================================================================

cat("\nSTEP 5: Fitting Global OLS regression (baseline)...\n")

# Create formula
formula_str <- paste("resale_price ~",
                    paste(setdiff(model_vars, "resale_price"), collapse = " + "))
ols_formula <- as.formula(formula_str)

# Fit OLS model
ols_model <- lm(ols_formula, data = model_data)

# Summary
ols_summary <- summary(ols_model)
ols_r2 <- ols_summary$r.squared
ols_adj_r2 <- ols_summary$adj.r.squared
ols_aic <- AIC(ols_model)

cat(sprintf("\n  Global OLS Results:\n"))
cat(sprintf("    R²: %.4f\n", ols_r2))
cat(sprintf("    Adjusted R²: %.4f\n", ols_adj_r2))
cat(sprintf("    AIC: %.2f\n", ols_aic))

# Extract significant predictors (p < 0.05)
coef_summary <- as.data.frame(ols_summary$coefficients)
significant_vars <- rownames(coef_summary)[coef_summary$`Pr(>|t|)` < 0.05]
significant_vars <- significant_vars[significant_vars != "(Intercept)"]

cat(sprintf("\n  Significant predictors (p < 0.05): %d out of %d\n", 
            length(significant_vars), length(model_vars) - 1))
if (length(significant_vars) > 0) {
  cat("    Top 5 significant variables:\n")
  top_sig <- head(significant_vars, 5)
  for (var in top_sig) {
    coef_val <- coef_summary[var, "Estimate"]
    p_val <- coef_summary[var, "Pr(>|t|)"]
    cat(sprintf("      - %s: coef=%.2f, p=%.6f\n", var, coef_val, p_val))
  }
}

# ==============================================================================
# STEP 6: FIND OPTIMAL BANDWIDTH FOR GWR
# ==============================================================================

cat("\n=== STEP 6: Finding optimal bandwidth for GWR ===\n")
cat("  Using cross-validation (this may take 10-20 minutes)...\n")

# Try to find optimal bandwidth
bw <- tryCatch({
  bw_result <- bw.gwr(
    ols_formula,
    data = model_data_sp,
    approach = "CV",
    kernel = "bisquare",
    adaptive = TRUE,
    longlat = FALSE
  )
  bw_result
}, error = function(e) {
  cat("\n  Cross-validation failed, using default bandwidth\n")
  cat(sprintf("  Error: %s\n", e$message))
  # Default to square root of number of observations
  return(floor(sqrt(nrow(model_data_sp))))
})

cat(sprintf("\n  Optimal bandwidth: %d nearest neighbors\n", round(bw)))

# ==============================================================================
# STEP 7: FIT GWR MODEL
# ==============================================================================

cat("\nSTEP 7: Fitting GWR model...\n")
cat("  This may take 10-15 minutes...\n")

# Fit GWR model
gwr_model <- gwr.basic(
  ols_formula,
  data = model_data_sp,
  bw = bw,
  kernel = "bisquare",
  adaptive = TRUE,
  longlat = FALSE
)

cat("\n  GWR model fitted successfully!\n")

# Extract results
gwr_r2 <- gwr_model$GW.diagnostic$gw.R2
gwr_adj_r2 <- gwr_model$GW.diagnostic$gwR2.adj
gwr_aicc <- gwr_model$GW.diagnostic$AICc

cat(sprintf("\n  GWR Results:\n"))
cat(sprintf("    R²: %.4f\n", gwr_r2))
cat(sprintf("    Adjusted R²: %.4f\n", gwr_adj_r2))
cat(sprintf("    AICc: %.2f\n", gwr_aicc))
cat(sprintf("\n  Improvement over OLS:\n"))
cat(sprintf("    ΔR²: %.4f (%.1f%% improvement)\n", 
            gwr_r2 - ols_r2, 
            (gwr_r2 - ols_r2) / ols_r2 * 100))
cat(sprintf("    ΔAIC: %.2f\n", gwr_aicc - ols_aic))

# ==============================================================================
# STEP 8: EXTRACT AND ANALYZE LOCAL COEFFICIENTS
# ==============================================================================

cat("\nSTEP 8: Extracting local coefficients...\n")

# Extract local coefficients
local_coefs <- as.data.frame(gwr_model$SDF)

# Get valid indices (matching model_data)
valid_indices <- complete.cases(st_drop_geometry(hdb_svy21)[, model_vars])
hdb_gwr <- hdb_svy21[valid_indices, ]

# Add local results to spatial data
hdb_gwr$local_r2 <- local_coefs$Local_R2

# Add key local coefficients
# Distance coefficients
hdb_gwr$coef_dist_mrt <- local_coefs$dist_mrt_m
hdb_gwr$coef_dist_hawker <- local_coefs$dist_hawker_m
hdb_gwr$coef_dist_school <- local_coefs$dist_school_m
hdb_gwr$coef_dist_park <- local_coefs$dist_park_m

# Count coefficients (with specific buffer distances)
hdb_gwr$coef_count_mrt <- local_coefs$count_mrt_800m
hdb_gwr$coef_count_hawker <- local_coefs$count_hawker_500m
hdb_gwr$coef_count_school <- local_coefs$count_school_1km
hdb_gwr$coef_count_park <- local_coefs$count_park_1km

# Control variables
hdb_gwr$coef_floor_area <- local_coefs$floor_area_sqm
hdb_gwr$coef_lease <- local_coefs$remaining_lease_years

# Summary statistics for key coefficients
cat("\n  Summary of local coefficients:\n")

key_coefs <- c("dist_mrt_m", "count_mrt_800m", "dist_hawker_m", "count_hawker_500m",
               "dist_park_m", "count_park_1km", "floor_area_sqm", "remaining_lease_years")

for (coef_name in key_coefs) {
  if (coef_name %in% names(local_coefs)) {
    coef_values <- local_coefs[[coef_name]]
    cat(sprintf("    %s:\n", coef_name))
    cat(sprintf("      Mean: %.2f, SD: %.2f\n", mean(coef_values), sd(coef_values)))
    cat(sprintf("      Range: [%.2f, %.2f]\n", min(coef_values), max(coef_values)))
  }
}

# ==============================================================================
# STEP 9: SAVE RESULTS
# ==============================================================================

cat("\nSTEP 9: Saving results...\n")

# Model comparison table
model_comparison <- data.frame(
  Model = c("Global OLS", "GWR"),
  R_Squared = c(ols_r2, gwr_r2),
  Adj_R_Squared = c(ols_adj_r2, gwr_adj_r2),
  AIC_AICc = c(ols_aic, gwr_aicc),
  N_Predictors = c(length(model_vars) - 1, length(model_vars) - 1),
  Bandwidth = c(NA, round(bw)),
  Note = c("Constant coefficients globally", "Coefficients vary by location")
)

write.csv(model_comparison, "HDB/outputs/gwr_model_comparison.csv", row.names = FALSE)
cat("  Saved: gwr_model_comparison.csv\n")

# Local coefficient summary
coef_summary_df <- data.frame(
  Variable = names(local_coefs)[grepl("^dist_|^count_|^floor|^remaining", names(local_coefs))],
  stringsAsFactors = FALSE
)

coef_summary_df$Mean <- sapply(coef_summary_df$Variable, function(v) mean(local_coefs[[v]]))
coef_summary_df$SD <- sapply(coef_summary_df$Variable, function(v) sd(local_coefs[[v]]))
coef_summary_df$Min <- sapply(coef_summary_df$Variable, function(v) min(local_coefs[[v]]))
coef_summary_df$Q25 <- sapply(coef_summary_df$Variable, function(v) quantile(local_coefs[[v]], 0.25))
coef_summary_df$Median <- sapply(coef_summary_df$Variable, function(v) median(local_coefs[[v]]))
coef_summary_df$Q75 <- sapply(coef_summary_df$Variable, function(v) quantile(local_coefs[[v]], 0.75))
coef_summary_df$Max <- sapply(coef_summary_df$Variable, function(v) max(local_coefs[[v]]))

write.csv(coef_summary_df, "HDB/outputs/gwr_local_coefficients_summary.csv", row.names = FALSE)
cat("  Saved: gwr_local_coefficients_summary.csv\n")

# ==============================================================================
# STEP 10: CREATE VISUALIZATIONS
# ==============================================================================

cat("\nSTEP 10: Creating visualizations...\n")

# Load planning areas for background
sf_use_s2(FALSE)
planning_areas <- st_read("Datasets/MasterPlan2019PlanningAreaBoundaryNoSea.geojson", quiet = TRUE)
planning_areas <- st_make_valid(planning_areas)

# Transform to WGS84 for mapping
hdb_gwr_wgs84 <- st_transform(hdb_gwr, crs = 4326)
planning_areas_wgs84 <- st_transform(planning_areas, crs = 4326)

# Map 1: Local R² values
cat("  1. Creating map: Local R² values\n")

p_r2 <- ggplot() +
  geom_sf(data = planning_areas_wgs84, fill = "white", color = "gray70", linewidth = 0.2) +
  geom_sf(data = hdb_gwr_wgs84, aes(color = local_r2), size = 1, alpha = 0.7) +
  scale_color_viridis_c(option = "viridis", name = "Local R²") +
  labs(
    title = "GWR Model Fit: Local R² Values",
    subtitle = sprintf("Overall R² = %.3f | Bandwidth = %d neighbors", gwr_r2, round(bw))
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 10),
    legend.position = "right",
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )

ggsave("HDB/figures/gwr_local_r2_map.png", p_r2,
       width = 12, height = 10, dpi = 300, bg = "white")

# Map 2: Local coefficient for MRT distance
cat("  2. Creating map: Local coefficient for MRT distance\n")

p_mrt_dist <- ggplot() +
  geom_sf(data = planning_areas_wgs84, fill = "white", color = "gray70", linewidth = 0.2) +
  geom_sf(data = hdb_gwr_wgs84, aes(color = coef_dist_mrt), size = 1, alpha = 0.7) +
  scale_color_gradient2(
    low = "#d73027", mid = "white", high = "#1a9850",
    midpoint = 0, name = "Coefficient"
  ) +
  labs(
    title = "GWR: Effect of Distance to MRT on Price",
    subtitle = "Negative (red) = closer to MRT increases price | Positive (green) = farther increases price"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 9),
    legend.position = "right",
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )

ggsave("HDB/figures/gwr_coef_mrt_distance_map.png", p_mrt_dist,
       width = 12, height = 10, dpi = 300, bg = "white")

# Map 3: Local coefficient for MRT count
cat("  3. Creating map: Local coefficient for MRT count within 800m\n")

p_mrt_count <- ggplot() +
  geom_sf(data = planning_areas_wgs84, fill = "white", color = "gray70", linewidth = 0.2) +
  geom_sf(data = hdb_gwr_wgs84, aes(color = coef_count_mrt), size = 1, alpha = 0.7) +
  scale_color_gradient2(
    low = "#d73027", mid = "white", high = "#1a9850",
    midpoint = 0, name = "Coefficient"
  ) +
  labs(
    title = "GWR: Effect of MRT Station Count (within 800m) on Price",
    subtitle = "Shows where having more MRT stations nearby matters most (10-min walk)"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 10),
    legend.position = "right",
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )

ggsave("HDB/figures/gwr_coef_mrt_count_map.png", p_mrt_count,
       width = 12, height = 10, dpi = 300, bg = "white")

# Map 4: Local coefficient for Hawker Center count
cat("  4. Creating map: Local coefficient for Hawker Center count within 500m\n")

p_hawker <- ggplot() +
  geom_sf(data = planning_areas_wgs84, fill = "white", color = "gray70", linewidth = 0.2) +
  geom_sf(data = hdb_gwr_wgs84, aes(color = coef_count_hawker), size = 1, alpha = 0.7) +
  scale_color_gradient2(
    low = "#d73027", mid = "white", high = "#1a9850",
    midpoint = 0, name = "Coefficient"
  ) +
  labs(
    title = "GWR: Effect of Hawker Center Count (within 500m) on Price",
    subtitle = "Shows where proximity to hawker centers impacts prices (5-7 min walk)"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 10),
    legend.position = "right",
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )

ggsave("HDB/figures/gwr_coef_hawker_count_map.png", p_hawker,
       width = 12, height = 10, dpi = 300, bg = "white")

# Map 5: Local coefficient for Park count
cat("  5. Creating map: Local coefficient for Park count\n")

p_park <- ggplot() +
  geom_sf(data = planning_areas_wgs84, fill = "white", color = "gray70", linewidth = 0.2) +
  geom_sf(data = hdb_gwr_wgs84, aes(color = coef_count_park), size = 1, alpha = 0.7) +
  scale_color_gradient2(
    low = "#d73027", mid = "white", high = "#1a9850",
    midpoint = 0, name = "Coefficient"
  ) +
  labs(
    title = "GWR: Effect of Park Count (within 1km) on Price",
    subtitle = "Shows where green spaces have the strongest effect on prices"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 10),
    legend.position = "right",
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )

ggsave("HDB/figures/gwr_coef_park_count_map.png", p_park,
       width = 12, height = 10, dpi = 300, bg = "white")

# Map 6: Local coefficient for Floor Area
cat("  6. Creating map: Local coefficient for Floor Area\n")

p_floor <- ggplot() +
  geom_sf(data = planning_areas_wgs84, fill = "white", color = "gray70", linewidth = 0.2) +
  geom_sf(data = hdb_gwr_wgs84, aes(color = coef_floor_area), size = 1, alpha = 0.7) +
  scale_color_viridis_c(option = "plasma", name = "Coefficient") +
  labs(
    title = "GWR: Effect of Floor Area on Price",
    subtitle = "Shows where larger floor area commands higher premiums"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 10),
    legend.position = "right",
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )

ggsave("HDB/figures/gwr_coef_floor_area_map.png", p_floor,
       width = 12, height = 10, dpi = 300, bg = "white")

cat("  All visualizations created!\n")

# ==============================================================================
# SUMMARY
# ==============================================================================

cat("\n=== ANALYSIS COMPLETE ===\n")
cat("\nFiles saved:\n")
cat("  Outputs:\n")
cat("    - HDB/outputs/gwr_model_comparison.csv\n")
cat("    - HDB/outputs/gwr_local_coefficients_summary.csv\n")
cat("  Figures:\n")
cat("    - HDB/figures/gwr_local_r2_map.png\n")
cat("    - HDB/figures/gwr_coef_mrt_distance_map.png\n")
cat("    - HDB/figures/gwr_coef_mrt_count_map.png\n")
cat("    - HDB/figures/gwr_coef_hawker_count_map.png\n")
cat("    - HDB/figures/gwr_coef_park_count_map.png\n")
cat("    - HDB/figures/gwr_coef_floor_area_map.png\n")

cat("\n=== KEY FINDINGS ===\n")
cat(sprintf("Model Performance:\n"))
cat(sprintf("  - Global OLS R²: %.4f\n", ols_r2))
cat(sprintf("  - GWR R²: %.4f\n", gwr_r2))
cat(sprintf("  - Improvement: %.4f (%.1f%%)\n", 
            gwr_r2 - ols_r2, 
            (gwr_r2 - ols_r2) / ols_r2 * 100))
cat(sprintf("\nModel Complexity:\n"))
cat(sprintf("  - Total predictors: %d\n", length(model_vars) - 1))
cat(sprintf("  - Bandwidth: %d nearest neighbors\n", round(bw)))
cat(sprintf("  - Observations: %d\n", nrow(model_data)))
cat("\nInterpretation:\n")
cat("  - Local R² map shows where the model fits best\n")
cat("  - Coefficient maps reveal spatial heterogeneity in effects\n")
cat("  - Red coefficients = negative effect, Green = positive effect\n")
cat("  - GWR captures spatial variation that global models miss\n")

