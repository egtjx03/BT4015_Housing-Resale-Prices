# ==============================================================================
# HDB SPATIAL ANALYSIS - MORAN'S I SPATIAL AUTOCORRELATION
# Project: BT4015 Housing Resale Prices
# Purpose: Test spatial autocorrelation for resale prices and transaction density
# ==============================================================================

# Load required libraries
library(sf)
library(dplyr)
library(spdep)
library(ggplot2)
library(viridis)
library(scales)

# Set working directory
setwd("/Users/zr/Code/Projects/BT4015_Housing-Resale-Prices")

# Create output directories
dir.create("HDB/outputs", showWarnings = FALSE, recursive = TRUE)
dir.create("HDB/figures", showWarnings = FALSE, recursive = TRUE)

cat("=== MORAN'S I SPATIAL AUTOCORRELATION ANALYSIS ===\n")
cat("Purpose: Test if similar values cluster together spatially\n\n")

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

# Transform to SVY21 (EPSG:3414) for accurate calculations
hdb_svy21 <- st_transform(hdb_filtered, crs = 3414)

# Load planning areas for mapping
sf_use_s2(FALSE)
planning_areas <- st_read("Datasets/MasterPlan2019PlanningAreaBoundaryNoSea.geojson", quiet = TRUE)
planning_areas <- st_make_valid(planning_areas)
planning_areas <- st_transform(planning_areas, crs = 3414)

# ==============================================================================
# STEP 2: CREATE SPATIAL WEIGHTS MATRIX
# ==============================================================================

cat("\nSTEP 2: Creating spatial weights matrix...\n")

# Extract coordinates
coords <- st_coordinates(hdb_svy21)

# Create k-nearest neighbors weights (k=8)
k <- 8
knn_nb <- knn2nb(knearneigh(coords, k = k))
knn_weights <- nb2listw(knn_nb, style = "W")

cat(sprintf("  Created %d-nearest neighbors weights matrix\n", k))
cat(sprintf("  Total spatial links: %d\n", sum(card(knn_nb))))

# ==============================================================================
# STEP 3: MORAN'S I FOR RESALE PRICES
# ==============================================================================

cat("\n=== TEST 1: MORAN'S I FOR RESALE PRICES ===\n")

cat("Testing if similar resale prices cluster together...\n")

# Global Moran's I test for resale prices
moran_price <- moran.test(hdb_svy21$resale_price, knn_weights)

cat(sprintf("\nResults:\n"))
cat(sprintf("  Moran's I statistic: %.4f\n", moran_price$estimate["Moran I statistic"]))
cat(sprintf("  Expected value: %.4f\n", moran_price$estimate["Expectation"]))
cat(sprintf("  Variance: %.6f\n", moran_price$estimate["Variance"]))
cat(sprintf("  Z-score: %.4f\n", moran_price$statistic))
cat(sprintf("  P-value: %.6f\n", moran_price$p.value))

# Interpretation
if (moran_price$estimate["Moran I statistic"] > 0) {
  price_pattern <- "Positive spatial autocorrelation (similar prices cluster together)"
} else {
  price_pattern <- "Negative spatial autocorrelation (dissimilar prices cluster together)"
}

price_significance <- ifelse(moran_price$p.value < 0.05, "SIGNIFICANT", "NOT significant")

cat(sprintf("  Interpretation: %s\n", price_pattern))
cat(sprintf("  Statistical significance: %s at α=0.05\n", price_significance))

# Calculate Local Moran's I (LISA)
cat("\nCalculating Local Indicators of Spatial Association (LISA)...\n")

local_moran_price <- localmoran(hdb_svy21$resale_price, knn_weights)

# Add LISA results to data
hdb_svy21$local_morans_i_price <- local_moran_price[, "Ii"]
hdb_svy21$local_morans_p_price <- local_moran_price[, "Pr(z != E(Ii))"]
hdb_svy21$local_morans_sig_price <- hdb_svy21$local_morans_p_price < 0.05

cat(sprintf("  %d locations show significant local autocorrelation (p < 0.05)\n",
            sum(hdb_svy21$local_morans_sig_price)))

# Identify LISA clusters
# Standardize prices
hdb_svy21$price_std <- scale(hdb_svy21$resale_price)[, 1]

# Calculate spatial lag
hdb_svy21$price_lag <- lag.listw(knn_weights, hdb_svy21$price_std)

# Classify into quadrants
hdb_svy21$lisa_cluster_price <- "Not Significant"

