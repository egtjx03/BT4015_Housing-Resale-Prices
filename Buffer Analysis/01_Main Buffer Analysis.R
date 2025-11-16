
# Libraries

library(sf)
library(dplyr)
library(tmap)
library(units)
library(stringr)

sf_use_s2(FALSE)
tmap_mode("plot")


# File paths 

base <- "C:/Users/egtay/OneDrive/Desktop/BT4015_Housing-Resale-Prices/Datasets"

txn_csv <- file.path(base, "transactions_with_lonlat.geojson")

paths <- list(
  planning_areas = file.path(base, "MasterPlan2019PlanningAreaBoundaryNoSea.geojson"),
  mrt_exits      = file.path(base, "LTAMRTStationExitGEOJSON.geojson"),
  supermarkets   = file.path(base, "SupermarketsGEOJSON.geojson"),
  hawkers        = file.path(base, "HawkerCentresGEOJSON.geojson"),
  sports         = file.path(base, "SportSGSportFacilitiesGEOJSON.geojson"),
  chas_clinics   = file.path(base, "CHASClinics.geojson"),
  parks          = file.path(base, "NParksParksandNatureReserves.geojson"),
  parking_ura    = file.path(base, "URAParkingLotGEOJSON.geojson"),
  schools        = file.path(base, "Schools_information_with_loc.geojson"),
  bus_path       = file.path(base, "LTABusStop.geojson"),
  park_connector = file.path(
    base,
    "SDCPParkConnectorLineSHP",
    "G_MP08_PK_CONECTR_LI.shp"
  )
)


# Read data as sf

hdb   <- st_read(txn_csv, quiet = TRUE)                    # HDB transactions
pa_raw<- st_read(paths$planning_areas, quiet = TRUE)       # planning areas (with HTML Description)
mrt   <- st_read(paths$mrt_exits, quiet = TRUE)            # MRT exits
bus   <- st_read(paths$bus_path, quiet = TRUE)             # Bus stops

supermarkets    <- st_read(paths$supermarkets, quiet = TRUE)
hawkers         <- st_read(paths$hawkers, quiet = TRUE)
sports_fac      <- st_read(paths$sports, quiet = TRUE)
chas_clinics    <- st_read(paths$chas_clinics, quiet = TRUE)
parks           <- st_read(paths$parks, quiet = TRUE)
parking_ura     <- st_read(paths$parking_ura, quiet = TRUE)
schools         <- st_read(paths$schools, quiet = TRUE)
park_connectors <- st_read(paths$park_connector, quiet = TRUE)


if ("flat_type" %in% names(hdb)) {
  hdb <- hdb %>% filter(flat_type == "4 ROOM")
} else {
  stop("Column 'flat_type' not found in HDB dataset. Check column names with names(hdb).")
}


# Extract PLN_AREA_N cleanly from planning-area Description

pa <- pa_raw %>%
  mutate(
    PLN_AREA_N = str_match(
      Description,
      "(?is)<th>\\s*PLN_AREA_N\\s*</th>\\s*<td>\\s*([^<]+?)\\s*</td>"
    )[, 2] %>% str_squish()
  ) %>%
  select(PLN_AREA_N, geometry)


# Reproject everything to Singapore SVY21 (EPSG:3414)

to_crs <- 3414

hdb            <- st_transform(hdb,            to_crs)
pa             <- st_transform(pa,             to_crs)
mrt            <- st_transform(mrt,            to_crs)
bus            <- st_transform(bus,            to_crs)
supermarkets   <- st_transform(supermarkets,   to_crs)
hawkers        <- st_transform(hawkers,        to_crs)
sports_fac     <- st_transform(sports_fac,     to_crs)
chas_clinics   <- st_transform(chas_clinics,   to_crs)
parks          <- st_transform(parks,          to_crs)
parking_ura    <- st_transform(parking_ura,    to_crs)
schools        <- st_transform(schools,        to_crs)
park_connectors<- st_transform(park_connectors,to_crs)


# 1) BUFFER DISTANCES 

