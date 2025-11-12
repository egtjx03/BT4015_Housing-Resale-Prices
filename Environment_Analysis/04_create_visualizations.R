# ==============================================================================
# ENVIRONMENT: GREEN DIVIDEND ANALYSIS - CREATE VISUALIZATIONS
# Project: BT4015 Housing Resale Prices
# Purpose: Create choropleth maps, point maps, and scatter plots
# ==============================================================================

library(sf)
library(dplyr)
library(ggplot2)
library(viridis)
library(scales)
library(ggspatial)

setwd("/Users/zr/Code/Projects/BT4015_Housing-Resale-Prices")

cat("=== Loading Data ===\n")
hdb <- readRDS("Environment_Analysis/data/hdb_4room_with_metrics.rds")
parks <- readRDS("Environment_Analysis/data/parks.rds")
park_connectors <- readRDS("Environment_Analysis/data/park_connectors.rds")

# Load official planning area boundaries
cat("Loading Singapore Planning Area boundaries...\n")
sf_use_s2(FALSE)  # Disable s2 to avoid geometry issues
planning_areas <- st_read("Datasets/MasterPlan2019PlanningAreaBoundaryNoSea.geojson", quiet = TRUE)
planning_areas <- st_make_valid(planning_areas)  # Fix any invalid geometries
planning_areas <- st_transform(planning_areas, crs = st_crs(hdb))  # Match HDB CRS

cat(sprintf("Loaded: %d transactions, %d parks, %d connectors, %d planning areas\n",
            nrow(hdb), nrow(parks), nrow(park_connectors), nrow(planning_areas)))

# Common theme for all plots - white background for proper maps
theme_map <- theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 10),
    legend.position = "right",
    legend.title = element_text(size = 10, face = "bold"),
    legend.text = element_text(size = 9),
    axis.text = element_text(size = 8, color = "gray40"),
    axis.title = element_text(size = 9, color = "gray40"),
    panel.grid.major = element_line(color = "gray90", linewidth = 0.3),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA),
    plot.margin = margin(10, 10, 10, 10)
  )

# ====================================================================
# PART 1: CHOROPLETH MAPS BY TOWN
# ====================================================================

cat("\n=== Creating Choropleth Maps ===\n")

# Aggregate data by town
town_summary <- hdb %>%
  st_drop_geometry() %>%
  group_by(town) %>%
  summarise(
    Count = n(),
    Mean_Price = mean(resale_price, na.rm = TRUE),
    Mean_Dist_Park = mean(dist_to_park_m, na.rm = TRUE),
    Mean_Parks_1km = mean(parks_within_1km, na.rm = TRUE),
    .groups = 'drop'
  )

# Extract planning area names from Description field (they're in HTML format)
cat("Extracting planning area names from HTML descriptions...\n")
library(stringr)

# Extract PLN_AREA_N from the Description HTML
planning_areas$town <- str_extract(planning_areas$Description, 
                                   "(?<=<th>PLN_AREA_N</th> <td>)[^<]+")
planning_areas$town <- toupper(trimws(planning_areas$town))

cat(sprintf("Extracted %d planning area names\n", sum(!is.na(planning_areas$town))))

# Create manual mappings for HDB town names that differ from planning areas
town_mapping <- data.frame(
  planning = c("KALLANG", "WHAMPOA", "CENTRAL AREA", "DOWNTOWN CORE", 
               "NEWTON", "NOVENA", "ORCHARD", "OUTRAM", "RIVER VALLEY",
               "ROCHOR", "SINGAPORE RIVER", "STRAITS VIEW", "MUSEUM",
               "MARINA EAST", "MARINA SOUTH"),
  hdb = c("KALLANG/WHAMPOA", "KALLANG/WHAMPOA", "CENTRAL AREA", "CENTRAL AREA",
          "CENTRAL AREA", "CENTRAL AREA", "CENTRAL AREA", "CENTRAL AREA", "CENTRAL AREA",
          "CENTRAL AREA", "CENTRAL AREA", "CENTRAL AREA", "CENTRAL AREA",
          "CENTRAL AREA", "CENTRAL AREA"),
  stringsAsFactors = FALSE
)

