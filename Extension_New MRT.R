# =========================================================
# PRICE UPLIFT PER KM CLOSER TO MRT
# Using:
#   - Transactions → estimate elasticity
#   - HDBExistingBuilding → apply effect to new vs old estates
# =========================================================

library(sf)
library(dplyr)
library(stringr)

sf_use_s2(FALSE)

# ---------------------------------------------------------
# 1) FILE PATHS
# ---------------------------------------------------------
base <- "C:/Users/egtay/OneDrive/Desktop/BT4015_Housing-Resale-Prices/Datasets"

txn_path   <- file.path(base, "transactions_with_lonlat.geojson")
mrt_path   <- file.path(base, "LTAMRTStationExitGEOJSON.geojson")
pa_path    <- file.path(base, "MasterPlan2019PlanningAreaBoundaryNoSea.geojson")
bldg_path  <- file.path(base, "HDBExistingBuilding (1).geojson")

# ---------------------------------------------------------
# 2) LOAD DATA
# ---------------------------------------------------------
txn   <- st_read(txn_path, quiet = TRUE)
mrt   <- st_read(mrt_path, quiet = TRUE)
pa_raw <- st_read(pa_path, quiet = TRUE)
bldg  <- st_read(bldg_path, quiet = TRUE)

if ("flat_type" %in% names(hdb)) {
  hdb <- hdb %>% filter(flat_type == "4 ROOM")
} else {
  stop("Column 'flat_type' not found in HDB dataset. Check column names with names(hdb).")
}

# ---------------------------------------------------------
# 3) CLEAN PLANNING AREAS (EXTRACT PLN_AREA_N)
# ---------------------------------------------------------
pa <- pa_raw %>%
  mutate(
    PLN_AREA_N = str_match(
      Description,
      "(?is)<th>\\s*PLN_AREA_N\\s*</th>\\s*<td>\\s*([^<]+?)\\s*</td>"
    )[, 2] %>% str_squish()
  ) %>%
  select(PLN_AREA_N, geometry)

if ("flat_type" %in% names(hdb)) {
  hdb <- hdb %>% filter(flat_type == "4 ROOM")
} else {
  stop("Column 'flat_type' not found in HDB dataset. Check column names with names(hdb).")
}

# ---------------------------------------------------------
# 4) REPROJECT EVERYTHING TO EPSG:3414
# ---------------------------------------------------------
to_crs <- 3414

txn  <- st_transform(txn,  to_crs)
mrt  <- st_transform(mrt,  to_crs)
pa   <- st_transform(pa,   to_crs)
bldg <- st_transform(bldg, to_crs)

# ---------------------------------------------------------
# 5) ESTIMATE PRICE ELASTICITY PER KM TO MRT (TRANSACTIONS)
# ---------------------------------------------------------

# Distance from each transaction to nearest existing MRT (meters)
idx_txn_mrt  <- st_nearest_feature(txn, mrt)
dist_txn_mrt <- st_distance(txn, mrt[idx_txn_mrt, ], by_element = TRUE)
txn$dist_mrt_km <- as.numeric(dist_txn_mrt) / 1000

# Detect price column
price_candidates <- c("resale_price", "price", "PRICE",
                      "TransactedPrice", "transacted_price")
price_col <- price_candidates[price_candidates %in% names(txn)][1]
if (is.na(price_col)) stop("Could not find a price column in txn.")

# Basic hedonic model (adjust controls as needed)
txn_df <- txn %>%
  st_drop_geometry() %>%
  filter(
    flat_type == "4 ROOM",  
    !is.na(.data[[price_col]]),
    !is.na(dist_mrt_km),
    !is.na(floor_area_sqm),
    !is.na(remaining_lease)
  ) %>%
  mutate(log_price = log(.data[[price_col]]))

mrt_model <- lm(
  log_price ~ dist_mrt_km +
    floor_area_sqm +
    remaining_lease,
  data = txn_df
)

summary(mrt_model)

beta_dist <- coef(mrt_model)["dist_mrt_km"]
cat("\nEstimated coefficient for distance to MRT (km):", beta_dist, "\n")

# For small changes, % uplift ≈ 100*(exp(-beta_dist * Δdist) - 1)
price_uplift_pct <- function(delta_km) {
  100 * (exp(-beta_dist * delta_km) - 1)
}

# ---------------------------------------------------------
# 6) HDB BUILDINGS — CURRENT DISTANCE TO MRT
# ---------------------------------------------------------

# Distance from each building to nearest existing MRT
idx_bldg_mrt  <- st_nearest_feature(bldg, mrt)
dist_bldg_now <- st_distance(bldg, mrt[idx_bldg_mrt, ], by_element = TRUE)

bldg$dist_now_km <- as.numeric(dist_bldg_now) / 1000

# ---------------------------------------------------------
# 7) DEFINE FUTURE MRT STATIONS (Tengah & West Coast)
#    → EDIT THESE COORDINATES IF YOU HAVE BETTER ONES
# ---------------------------------------------------------
future_mrt_df <- data.frame(
  station = c("Tengah (Future)", "West Coast (Future)"),
  lon     = c(103.73007, 103.75778),  # longitudes
  lat     = c(1.36633,  1.31083)      # latitudes
)