# Distances in metres
amenity_specs <- list(
  mrt         = list(sf = mrt,            dist = 800),
  bus         = list(sf = bus,            dist = 200),
  schools     = list(sf = schools,        dist = 1000),  # changed to 1000m
  hawker      = list(sf = hawkers,        dist = 500),
  supermarket = list(sf = supermarkets,   dist = 400),
  clinic      = list(sf = chas_clinics,   dist = 800),   # changed to 800m
  
  park400     = list(sf = parks,          dist = 400),   # local park
  park1000    = list(sf = parks,          dist = 1000),  # added 2km park
  parkconn    = list(sf = park_connectors,dist = 200),   # park connector 200m
  
  sports      = list(sf = sports_fac,     dist = 2000),
  parking     = list(sf = parking_ura,    dist = 200)
)


# 2) For EACH amenity: flag if HDB is within the optimal buffer

for (nm in names(amenity_specs)) {
  cat("Computing within-distance flag for:", nm, "\n")
  obj  <- amenity_specs[[nm]]
  dmax <- obj$dist
  
  within_list <- st_is_within_distance(hdb, obj$sf, dist = dmax)
  hdb[[paste0("near_", nm)]] <- lengths(within_list) > 0
}


# 3) GLOBAL SUMMARY (overall % of HDBs within each optimal buffer)

total_hdb   <- nrow(hdb)
near_cols   <- grep("^near_", names(hdb), value = TRUE)
amenity_key <- sub("^near_", "", near_cols)

global_summary <- data.frame(
  amenity      = amenity_key,
  buffer_m     = sapply(amenity_key, function(a) amenity_specs[[a]]$dist),
  count_inside = sapply(near_cols, function(x) sum(hdb[[x]], na.rm = TRUE)),
  prop_inside  = sapply(near_cols, function(x) mean(hdb[[x]], na.rm = TRUE))
)

cat("\n===== Global HDB Proximity Summary (optimal buffers) =====\n")
print(
  transform(global_summary,
            pct_inside = round(prop_inside * 100, 1))
)


# 4) PLANNING-AREA SUMMARY & CHOROPLETHS


# Attach planning-area (with PLN_AREA_N) to each HDB
hdb_pa <- st_join(hdb, pa, left = TRUE)

# Summarise counts per planning area
hdb_pa_sum <- hdb_pa %>%
  st_drop_geometry() %>%
  group_by(PLN_AREA_N) %>%
  summarise(
    n_hdb       = n(),
    n_mrt       = sum(near_mrt,      na.rm = TRUE),
    n_bus       = sum(near_bus,      na.rm = TRUE),
    n_school    = sum(near_schools,  na.rm = TRUE),
    n_hawker    = sum(near_hawker,   na.rm = TRUE),
    n_super     = sum(near_supermarket, na.rm = TRUE),
    n_clinic    = sum(near_clinic,   na.rm = TRUE),
    n_park400   = sum(near_park400,  na.rm = TRUE),
    n_park1000  = sum(near_park1000, na.rm = TRUE),
    n_parkconn  = sum(near_parkconn, na.rm = TRUE),
    n_sports    = sum(near_sports,   na.rm = TRUE),
    n_parking   = sum(near_parking,  na.rm = TRUE)
  ) %>%
  mutate(
    prop_mrt       = ifelse(n_hdb > 0, n_mrt      / n_hdb, NA_real_),
    prop_bus       = ifelse(n_hdb > 0, n_bus      / n_hdb, NA_real_),
    prop_school    = ifelse(n_hdb > 0, n_school   / n_hdb, NA_real_),
    prop_hawker    = ifelse(n_hdb > 0, n_hawker   / n_hdb, NA_real_),
    prop_super     = ifelse(n_hdb > 0, n_super    / n_hdb, NA_real_),
    prop_clinic    = ifelse(n_hdb > 0, n_clinic   / n_hdb, NA_real_),
    prop_park400   = ifelse(n_hdb > 0, n_park400  / n_hdb, NA_real_),
    prop_park1000  = ifelse(n_hdb > 0, n_park1000 / n_hdb, NA_real_),
    prop_parkconn  = ifelse(n_hdb > 0, n_parkconn / n_hdb, NA_real_),
    prop_sports    = ifelse(n_hdb > 0, n_sports   / n_hdb, NA_real_),
    prop_parking   = ifelse(n_hdb > 0, n_parking  / n_hdb, NA_real_)
  )

