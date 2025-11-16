library(sf)
library(dplyr)
library(ggplot2)

schools <- read.csv("/Users/sugarcane/Downloads/Schools_information_with_loc.csv")
schools <- na.omit(schools[, c("longitude", "latitude")])
schools_sf <- st_as_sf(schools, coords = c("longitude", "latitude"), crs = 4326, remove = FALSE)
st_write(schools_sf, "/Users/sugarcane/Downloads/bt4015/Schools_information_with_loc.geojson", delete_dsn = TRUE)

hdb <- st_read("/Users/sugarcane/Downloads/bt4015/Datasets/transactions_with_lonlat.geojson")
mrt <- st_read("/Users/sugarcane/Downloads/bt4015/Datasets/LTAMRTStationExitGEOJSON.geojson")
bus <- st_read("/Users/sugarcane/Downloads/bt4015/Datasets/LTABusStop.geojson")
hawkers <- st_read("/Users/sugarcane/Downloads/bt4015/Datasets/HawkerCentresGEOJSON.geojson")
schools <- st_read("/Users/sugarcane/Downloads/bt4015/Datasets/Schools_information_with_loc.geojson")
polyclinics <- st_read("/Users/sugarcane/Downloads/bt4015/Datasets/CHASClinics.geojson")
supermarkets <- st_read("/Users/sugarcane/Downloads/bt4015/Datasets/SupermarketsGEOJSON.geojson")
sports <- st_read("/Users/sugarcane/Downloads/bt4015/Datasets/SportSGSportFacilitiesGEOJSON.geojson")
parking <- st_read("/Users/sugarcane/Downloads/bt4015/Datasets/URAParkingLotGEOJSON.geojson")
parks <- st_read("/Users/sugarcane/Downloads/bt4015/Datasets/NParksParksandNatureReserves.geojson")
parkConnector <- st_read("/Users/sugarcane/Downloads/bt4015/Datasets/SDCPParkConnectorLine/SDCP Park Connector Line (SHP)/G_MP08_PK_CONECTR_LI.shp")

hdb <- hdb %>% filter(flat_type == "4 ROOM")

hdb <- st_transform(hdb, 3414)
mrt <- st_transform(mrt, 3414)
bus <- st_transform(bus, 3414)
hawkers <- st_transform(hawkers, 3414)
schools <- st_transform(schools, 3414)
polyclinics <- st_transform(polyclinics, 3414)
supermarkets <- st_transform(supermarkets, 3414)
sports <- st_transform(sports, 3414)
parking <- st_transform(parking, 3414)
parks <- st_transform(parks, 3414)
parkConnector <- st_transform(parkConnector, 3414)

hdb$dist_mrt <- apply(st_distance(hdb, mrt), 1, min)
hdb$dist_bus <- apply(st_distance(hdb, bus), 1, min)
hdb$dist_hawker <- apply(st_distance(hdb, hawkers), 1, min)
hdb$dist_school <- apply(st_distance(hdb, schools), 1, min)
hdb$dist_polyclinic <- apply(st_distance(hdb, polyclinics), 1, min)
hdb$dist_supermarket <- apply(st_distance(hdb, supermarkets), 1, min)
hdb$dist_sport <- apply(st_distance(hdb, sports), 1, min)
hdb$dist_parking <- apply(st_distance(hdb, parking), 1, min)
hdb$dist_parks <- apply(st_distance(hdb, parking), 1, min)
hdb$dist_parkConnector <- apply(st_distance(hdb, parking), 1, min)

st_write(hdb, "/Users/sugarcane/Downloads/bt4015/hdb_4room_with_distances.geojson", delete_dsn = TRUE)

ggplot(hdb, aes(x = as.numeric(dist_hawker), y = resale_price)) +
  geom_point(alpha = 0.3, color = "steelblue") +
  geom_smooth(method = "lm", se = TRUE, color = "red") +
  labs(
    x = "Distance to nearest hawker (m)",
    y = "Resale Price (SGD)",
    title = "Relationship between HDB price and hawker proximity (4-room only)"
  ) +
  theme_minimal(base_size = 13)

