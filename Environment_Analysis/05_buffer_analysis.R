# ==============================================================================
# ENVIRONMENT: SPATIAL ANALYSIS - BUFFER ANALYSIS FOR AMENITIES
# Project: BT4015 Housing Resale Prices
# Purpose: Create and analyze buffer zones around parks
# ==============================================================================

library(sf)
library(dplyr)
library(ggplot2)
library(scales)
library(viridis)

setwd("/Users/zr/Code/Projects/BT4015_Housing-Resale-Prices")

cat("=== Loading Data ===\n")
hdb <- readRDS("Environment_Analysis/data/hdb_4room_with_metrics.rds")
parks <- readRDS("Environment_Analysis/data/parks.rds")

# Load planning areas
sf_use_s2(FALSE)
planning_areas <- st_read("Datasets/MasterPlan2019PlanningAreaBoundaryNoSea.geojson", quiet = TRUE)
planning_areas <- st_make_valid(planning_areas)
planning_areas <- st_transform(planning_areas, crs = st_crs(hdb))

cat(sprintf("Loaded: %d transactions, %d parks, %d planning areas\n",
            nrow(hdb), nrow(parks), nrow(planning_areas)))

cat("\n=== Creating Buffer Zones ===\n")

# Convert to Singapore projected CRS (SVY21 - EPSG:3414) for accurate meter-based buffers
parks_svy21 <- st_transform(parks, crs = 3414)
hdb_svy21 <- st_transform(hdb, crs = 3414)

# Create multiple buffer zones around parks (250m, 500m, 1km) in SVY21
park_buffer_250m <- st_buffer(parks_svy21, dist = 250)
park_buffer_500m <- st_buffer(parks_svy21, dist = 500)
park_buffer_1km <- st_buffer(parks_svy21, dist = 1000)

# Transform back to WGS84 for visualization
park_buffer_250m <- st_transform(park_buffer_250m, crs = 4326)
park_buffer_500m <- st_transform(park_buffer_500m, crs = 4326)
park_buffer_1km <- st_transform(park_buffer_1km, crs = 4326)

# Union overlapping buffers
park_buffer_250m_union <- st_union(park_buffer_250m)
park_buffer_500m_union <- st_union(park_buffer_500m)
park_buffer_1km_union <- st_union(park_buffer_1km)

cat("Created buffer zones: 250m, 500m, 1km\n")

cat("\n=== Classifying Transactions by Buffer Zone ===\n")

# Determine which buffer zone each transaction falls in (using SVY21 for accuracy)
hdb_svy21$buffer_zone <- "Beyond 1km"

# Check intersection with each buffer (from smallest to largest) - in SVY21
in_1km <- lengths(st_intersects(hdb_svy21, st_transform(park_buffer_1km_union, 3414))) > 0
in_500m <- lengths(st_intersects(hdb_svy21, st_transform(park_buffer_500m_union, 3414))) > 0
in_250m <- lengths(st_intersects(hdb_svy21, st_transform(park_buffer_250m_union, 3414))) > 0

hdb_svy21$buffer_zone[in_1km] <- "500m-1km"
hdb_svy21$buffer_zone[in_500m] <- "250m-500m"
hdb_svy21$buffer_zone[in_250m] <- "0-250m"

# Convert to factor with proper order
hdb_svy21$buffer_zone <- factor(hdb_svy21$buffer_zone, 
                                levels = c("0-250m", "250m-500m", "500m-1km", "Beyond 1km"))

# Copy buffer_zone back to main hdb dataset
hdb$buffer_zone <- hdb_svy21$buffer_zone

cat("\nTransactions by buffer zone:\n")
print(table(hdb$buffer_zone))

cat("\n=== Price Analysis by Buffer Zone ===\n")

# Calculate statistics by buffer zone
buffer_stats <- hdb %>%
  st_drop_geometry() %>%
  group_by(buffer_zone) %>%
  summarise(
    Count = n(),
    Mean_Price = mean(resale_price, na.rm = TRUE),
    Median_Price = median(resale_price, na.rm = TRUE),
    SD_Price = sd(resale_price, na.rm = TRUE),
    Min_Price = min(resale_price, na.rm = TRUE),
    Max_Price = max(resale_price, na.rm = TRUE),
    .groups = 'drop'
  ) %>%
  mutate(Pct_of_Total = Count / sum(Count) * 100)

print(buffer_stats)

write.csv(buffer_stats, 
          "Environment_Analysis/outputs/price_by_buffer_zone.csv", 
          row.names = FALSE)

cat("\n=== Creating Buffer Zone Visualization ===\n")

# Create buffer zone map
singapore_bbox <- st_bbox(planning_areas)