# Join back to PA polygons
pa_map <- pa %>%
  left_join(hdb_pa_sum, by = "PLN_AREA_N") %>%
  mutate(
    prop_mrt_pct       = prop_mrt       * 100,
    prop_bus_pct       = prop_bus       * 100,
    prop_school_pct    = prop_school    * 100,
    prop_hawker_pct    = prop_hawker    * 100,
    prop_super_pct     = prop_super     * 100,
    prop_clinic_pct    = prop_clinic    * 100,
    prop_park400_pct   = prop_park400   * 100,
    prop_park1000_pct  = prop_park1000  * 100,
    prop_parkconn_pct  = prop_parkconn  * 100,
    prop_sports_pct    = prop_sports    * 100,
    prop_parking_pct   = prop_parking   * 100
  )


# 5) Helper function: one-liner to plot any amenity map

plot_access_map <- function(var, main_title) {
  tm_shape(pa_map) +
    tm_polygons(
      var,
      palette = "YlGnBu",
      style   = "cont",
      title   = "Proportion of HDBs (%)",
      colorNA = "grey90"
    ) +
    tm_layout(
      main.title     = main_title,
      legend.outside = TRUE,
      legend.format  = list(suffix = "%", digits = 0)
    ) + tm_check_fix()
}


# 6) Example maps for ALL factors


# MRT 800 m
plot_access_map("prop_mrt_pct",
                "HDB within 800 m of MRT (by Planning Area)")

# Bus 200 m
plot_access_map("prop_bus_pct",
                "HDB within 200 m of Bus Stop (by Planning Area)")

# Schools 1000 m
plot_access_map("prop_school_pct",
                "HDB within 1 km of School (by Planning Area)")

# Hawker 500 m
plot_access_map("prop_hawker_pct",
                "HDB within 500 m of Hawker Centre (by Planning Area)")

# Supermarket 800 m
plot_access_map("prop_super_pct",
                "HDB within 800 m of Supermarket (by Planning Area)")

# Clinic 800 m
plot_access_map("prop_clinic_pct",
                "HDB within 800 m of CHAS Clinic (by Planning Area)")

# Park 400 m (local access)
plot_access_map("prop_park400_pct",
                "HDB within 400 m of Park (by Planning Area)")

# Park 2000 m (regional access)
plot_access_map("prop_park1000_pct",
                "HDB within 1 km of Park (by Planning Area)")

# Park connector 200 m
plot_access_map("prop_parkconn_pct",
                "HDB within 200 m of Park Connector (by Planning Area)")

# Sports facilities 2000 m
plot_access_map("prop_sports_pct",
                "HDB within 2 km of Sports Facility (by Planning Area)")

# Parking 200 m
plot_access_map("prop_parking_pct",
                "HDB within 200 m of URA Parking (by Planning Area)")

# ============================================================
# 7) RANKING OF PLANNING AREAS BY FACTOR
# ============================================================

# Keep PA + all proportion columns
rank_df <- pa_map %>%
  st_drop_geometry() %>%
  select(
    PLN_AREA_N,
    prop_mrt_pct, prop_bus_pct,
    prop_school_pct, prop_hawker_pct, prop_super_pct,
    prop_clinic_pct, prop_sports_pct,
    prop_parking_pct,
    everything()
  )

rank_df_sorted <- 

# If park connector exists, include it
has_parkconn <- "prop_parkconn_pct" %in% names(rank_df)


# -----------------------------
# HELPER: Make ranking table
# -----------------------------
rank_top5 <- function(df, colname) {
  df %>%
    arrange(desc(.data[[colname]])) %>%
    slice(1:5) %>%
    select(PLN_AREA_N, Rank = .data[[colname]])
}