# High-High: High prices surrounded by high prices (hot spots)
hdb_svy21$lisa_cluster_price[hdb_svy21$price_std > 0 & 
                              hdb_svy21$price_lag > 0 & 
                              hdb_svy21$local_morans_sig_price] <- "High-High"

# Low-Low: Low prices surrounded by low prices (cold spots)
hdb_svy21$lisa_cluster_price[hdb_svy21$price_std < 0 & 
                              hdb_svy21$price_lag < 0 & 
                              hdb_svy21$local_morans_sig_price] <- "Low-Low"

# High-Low: High price surrounded by low prices (outlier)
hdb_svy21$lisa_cluster_price[hdb_svy21$price_std > 0 & 
                              hdb_svy21$price_lag < 0 & 
                              hdb_svy21$local_morans_sig_price] <- "High-Low"

# Low-High: Low price surrounded by high prices (outlier)
hdb_svy21$lisa_cluster_price[hdb_svy21$price_std < 0 & 
                              hdb_svy21$price_lag > 0 & 
                              hdb_svy21$local_morans_sig_price] <- "Low-High"

# Summary of LISA clusters
cat("\nLISA Cluster Distribution (Resale Prices):\n")
cluster_summary_price <- table(hdb_svy21$lisa_cluster_price)
print(cluster_summary_price)

# Save results
price_results <- data.frame(
  Test = "Global Moran's I (Resale Price)",
  Variable = "Resale Price",
  Morans_I = moran_price$estimate["Moran I statistic"],
  Expected_I = moran_price$estimate["Expectation"],
  Variance = moran_price$estimate["Variance"],
  Z_Score = moran_price$statistic,
  P_Value = moran_price$p.value,
  Significance = price_significance,
  Interpretation = price_pattern,
  N_Significant_Local = sum(hdb_svy21$local_morans_sig_price),
  N_High_High = sum(hdb_svy21$lisa_cluster_price == "High-High"),
  N_Low_Low = sum(hdb_svy21$lisa_cluster_price == "Low-Low"),
  N_High_Low = sum(hdb_svy21$lisa_cluster_price == "High-Low"),
  N_Low_High = sum(hdb_svy21$lisa_cluster_price == "Low-High")
)

write.csv(price_results, "HDB/outputs/morans_i_resale_price.csv", row.names = FALSE)

# ==============================================================================
# STEP 4: MORAN'S I FOR TRANSACTION DENSITY
# ==============================================================================

cat("\n=== TEST 2: MORAN'S I FOR TRANSACTION DENSITY ===\n")

cat("Calculating transaction density using hexagonal grid...\n")

# Create hexagonal grid over study area
grid_size <- 500  # 500m hexagons
hex_grid <- st_make_grid(hdb_svy21, cellsize = grid_size, square = FALSE)
hex_grid <- st_sf(geometry = hex_grid)
hex_grid$cell_id <- 1:nrow(hex_grid)

# Count transactions in each hex cell
hex_grid$transaction_count <- lengths(st_intersects(hex_grid, hdb_svy21))

# Filter to cells with at least one transaction
hex_grid_filtered <- hex_grid %>%
  filter(transaction_count > 0)

cat(sprintf("  Created %d hexagonal cells (size: %dm)\n", nrow(hex_grid_filtered), grid_size))
cat(sprintf("  Transaction counts range: %d to %d\n", 
            min(hex_grid_filtered$transaction_count),
            max(hex_grid_filtered$transaction_count)))

# Calculate density (transactions per sq km)
hex_grid_filtered$area_sqkm <- as.numeric(st_area(hex_grid_filtered)) / 1e6
hex_grid_filtered$density <- hex_grid_filtered$transaction_count / hex_grid_filtered$area_sqkm

cat(sprintf("  Density range: %.1f to %.1f transactions/sq.km\n",
            min(hex_grid_filtered$density),
            max(hex_grid_filtered$density)))

# Create spatial weights for grid cells
cat("\nCreating spatial weights for grid cells...\n")

# Get centroids
hex_centroids <- st_centroid(hex_grid_filtered)
hex_coords <- st_coordinates(hex_centroids)

# Create contiguity-based neighbors (queen)
hex_nb <- poly2nb(hex_grid_filtered, queen = TRUE)
hex_weights <- nb2listw(hex_nb, style = "W", zero.policy = TRUE)

cat(sprintf("  Average neighbors per cell: %.1f\n", mean(card(hex_nb))))

# Global Moran's I test for density
moran_density <- moran.test(hex_grid_filtered$density, hex_weights, zero.policy = TRUE)

