# ==============================================================================
# ENVIRONMENT: SPATIAL ANALYSIS - SPATIAL AUTOCORRELATION
# Project: BT4015 Housing Resale Prices
# Purpose: Moran's I and LISA analysis
# ==============================================================================

library(sf)
library(dplyr)
library(spdep)
library(ggplot2)
library(scales)

setwd("/Users/zr/Code/Projects/BT4015_Housing-Resale-Prices")

cat("=== Loading Data ===\n")
hdb <- readRDS("Environment_Analysis/data/hdb_4room_with_metrics.rds")

# Load planning areas
sf_use_s2(FALSE)
planning_areas <- st_read("Datasets/MasterPlan2019PlanningAreaBoundaryNoSea.geojson", quiet = TRUE)
planning_areas <- st_make_valid(planning_areas)
planning_areas <- st_transform(planning_areas, crs = 3414)  # SVY21

# Transform to SVY21
hdb_svy21 <- st_transform(hdb, crs = 3414)

cat(sprintf("Loaded: %d transactions\n", nrow(hdb)))

# ====================================================================
# 6.3 SPATIAL AUTOCORRELATION - MORAN'S I
# ====================================================================

cat("\n=== GLOBAL MORAN'S I ANALYSIS ===\n")

cat("\n1. Creating Spatial Weights Matrix (k-nearest neighbors)...\n")

# Create k-nearest neighbors weights (k=8)
coords <- st_coordinates(hdb_svy21)
k <- 8
knn_nb <- knn2nb(knearneigh(coords, k = k))
knn_weights <- nb2listw(knn_nb, style = "W")

cat(sprintf("  Created %d-nearest neighbors weights matrix\n", k))

cat("\n2. Testing Global Moran's I for Resale Prices...\n")

# Global Moran's I test
moran_test <- moran.test(hdb$resale_price, knn_weights)

cat(sprintf("  Moran's I statistic: %.4f\n", moran_test$estimate["Moran I statistic"]))
cat(sprintf("  Expected value: %.4f\n", moran_test$estimate["Expectation"]))
cat(sprintf("  Variance: %.6f\n", moran_test$estimate["Variance"]))
cat(sprintf("  Z-score: %.3f\n", moran_test$statistic))
cat(sprintf("  P-value: %.6f\n", moran_test$p.value))

interpretation <- ifelse(moran_test$estimate["Moran I statistic"] > 0,
                        "Positive spatial autocorrelation (similar prices cluster together)",
                        "Negative spatial autocorrelation (dissimilar prices cluster together)")
significance <- ifelse(moran_test$p.value < 0.05, "SIGNIFICANT", "NOT significant")

cat(sprintf("  Interpretation: %s\n", interpretation))
cat(sprintf("  Statistical significance: %s at α=0.05\n", significance))

# Save Moran's I results
morans_i_results <- data.frame(
  Test = "Global Moran's I (Resale Price)",
  Morans_I = moran_test$estimate["Moran I statistic"],
  Expected_I = moran_test$estimate["Expectation"],
  Variance = moran_test$estimate["Variance"],
  Z_Score = moran_test$statistic,
  P_Value = moran_test$p.value,
  Significance = significance,
  Interpretation = interpretation
)

write.csv(morans_i_results, 
          "Environment_Analysis/outputs/morans_i_results.csv",
          row.names = FALSE)

# ====================================================================
# LISA - LOCAL INDICATORS OF SPATIAL ASSOCIATION
# ====================================================================

cat("\n=== LOCAL INDICATORS OF SPATIAL ASSOCIATION (LISA) ===\n")

cat("\n1. Calculating Local Moran's I...\n")

# Local Moran's I
local_moran <- localmoran(hdb$resale_price, knn_weights)

# Add local Moran's I to data
hdb$local_morans_i <- local_moran[, "Ii"]
hdb$local_morans_p <- local_moran[, "Pr(z != E(Ii))"]
hdb$local_morans_sig <- hdb$local_morans_p < 0.05

cat(sprintf("  %d locations show significant local spatial autocorrelation (p < 0.05)\n",
            sum(hdb$local_morans_sig)))

cat("\n2. Identifying LISA Clusters...\n")

# Standardize prices for cluster identification
hdb$price_std <- scale(hdb$resale_price)[, 1]