# ============================================================
# 7A) TOP 5 BY INDIVIDUAL FACTORS
# ============================================================
top5_mrt     <- rank_top5(rank_df, "prop_mrt_pct")
top5_bus     <- rank_top5(rank_df, "prop_bus_pct")
top5_school  <- rank_top5(rank_df, "prop_school_pct")
top5_hawker  <- rank_top5(rank_df, "prop_hawker_pct")
top5_super   <- rank_top5(rank_df, "prop_super_pct")
top5_clinic  <- rank_top5(rank_df, "prop_clinic_pct")
#top5_park400 <- rank_top5(rank_df, "prop_park_pct")
top5_sports  <- rank_top5(rank_df, "prop_sports_pct")
top5_parking <- rank_top5(rank_df, "prop_parking_pct")

if (has_parkconn) {
  top5_parkconn <- rank_top5(rank_df, "prop_parkconn_pct")
}

# ============================================================
# 7D) ENVIRONMENT SCORE (Park 2000 + Park Connector)
# ============================================================

# Start with park2000 only
env_cols <- c("prop_park1000_pct")

# Add park connector if available
if (has_parkconn && "prop_parkconn_pct" %in% names(rank_df)) {
  env_cols <- c(env_cols, "prop_parkconn_pct")
}

# Compute score
rank_df$environment_score <- rowSums(rank_df[, env_cols], na.rm = TRUE)



# ============================================================
# 7C) TRANSPORT SCORE (MRT + BUS)
# ============================================================

rank_df$transport_score <- rank_df$prop_mrt_pct + rank_df$prop_bus_pct

top5_transport <- rank_df %>%
  arrange(desc(transport_score)) %>%
  slice(1:5) %>%
  select(PLN_AREA_N, transport_score)


# ============================================================
# 7D) ENVIRONMENT SCORE (Park 400 + Park 2000 + Park Connector)
# ============================================================

#env_cols <- c("prop_park_pct")   # 400m park

if ("prop_park1000_pct" %in% names(rank_df)) {
  env_cols <- c(env_cols, "prop_park1000_pct")
}

if (has_parkconn) {
  env_cols <- c(env_cols, "prop_parkconn_pct")
}

rank_df$environment_score <- rowSums(rank_df[env_cols], na.rm = TRUE)

top5_environment <- rank_df %>%
  arrange(desc(environment_score)) %>%
  slice(1:5) %>%
  select(PLN_AREA_N, environment_score)


# ============================================================
# 7E) AMENITIES SCORE (Everything except MRT/BUS & Environment)
# ============================================================

amenity_cols <- c(
  "prop_school_pct", "prop_hawker_pct",
  "prop_super_pct", "prop_clinic_pct",
  "prop_sports_pct", "prop_parking_pct"
)

rank_df$amenities_score <- rowSums(rank_df[amenity_cols], na.rm = TRUE)

top5_amenities <- rank_df %>%
  arrange(desc(amenities_score)) %>%
  slice(1:5) %>%
  select(PLN_AREA_N, amenities_score)


# ============================================================
# 7F) PRINT RESULTS
# ============================================================

cat("\n================ TOP 5 BY FACTOR ================\n")
print(list(
  MRT = top5_mrt,
  Bus = top5_bus,
  School = top5_school,
  Hawker = top5_hawker,
  Supermarket = top5_super,
  Clinic = top5_clinic,
  #Park_400m = top5_park400,
  Sports = top5_sports,
  Parking = top5_parking,
  Park_Connector = if (has_parkconn) top5_parkconn else "No park connector layer"
))

cat("\n================ TOP 5 TRANSPORT =================\n")
print(top5_transport)

cat("\n================ TOP 5 ENVIRONMENT ================\n")
print(top5_environment)

cat("\n================ TOP 5 AMENITIES =================\n")
print(top5_amenities)

cat("\n================ TOP 5 OVERALL (ALL FACTORS) ================\n")
print(top5_combined)

# ============================================================
# COMBINED ACCESSIBILITY SCORE MAP
# ============================================================

# 1) Identify all proportion (%) columns we want to combine
candidate_cols <- c(
  "prop_mrt_pct", "prop_bus_pct",
  "prop_school_pct", "prop_hawker_pct", "prop_super_pct",
  "prop_clinic_pct",
  "prop_park_pct",         # if using single park
  #"prop_park400_pct",      # if using 400m park
  "prop_park1000_pct",     # if using 2km park
  "prop_parkconn_pct",     # if park connector exists
  "prop_sports_pct", "prop_parking_pct"
)