cat(sprintf("\nResults:\n"))
cat(sprintf("  Moran's I statistic: %.4f\n", moran_density$estimate["Moran I statistic"]))
cat(sprintf("  Expected value: %.4f\n", moran_density$estimate["Expectation"]))
cat(sprintf("  Variance: %.6f\n", moran_density$estimate["Variance"]))
cat(sprintf("  Z-score: %.4f\n", moran_density$statistic))
cat(sprintf("  P-value: %.6f\n", moran_density$p.value))

# Interpretation
if (moran_density$estimate["Moran I statistic"] > 0) {
  density_pattern <- "Positive spatial autocorrelation (high-density areas cluster together)"
} else {
  density_pattern <- "Negative spatial autocorrelation (high/low density areas are dispersed)"
}

density_significance <- ifelse(moran_density$p.value < 0.05, "SIGNIFICANT", "NOT significant")

cat(sprintf("  Interpretation: %s\n", density_pattern))
cat(sprintf("  Statistical significance: %s at α=0.05\n", density_significance))

# Calculate Local Moran's I for density
cat("\nCalculating LISA for transaction density...\n")

local_moran_density <- localmoran(hex_grid_filtered$density, hex_weights, zero.policy = TRUE)

# Add LISA results
hex_grid_filtered$local_morans_i_density <- local_moran_density[, "Ii"]
hex_grid_filtered$local_morans_p_density <- local_moran_density[, "Pr(z != E(Ii))"]
hex_grid_filtered$local_morans_sig_density <- hex_grid_filtered$local_morans_p_density < 0.05

cat(sprintf("  %d cells show significant local autocorrelation (p < 0.05)\n",
            sum(hex_grid_filtered$local_morans_sig_density)))

# Identify LISA clusters for density
hex_grid_filtered$density_std <- scale(hex_grid_filtered$density)[, 1]
hex_grid_filtered$density_lag <- lag.listw(hex_weights, hex_grid_filtered$density_std, zero.policy = TRUE)

hex_grid_filtered$lisa_cluster_density <- "Not Significant"

hex_grid_filtered$lisa_cluster_density[hex_grid_filtered$density_std > 0 & 
                                        hex_grid_filtered$density_lag > 0 & 
                                        hex_grid_filtered$local_morans_sig_density] <- "High-High"

hex_grid_filtered$lisa_cluster_density[hex_grid_filtered$density_std < 0 & 
                                        hex_grid_filtered$density_lag < 0 & 
                                        hex_grid_filtered$local_morans_sig_density] <- "Low-Low"

hex_grid_filtered$lisa_cluster_density[hex_grid_filtered$density_std > 0 & 
                                        hex_grid_filtered$density_lag < 0 & 
                                        hex_grid_filtered$local_morans_sig_density] <- "High-Low"

hex_grid_filtered$lisa_cluster_density[hex_grid_filtered$density_std < 0 & 
                                        hex_grid_filtered$density_lag > 0 & 
                                        hex_grid_filtered$local_morans_sig_density] <- "Low-High"

cat("\nLISA Cluster Distribution (Transaction Density):\n")
cluster_summary_density <- table(hex_grid_filtered$lisa_cluster_density)
print(cluster_summary_density)

# Save results
density_results <- data.frame(
  Test = "Global Moran's I (Transaction Density)",
  Variable = "Transaction Density",
  Morans_I = moran_density$estimate["Moran I statistic"],
  Expected_I = moran_density$estimate["Expectation"],
  Variance = moran_density$estimate["Variance"],
  Z_Score = moran_density$statistic,
  P_Value = moran_density$p.value,
  Significance = density_significance,
  Interpretation = density_pattern,
  N_Significant_Local = sum(hex_grid_filtered$local_morans_sig_density),
  N_High_High = sum(hex_grid_filtered$lisa_cluster_density == "High-High"),
  N_Low_Low = sum(hex_grid_filtered$lisa_cluster_density == "Low-Low"),
  N_High_Low = sum(hex_grid_filtered$lisa_cluster_density == "High-Low"),
  N_Low_High = sum(hex_grid_filtered$lisa_cluster_density == "Low-High")
)

write.csv(density_results, "HDB/outputs/morans_i_density.csv", row.names = FALSE)

# ==============================================================================
# STEP 5: VISUALIZATIONS
# ==============================================================================

cat("\n=== Creating visualizations ===\n")

