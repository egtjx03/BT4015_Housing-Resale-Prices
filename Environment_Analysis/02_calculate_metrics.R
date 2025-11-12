# ==============================================================================
# ENVIRONMENT: GREEN DIVIDEND ANALYSIS - CALCULATE GREEN SPACE METRICS
# Project: BT4015 Housing Resale Prices
# Purpose: Calculate distance and count metrics for parks and park connectors
# ==============================================================================

library(sf)
library(dplyr)
library(units)

setwd("/Users/zr/Code/Projects/BT4015_Housing-Resale-Prices")

cat("=== Loading Prepared Data ===\n")
hdb_4room <- readRDS("Environment_Analysis/data/hdb_4room_2024.rds")
parks <- readRDS("Environment_Analysis/data/parks.rds")
park_connectors <- readRDS("Environment_Analysis/data/park_connectors.rds")

cat(sprintf("Loaded: %d transactions, %d parks, %d connectors\n", 
            nrow(hdb_4room), nrow(parks), nrow(park_connectors)))

cat("\n=== Calculating Distance Metrics ===\n")

# Function to calculate distance to nearest feature
calc_nearest_distance <- function(points, features) {
  cat("  Computing distances...\n")
  distances <- st_distance(points, features)
  nearest_dist <- apply(distances, 1, min)
  # Convert to numeric (meters)
  if (inherits(nearest_dist, "units")) {
    return(drop_units(nearest_dist))
  } else {
    return(as.numeric(nearest_dist))
  }
}

# Distance to nearest park
cat("1. Distance to nearest park\n")
hdb_4room$dist_to_park_m <- calc_nearest_distance(hdb_4room, parks)

# Distance to nearest park connector
cat("2. Distance to nearest park connector\n")
hdb_4room$dist_to_connector_m <- calc_nearest_distance(hdb_4room, park_connectors)

cat(sprintf("   Mean distance to park: %.0f m\n", mean(hdb_4room$dist_to_park_m, na.rm = TRUE)))
cat(sprintf("   Mean distance to connector: %.0f m\n", mean(hdb_4room$dist_to_connector_m, na.rm = TRUE)))

cat("\n=== Calculating Count Metrics ===\n")

# Function to count features within radius
count_within_radius <- function(points, features, radius_m) {
  cat(sprintf("  Counting features within %d m...\n", radius_m))
  
  counts <- sapply(1:nrow(points), function(i) {
    if (i %% 1000 == 0) cat(sprintf("    Progress: %d/%d\n", i, nrow(points)))
    
    # Create buffer around point
    buffer <- st_buffer(points[i, ], dist = radius_m)
    
    # Count intersecting features
    intersects <- st_intersects(buffer, features)
    return(length(intersects[[1]]))
  })
  
  return(counts)
}

# Parks within 500m
cat("3. Parks within 500m\n")
hdb_4room$parks_within_500m <- count_within_radius(hdb_4room, parks, 500)

# Parks within 1km
cat("4. Parks within 1km\n")
hdb_4room$parks_within_1km <- count_within_radius(hdb_4room, parks, 1000)

cat(sprintf("   Mean parks within 500m: %.2f\n", mean(hdb_4room$parks_within_500m, na.rm = TRUE)))
cat(sprintf("   Mean parks within 1km: %.2f\n", mean(hdb_4room$parks_within_1km, na.rm = TRUE)))

cat("\n=== Calculating Park Connector Length Metrics ===\n")

# Function to calculate length of connectors within buffer
calc_connector_length <- function(points, connectors, radius_m) {
  cat(sprintf("  Calculating connector length within %d m...\n", radius_m))
  
  lengths <- sapply(1:nrow(points), function(i) {
    if (i %% 1000 == 0) cat(sprintf("    Progress: %d/%d\n", i, nrow(points)))
    
    # Create buffer around point
    buffer <- st_buffer(points[i, ], dist = radius_m)
    
    # Intersect connectors with buffer
    connectors_in_buffer <- st_intersection(connectors, buffer)
    
    if (nrow(connectors_in_buffer) == 0) {
      return(0)
    }
    
    # Calculate total length
    total_length <- sum(st_length(connectors_in_buffer))
    if (inherits(total_length, "units")) {
      return(drop_units(total_length))
    } else {
      return(as.numeric(total_length))
    }
  })
  
  return(lengths)
}

# Connector length within 500m
cat("5. Park connector length within 500m\n")
hdb_4room$connector_length_500m <- calc_connector_length(hdb_4room, park_connectors, 500)

# Connector length within 1km
cat("6. Park connector length within 1km\n")
hdb_4room$connector_length_1km <- calc_connector_length(hdb_4room, park_connectors, 1000)

cat(sprintf("   Mean connector length within 500m: %.0f m\n", 
            mean(hdb_4room$connector_length_500m, na.rm = TRUE)))
cat(sprintf("   Mean connector length within 1km: %.0f m\n", 
            mean(hdb_4room$connector_length_1km, na.rm = TRUE)))

cat("\n=== Saving Results ===\n")

# Save enhanced dataset
saveRDS(hdb_4room, "Environment_Analysis/data/hdb_4room_with_metrics.rds")

# Also save as CSV (without geometry for easier viewing)
hdb_csv <- hdb_4room
st_geometry(hdb_csv) <- NULL
write.csv(hdb_csv, "Environment_Analysis/data/hdb_4room_with_metrics.csv", row.names = FALSE)

cat("\n=== Metrics Calculation Complete ===\n")
cat("Summary of green space metrics:\n")
cat(sprintf("  Distance to nearest park: %.0f m (median)\n", 
            median(hdb_4room$dist_to_park_m, na.rm = TRUE)))
cat(sprintf("  Distance to nearest connector: %.0f m (median)\n", 
            median(hdb_4room$dist_to_connector_m, na.rm = TRUE)))
cat(sprintf("  Parks within 500m: %.1f (mean)\n", 
            mean(hdb_4room$parks_within_500m, na.rm = TRUE)))
cat(sprintf("  Parks within 1km: %.1f (mean)\n", 
            mean(hdb_4room$parks_within_1km, na.rm = TRUE)))
cat(sprintf("  Connector length within 500m: %.0f m (mean)\n", 
            mean(hdb_4room$connector_length_500m, na.rm = TRUE)))
cat(sprintf("  Connector length within 1km: %.0f m (mean)\n", 
            mean(hdb_4room$connector_length_1km, na.rm = TRUE)))

