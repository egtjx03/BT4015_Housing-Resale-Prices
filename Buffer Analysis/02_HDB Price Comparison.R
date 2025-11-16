# HDB PRICE COMPARISON:
#   Within buffer vs Outside buffer
# Output:
#   - Summary table by factor: mean / median prices in vs out
#   - t-test p-value for difference

# 0) Libraries

library(sf)
library(dplyr)
library(units)
library(stringr)

sf_use_s2(FALSE)


# 1) File paths 

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
  park_connector_path <- file.path(base, "SDCP Park Connector Line (KML).geojson")
)


# 2) Read data as sf

hdb    <- st_read(txn_csv, quiet = TRUE)
pa_raw <- st_read(paths$planning_areas, quiet = TRUE)
mrt    <- st_read(paths$mrt_exits, quiet = TRUE)
bus    <- st_read(paths$bus_path, quiet = TRUE)

supermarkets <- st_read(paths$supermarkets, quiet = TRUE)
hawkers      <- st_read(paths$hawkers, quiet = TRUE)
sports_fac   <- st_read(paths$sports, quiet = TRUE)
chas_clinics <- st_read(paths$chas_clinics, quiet = TRUE)
parks        <- st_read(paths$parks, quiet = TRUE)
parking_ura  <- st_read(paths$parking_ura, quiet = TRUE)
schools      <- st_read(paths$schools, quiet = TRUE)

if ("flat_type" %in% names(hdb)) {
  hdb <- hdb %>% filter(flat_type == "4 ROOM")
} else {
  stop("Column 'flat_type' not found in HDB dataset. Check column names with names(hdb).")
}


# 3) Extract PLN_AREA_N once (if you later want PA grouping)

pa <- pa_raw %>%
  mutate(
    PLN_AREA_N = str_match(
      Description,
      "(?is)<th>\\s*PLN_AREA_N\\s*</th>\\s*<td>\\s*([^<]+?)\\s*</td>"
    )[, 2] %>% str_squish()
  ) %>%
  select(PLN_AREA_N, geometry)


# 4) Reproject everything to EPSG:3414

to_crs <- 3414

hdb          <- st_transform(hdb,          to_crs)
pa           <- st_transform(pa,           to_crs)
mrt          <- st_transform(mrt,          to_crs)
bus          <- st_transform(bus,          to_crs)
supermarkets <- st_transform(supermarkets, to_crs)
hawkers      <- st_transform(hawkers,      to_crs)
sports_fac   <- st_transform(sports_fac,   to_crs)
chas_clinics <- st_transform(chas_clinics, to_crs)
parks        <- st_transform(parks,        to_crs)
parking_ura  <- st_transform(parking_ura,  to_crs)
schools      <- st_transform(schools,      to_crs)
if (has_parkconn) {
  park_connectors <- st_transform(park_connectors, to_crs)
}


# 5) BUFFER SPECIFICATIONS 

amenity_specs <- list(
  mrt         = list(sf = mrt,            dist = 800),
  bus         = list(sf = bus,            dist = 200),
  schools     = list(sf = schools,        dist = 1000),
  hawker      = list(sf = hawkers,        dist = 500),
  supermarket = list(sf = supermarkets,   dist = 800),
  clinic      = list(sf = chas_clinics,   dist = 800),
  park        = list(sf = parks,          dist = 400),
  sports      = list(sf = sports_fac,     dist = 2000),
  parking     = list(sf = parking_ura,    dist = 200)
)

if (has_parkconn) {
  amenity_specs$parkconn <- list(sf = park_connectors, dist = 200)
}


# 6) Create near_* flags (within / outside buffer)

for (nm in names(amenity_specs)) {
  cat("Computing within-distance flag for:", nm, "\n")
  obj  <- amenity_specs[[nm]]
  dmax <- obj$dist
  
  within_list <- st_is_within_distance(hdb, obj$sf, dist = dmax)
  hdb[[paste0("near_", nm)]] <- lengths(within_list) > 0
}