# Apply mappings
for (i in 1:nrow(town_mapping)) {
  planning_areas$town[planning_areas$town == town_mapping$planning[i]] <- town_mapping$hdb[i]
}

# Merge statistics with planning area boundaries
town_data <- left_join(planning_areas, town_summary, by = "town")

cat(sprintf("Matched %d planning areas with HDB transaction data\n", 
            sum(!is.na(town_data$Mean_Price))))

# Create Singapore outline
singapore_outline <- st_union(planning_areas)

# Map 1: Average Resale Price by Town
cat("1. Creating choropleth: Average resale price by town\n")
p1 <- ggplot() +
  # All planning areas with data filled by price, missing areas in light gray
  geom_sf(data = town_data, aes(fill = Mean_Price), color = "gray40", linewidth = 0.3) +
  scale_fill_gradientn(
    colors = c("#FFFFCC", "#FFEDA0", "#FED976", "#FEB24C", "#FD8D3C", 
               "#FC4E2A", "#E31A1C", "#BD0026", "#800026"),
    labels = comma,
    name = "Avg Price\n(SGD)",
    na.value = "gray90"
  ) +
  labs(title = "Average 4-Room HDB Resale Prices by Planning Area (2024)",
       subtitle = sprintf("Based on %s transactions | Gray areas have no 4-room transactions", 
                         format(nrow(hdb), big.mark = ","))) +
  theme_map +
  annotation_scale(location = "br", width_hint = 0.2) +
  theme(legend.key.height = unit(1.5, "cm"),
        legend.key.width = unit(0.5, "cm"))

ggsave("Environment_Analysis/figures/map1_price_by_town.png", p1, 
       width = 10, height = 8, dpi = 300, bg = "white")

# Map 2: Average Distance to Nearest Park by Town
cat("2. Creating choropleth: Distance to nearest park by town\n")
p2 <- ggplot() +
  geom_sf(data = town_data, aes(fill = Mean_Dist_Park), color = "gray40", linewidth = 0.3) +
  scale_fill_gradientn(
    colors = c("#006837", "#1a9850", "#66bd63", "#a6d96a", "#d9ef8b", 
               "#ffffbf", "#fee08b", "#fdae61", "#f46d43", "#d73027"),
    labels = comma,
    name = "Mean Distance\n(meters)",
    na.value = "gray90",
    trans = "reverse"
  ) +
  labs(title = "Average Distance to Nearest Park by Planning Area (2024)",
       subtitle = "4-Room HDB Flats | Darker green = closer to parks | Gray areas have no data") +
  theme_map +
  annotation_scale(location = "br", width_hint = 0.2) +
  theme(legend.key.height = unit(1.5, "cm"),
        legend.key.width = unit(0.5, "cm"))

ggsave("Environment_Analysis/figures/map2_dist_park_by_town.png", p2,
       width = 10, height = 8, dpi = 300, bg = "white")

# Map 3: Average Park Count within 1km by Town
cat("3. Creating choropleth: Park count within 1km by town\n")
p3 <- ggplot() +
  geom_sf(data = town_data, aes(fill = Mean_Parks_1km), color = "gray40", linewidth = 0.3) +
  scale_fill_gradientn(
    colors = c("#f7f7f7", "#d9f0d3", "#a6dba0", "#5aae61", "#1b7837", "#00441b"),
    name = "Avg Park\nCount",
    na.value = "gray90"
  ) +
  labs(title = "Average Number of Parks within 1km by Planning Area (2024)",
       subtitle = "4-Room HDB Flats | Darker green = more parks nearby | Gray areas have no data") +
  theme_map +
  annotation_scale(location = "br", width_hint = 0.2) +
  theme(legend.key.height = unit(1.5, "cm"),
        legend.key.width = unit(0.5, "cm"))

ggsave("Environment_Analysis/figures/map3_park_count_by_town.png", p3,
       width = 10, height = 8, dpi = 300, bg = "white")

# ====================================================================
# PART 2: POINT MAPS
# ====================================================================

cat("\n=== Creating Point Maps ===\n")

# Get Singapore bounding box from planning areas (full extent)
singapore_bbox <- st_bbox(planning_areas)

# Map 4: Transaction Points colored by Price with Parks overlay (IMPROVED)
cat("4. Creating improved point map: Transactions by price with parks\n")

