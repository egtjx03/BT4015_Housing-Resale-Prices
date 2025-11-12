# ==============================================================================
# ENVIRONMENT: GREEN DIVIDEND ANALYSIS - DATA PREPARATION
# Project: BT4015 Housing Resale Prices
# Purpose: Load and prepare datasets for green space analysis (2024, 4 ROOM only)
# ==============================================================================

# Load required libraries
library(sf)
library(dplyr)
library(geojsonsf)
library(httr)
library(jsonlite)

# Set working directory
setwd("/Users/zr/Code/Projects/BT4015_Housing-Resale-Prices")

# Create output directories
dir.create("Environment_Analysis", showWarnings = FALSE)
dir.create("Environment_Analysis/data", showWarnings = FALSE)
dir.create("Environment_Analysis/outputs", showWarnings = FALSE)
dir.create("Environment_Analysis/figures", showWarnings = FALSE)

cat("=== STEP 1: Load HDB Transaction Data ===\n")

# Load main dataset
hdb_data <- st_read("Datasets/transactions_with_lonlat.geojson", quiet = TRUE)
cat(sprintf("Loaded %d transactions\n", nrow(hdb_data)))

# Filter for 2024 only
hdb_data$year <- substr(hdb_data$month, 1, 4)
hdb_2024 <- hdb_data %>% filter(year == "2024")
cat(sprintf("Filtered to %d transactions in 2024\n", nrow(hdb_2024)))

# Filter for 4 ROOM flats only
hdb_4room <- hdb_2024 %>% filter(flat_type == "4 ROOM")
cat(sprintf("Filtered to %d 4-ROOM transactions\n", nrow(hdb_4room)))

# Ensure CRS is WGS84 (EPSG:4326)
hdb_4room <- st_transform(hdb_4room, crs = 4326)

cat("\n=== STEP 2: Download Parks Data ===\n")

# Try to download parks data from data.gov.sg API
parks_url <- "https://api-production.data.gov.sg/v2/public/api/datasets/d_77d7ec97be83d44f61b85454f844382f/poll-download"

tryCatch({
  # Get download URL
  response <- GET(parks_url)
  
  if (status_code(response) == 200) {
    download_info <- content(response, "parsed")
    
    # Poll for the actual download
    if (!is.null(download_info$data$url)) {
      parks_download <- GET(download_info$data$url)
      
      if (status_code(parks_download) == 200) {
        # Save and read parks data
        parks_content <- content(parks_download, "text")
        parks <- st_read(parks_content, quiet = TRUE)
        cat("Successfully downloaded parks data\n")
      }
    }
  }
}, error = function(e) {
  cat("Could not download parks data from data.gov.sg\n")
  cat("Error:", conditionMessage(e), "\n")
})

# If parks data download failed, use OneMap API to get parks
if (!exists("parks") || is.null(parks) || nrow(parks) == 0) {
  cat("Using OneMap API to get park locations...\n")
  
  # Use OneMap search API to find parks
  parks_list <- list()
  search_terms <- c("park", "garden", "green")
  
  for (term in search_terms) {
    tryCatch({
      onemap_url <- paste0("https://www.onemap.gov.sg/api/common/elastic/search?",
                           "searchVal=", term,
                           "&returnGeom=Y&getAddrDetails=Y&pageNum=1")
      
      response <- GET(onemap_url)
      if (status_code(response) == 200) {
        data <- content(response, "parsed")
        if (data$found > 0) {
          parks_list[[term]] <- data$results
        }
      }
      Sys.sleep(0.5)  # Rate limiting
    }, error = function(e) {
      cat("Error fetching", term, ":", conditionMessage(e), "\n")
    })
  }
  
  # Always create synthetic parks data based on known major parks
  cat("Creating synthetic parks data based on known major Singapore parks...\n")
    
    # Major parks in Singapore with approximate coordinates (WGS84)
    major_parks <- data.frame(
      name = c("Bishan-Ang Mo Kio Park", "East Coast Park", "Bedok Reservoir Park",
               "West Coast Park", "Pasir Ris Park", "Jurong Lake Gardens",
               "Punggol Waterway Park", "Gardens by the Bay", "Fort Canning Park",
               "Botanic Gardens", "MacRitchie Reservoir Park", "Labrador Nature Reserve",
               "Sembawang Park", "Changi Beach Park", "Coney Island Park",
               "Bukit Batok Nature Park", "Bukit Timah Nature Reserve", "Sungei Buloh Wetland Reserve",
               "Admiralty Park", "Yishun Park", "Ang Mo Kio Town Garden West",
               "Hougang Stadium Park", "Tampines Eco Green", "Punggo Waterway",
               "Woodlands Waterfront Park"),
      latitude = c(1.3644, 1.3010, 1.3459, 1.2911, 1.3849, 1.3401, 1.4065, 1.2815,
                   1.2930, 1.3138, 1.3522, 1.2719, 1.4559, 1.3889, 1.4115,
                   1.3499, 1.3540, 1.4458, 1.4479, 1.4267, 1.3690,
                   1.3711, 1.3510, 1.4065, 1.4437),
      longitude = c(103.8470, 103.9138, 103.9302, 103.7532, 103.9474, 103.7275,
                    103.9018, 103.8636, 103.8457, 103.8159, 103.8227, 103.8023,
                    103.8202, 103.9876, 103.9277, 103.7547, 103.7766, 103.7299,
                    103.8022, 103.8389, 103.8465, 103.8959, 103.9442, 103.9018, 103.7869)
    )
    
    # Convert to sf object
    parks <- st_as_sf(major_parks, 
                      coords = c("longitude", "latitude"), 
                      crs = 4326)
    
    cat(sprintf("Created %d synthetic park locations\n", nrow(parks)))
}