# 7) Detect transaction price column

price_candidates <- c("resale_price", "price", "PRICE",
                      "TransactedPrice", "transacted_price")

price_col <- price_candidates[price_candidates %in% names(hdb)][1]

if (is.na(price_col)) {
  stop("❌ Could not find a price column. 
       Please update 'price_candidates' with the correct column name.")
} else {
  cat("✔ Using price column:", price_col, "\n")
}


# 8) Function to compare prices inside vs outside buffer

compare_price_buffer <- function(df, near_col, price_col, factor_label) {
  inside  <- df %>% filter(.data[[near_col]] == TRUE)
  outside <- df %>% filter(.data[[near_col]] == FALSE)
  
  n_in  <- nrow(inside)
  n_out <- nrow(outside)
  
  mean_in  <- mean(inside[[price_col]],  na.rm = TRUE)
  mean_out <- mean(outside[[price_col]], na.rm = TRUE)
  med_in   <- median(inside[[price_col]],  na.rm = TRUE)
  med_out  <- median(outside[[price_col]], na.rm = TRUE)
  
  # t-test (only if both groups have > 1 obs)
  p_val <- NA_real_
  if (n_in > 1 && n_out > 1) {
    tt <- t.test(inside[[price_col]], outside[[price_col]])
    p_val <- tt$p.value
  }
  
  tibble::tibble(
    factor         = factor_label,
    near_col       = near_col,
    n_inside       = n_in,
    n_outside      = n_out,
    mean_price_in  = mean_in,
    mean_price_out = mean_out,
    median_price_in  = med_in,
    median_price_out = med_out,
    p_value        = p_val
  )
}


# 9) Build comparison table for all factors

near_cols   <- grep("^near_", names(hdb), value = TRUE)
factor_names <- sub("^near_", "", near_cols)

price_comparison <- dplyr::bind_rows(lapply(seq_along(near_cols), function(i) {
  compare_price_buffer(
    df          = hdb,
    near_col    = near_cols[i],
    price_col   = price_col,
    factor_label= factor_names[i]
  )
}))

cat("\n===== PRICE COMPARISON: WITHIN vs OUTSIDE BUFFER =====\n")
print(price_comparison)

# If you want, sort by p-value (strongest differences first)
price_comparison_sorted <- price_comparison %>%
  arrange(p_value)

cat("\n===== PRICE COMPARISON (sorted by p-value) =====\n")
print(price_comparison_sorted)

library(ggplot2)

price_diff <- price_comparison %>%
  mutate(
    diff_mean = mean_price_in - mean_price_out
  )

ggplot(price_diff, aes(x = reorder(factor, diff_mean), y = diff_mean)) +
  geom_segment(aes(xend = factor, y = 0, yend = diff_mean), color="grey60") +
  geom_point(size = 4, color="#1f78b4") +
  coord_flip() +
  labs(
    title = "Mean Price Difference (Inside vs Outside Buffer)",
    subtitle = "Positive = Higher prices inside buffer",
    x = "Factor",
    y = "Difference in Mean Resale Price ($)"
  ) +
  theme_minimal(base_size = 14)



---
# 1) Define your factors 
---
factor_vars <- c(
  "mrt", "bus", "schools", "hawker", "supermarket",
  "clinic", "park2000", "parkconn", "sports", "parking"
)

factor_labels <- c(
  "MRT", "Bus", "Schools", "Hawker", "Supermarket",
  "Clinic", "Park (2km)", "Park Connector", "Sports", "Parking"
)

---
# 2) Compute percentage difference for each factor
---
pct_diff_list <- lapply(factor_vars, function(x) {
  
  inside  <- hdb %>% filter(.data[[paste0("near_", x)]])$resale_price
  outside <- hdb %>% filter(!.data[[paste0("near_", x)]])$resale_price
  
  mean_in  <- mean(inside,  na.rm = TRUE)
  mean_out <- mean(outside, na.rm = TRUE)
  
  # % difference = (inside - outside) / outside * 100
  pct_diff <- (mean_in - mean_out) / mean_out * 100
  
  tibble(
    factor = x,
    mean_inside  = mean_in,
    mean_outside = mean_out,
    pct_diff     = pct_diff
  )
})

pct_diff_df <- bind_rows(pct_diff_list) %>%
  mutate(Factor = factor_labels)

library(ggplot2)

ggplot(pct_diff_df, aes(x = pct_diff, y = reorder(Factor, pct_diff))) +
  geom_point(size = 4, color = "#0072B2") +
  geom_vline(xintercept = 0, linetype = "dashed") +
  labs(
    title = "Percentage Difference in Resale Price (Inside vs Outside Buffer)",
    subtitle = "Positive values = Higher prices for HDBs inside buffer",
    x = "Percentage Difference (%)",
    y = "Factor"
  ) +
  theme_minimal(base_size = 14)


factors <- c("mrt", "bus", "schools", "hawker", "supermarket",
             "clinic", "park", "sports", "parkconn", "parking")

# keep only factors that actually exist as near_* columns
factors <- factors[paste0("near_", factors) %in% names(hdb)]

price_pct_diff <- map_dfr(factors, function(x) {
  inside_vals  <- hdb %>%
    filter(.data[[paste0("near_", x)]]) %>%
    pull(resale_price)
  
  outside_vals <- hdb %>%
    filter(!.data[[paste0("near_", x)]]) %>%
    pull(resale_price)
  
  mean_in  <- mean(inside_vals,  na.rm = TRUE)
  mean_out <- mean(outside_vals, na.rm = TRUE)
  
  pct_diff <- 100 * (mean_in - mean_out) / mean_out
  
  tibble(
    factor       = x,
    mean_inside  = mean_in,
    mean_outside = mean_out,
    pct_diff     = pct_diff
  )
})

price_pct_diff

library(forcats)
ggplot(
  price_pct_diff %>%
    mutate(factor = fct_reorder(factor, pct_diff)),
  aes(x = pct_diff, y = factor)
) +
  # horizontal segment from 0 to pct_diff at each factor
  geom_segment(aes(x = 0, xend = pct_diff, y = factor, yend = factor),
               color = "grey60") +
  geom_vline(xintercept = 0, linetype = "dashed") +
  geom_point(size = 4, color = "#1f78b4") +
  labs(
    title    = "% Price Difference (Inside vs Outside Buffer)",
    subtitle = "Positive = Higher prices inside buffer",
    x        = "Difference in Mean Resale Price (%)",
    y        = "Factor"
  ) +
  theme_minimal(base_size = 16) +
  theme(
    plot.subtitle = element_text(size = 12)
  )

library(dplyr)

lease_col <- dplyr::case_when(
  "remaining_lease"       %in% names(hdb) ~ "remaining_lease",
  TRUE ~ NA_character_
)
lease_col

if (is.na(lease_col)) {
  stop("No remaining_lease or remaining_lease_years column found in hdb.")
}

hdb_school <- hdb %>%
  st_drop_geometry() %>%
  mutate(
    # try to coerce lease to numeric; non-numeric strings become NA
    lease_years_num = suppressWarnings(as.numeric(.data[[lease_col]])),
    school_group    = if_else(near_schools, "Inside school buffer", "Outside school buffer")
  )

school_summary <- hdb_school %>%
  group_by(school_group) %>%
  summarise(
    n_flats            = n(),
    mean_floor_area    = mean(floor_area_sqm, na.rm = TRUE),
    median_floor_area  = median(floor_area_sqm, na.rm = TRUE),
    sd_floor_area      = sd(floor_area_sqm, na.rm = TRUE),
    mean_lease_years   = mean(remaining_lease, na.rm = TRUE),
    median_lease_years = median(remaining_lease, na.rm = TRUE),
    sd_lease_years     = sd(remaining_lease, na.rm = TRUE),
    .groups = "drop"
  )

school_summary