# Sample points for cleaner visualization (too many points create clutter)
set.seed(123)
hdb_sample <- hdb[sample(nrow(hdb), min(3000, nrow(hdb))), ]

p4 <- ggplot() +
  # Planning area boundaries for context
  geom_sf(data = planning_areas, fill = "gray98", color = "gray70", linewidth = 0.2) +
  
  # Transaction points (sampled for clarity)
  geom_sf(data = hdb_sample, aes(color = resale_price), size = 0.8, alpha = 0.6) +
  
  # Parks with clear visual distinction
  geom_sf(data = parks, fill = "#238b45", color = "#00441b", size = 4, shape = 23, stroke = 0.8) +
  
  scale_color_gradientn(
    colors = c("#FFFFCC", "#FFEDA0", "#FED976", "#FEB24C", "#FD8D3C", 
               "#FC4E2A", "#E31A1C", "#BD0026", "#800026"),
    labels = comma,
    name = "Resale\nPrice\n(SGD)",
    breaks = seq(400000, 900000, 100000)
  ) +
  
  labs(title = "4-Room HDB Resale Prices and Park Locations (2024)",
       subtitle = sprintf("Sample of %d transactions (out of %d) | Green diamonds show major parks", 
                         nrow(hdb_sample), nrow(hdb))) +
  theme_map +
  annotation_scale(location = "br", width_hint = 0.2) +
  annotation_north_arrow(location = "tl", which_north = "true",
                         style = north_arrow_fancy_orienteering,
                         height = unit(1.2, "cm"), width = unit(1.2, "cm")) +
  theme(legend.key.height = unit(1.5, "cm"),
        legend.key.width = unit(0.5, "cm"))

ggsave("Environment_Analysis/figures/map4_transactions_parks.png", p4,
       width = 12, height = 10, dpi = 300, bg = "white")

# Map 5: Transaction Points colored by Distance to Park (IMPROVED)
cat("5. Creating improved point map: Transactions by distance to park\n")

# Use same sample for consistency
p5 <- ggplot() +
  # Planning area boundaries for context
  geom_sf(data = planning_areas, fill = "gray98", color = "gray70", linewidth = 0.2) +
  
  # Transaction points colored by distance
  geom_sf(data = hdb_sample, aes(color = dist_to_park_m), size = 0.8, alpha = 0.6) +
  
  # Parks as reference points
  geom_sf(data = parks, fill = "#d73027", color = "#67000d", size = 4, shape = 24, stroke = 0.8) +
  
  scale_color_gradientn(
    colors = c("#006837", "#1a9850", "#66bd63", "#a6d96a", "#d9ef8b", 
               "#ffffbf", "#fee08b", "#fdae61", "#f46d43", "#d73027", "#a50026"),
    labels = comma,
    name = "Distance to\nNearest\nPark (m)",
    breaks = c(0, 500, 1000, 2000, 3000, 5000)
  ) +
  
  labs(title = "Proximity to Parks for 4-Room HDB Resale Transactions (2024)",
       subtitle = sprintf("Dark green = close to parks | Red = far from parks | Red triangles show park locations (n=%d)", 
                         nrow(hdb_sample))) +
  theme_map +
  annotation_scale(location = "br", width_hint = 0.2) +
  annotation_north_arrow(location = "tl", which_north = "true",
                         style = north_arrow_fancy_orienteering,
                         height = unit(1.2, "cm"), width = unit(1.2, "cm")) +
  theme(legend.key.height = unit(1.5, "cm"),
        legend.key.width = unit(0.5, "cm"))

ggsave("Environment_Analysis/figures/map5_transactions_by_distance.png", p5,
       width = 12, height = 10, dpi = 300, bg = "white")

# Map 6: Improved Park Connector Accessibility and Transaction Density
cat("6. Creating improved map: Park connectors with transaction density\n")

# Create hexagonal bins for cleaner density visualization
library(hexbin)

# Get coordinates for hexbin
coords_df <- as.data.frame(st_coordinates(hdb))