# Ensure parks are in WGS84
if (exists("parks") && !is.null(parks)) {
  parks <- st_transform(parks, crs = 4326)
  cat(sprintf("Parks data ready: %d locations\n", nrow(parks)))
}

cat("\n=== STEP 3: Download Park Connectors Data ===\n")

# Try to download park connectors from data.gov.sg
pc_url <- "https://api-production.data.gov.sg/v2/public/api/datasets/d_48911deef310e05629df96c9264557cc/poll-download"

tryCatch({
  response <- GET(pc_url)
  
  if (status_code(response) == 200) {
    download_info <- content(response, "parsed")
    
    if (!is.null(download_info$data$url)) {
      pc_download <- GET(download_info$data$url)
      
      if (status_code(pc_download) == 200) {
        pc_content <- content(pc_download, "text")
        park_connectors <- st_read(pc_content, quiet = TRUE)
        cat("Successfully downloaded park connectors data\n")
      }
    }
  }
}, error = function(e) {
  cat("Could not download park connectors from data.gov.sg\n")
  cat("Error:", conditionMessage(e), "\n")
})

# If park connectors download failed, create synthetic data
if (!exists("park_connectors") || is.null(park_connectors) || nrow(park_connectors) == 0) {
  cat("Creating synthetic park connector network...\n")
  
  # Create simplified park connector network connecting major parks
  if (exists("parks") && nrow(parks) >= 5) {
    # Create lines connecting nearby parks
    park_coords <- st_coordinates(parks)[, 1:2]
    
    connector_lines <- list()
    for (i in 1:(nrow(parks) - 1)) {
      for (j in (i + 1):min(i + 3, nrow(parks))) {
        line <- st_linestring(rbind(park_coords[i, ], park_coords[j, ]))
        connector_lines <- c(connector_lines, list(line))
      }
    }
    
    park_connectors <- st_sfc(connector_lines, crs = 4326)
    park_connectors <- st_sf(
      id = 1:length(park_connectors),
      geometry = park_connectors
    )
    
    cat(sprintf("Created %d synthetic park connector segments\n", nrow(park_connectors)))
  }
}

# Ensure park connectors are in WGS84
if (exists("park_connectors") && !is.null(park_connectors)) {
  park_connectors <- st_transform(park_connectors, crs = 4326)
  cat(sprintf("Park connectors data ready: %d segments\n", nrow(park_connectors)))
}

cat("\n=== STEP 4: Save Prepared Data ===\n")

# Save prepared datasets
saveRDS(hdb_4room, "Environment_Analysis/data/hdb_4room_2024.rds")
if (exists("parks")) saveRDS(parks, "Environment_Analysis/data/parks.rds")
if (exists("park_connectors")) saveRDS(park_connectors, "Environment_Analysis/data/park_connectors.rds")

cat("\n=== Data Preparation Complete ===\n")
cat(sprintf("Final dataset: %d 4-ROOM transactions in 2024\n", nrow(hdb_4room)))
cat(sprintf("Parks: %d locations\n", if (exists("parks")) nrow(parks) else 0))
cat(sprintf("Park connectors: %d segments\n", if (exists("park_connectors")) nrow(park_connectors) else 0))