all_factor_cols <- intersect(candidate_cols, names(pa_map))

# 2) Create combined accessibility score (sum of proportions)
pa_map <- pa_map %>%
  mutate(
    combined_score = rowSums(across(all_of(all_factor_cols)), na.rm = TRUE)
  )

# Quick check of range
summary(pa_map$combined_score)

# 3) Choropleth of combined accessibility
tm_shape(pa_map) +
  tm_polygons(
    "combined_score",
    palette = "YlGnBu",
    style   = "cont",
    title   = "Combined Score\n(sum of % within buffers)",
    colorNA = "grey90"
  ) +
  tm_layout(
    main.title     = "Combined Factors HDB Transactions (All Factors)",
    legend.outside = TRUE
  )


# List of factors and their corresponding pa_scores columns
factor_list <- list(
  MRT         = "prop_mrt_pct",
  Bus         = "prop_bus_pct",
  School      = "prop_school_pct",
  Hawker      = "prop_hawker_pct",
  Supermarket = "prop_super_pct",
  Clinic      = "prop_clinic_pct",
  Park2000    = "prop_park2000_pct",
  ParkConn    = "prop_parkconn_pct",
  Sports      = "prop_sports_pct",
  Parking     = "prop_parking_pct"
)

all_pa <- nrow(pa_scores)

summarize_factor <- function(name, col) {
  
  cat("\n====================== ", name, " ======================\n")
  
  # extract and sort
  df <- pa_scores %>%
    select(PLN_AREA_N, !!col) %>%
    arrange(desc(.data[[col]]))
  
  print(df)
  
  # Count 100% coverage
  n100 <- sum(df[[col]] == 100, na.rm = TRUE)
  pct100 <- round(100 * n100 / all_pa, 1)
  
  cat("\n➡ ", n100, "out of", all_pa,
      "planning areas have **100% accessibility** (", pct100, "%)\n", sep = " ")
  
  # If <25% have full accessibility, also look at >90%
  if (pct100 < 25) {
    n90 <- sum(df[[col]] > 90, na.rm = TRUE)
    n90_only <- n90 - n100  # exclude 100% group
    
    pct90 <- round(100 * n90 / all_pa, 1)
    pct90_only <- round(100 * n90_only / all_pa, 1)
    
    cat("➡ Since this is <25%, also examining >90% accessibility:\n")
    cat("   -", n90, "areas (", pct90, "%) have >90% accessibility\n")
    cat("   -", n90_only, "areas (", pct90_only, "%) fall between 90–99%\n\n")
  } else {
    cat("➡ More than 25% have full coverage — >90% breakdown not required.\n")
  }
  
  return(df)
}

summarize_factor <- function(name, col) {
  
  cat("\n====================== ", name, " ======================\n")
  
  # extract and sort
  df <- pa_scores %>%
    select(PLN_AREA_N, !!col) %>%
    arrange(desc(.data[[col]]))
  
  print(df)
  
  # Count 100% coverage
  n100 <- sum(df[[col]] == 100, na.rm = TRUE)
  pct100 <- round(100 * n100 / all_pa, 1)
  
  cat("\n➡ ", n100, "out of", all_pa,
      "planning areas have **100% accessibility** (", pct100, "%)\n", sep = " ")
  
  # If <25% have full accessibility, also look at >90%
  if (pct100 < 25) {
    n90 <- sum(df[[col]] > 90, na.rm = TRUE)
    n90_only <- n90 - n100  # exclude 100% group
    
    pct90 <- round(100 * n90 / all_pa, 1)
    pct90_only <- round(100 * n90_only / all_pa, 1)
    
    cat("➡ Since this is <25%, also examining >90% accessibility:\n")
    cat("   -", n90, "areas (", pct90, "%) have >90% accessibility\n")
    cat("   -", n90_only, "areas (", pct90_only, "%) fall between 90–99%\n\n")
  } else {
    cat("➡ More than 25% have full coverage — >90% breakdown not required.\n")
  }
  
  return(df)
}