future_mrt_sf <- st_as_sf(
  future_mrt_df,
  coords = c("lon", "lat"),
  crs    = 4326
) %>%
  st_transform(to_crs)

tengah_sf    <- future_mrt_sf[future_mrt_sf$station == "Tengah (Future)", ]
westcoast_sf <- future_mrt_sf[future_mrt_sf$station == "West Coast (Future)", ]

# Align new station sf to MRT schema to allow rbind
align_to_mrt <- function(new_sf, mrt_sf) {
  out <- new_sf
  missing_cols <- setdiff(names(mrt_sf), names(out))
  for (cl in missing_cols) {
    out[[cl]] <- NA
  }
  out <- out[, names(mrt_sf)]
  out
}

tengah_sf_aligned    <- align_to_mrt(tengah_sf,    mrt)
westcoast_sf_aligned <- align_to_mrt(westcoast_sf, mrt)

# ---------------------------------------------------------
# 8) DISTANCE AFTER ADDING TENGAH (NEW ESTATE STATION)
# ---------------------------------------------------------
mrt_with_tengah <- rbind(mrt, tengah_sf_aligned)

idx_bldg_tengah  <- st_nearest_feature(bldg, mrt_with_tengah)
dist_after_tengah <- st_distance(bldg, mrt_with_tengah[idx_bldg_tengah, ], by_element = TRUE)

bldg$dist_after_tengah_km <- as.numeric(dist_after_tengah) / 1000

# ---------------------------------------------------------
# 9) DISTANCE AFTER ADDING WEST COAST (OLD ESTATE STATION)
# ---------------------------------------------------------
mrt_with_west <- rbind(mrt, westcoast_sf_aligned)

idx_bldg_west  <- st_nearest_feature(bldg, mrt_with_west)
dist_after_west <- st_distance(bldg, mrt_with_west[idx_bldg_west, ], by_element = TRUE)

bldg$dist_after_west_km <- as.numeric(dist_after_west) / 1000

# ---------------------------------------------------------
# 10) DISTANCE REDUCTION & PREDICTED PRICE UPLIFT (%)
# ---------------------------------------------------------
bldg <- bldg %>%
  mutate(
    delta_tengah_km = pmax(dist_now_km - dist_after_tengah_km, 0),
    delta_west_km   = pmax(dist_now_km - dist_after_west_km,   0),
    uplift_tengah_pct = price_uplift_pct(delta_tengah_km),
    uplift_west_pct   = price_uplift_pct(delta_west_km)
  )
bldg

# ---------------------------------------------------------
# 11) ASSIGN PLANNING AREA TO BUILDINGS
# ---------------------------------------------------------
bldg_pa <- st_join(bldg, pa, left = TRUE)

# ---------------------------------------------------------
# 12) SUMMARY BY PLANNING AREA
#     → Compare how much uplift (per km) new vs old station gives
# ---------------------------------------------------------
uplift_pa <- bldg_pa %>%
  st_drop_geometry() %>%
  group_by(PLN_AREA_N) %>%
  summarise(
    avg_dist_now_km     = mean(dist_now_km,       na.rm = TRUE),
    avg_delta_tengah_km = mean(delta_tengah_km,   na.rm = TRUE),
    avg_delta_west_km   = mean(delta_west_km,     na.rm = TRUE),
    avg_uplift_tengah   = mean(uplift_tengah_pct, na.rm = TRUE),
    avg_uplift_west     = mean(uplift_west_pct,   na.rm = TRUE),
    n_blocks            = n()
  ) %>%
  arrange(desc(avg_uplift_tengah))

cat("\n===== UPLIFT BY PLANNING AREA (USING BUILDING DATA) =====\n")
print(uplift_pa)

# ---------------------------------------------------------
# 13) FOCUS ON NEW ESTATE vs OLD ESTATE
#     → EDIT THESE PA NAMES ACCORDING TO YOUR DATA
# ---------------------------------------------------------

# Example guesses (change these to match your actual PLN_AREA_N values)
new_estate_pas <- c("TENGAH")       # or any PA(s) representing new estate
old_estate_pas <- c("WEST COAST", "CLEMENTI")  # example mature areas

uplift_new_estate <- uplift_pa %>%
  filter(PLN_AREA_N %in% new_estate_pas)

uplift_old_estate <- uplift_pa %>%
  filter(PLN_AREA_N %in% old_estate_pas)

cat("\n===== NEW ESTATE (TENGAH AREA) BLOCK UPLIFT =====\n")
print(uplift_new_estate)

cat("\n===== OLD ESTATE (WEST COAST / CLEMENTI AREA) BLOCK UPLIFT =====\n")
print(uplift_old_estate)

# Optional ratio comparison
cat("\n===== COMPARISON: NEW vs OLD ESTATE (avg % uplift) =====\n")
mean_new <- mean(uplift_new_estate$avg_uplift_tengah, na.rm = TRUE)
mean_old <- mean(uplift_old_estate$avg_uplift_west,   na.rm = TRUE)

cat(sprintf("Average uplift in new estate (Tengah side): %0.2f%%\n", mean_new))
cat(sprintf("Average uplift in old estate (West Coast side): %0.2f%%\n", mean_old))

