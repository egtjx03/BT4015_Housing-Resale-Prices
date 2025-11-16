# L & G functions

# 1) Libraries

library(sf)
library(dplyr)
library(spatstat.geom)
library(spatstat.explore)

sf_use_s2(FALSE)


# 2) File paths 

base <- "C:/Users/egtay/OneDrive/Desktop/BT4015_Housing-Resale-Prices/Datasets"

txn_csv <- file.path(base, "transactions_with_lonlat.geojson")

paths <- list(
  planning_areas      = file.path(base, "MasterPlan2019PlanningAreaBoundaryNoSea.geojson"),
  mrt_exits           = file.path(base, "LTAMRTStationExitGEOJSON.geojson"),
  supermarkets        = file.path(base, "SupermarketsGEOJSON.geojson"),
  hawkers             = file.path(base, "HawkerCentresGEOJSON.geojson"),
  sports              = file.path(base, "SportSGSportFacilitiesGEOJSON.geojson"),
  chas_clinics        = file.path(base, "CHASClinics.geojson"),
  parks               = file.path(base, "NParksParksandNatureReserves.geojson"),
  parking_ura         = file.path(base, "URAParkingLotGEOJSON.geojson"),
  schools             = file.path(base, "Schools_information_with_loc.geojson"),
  bus_path            = file.path(base, "LTABusStop.geojson")
)

park_connector_path <- file.path(
  base,
  "SDCPParkConnectorLineSHP",
  "G_MP08_PK_CONECTR_LI.shp"
)


# 3) Read data as sf

hdb   <- st_read(txn_csv,                  quiet = TRUE)  # HDB transactions
pa    <- st_read(paths$planning_areas,     quiet = TRUE)  # planning areas
mrt   <- st_read(paths$mrt_exits,          quiet = TRUE)  # MRT exits
bus   <- st_read(paths$bus_path,           quiet = TRUE)  # Bus stops
supermarkets <- st_read(paths$supermarkets,quiet = TRUE)
hawkers      <- st_read(paths$hawkers,     quiet = TRUE)
sports_fac   <- st_read(paths$sports,      quiet = TRUE)
chas_clinics <- st_read(paths$chas_clinics,quiet = TRUE)
parks        <- st_read(paths$parks,       quiet = TRUE)
parking_ura  <- st_read(paths$parking_ura, quiet = TRUE)
schools      <- st_read(paths$schools,     quiet = TRUE)

# Park connectors (line data; not used for point L/G, but loaded for completeness)
park_connectors <- st_read(park_connector_path, quiet = TRUE)


# 4) Reproject everything to EPSG:3414 (SVY21)

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
park_connectors <- st_transform(park_connectors, to_crs)


# 5) Filter HDB to 4 ROOM only

if ("flat_type" %in% names(hdb)) {
  hdb <- hdb %>% filter(flat_type == "4 ROOM")
} else {
  stop("Column 'flat_type' not found in HDB dataset.")
}
cat("HDB 4-Room points:", nrow(hdb), "\n")


# 6) Create study window from planning areas

pa_union <- st_union(pa)           # sfc_MULTIPOLYGON
win      <- as.owin(st_as_sf(pa_union))  # convert to spatstat window


# 7) Helper: convert sf POINT -> ppp

sf_to_ppp <- function(sf_points, win) {
  sf_points <- sf_points[!st_is_empty(sf_points), ]
  coords <- st_coordinates(sf_points)
  if (nrow(coords) == 0) {
    stop("No points in sf object for conversion to ppp.")
  }
  ppp(
    x      = coords[, 1],
    y      = coords[, 2],
    window = win,
    check  = FALSE
  )
}


# 8) Build list of point patterns for L/G analysis
#     (park connectors are LINES -> not included here)

pp_list <- list(
  HDB_4room    = sf_to_ppp(hdb,          win),
  MRT          = sf_to_ppp(mrt,          win),
  BusStops     = sf_to_ppp(bus,          win),
  Supermarkets = sf_to_ppp(supermarkets, win),
  Hawkers      = sf_to_ppp(hawkers,      win),
  Sports       = sf_to_ppp(sports_fac,   win),
  Clinics      = sf_to_ppp(chas_clinics, win),
  Schools      = sf_to_ppp(schools,      win),
  ParkingURA   = sf_to_ppp(parking_ura,  win)
)


# 9) Helper: choose pattern (full or thinned) to avoid memory issues

# Try Gest on full; if memory error, thin to n_max points and retry
pick_pp_for_envelope <- function(pp, nm, rmax = 600, nrval = 100, n_max = 4000) {
  n <- npoints(pp)
  cat("  Points in pattern:", n, "\n")
  
  # Remove marks, if any
  pp <- unmark(pp)
  
  try_GL <- function(pp_use) {
    Gest(pp_use, correction = "rs", rmax = rmax, nrval = nrval)
  }
  
  # Try full pattern
  ok_full <- !inherits(try(try_GL(pp), silent = TRUE), "try-error")
  if (ok_full) {
    cat("  -> Using FULL pattern for envelopes.\n")
    return(pp)
  }
  
  cat("  -> Memory error on full pattern. Trying thinning...\n")
  
  if (n <= n_max) {
    stop("Pattern ", nm, " has <= ", n_max, " points but still fails G; cannot proceed.")
  }
  
  # Thin by random subsample
  idx <- sample.int(n, n_max)
  pp_small <- pp[idx]
  
  ok_small <- !inherits(try(try_GL(pp_small), silent = TRUE), "try-error")
  if (!ok_small) {
    stop("Even thinned pattern for ", nm, " fails G; reduce rmax/nrval or n_max.")
  }
  
  cat("  -> Using THINNED pattern of", n_max, "points for envelopes.\n")
  pp_small
}