# Calculate spatial lag (mean of neighbors' prices)
hdb$price_lag <- lag.listw(knn_weights, hdb$price_std)

# Classify into quadrants
hdb$lisa_cluster <- "Not Significant"

# High-High: High values surrounded by high values
hdb$lisa_cluster[hdb$price_std > 0 & hdb$price_lag > 0 & hdb$local_morans_sig] <- "High-High"

# Low-Low: Low values surrounded by low values
hdb$lisa_cluster[hdb$price_std < 0 & hdb$price_lag < 0 & hdb$local_morans_sig] <- "Low-Low"

# High-Low: High value surrounded by low values (outlier)
hdb$lisa_cluster[hdb$price_std > 0 & hdb$price_lag < 0 & hdb$local_morans_sig] <- "High-Low"

# Low-High: Low value surrounded by high values (outlier)
hdb$lisa_cluster[hdb$price_std < 0 & hdb$price_lag > 0 & hdb$local_morans_sig] <- "Low-High"

# Summary of clusters
cluster_summary <- table(hdb$lisa_cluster)
cat("\nLISA Cluster Distribution:\n")
print(cluster_summary)

# Calculate mean green space metrics by cluster type
lisa_green_analysis <- hdb %>%
  st_drop_geometry() %>%
  group_by(lisa_cluster) %>%
  summarise(
    Count = n(),
    Mean_Price = mean(resale_price, na.rm = TRUE),
    Mean_Dist_Park = mean(dist_to_park_m, na.rm = TRUE),
    Mean_Parks_1km = mean(parks_within_1km, na.rm = TRUE),
    Mean_Connector_Length_1km = mean(connector_length_1km, na.rm = TRUE),
    .groups = 'drop'
  ) %>%
  arrange(desc(Mean_Price))

cat("\nGreen space metrics by LISA cluster:\n")
print(lisa_green_analysis)

write.csv(lisa_green_analysis,
          "Environment_Analysis/outputs/lisa_green_space_analysis.csv",
          row.names = FALSE)

cat("\n3. Creating LISA Cluster Map...\n")

# Create LISA cluster map
hdb_wgs84 <- st_transform(hdb, crs = 4326)
planning_areas_wgs84 <- st_transform(planning_areas, crs = 4326)

p_lisa <- ggplot() +
  # Base layer
  geom_sf(data = planning_areas_wgs84, fill = "white", color = "gray70", linewidth = 0.2) +
  
  # LISA clusters
  geom_sf(data = filter(hdb_wgs84, lisa_cluster != "Not Significant"),
          aes(color = lisa_cluster), size = 1.2, alpha = 0.7) +
  
  scale_color_manual(
    values = c("High-High" = "#d73027",
               "High-Low" = "#fc8d59",
               "Low-High" = "#91bfdb",
               "Low-Low" = "#4575b4"),
    name = "LISA Cluster\nType",
    breaks = c("High-High", "Low-Low", "High-Low", "Low-High")
  ) +
  
  labs(title = "Local Spatial Autocorrelation Clusters (LISA)",
       subtitle = sprintf("4-Room HDB Prices, 2024 | %d significant clusters (p<0.05) | Based on %d-nearest neighbors",
                         sum(hdb$lisa_cluster != "Not Significant"), k)) +
  
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 10),
    legend.position = "right",
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )

ggsave("Environment_Analysis/figures/lisa_clusters_map.png", p_lisa,
       width = 12, height = 10, dpi = 300, bg = "white")

cat("\n=== SPATIAL AUTOCORRELATION ANALYSIS COMPLETE ===\n")
cat("Results saved:\n")
cat("  - Global Moran's I statistics\n")
cat("  - LISA cluster analysis\n")
cat("  - LISA cluster map\n")
cat("\nKey Findings:\n")
cat(sprintf("  - Moran's I: %.4f (%s)\n", 
            moran_test$estimate["Moran I statistic"], significance))
cat(sprintf("  - Significant clusters: %d locations\n", 
            sum(hdb$lisa_cluster != "Not Significant")))
cat(sprintf("  - High-High clusters: %d (price hot spots)\n", 
            sum(hdb$lisa_cluster == "High-High")))
cat(sprintf("  - Low-Low clusters: %d (price cold spots)\n", 
            sum(hdb$lisa_cluster == "Low-Low")))