p6 <- ggplot() +
  # Base layer: planning area boundaries for context
  geom_sf(data = planning_areas, fill = "gray98", color = "gray80", linewidth = 0.2) +
  
  # Hexagonal binning for transaction density (cleaner than contours)
  stat_summary_hex(data = coords_df,
                   aes(x = X, y = Y, z = 1),
                   fun = "sum",
                   bins = 30,
                   alpha = 0.7) +
  
  # Park connectors on top (with better visibility)
  geom_sf(data = park_connectors, color = "#006837", linewidth = 1.5, alpha = 0.9) +
  
  # Parks as reference points
  geom_sf(data = parks, color = "#00441b", size = 4, shape = 18) +
  
  # Color scale for density
  scale_fill_gradientn(
    colors = c("#FFFFCC", "#FFEDA0", "#FED976", "#FEB24C", "#FD8D3C", 
               "#FC4E2A", "#E31A1C", "#BD0026", "#800026"),
    name = "Transaction\nCount per\nHexagon",
    na.value = NA
  ) +
  
  labs(title = "Park Connector Network and 4-Room HDB Transaction Density (2024)",
       subtitle = "Dark green lines: park connectors | Dark green diamonds: parks | Colored hexagons: transaction density") +
  
  theme_map +
  annotation_scale(location = "br", width_hint = 0.2) +
  annotation_north_arrow(location = "tl", which_north = "true",
                         style = north_arrow_fancy_orienteering,
                         height = unit(1.2, "cm"),
                         width = unit(1.2, "cm")) +
  theme(legend.key.height = unit(1.5, "cm"),
        legend.key.width = unit(0.5, "cm"),
        panel.grid.major = element_line(color = "gray85", linewidth = 0.2))

ggsave("Environment_Analysis/figures/map6_connectors_density.png", p6,
       width = 12, height = 10, dpi = 300, bg = "white")

# ====================================================================
# PART 3: SCATTER PLOTS FOR CORRELATIONS
# ====================================================================

cat("\n=== Creating Scatter Plots ===\n")

# Drop geometry for scatter plots
hdb_df <- hdb %>% st_drop_geometry()

# Plot 7: Distance to Nearest Park vs Resale Price (IMPROVED)
cat("7. Creating improved scatter: Distance to park vs price\n")

# Calculate correlation
cor_park_dist <- cor(hdb_df$dist_to_park_m, hdb_df$resale_price, use = "complete.obs")

p7 <- ggplot(hdb_df, aes(x = dist_to_park_m, y = resale_price)) +
  # Hexagonal bins to show density (cleaner than overlapping points)
  geom_hex(bins = 40, alpha = 0.8) +
  scale_fill_gradientn(colors = c("#EFF3FF", "#BDD7E7", "#6BAED6", "#3182BD", "#08519C"),
                       name = "Count", trans = "log10") +
  
  # Add smooth trend line
  geom_smooth(method = "loess", color = "red", se = TRUE, linewidth = 1.5, alpha = 0.3) +
  
  # Add correlation text
  annotate("text", x = max(hdb_df$dist_to_park_m) * 0.7, 
           y = max(hdb_df$resale_price) * 0.95,
           label = sprintf("Correlation: %.3f", cor_park_dist),
           size = 5, fontface = "bold", color = "red") +
  
  scale_x_continuous(labels = comma, breaks = seq(0, 6000, 1000)) +
  scale_y_continuous(labels = comma, breaks = seq(400000, 1000000, 100000)) +
  
  labs(title = "Resale Price vs Distance to Nearest Park",
       subtitle = sprintf("4-Room HDB Flats, 2024 | n=%s transactions | Weak negative correlation", 
                         format(nrow(hdb_df), big.mark = ",")),
       x = "Distance to Nearest Park (meters)",
       y = "Resale Price (SGD)") +
  
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 11, color = "gray30"),
    axis.title = element_text(size = 11, face = "bold"),
    axis.text = element_text(size = 10),
    legend.position = "right",
    panel.grid.minor = element_blank(),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )

ggsave("Environment_Analysis/figures/scatter1_dist_park_vs_price.png", p7,
       width = 11, height = 8, dpi = 300, bg = "white")

# Plot 8: Park Count within 1km vs Resale Price (IMPROVED)
cat("8. Creating improved scatter: Park count vs price\n")

# Calculate correlation
cor_park_count <- cor(hdb_df$parks_within_1km, hdb_df$resale_price, use = "complete.obs")