# 10) INDIVIDUAL PLOTS: G & L with CSR envelopes for each pattern

old_par <- par(no.readonly = TRUE)

for (nm in names(pp_list)) {
  cat("\n=== Computing G/L + envelopes for:", nm, "===\n")
  pp <- pp_list[[nm]]
  
  n_pp <- npoints(pp)
  if (n_pp < 5) {
    cat("  -> Skipping", nm, ": < 5 points.\n")
    next
  }
  
  # Choose safe pp (full or thinned)
  pp_use <- pick_pp_for_envelope(pp, nm, rmax = 600, nrval = 100, n_max = 4000)
  
  # CSR envelopes (Monte Carlo)
  cat("  -> Simulating CSR envelopes (nsim = 19)...\n")
  
  G_env <- envelope(
    pp_use,
    Gest,
    nsim       = 19,
    correction = "rs",
    rmax       = 600,
    nrval      = 100,
    verbose    = FALSE,
    savefuns   = FALSE
  )
  
  L_env <- envelope(
    pp_use,
    Lest,
    nsim       = 19,
    correction = "iso",
    rmax       = 600,
    nrval      = 100,
    verbose    = FALSE,
    savefuns   = FALSE
  )
  
  par(mfrow = c(1, 2))
  
  ## ------------------------------------------------------
  ## LEFT: G-function with envelope (formatted like example)
  ## ------------------------------------------------------
  # Extract columns and convert r to km for axis
  rG    <- G_env$r / 1000
  G_obs <- G_env$obs
  G_theo<- G_env$theo
  G_lo  <- G_env$lo
  G_hi  <- G_env$hi
  
  yG_min <- min(c(G_lo, G_hi, G_obs), na.rm = TRUE)
  yG_max <- max(c(G_lo, G_hi, G_obs), na.rm = TRUE)
  
  # Empty plot frame
  plot(range(rG, na.rm = TRUE),
       c(yG_min, yG_max),
       type = "n",
       xlab = "r (km)",
       ylab = "G(r)",
       main = paste("G-function -", nm))
  
  # Grey envelope polygon
  polygon(
    x = c(rG, rev(rG)),
    y = c(G_hi, rev(G_lo)),
    col    = "grey85",
    border = NA
  )
  
  # Theoretical CSR line
  lines(rG, G_theo, col = "red", lwd = 1.5, lty = 2)
  
  # Observed G
  lines(rG, G_obs, col = "black", lwd = 2)
  
  # Legend (top left)
  legend(
    "topleft",
    legend = c(
      expression(hat(G)[obs](r)),
      expression(G[theo](r)),
      expression(hat(G)[hi](r)),
      expression(hat(G)[lo](r))
    ),
    cex    = 0.6, 
    col    = c("black", "red", "grey40", "grey40"),
    lwd    = c(2, 1.5, 1, 1),
    lty    = c(1, 2, 1, 1),
    bty    = "n"
  )
  
  ## ------------------------------------------------------
  ## RIGHT: L-function with envelope (formatted like example)
  ## ------------------------------------------------------
  rL    <- L_env$r / 1000
  L_obs <- L_env$obs
  L_theo<- L_env$theo
  L_lo  <- L_env$lo
  L_hi  <- L_env$hi
  
  yL_min <- min(c(L_lo, L_hi, L_obs), na.rm = TRUE)
  yL_max <- max(c(L_lo, L_hi, L_obs), na.rm = TRUE)
  
  plot(range(rL, na.rm = TRUE),
       c(yL_min, yL_max),
       type = "n",
       xlab = "r (km)",
       ylab = "L(r)",
       main = paste("L-function -", nm))
  
  polygon(
    x = c(rL, rev(rL)),
    y = c(L_hi, rev(L_lo)),
    col    = "grey85",
    border = NA
  )
  
  lines(rL, L_theo, col = "red",   lwd = 1.5, lty = 2)  # CSR theo
  lines(rL, L_obs,  col = "black", lwd = 2)             # observed
  
  legend(
    "topleft",
    legend = c(
      expression(hat(L)[obs](r)),
      expression(L[theo](r)),
      expression(hat(L)[hi](r)),
      expression(hat(L)[lo](r))
    ),
    cex    = 0.6,   
    col    = c("black", "red", "grey40", "grey40"),
    lwd    = c(2, 1.5, 1, 1),
    lty    = c(1, 2, 1, 1),
    bty    = "n"
  )
}

par(old_par)
