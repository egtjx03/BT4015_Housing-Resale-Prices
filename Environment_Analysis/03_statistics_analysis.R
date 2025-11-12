# ==============================================================================
# ENVIRONMENT: GREEN DIVIDEND ANALYSIS - DESCRIPTIVE STATISTICS
# Project: BT4015 Housing Resale Prices
# Purpose: Generate descriptive statistics and correlation analysis
# ==============================================================================

library(sf)
library(dplyr)
library(tidyr)

setwd("/Users/zr/Code/Projects/BT4015_Housing-Resale-Prices")

cat("=== Loading Data with Metrics ===\n")
hdb <- readRDS("Environment_Analysis/data/hdb_4room_with_metrics.rds")

cat(sprintf("Loaded %d 4-ROOM transactions with green space metrics\n", nrow(hdb)))

cat("\n=== DESCRIPTIVE STATISTICS ===\n")

# Summary statistics for green space metrics
green_metrics <- c("dist_to_park_m", "dist_to_connector_m", 
                   "parks_within_500m", "parks_within_1km",
                   "connector_length_500m", "connector_length_1km")

# Create summary table
summary_stats <- data.frame(
  Metric = c("Distance to Nearest Park (m)", 
             "Distance to Nearest Connector (m)",
             "Parks within 500m",
             "Parks within 1km",
             "Connector Length within 500m (m)",
             "Connector Length within 1km (m)"),
  Mean = sapply(green_metrics, function(x) mean(hdb[[x]], na.rm = TRUE)),
  Median = sapply(green_metrics, function(x) median(hdb[[x]], na.rm = TRUE)),
  SD = sapply(green_metrics, function(x) sd(hdb[[x]], na.rm = TRUE)),
  Min = sapply(green_metrics, function(x) min(hdb[[x]], na.rm = TRUE)),
  Max = sapply(green_metrics, function(x) max(hdb[[x]], na.rm = TRUE))
)

print(summary_stats)

# Save summary statistics
write.csv(summary_stats, "Environment_Analysis/outputs/green_metrics_summary.csv", 
          row.names = FALSE)

cat("\n=== PRICE ANALYSIS BY GREEN SPACE PROXIMITY ===\n")

# Create proximity categories for distance to park
hdb$park_proximity <- cut(hdb$dist_to_park_m,
                           breaks = c(0, 300, 600, 1000, Inf),
                           labels = c("<300m", "300-600m", "600-1000m", ">1000m"))

# Price statistics by proximity category
price_by_proximity <- hdb %>%
  st_drop_geometry() %>%
  group_by(park_proximity) %>%
  summarise(
    Count = n(),
    Mean_Price = mean(resale_price, na.rm = TRUE),
    Median_Price = median(resale_price, na.rm = TRUE),
    SD_Price = sd(resale_price, na.rm = TRUE),
    .groups = 'drop'
  )

cat("\nPrice statistics by distance to nearest park:\n")
print(price_by_proximity)

write.csv(price_by_proximity, 
          "Environment_Analysis/outputs/price_by_park_proximity.csv", 
          row.names = FALSE)

# Create categories for park count
hdb$park_count_cat <- cut(hdb$parks_within_1km,
                           breaks = c(-Inf, 0, 1, 2, Inf),
                           labels = c("None", "1 park", "2 parks", "3+ parks"))

# Price statistics by park count
price_by_count <- hdb %>%
  st_drop_geometry() %>%
  group_by(park_count_cat) %>%
  summarise(
    Count = n(),
    Mean_Price = mean(resale_price, na.rm = TRUE),
    Median_Price = median(resale_price, na.rm = TRUE),
    SD_Price = sd(resale_price, na.rm = TRUE),
    .groups = 'drop'
  )

cat("\nPrice statistics by parks within 1km:\n")
print(price_by_count)

write.csv(price_by_count, 
          "Environment_Analysis/outputs/price_by_park_count.csv", 
          row.names = FALSE)

cat("\n=== CORRELATION ANALYSIS ===\n")

# Select numeric columns for correlation
hdb_numeric <- hdb %>%
  st_drop_geometry() %>%
  select(resale_price, all_of(green_metrics))

# Calculate correlation matrix
cor_matrix <- cor(hdb_numeric, use = "complete.obs")

cat("\nCorrelation with resale price:\n")
print(cor_matrix[, "resale_price"])

# Save correlation matrix
write.csv(cor_matrix, "Environment_Analysis/outputs/correlation_matrix.csv")

# Detailed correlation output
cor_with_price <- data.frame(
  Metric = names(cor_matrix[, "resale_price"])[-1],
  Correlation = cor_matrix[-1, "resale_price"]
)

cat("\nDetailed correlations:\n")
print(cor_with_price)

write.csv(cor_with_price, 
          "Environment_Analysis/outputs/price_correlations.csv", 
          row.names = FALSE)

cat("\n=== STATISTICS BY TOWN ===\n")

# Calculate mean metrics by town
town_summary <- hdb %>%
  st_drop_geometry() %>%
  group_by(town) %>%
  summarise(
    Count = n(),
    Mean_Price = mean(resale_price, na.rm = TRUE),
    Mean_Dist_Park = mean(dist_to_park_m, na.rm = TRUE),
    Mean_Dist_Connector = mean(dist_to_connector_m, na.rm = TRUE),
    Mean_Parks_1km = mean(parks_within_1km, na.rm = TRUE),
    Mean_Connector_Length_1km = mean(connector_length_1km, na.rm = TRUE),
    .groups = 'drop'
  ) %>%
  arrange(desc(Mean_Price))

cat("\nTop 10 towns by average resale price:\n")
print(head(town_summary, 10))

write.csv(town_summary, "Environment_Analysis/outputs/town_summary.csv", 
          row.names = FALSE)

cat("\n=== ANALYSIS COMPLETE ===\n")
cat("All statistics saved to Environment_Analysis/outputs/\n")