full_tables <- lapply(names(factor_list), function(nm) {
  summarize_factor(nm, factor_list[[nm]])
})

names(full_tables) <- names(factor_list)




install.packages("nngeo")   # <- uncomment this once if you haven't installed
library(nngeo)

# ============================================================
# NEAREST DISTANCE TO EACH AMENITY (per HDB) — FIXED VERSION
# ============================================================

# Build a list of amenity layers for distance calc (all already st_zm above)
amenity_sfs <- list(
  mrt         = mrt,
  bus         = bus,
  schools     = schools,
  hawker      = hawkers,
  supermarket = supermarkets,
  clinic      = chas_clinics,
  park        = parks,
  sports      = sports_fac,
  parking     = parking_ura
)

if (exists("park_connectors")) {
  amenity_sfs$parkconn <- park_connectors
}

# Make sure we have nngeo
# install.packages("nngeo")    # run once if not installed
library(nngeo)

# Compute nearest distances (m) HDB -> each amenity
for (nm in names(amenity_sfs)) {
  cat("Computing nearest distance (m) from HDB to:", nm, "...\n")
  
  # Ensure same CRS & 2D just in case
  tgt <- amenity_sfs[[nm]] %>%
    st_transform(st_crs(hdb)) %>%
    st_zm()
  
  nn <- nngeo::st_nn(hdb, tgt, k = 1, returnDist = TRUE)
  
  hdb[[paste0("dist_", nm)]] <- sapply(
    nn$dist,
    function(x) ifelse(length(x) == 0, NA_real_, x[1])
  )
}

# Quick sanity check:
# summary(hdb$dist_supermarket)
# summary(hdb$dist_hawker)

# ============================================================
# MEAN DISTANCE PER PLANNING AREA
# ============================================================

hdb_pa_dist <- st_join(hdb, pa, left = TRUE)

dist_pa <- hdb_pa_dist %>%
  st_drop_geometry() %>%
  group_by(PLN_AREA_N) %>%
  summarise(
    mean_dist_mrt         = mean(dist_mrt,         na.rm = TRUE),
    mean_dist_bus         = mean(dist_bus,         na.rm = TRUE),
    mean_dist_schools     = mean(dist_schools,     na.rm = TRUE),
    mean_dist_hawker      = mean(dist_hawker,      na.rm = TRUE),
    mean_dist_supermarket = mean(dist_supermarket, na.rm = TRUE),
    mean_dist_clinic      = mean(dist_clinic,      na.rm = TRUE),
    mean_dist_park        = mean(dist_park,        na.rm = TRUE),
    mean_dist_sports      = mean(dist_sports,      na.rm = TRUE),
    mean_dist_parking     = mean(dist_parking,     na.rm = TRUE),
    mean_dist_parkconn    = if ("dist_parkconn" %in% names(hdb))
      mean(dist_parkconn, na.rm = TRUE) else NA_real_
  )

# -----------------------------
# Helper: Top 5 smallest mean distance
# -----------------------------
rank_dist_top5 <- function(df, colname, label) {
  df %>%
    arrange(.data[[colname]]) %>%
    slice(1:5) %>%
    select(PLN_AREA_N, !!label := .data[[colname]])
}

top5_dist_mrt   <- rank_dist_top5(dist_pa, "mean_dist_mrt",   "mean_dist_m_mrt")
top5_dist_bus   <- rank_dist_top5(dist_pa, "mean_dist_bus",   "mean_dist_m_bus")
top5_dist_school<- rank_dist_top5(dist_pa, "mean_dist_schools","mean_dist_m_school")
top5_dist_hawker<- rank_dist_top5(dist_pa, "mean_dist_hawker","mean_dist_m_hawker")
top5_dist_super <- rank_dist_top5(dist_pa, "mean_dist_supermarket","mean_dist_m_supermarket")
top5_dist_clinic<- rank_dist_top5(dist_pa, "mean_dist_clinic","mean_dist_m_clinic")
top5_dist_park  <- rank_dist_top5(dist_pa, "mean_dist_park", "mean_dist_m_park")
top5_dist_sports<- rank_dist_top5(dist_pa, "mean_dist_sports","mean_dist_m_sports")
top5_dist_parking<-rank_dist_top5(dist_pa, "mean_dist_parking","mean_dist_m_parking")