# schools
ggplot(hdb, aes(x = as.numeric(dist_school), y = resale_price)) +
  geom_point(alpha = 0.3, color = "steelblue") +
  geom_smooth(method = "lm", se = TRUE, color = "red") +
  labs(
    x = "Distance to nearest school (m)",
    y = "Resale Price (SGD)",
    title = "Relationship between HDB price and school proximity"
  ) +
  theme_minimal(base_size = 13)

# clinics
ggplot(hdb, aes(x = as.numeric(dist_polyclinic), y = resale_price)) +
  geom_point(alpha = 0.3, color = "steelblue") +
  geom_smooth(method = "lm", se = TRUE, color = "red") +
  labs(
    x = "Distance to nearest polyclinic (m)",
    y = "Resale Price (SGD)",
    title = "Relationship between HDB price and polyclinic proximity"
  ) +
  theme_minimal(base_size = 13)

# supermarket
ggplot(hdb, aes(x = as.numeric(dist_supermarket), y = resale_price)) +
  geom_point(alpha = 0.3, color = "steelblue") +
  geom_smooth(method = "lm", se = TRUE, color = "red") +
  labs(
    x = "Distance to nearest supermarket (m)",
    y = "Resale Price (SGD)",
    title = "Relationship between HDB price and supermarket proximity"
  ) +
  theme_minimal(base_size = 13)

# facility
ggplot(hdb, aes(x = as.numeric(dist_sport), y = resale_price)) +
  geom_point(alpha = 0.3, color = "steelblue") +
  geom_smooth(method = "lm", se = TRUE, color = "red") +
  labs(
    x = "Distance to nearest facility (m)",
    y = "Resale Price (SGD)",
    title = "Relationship between HDB price and facility proximity"
  ) +
  theme_minimal(base_size = 13)

# parking
ggplot(hdb, aes(x = as.numeric(dist_parking), y = resale_price)) +
  geom_point(alpha = 0.3, color = "steelblue") +
  geom_smooth(method = "lm", se = TRUE, color = "red") +
  labs(
    x = "Distance to nearest parking (m)",
    y = "Resale Price (SGD)",
    title = "Relationship between HDB price and parking proximity"
  ) +
  theme_minimal(base_size = 13)

ggplot(hdb, aes(x = as.numeric(dist_parks), y = resale_price)) +
  geom_point(alpha = 0.3, color = "steelblue") +
  geom_smooth(method = "lm", se = TRUE, color = "red") +
  labs(
    x = "Distance to nearest park (m)",
    y = "Resale Price (SGD)",
    title = "Relationship between HDB price and park proximity (4-room only)"
  ) +
  theme_minimal(base_size = 13)

ggplot(hdb, aes(x = as.numeric(dist_parkConnector), y = resale_price)) +
  geom_point(alpha = 0.3, color = "steelblue") +
  geom_smooth(method = "lm", se = TRUE, color = "red") +
  labs(
    x = "Distance to nearest park connector (m)",
    y = "Resale Price (SGD)",
    title = "Relationship between HDB price and park connector proximity (4-room only)"
  ) +
  theme_minimal(base_size = 13)

# OLS
model_4room <- lm(
  resale_price ~ dist_mrt + dist_bus + dist_hawker + dist_school + dist_polyclinic +
    dist_supermarket + dist_sport + dist_parking + dist_parks + dist_parkConnector,
  data = hdb
)

summary(model_4room)

model2 <- lm(
  resale_price ~ dist_hawker + dist_school + dist_polyclinic +
    dist_supermarket + dist_sport + dist_parking +
    floor_area_sqm,
  data = hdb
)

summary(model2)

# autocorrelation
library(spdep)

coords <- st_coordinates(hdb)
nb <- knn2nb(knearneigh(coords, k = 4)) 
lw <- nb2listw(nb, style = "W")

ols_resid <- residuals(model_4room)
moran.test(ols_resid, lw)

moran.plot(ols_resid, lw, labels = FALSE, pch = 20, main = "Moran Scatterplot")

lisa <- localmoran(ols_resid, lw)
head(lisa)

hdb$lisa_I <- lisa[, "Ii"]
hdb$lisa_p <- lisa[, "Pr(z != E(Ii))"]