# Create boxplots for each park count category
p8 <- ggplot(hdb_df, aes(x = factor(parks_within_1km), y = resale_price)) +
  # Violin plot to show distribution
  geom_violin(aes(fill = factor(parks_within_1km)), alpha = 0.4, scale = "width") +
  
  # Boxplot overlay for summary statistics
  geom_boxplot(width = 0.3, outlier.alpha = 0.3, outlier.size = 0.5) +
  
  # Add median line
  stat_summary(fun = median, geom = "point", shape = 23, size = 3, 
               fill = "red", color = "darkred") +
  
  scale_fill_brewer(palette = "Greens", name = "Parks\nwithin 1km") +
  scale_y_continuous(labels = comma, breaks = seq(400000, 1200000, 100000)) +
  
  # Add correlation annotation
  annotate("text", x = 1.5, y = max(hdb_df$resale_price) * 0.95,
           label = sprintf("Correlation: %.3f", cor_park_count),
           size = 5, fontface = "bold", color = "red") +
  
  labs(title = "Resale Price Distribution by Number of Parks within 1km",
       subtitle = sprintf("4-Room HDB Flats, 2024 | n=%s | Red diamonds show median prices", 
                         format(nrow(hdb_df), big.mark = ",")),
       x = "Number of Parks within 1km Radius",
       y = "Resale Price (SGD)") +
  
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 11, color = "gray30"),
    axis.title = element_text(size = 11, face = "bold"),
    axis.text = element_text(size = 10),
    legend.position = "none",
    panel.grid.minor = element_blank(),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )

ggsave("Environment_Analysis/figures/scatter2_park_count_vs_price.png", p8,
       width = 11, height = 8, dpi = 300, bg = "white")

# Plot 9: Park Connector Length within 1km vs Resale Price (IMPROVED)
cat("9. Creating improved scatter: Connector length vs price\n")

# Calculate correlation
cor_connector <- cor(hdb_df$connector_length_1km, hdb_df$resale_price, use = "complete.obs")

# Filter out extreme outliers for better visualization
hdb_filtered <- hdb_df %>% 
  filter(connector_length_1km > 0)  # Only show areas with some connector access

p9 <- ggplot(hdb_filtered, aes(x = connector_length_1km, y = resale_price)) +
  # Hexagonal bins to show density
  geom_hex(bins = 40, alpha = 0.8) +
  scale_fill_gradientn(colors = c("#F0F9E8", "#BAE4BC", "#7BCCC4", "#43A2CA", "#0868AC"),
                       name = "Count", trans = "log10") +
  
  # Add smooth trend line with wider confidence interval
  geom_smooth(method = "loess", color = "red", se = TRUE, linewidth = 1.5, 
              alpha = 0.3, span = 0.5) +
  
  # Add correlation text
  annotate("text", x = max(hdb_filtered$connector_length_1km) * 0.7, 
           y = max(hdb_filtered$resale_price) * 0.95,
           label = sprintf("Correlation: %.3f", cor_connector),
           size = 5, fontface = "bold", color = "red") +
  
  scale_x_continuous(labels = comma, breaks = seq(0, 25000, 5000)) +
  scale_y_continuous(labels = comma, breaks = seq(400000, 1000000, 100000)) +
  
  labs(title = "Resale Price vs Park Connector Accessibility",
       subtitle = sprintf("4-Room HDB Flats, 2024 | n=%s transactions with connector access | Moderate positive correlation", 
                         format(nrow(hdb_filtered), big.mark = ",")),
       x = "Total Park Connector Length within 1km (meters)",
       y = "Resale Price (SGD)") +
  
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 11, color = "gray30"),
    axis.title = element_text(size = 11, face = "bold"),
    axis.text = element_text(size = 10),
    legend.position = "right",
    panel.grid.minor = element_blank(),
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )

ggsave("Environment_Analysis/figures/scatter3_connector_vs_price.png", p9,
       width = 11, height = 8, dpi = 300, bg = "white")

cat("\n=== ALL VISUALIZATIONS CREATED ===\n")
cat("Saved 9 figures to Environment_Analysis/figures/\n")
cat("  - 3 Choropleth maps\n")
cat("  - 3 Point maps\n")
cat("  - 3 Scatter plots\n")