p_buffer <- ggplot() +
  # Base layer
  geom_sf(data = planning_areas, fill = "gray98", color = "gray70", linewidth = 0.2) +
  
  # Buffer zones (from largest to smallest for proper layering)
  geom_sf(data = park_buffer_1km_union, fill = "#c6dbef", color = NA, alpha = 0.4) +
  geom_sf(data = park_buffer_500m_union, fill = "#6baed6", color = NA, alpha = 0.5) +
  geom_sf(data = park_buffer_250m_union, fill = "#2171b5", color = NA, alpha = 0.6) +
  
  # Parks
  geom_sf(data = parks, color = "#08306b", size = 3, shape = 18) +
  
  # Manual legend
  annotate("rect", xmin = singapore_bbox["xmax"] - 0.08, 
           xmax = singapore_bbox["xmax"] - 0.06,
           ymin = singapore_bbox["ymax"] - 0.15,
           ymax = singapore_bbox["ymax"] - 0.13,
           fill = "#2171b5", alpha = 0.6) +
  annotate("text", x = singapore_bbox["xmax"] - 0.055, 
           y = singapore_bbox["ymax"] - 0.14,
           label = "0-250m", hjust = 0, size = 3) +
  
  annotate("rect", xmin = singapore_bbox["xmax"] - 0.08, 
           xmax = singapore_bbox["xmax"] - 0.06,
           ymin = singapore_bbox["ymax"] - 0.18,
           ymax = singapore_bbox["ymax"] - 0.16,
           fill = "#6baed6", alpha = 0.5) +
  annotate("text", x = singapore_bbox["xmax"] - 0.055, 
           y = singapore_bbox["ymax"] - 0.17,
           label = "250m-500m", hjust = 0, size = 3) +
  
  annotate("rect", xmin = singapore_bbox["xmax"] - 0.08, 
           xmax = singapore_bbox["xmax"] - 0.06,
           ymin = singapore_bbox["ymax"] - 0.21,
           ymax = singapore_bbox["ymax"] - 0.19,
           fill = "#c6dbef", alpha = 0.4) +
  annotate("text", x = singapore_bbox["xmax"] - 0.055, 
           y = singapore_bbox["ymax"] - 0.20,
           label = "500m-1km", hjust = 0, size = 3) +
  
  labs(title = "Park Service Areas - Buffer Zones (2024)",
       subtitle = sprintf("%d parks with 250m, 500m, and 1km buffer zones | Dark blue diamonds show park locations",
                         nrow(parks))) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 10),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )

ggsave("Environment_Analysis/figures/buffer_zones_map.png", p_buffer,
       width = 12, height = 10, dpi = 300, bg = "white")

cat("\n=== Creating Price Comparison by Buffer Zone ===\n")

# Boxplot comparing prices by buffer zone
p_buffer_price <- ggplot(st_drop_geometry(hdb), 
                         aes(x = buffer_zone, y = resale_price, fill = buffer_zone)) +
  geom_violin(alpha = 0.4, scale = "width") +
  geom_boxplot(width = 0.3, outlier.alpha = 0.3, outlier.size = 0.5) +
  stat_summary(fun = median, geom = "point", shape = 23, size = 3, 
               fill = "red", color = "darkred") +
  scale_fill_manual(values = c("#08306b", "#2171b5", "#6baed6", "#c6dbef")) +
  scale_y_continuous(labels = comma, breaks = seq(400000, 1200000, 100000)) +
  labs(title = "Resale Price Distribution by Park Buffer Zone",
       subtitle = sprintf("4-Room HDB Flats, 2024 | n=%s | Red diamonds show median prices",
                         format(nrow(hdb), big.mark = ",")),
       x = "Distance to Nearest Park",
       y = "Resale Price (SGD)") +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 11, color = "gray30"),
    axis.title = element_text(size = 11, face = "bold"),
    axis.text = element_text(size = 10),
    legend.position = "none",
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )

ggsave("Environment_Analysis/figures/buffer_price_comparison.png", p_buffer_price,
       width = 10, height = 7, dpi = 300, bg = "white")

cat("\n=== Coverage Analysis ===\n")

# Calculate total area and coverage in SVY21 for accurate area calculations
singapore_outline_svy21 <- st_transform(st_union(planning_areas), 3414)
buffer_250m_svy21 <- st_transform(park_buffer_250m_union, 3414)
buffer_500m_svy21 <- st_transform(park_buffer_500m_union, 3414)
buffer_1km_svy21 <- st_transform(park_buffer_1km_union, 3414)

singapore_area <- st_area(singapore_outline_svy21)
buffer_250m_area <- st_area(buffer_250m_svy21)
buffer_500m_area <- st_area(buffer_500m_svy21)
buffer_1km_area <- st_area(buffer_1km_svy21)

coverage_stats <- data.frame(
  Buffer_Zone = c("0-250m", "250m-500m", "500m-1km"),
  Area_sq_km = c(as.numeric(buffer_250m_area) / 1e6,
                 (as.numeric(buffer_500m_area) - as.numeric(buffer_250m_area)) / 1e6,
                 (as.numeric(buffer_1km_area) - as.numeric(buffer_500m_area)) / 1e6),
  Pct_of_Singapore = c(as.numeric(buffer_250m_area) / as.numeric(singapore_area) * 100,
                       (as.numeric(buffer_500m_area) - as.numeric(buffer_250m_area)) / as.numeric(singapore_area) * 100,
                       (as.numeric(buffer_1km_area) - as.numeric(buffer_500m_area)) / as.numeric(singapore_area) * 100),
  Transactions = c(sum(hdb$buffer_zone == "0-250m"),
                   sum(hdb$buffer_zone == "250m-500m"),
                   sum(hdb$buffer_zone == "500m-1km")),
  Mean_Price = c(mean(hdb$resale_price[hdb$buffer_zone == "0-250m"], na.rm = TRUE),
                 mean(hdb$resale_price[hdb$buffer_zone == "250m-500m"], na.rm = TRUE),
                 mean(hdb$resale_price[hdb$buffer_zone == "500m-1km"], na.rm = TRUE))
)

cat("\nPark buffer coverage statistics:\n")
print(coverage_stats)

write.csv(coverage_stats,
          "Environment_Analysis/outputs/buffer_coverage_stats.csv",
          row.names = FALSE)

cat("\n=== BUFFER ANALYSIS COMPLETE ===\n")
cat("Generated:\n")
cat("  - Buffer zone map\n")
cat("  - Price comparison by buffer zone\n")
cat("  - Coverage statistics\n")