library(tmap)
tm_shape(hdb) +
  tm_polygons("lisa_I", palette = "RdBu", style = "pretty",
              title = "Local Moran's I (LISA)") +
  tm_layout(frame = FALSE)

# GWR
library(GWmodel)
library(tmap)

hdb_gwr <- hdb %>%
  dplyr::select(resale_price, dist_hawker, dist_school, dist_polyclinic, geometry) %>%
  na.omit()

hdb_gwr <- st_transform(hdb_gwr, 3414)

bw <- bw.gwr(
  resale_price ~ dist_hawker + dist_school + dist_polyclinic,
  data = as_Spatial(hdb_gwr), 
  approach = "AICc",
  kernel = "bisquare",
  adaptive = TRUE
)

gwr_result <- gwr.basic(
  resale_price ~ dist_hawker + dist_school + dist_polyclinic,
  data = as_Spatial(hdb_gwr),
  bw = bw,
  kernel = "bisquare",
  adaptive = TRUE
)

planning <- st_read("/Users/sugarcane/Downloads/bt4015/MasterPlan2019PlanningAreaBoundaryNoSea.geojson")
planning <- st_transform(planning, 3414)
gwr_sf <- st_set_crs(gwr_sf, 3414)

tmap_mode("plot")

# hawker
tm_shape(planning) + 
  tm_borders(col = "grey80", lwd = 0.5) +
  tm_shape(gwr_sf) +
  tm_fill(
    "dist_hawker",
    palette = "RdYlGn",
    style = "quantile",
    title = "Local effect of 
hawker proximity"
  ) +
  tm_layout(
    legend.outside = FALSE,
    frame = FALSE,
    bg.color = "white",
    legend.height = 7, legend.width = 5,
    legend.position = c("right", "bottom"),  
    legend.bg.color = "white",            
    legend.frame = FALSE,        
    legend.text.size = 0.8,
    legend.title.size = 0.5,
  )

# school
tm_shape(planning) + 
  tm_borders(col = "grey80", lwd = 0.5) +
  tm_shape(gwr_sf) +
  tm_fill(
    "dist_school",
    palette = "RdYlGn",
    style = "quantile",
    title = "Local effect of 
school proximity"
  ) +
  tm_layout(
    legend.outside = FALSE,
    frame = FALSE,
    bg.color = "white",
    legend.height = 7, legend.width = 5,
    legend.position = c("right", "bottom"), 
    legend.bg.color = "white",                  
    legend.frame = FALSE,                   
    legend.text.size = 0.8,
    legend.title.size = 0.5,
  )

# clinic
tm_shape(planning) + 
  tm_borders(col = "grey80", lwd = 0.5) +
  tm_shape(gwr_sf) +
  tm_fill(
    "dist_polyclinic",
    palette = "RdYlGn",
    style = "quantile",
    title = "Local effect of 
clinic proximity"
  ) +
  tm_layout(
    legend.outside = FALSE,
    frame = FALSE,
    bg.color = "white",
    legend.height = 7, legend.width = 5,
    legend.position = c("right", "bottom"),  
    legend.bg.color = "white",                   
    legend.frame = FALSE,                   
    legend.text.size = 0.8,
    legend.title.size = 0.5,
  )

# clinic
tm_shape(planning) + 
  tm_borders(col = "grey80", lwd = 0.5) +
  tm_shape(gwr_sf) +
  tm_fill(
    "dist_polyclinic",
    palette = "RdYlGn",
    style = "quantile",
    title = "Local effect of 
clinic proximity"
  ) +
  tm_layout(
    legend.outside = FALSE,
    frame = FALSE,
    bg.color = "white",
    legend.height = 7, legend.width = 5,
    legend.position = c("right", "bottom"),  
    legend.bg.color = "white",                   
    legend.frame = FALSE,                   
    legend.text.size = 0.8,
    legend.title.size = 0.5,
  )

# SAR
library(spdep)
library(spatialreg)

sar_model <- lagsarlm(resale_price ~ dist_mrt + dist_bus + dist_hawker + dist_school + dist_polyclinic +
                        dist_supermarket + dist_sport + dist_parking + dist_parks + dist_parkConnector,
                      data = hdb, listw = lw, zero.policy = TRUE)
summary(sar_model)