# Transform to WGS84 for mapping
hdb_wgs84 <- st_transform(hdb_svy21, crs = 4326)
planning_areas_wgs84 <- st_transform(planning_areas, crs = 4326)
hex_grid_wgs84 <- st_transform(hex_grid_filtered, crs = 4326)

# Map 1: LISA clusters for resale prices
cat("1. Creating LISA map for resale prices...\n")

p_lisa_price <- ggplot() +
  geom_sf(data = planning_areas_wgs84, fill = "white", color = "gray70", linewidth = 0.2) +
  geom_sf(data = filter(hdb_wgs84, lisa_cluster_price != "Not Significant"),
          aes(color = lisa_cluster_price), size = 1.5, alpha = 0.7) +
  scale_color_manual(
    values = c("High-High" = "#d73027",
               "Low-Low" = "#4575b4",
               "High-Low" = "#fc8d59",
               "Low-High" = "#91bfdb"),
    name = "LISA Cluster",
    breaks = c("High-High", "Low-Low", "High-Low", "Low-High")
  ) +
  labs(
    title = "Local Spatial Autocorrelation - HDB Resale Prices",
    subtitle = sprintf("4-Room HDB 2024 | Moran's I: %.4f (p=%.4f) | %d significant clusters",
                      moran_price$estimate["Moran I statistic"], 
                      moran_price$p.value,
                      sum(hdb_wgs84$lisa_cluster_price != "Not Significant")),
    caption = "High-High = Price hot spots | Low-Low = Price cold spots"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 10),
    legend.position = "right",
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )

ggsave("HDB/figures/morans_i_price_lisa_map.png", p_lisa_price,
       width = 12, height = 10, dpi = 300, bg = "white")

cat("  Saved: morans_i_price_lisa_map.png\n")

# Map 2: LISA clusters for transaction density
cat("2. Creating LISA map for transaction density...\n")

p_lisa_density <- ggplot() +
  geom_sf(data = planning_areas_wgs84, fill = "white", color = "gray70", linewidth = 0.2) +
  geom_sf(data = filter(hex_grid_wgs84, lisa_cluster_density != "Not Significant"),
          aes(fill = lisa_cluster_density), color = NA, alpha = 0.7) +
  scale_fill_manual(
    values = c("High-High" = "#d73027",
               "Low-Low" = "#4575b4",
               "High-Low" = "#fc8d59",
               "Low-High" = "#91bfdb"),
    name = "LISA Cluster",
    breaks = c("High-High", "Low-Low", "High-Low", "Low-High")
  ) +
  labs(
    title = "Local Spatial Autocorrelation - Transaction Density",
    subtitle = sprintf("4-Room HDB 2024 | Moran's I: %.4f (p=%.4f) | %d significant clusters",
                      moran_density$estimate["Moran I statistic"], 
                      moran_density$p.value,
                      sum(hex_grid_wgs84$lisa_cluster_density != "Not Significant")),
    caption = "High-High = High-density clusters | Low-Low = Low-density clusters"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 10),
    legend.position = "right",
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )

ggsave("HDB/figures/morans_i_density_lisa_map.png", p_lisa_density,
       width = 12, height = 10, dpi = 300, bg = "white")

cat("  Saved: morans_i_density_lisa_map.png\n")

# ==============================================================================
# SUMMARY
# ==============================================================================

cat("\n=== ANALYSIS COMPLETE ===\n")
cat("Results saved to:\n")
cat("  - HDB/outputs/morans_i_resale_price.csv\n")
cat("  - HDB/outputs/morans_i_density.csv\n")
cat("  - HDB/figures/morans_i_price_lisa_map.png\n")
cat("  - HDB/figures/morans_i_density_lisa_map.png\n")
cat("\nKey Findings:\n")
cat(sprintf("  Resale Prices: Moran's I = %.4f (%s)\n", 
            moran_price$estimate["Moran I statistic"], price_significance))
cat(sprintf("    - %d High-High clusters (hot spots)\n", 
            sum(hdb_svy21$lisa_cluster_price == "High-High")))
cat(sprintf("    - %d Low-Low clusters (cold spots)\n", 
            sum(hdb_svy21$lisa_cluster_price == "Low-Low")))
cat(sprintf("\n  Transaction Density: Moran's I = %.4f (%s)\n", 
            moran_density$estimate["Moran I statistic"], density_significance))
cat(sprintf("    - %d High-density clusters\n", 
            sum(hex_grid_filtered$lisa_cluster_density == "High-High")))
cat(sprintf("    - %d Low-density clusters\n", 
            sum(hex_grid_filtered$lisa_cluster_density == "Low-Low")))

