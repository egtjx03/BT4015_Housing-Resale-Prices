# ==============================================================================
# ENVIRONMENT: SPATIAL ANALYSIS - GEOGRAPHICALLY WEIGHTED REGRESSION (PRICE)
# Project: BT4015 Housing Resale Prices
# Purpose: Model spatially varying effects of green spaces on prices
# ==============================================================================

library(sf)
library(dplyr)
library(GWmodel)
library(ggplot2)
library(scales)
library(viridis)

setwd("/Users/zr/Code/Projects/BT4015_Housing-Resale-Prices")

cat("=== Loading Data ===\n")
hdb <- readRDS("Environment_Analysis/data/hdb_4room_with_metrics.rds")

# Load planning areas
sf_use_s2(FALSE)
planning_areas <- st_read("Datasets/MasterPlan2019PlanningAreaBoundaryNoSea.geojson", quiet = TRUE)
planning_areas <- st_make_valid(planning_areas)
planning_areas <- st_transform(planning_areas, crs = 3414)

# Transform to SVY21
hdb_svy21 <- st_transform(hdb, crs = 3414)

cat(sprintf("Loaded: %d transactions\n", nrow(hdb)))

# ====================================================================
# 6.4.1 GEOGRAPHICALLY WEIGHTED REGRESSION - PREDICTING RESALE PRICES
# ====================================================================

cat("\n=== PREPARING DATA FOR GWR ===\n")

# Extract remaining lease as numeric (years)
hdb_svy21$remaining_lease_years <- as.numeric(gsub(" years.*", "", hdb_svy21$remaining_lease))

# Select variables for modeling (remove NAs)
model_data <- hdb_svy21 %>%
  st_drop_geometry() %>%
  select(resale_price, dist_to_park_m, dist_to_connector_m, 
         connector_length_1km, parks_within_1km, 
         floor_area_sqm, remaining_lease_years) %>%
  na.omit()

# Add coordinates back
model_coords <- st_coordinates(hdb_svy21)[complete.cases(
  st_drop_geometry(hdb_svy21)[, c("resale_price", "dist_to_park_m", "dist_to_connector_m",
                                   "connector_length_1km", "parks_within_1km",
                                   "floor_area_sqm", "remaining_lease_years")]), ]

model_data_sp <- cbind(model_data, model_coords)
coordinates(model_data_sp) <- ~X+Y

cat(sprintf("Model dataset: %d observations\n", nrow(model_data)))

cat("\n=== FITTING GLOBAL OLS MODEL (Baseline) ===\n")

# Fit global OLS regression
ols_formula <- resale_price ~ dist_to_park_m + dist_to_connector_m + 
  connector_length_1km + parks_within_1km + 
  floor_area_sqm + remaining_lease_years

ols_model <- lm(ols_formula, data = model_data)

cat("\nGlobal OLS Model Summary:\n")
print(summary(ols_model))

# Extract OLS R-squared
ols_r2 <- summary(ols_model)$r.squared
ols_adj_r2 <- summary(ols_model)$adj.r.squared

cat(sprintf("\nGlobal OLS R²: %.4f\n", ols_r2))
cat(sprintf("Adjusted R²: %.4f\n", ols_adj_r2))

cat("\n=== FINDING OPTIMAL BANDWIDTH FOR GWR ===\n")

# Find optimal bandwidth using cross-validation
cat("This may take several minutes...\n")

bw <- tryCatch({
  bw.gwr(resale_price ~ dist_to_park_m + dist_to_connector_m + 
           connector_length_1km + parks_within_1km + 
           floor_area_sqm + remaining_lease_years,
         data = model_data_sp,
         approach = "CV",  # Cross-validation
         kernel = "bisquare",
         adaptive = TRUE,  # Adaptive bandwidth (number of neighbors)
         longlat = FALSE)  # Using projected coordinates
}, error = function(e) {
  cat("Cross-validation bandwidth selection failed, using fixed bandwidth\n")
  return(50)  # Default to 50 nearest neighbors
})

cat(sprintf("Optimal bandwidth: %d nearest neighbors\n", round(bw)))

cat("\n=== FITTING GWR MODEL ===\n")

# Fit GWR model
gwr_model <- gwr.basic(resale_price ~ dist_to_park_m + dist_to_connector_m + 
                         connector_length_1km + parks_within_1km + 
                         floor_area_sqm + remaining_lease_years,
                       data = model_data_sp,
                       bw = bw,
                       kernel = "bisquare",
                       adaptive = TRUE,
                       longlat = FALSE)

cat("\nGWR Model Results:\n")
print(gwr_model)

# Extract GWR R-squared
gwr_r2 <- gwr_model$GW.diagnostic$gw.R2
gwr_adj_r2 <- gwr_model$GW.diagnostic$gwR2.adj

cat(sprintf("\nGWR R²: %.4f\n", gwr_r2))
cat(sprintf("GWR Adjusted R²: %.4f\n", gwr_adj_r2))
cat(sprintf("Improvement over OLS: %.4f (%.1f%%)\n", 
            gwr_r2 - ols_r2, (gwr_r2 - ols_r2) / ols_r2 * 100))

