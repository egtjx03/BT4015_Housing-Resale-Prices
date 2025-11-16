library(sf)
library(MASS)
library(raster)
library(tmap)

parking <- st_read("/Users/sugarcane/Downloads/bt4015/URAParkingLotGEOJSON.geojson")
planning <- st_read("/Users/sugarcane/Downloads/bt4015/MasterPlan2019PlanningAreaBoundaryNoSea.geojson")

parking <- st_zm(parking)
planning <- st_zm(planning)

parking_3414 <- st_transform(parking, 3414)
planning_3414 <- st_transform(planning, 3414)

coords <- st_coordinates(parking_3414)
kde <- kde2d(
  coords[,1],
  coords[,2],
  n = 300,    
  h = 5000,   
  lims = c(st_bbox(planning_3414)[c(1,3,2,4)])
)

r <- raster(kde)
crs(r) <- st_crs(planning_3414)$proj4string
planning_sp <- as(st_zm(planning_3414), "Spatial")
r_masked <- mask(r, planning_sp)

r_norm <- (r_masked - cellStats(r_masked, 'min')) /
  (cellStats(r_masked, 'max') - cellStats(r_masked, 'min'))

breaks <- c(0, 0.00005, 0.01, 0.1, 0.3, 0.5, 1, 5)  

labels <- c(
  "0–0.00005",
  "0.00005–0.01",
  "0.01–0.1",
  "0.1–0.3",
  "0.3–0.5",
  "0.5–1",
  ">1"
)

# 绘图
tm_shape(r_norm) +
  tm_raster(
    breaks = breaks,
    palette = colorRampPalette(c("#c6dbef", "#6baed6", "#2171b5", "#08306b"))(7),
    title = "Density",
    labels = labels
  ) +
  tm_shape(planning_3414) +
  tm_borders(col = "white", lwd = 0.5) +
  tm_layout(
    legend.height = 7, legend.width = 5,
    legend.position = c("right", "bottom"),   
    legend.bg.color = "white",                
    legend.frame = FALSE,                
    legend.text.size = 0.8,
    legend.title.size = 1,
    frame = FALSE,                          
    bg.color = "white"                  
  )