if ("mean_dist_parkconn" %in% names(dist_pa) &&
    any(!is.na(dist_pa$mean_dist_parkconn))) {
  top5_dist_parkconn <- rank_dist_top5(dist_pa, "mean_dist_parkconn","mean_dist_m_parkconn")
} else {
  top5_dist_parkconn <- "Park connector distances not available."
}

cat("\n============= TOP 5 (DISTANCE-BASED) BY FACTOR =============\n")
print(list(
  MRT         = top5_dist_mrt,
  Bus         = top5_dist_bus,
  Schools     = top5_dist_school,
  Hawker      = top5_dist_hawker,
  Supermarket = top5_dist_super,
  Clinic      = top5_dist_clinic,
  Park        = top5_dist_park,
  Sports      = top5_dist_sports,
  Parking     = top5_dist_parking,
  ParkConnector = top5_dist_parkconn
))

# ============================================================
# OVERALL DISTANCE-BASED ACCESSIBILITY SCORE
# (smaller distances -> better accessibility)
# ============================================================

distance_cols <- intersect(
  c("mean_dist_mrt", "mean_dist_bus", "mean_dist_schools",
    "mean_dist_hawker", "mean_dist_supermarket", "mean_dist_clinic",
    "mean_dist_park", "mean_dist_sports", "mean_dist_parking",
    "mean_dist_parkconn"),
  names(dist_pa)
)

dist_pa <- dist_pa %>%
  mutate(
    # Simple score: negative sum of mean distances
    distance_score = -rowSums(across(all_of(distance_cols)), na.rm = TRUE)
  )

top5_distance_overall <- dist_pa %>%
  arrange(desc(distance_score)) %>%
  slice(1:5) %>%
  select(PLN_AREA_N, distance_score)

cat("\n============= TOP 5 OVERALL (DISTANCE-BASED) =============\n")
print(top5_distance_overall)

# List of factors and their corresponding pa_scores columns
factor_list <- list(
  MRT         = "prop_mrt_pct",
  Bus         = "prop_bus_pct",
  School      = "prop_school_pct",
  Hawker      = "prop_hawker_pct",
  Supermarket = "prop_super_pct",
  Clinic      = "prop_clinic_pct",
  Park2000    = "prop_park2000_pct",
  ParkConn    = "prop_parkconn_pct",
  Sports      = "prop_sports_pct",
  Parking     = "prop_parking_pct"
)

all_pa <- nrow(pa_scores)

summarize_factor <- function(name, col) {
  
  cat("\n====================== ", name, " ======================\n")
  
  # extract and sort
  df <- pa_scores %>%
    select(PLN_AREA_N, !!col) %>%
    arrange(desc(.data[[col]]))
  
  print(df)
  
  # Count 100% coverage
  n100 <- sum(df[[col]] == 100, na.rm = TRUE)
  pct100 <- round(100 * n100 / all_pa, 1)
  
  cat("\n➡ ", n100, "out of", all_pa,
      "planning areas have **100% accessibility** (", pct100, "%)\n", sep = " ")
  
  # If <25% have full accessibility, also look at >90%
  if (pct100 < 25) {
    n90 <- sum(df[[col]] > 90, na.rm = TRUE)
    n90_only <- n90 - n100  # exclude 100% group
    
    pct90 <- round(100 * n90 / all_pa, 1)
    pct90_only <- round(100 * n90_only / all_pa, 1)
    
    cat("➡ Since this is <25%, also examining >90% accessibility:\n")
    cat("   -", n90, "areas (", pct90, "%) have >90% accessibility\n")
    cat("   -", n90_only, "areas (", pct90_only, "%) fall between 90–99%\n\n")
  } else {
    cat("➡ More than 25% have full coverage — >90% breakdown not required.\n")
  }
  
  return(df)
}

full_tables <- lapply(names(factor_list), function(nm) {
  summarize_factor(nm, factor_list[[nm]])
})

names(full_tables) <- names(factor_list)