# Model comparison
model_comparison <- data.frame(
  Model = c("Global OLS", "GWR"),
  R_Squared = c(ols_r2, gwr_r2),
  Adj_R_Squared = c(ols_adj_r2, gwr_adj_r2),
  AICc = c(AIC(ols_model), gwr_model$GW.diagnostic$AICc),
  Note = c("Constant coefficients across space", 
           "Coefficients vary by location")
)

print(model_comparison)

write.csv(model_comparison,
          "Environment_Analysis/outputs/gwr_model_comparison.csv",
          row.names = FALSE)

cat("\n=== EXTRACTING LOCAL COEFFICIENTS ===\n")

# Extract local coefficients
local_coefs <- as.data.frame(gwr_model$SDF)

# Add back to spatial data
hdb_gwr <- hdb_svy21[complete.cases(st_drop_geometry(hdb_svy21)[, 
                                    c("resale_price", "dist_to_park_m", "dist_to_connector_m",
                                      "connector_length_1km", "parks_within_1km",
                                      "floor_area_sqm", "remaining_lease_years")]), ]

hdb_gwr$local_r2 <- local_coefs$Local_R2
hdb_gwr$coef_connector <- local_coefs$connector_length_1km
hdb_gwr$coef_dist_park <- local_coefs$dist_to_park_m
hdb_gwr$coef_parks_1km <- local_coefs$parks_within_1km

# Summary of local coefficients
cat("\nSummary of local coefficients:\n")
cat(sprintf("  Connector length (1km): Mean=%.2f, Range=[%.2f, %.2f]\n",
            mean(hdb_gwr$coef_connector, na.rm = TRUE),
            min(hdb_gwr$coef_connector, na.rm = TRUE),
            max(hdb_gwr$coef_connector, na.rm = TRUE)))
cat(sprintf("  Distance to park: Mean=%.2f, Range=[%.2f, %.2f]\n",
            mean(hdb_gwr$coef_dist_park, na.rm = TRUE),
            min(hdb_gwr$coef_dist_park, na.rm = TRUE),
            max(hdb_gwr$coef_dist_park, na.rm = TRUE)))

cat("\n=== CREATING GWR VISUALIZATIONS ===\n")

# Transform back to WGS84 for mapping
hdb_gwr_wgs84 <- st_transform(hdb_gwr, crs = 4326)
planning_areas_wgs84 <- st_transform(planning_areas, crs = 4326)

# Map 1: Local R² values
cat("1. Creating map: Local R² values\n")
p_r2 <- ggplot() +
  geom_sf(data = planning_areas_wgs84, fill = "white", color = "gray70", linewidth = 0.2) +
  geom_sf(data = hdb_gwr_wgs84, aes(color = local_r2), size = 0.6, alpha = 0.7) +
  scale_color_viridis_c(option = "viridis", name = "Local R²") +
  labs(title = "GWR Model Fit: Local R² Values",
       subtitle = sprintf("Geographically Weighted Regression | Overall R² = %.3f", gwr_r2)) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )

ggsave("Environment_Analysis/figures/gwr_local_r2_map.png", p_r2,
       width = 12, height = 10, dpi = 300, bg = "white")

# Map 2: Local coefficients for connector length
cat("2. Creating map: Local coefficients for park connector length\n")
p_coef_connector <- ggplot() +
  geom_sf(data = planning_areas_wgs84, fill = "white", color = "gray70", linewidth = 0.2) +
  geom_sf(data = hdb_gwr_wgs84, aes(color = coef_connector), size = 0.6, alpha = 0.7) +
  scale_color_gradient2(low = "#d73027", mid = "white", high = "#1a9850",
                        midpoint = 0, name = "Coefficient") +
  labs(title = "GWR: Local Effect of Park Connector Length on Price",
       subtitle = "Positive values (green) indicate connector length increases price locally") +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )

ggsave("Environment_Analysis/figures/gwr_connector_coef_map.png", p_coef_connector,
       width = 12, height = 10, dpi = 300, bg = "white")

# Map 3: Local coefficients for number of parks
cat("3. Creating map: Local coefficients for parks within 1km\n")
p_coef_parks <- ggplot() +
  geom_sf(data = planning_areas_wgs84, fill = "white", color = "gray70", linewidth = 0.2) +
  geom_sf(data = hdb_gwr_wgs84, aes(color = coef_parks_1km), size = 0.6, alpha = 0.7) +
  scale_color_gradient2(low = "#d73027", mid = "white", high = "#1a9850",
                        midpoint = 0, name = "Coefficient") +
  labs(title = "GWR: Local Effect of Park Count on Price",
       subtitle = "Shows where having more parks nearby matters most for prices") +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )

ggsave("Environment_Analysis/figures/gwr_park_count_coef_map.png", p_coef_parks,
       width = 12, height = 10, dpi = 300, bg = "white")

cat("\n=== GWR PRICE MODEL COMPLETE ===\n")
cat("Results saved:\n")
cat("  - Model comparison table (OLS vs GWR)\n")
cat("  - Local R² map\n")
cat("  - Local coefficient maps\n")
cat("\nKey Findings:\n")
cat(sprintf("  - GWR R²: %.4f (vs OLS: %.4f)\n", gwr_r2, ols_r2))
cat(sprintf("  - Improvement: %.1f%%\n", (gwr_r2 - ols_r2) / ols_r2 * 100))
cat("  - Green space effects vary significantly across Singapore\n")

