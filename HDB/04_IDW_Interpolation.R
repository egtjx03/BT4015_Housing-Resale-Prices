# IDW INTERPOLATION (4-ROOM) 

library(sf)
library(dplyr)
library(gstat)
library(stars)
library(tmap)


# 1) File paths  

base        <- "C:/Users/egtay/OneDrive/Desktop/BT4015_Housing-Resale-Prices/Datasets"

txn_geo     <- file.path(base, "transactions_with_lonlat.geojson")
pa_geo      <- file.path(base, "MasterPlan2019PlanningAreaBoundaryNoSea.geojson")
landuse_geo <- file.path(base, "MasterPlan2019LandUselayer (1).geojson")  


# 2) Read data

hdb      <- st_read(txn_geo,     quiet = TRUE)
pa_raw   <- st_read(pa_geo,      quiet = TRUE)
lu_raw   <- st_read(landuse_geo, quiet = TRUE)   

price_col <- "resale_price"  # change if needed
stopifnot(price_col %in% names(hdb))


# 3) Filter to 4-ROOM & clean

hdb_4room <- hdb %>%
  filter(flat_type == "4 ROOM") %>%
  filter(!is.na(.data[[price_col]])) %>%
  filter(!st_is_empty(geometry))

hdb_4room[[price_col]] <- as.numeric(hdb_4room[[price_col]])


# 4) Reproject everything to SVY21 (EPSG:3414)

to_crs <- 3414

hdb_4room_3414 <- st_transform(hdb_4room, crs = to_crs)
pa_3414        <- st_transform(pa_raw,    crs = to_crs)
lu_3414        <- st_transform(lu_raw,    crs = to_crs)


# 5) Create prediction grid over Singapore land extent

cell_size <- 200  # metres

bb <- st_bbox(lu_3414)   # full SG land extent

grid_df <- expand.grid(
  x = seq(bb["xmin"], bb["xmax"], by = cell_size),
  y = seq(bb["ymin"], bb["ymax"], by = cell_size)
)

grid_sf <- st_as_sf(grid_df, coords = c("x", "y"), crs = to_crs)


# 6) IDW interpolation

idw_g <- gstat::gstat(
  formula = as.formula(paste(price_col, "~ 1")),
  data    = hdb_4room_3414,
  nmax    = 15,
  set     = list(idp = 2)   # power parameter
)

idw_pred <- predict(idw_g, newdata = grid_sf) 

# 7) Convert to stars raster
idw_rast <- st_rasterize(
  idw_pred["var1.pred"],
  dx = cell_size,
  dy = cell_size
)


# 8) Clip IDW raster to planning-area polygons using crop()

library(terra)

# Union all planning areas into one polygon
pa_union <- st_union(pa_3414)

# Convert stars → terra
idw_terra <- rast(idw_rast)
names(idw_terra) <- "var1.pred"   

# Convert polygon to terra vect
pa_union_vect <- vect(pa_union)

# Crop AND mask: keep only cells inside polygon
idw_clipped_terra <- crop(idw_terra, pa_union_vect, mask = TRUE)

# Convert back to stars for tmap
idw_clipped <- st_as_stars(idw_clipped_terra)


# 9) Plot – interpolation over land
tmap_mode("plot")

tm_shape(pa_3414) +   
  tm_polygons(
    col        = "grey90",
    border.col = "grey80",
    lwd        = 0.5
  ) +
  tm_shape(idw_clipped) +   # INTERPOLATED PRICES (clipped)
  tm_raster(
    col       = "var1.pred",
    style     = "cont",
    palette   = "YlOrRd",
    alpha     = 0.85,
    colorNA   = NA,          # << NA cells fully transparent
    title     = "Interpolated Resale Price (4-Room)"
  ) +
  tm_shape(pa_3414) +       
  tm_borders(
    col = "grey40",
    lwd = 0.4
  ) +
  tm_shape(hdb_4room_3414) +  # transaction points
  tm_dots(
    size        = 0.03,
    col         = price_col,
    style       = "cont",
    palette     = "Greys",
    alpha       = 0.6,
    legend.show = FALSE
  ) +
  tm_layout(
    main.title              = "IDW-Interpolated HDB Resale Prices (4-Room Flats)",
    legend.outside          = TRUE,
    legend.outside.position = "left"
  )
