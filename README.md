# BT4015: Singapore HDB Resale Price Spatial Analysis

A comprehensive geospatial analysis investigating the relationship between Singapore HDB (Housing & Development Board) resale prices and environmental, accessibility, and amenity factors using advanced spatial statistical methods.

## Project Overview

This project analyzes **8,271 4-room HDB resale transactions in 2024** to understand how location-based factors influence housing prices. Using spatial statistics and GIS techniques, we examine the "green dividend," amenity effects, and spatial patterns in Singapore's public housing market.

### Key Questions
- Do green spaces (parks and park connectors) affect HDB resale prices?
- How do amenities (hawkers, schools, clinics, transport) impact property values?
- Are these effects uniform across Singapore or location-specific?
- What spatial patterns exist in transaction distribution and pricing?

## Key Findings

### Spatial Patterns
- **Extreme clustering**: HDB transactions show significant spatial clustering (ANN ratio = 0.08, p < 0.001)
- **Strong price autocorrelation**: Moran's I = 0.87, indicating distinct "expensive" and "affordable" zones
- **1,427 price hot spots** and **1,909 cold spots** identified across Singapore

### Green Dividend Analysis
- **Park connectors matter more than parks**: Correlation with price (r = 0.14 vs r = -0.02)
- **Non-linear relationship**: Optimal distance to parks is 300-1000m (not closest)
- **Multiple parks premium**: Flats with 2+ parks within 1km command ~$40,000 premium
- **Limited coverage**: 79% of transactions are >1km from nearest park

### Geographically Weighted Regression (GWR)
- **Model accuracy**: R² = 0.90 (56% improvement over global OLS)
- **Location matters**: Same amenity can increase prices in one location, decrease in another
- **Calibrated buffers**: Different optimal distances for different amenities (200m-2000m)
- **Spatial heterogeneity**: Floor area premium varies **53-fold** across Singapore

## Project Structure

```
BT4015_Housing-Resale-Prices/
├── Amenities_Analysis/          # Individual amenity analysis scripts
│   ├── clinics.R, hawkers.R, schools.R, parks.R, etc.
├── Buffer Analysis/             # Spatial buffer zone analysis
│   ├── 01_Main Buffer Analysis.R
│   └── 02_HDB Price Comparison.R
├── Data_Preparation/            # Data preprocessing scripts
│   └── create transaction data with location.py
├── Datasets/                    # GeoJSON and spatial datasets
│   ├── amenities/              # Amenity locations (schools, clinics, hawkers, etc.)
│   ├── accessbilities/         # Transport data (MRT, bus stops)
│   ├── green_spaces/           # Parks and park connectors
│   └── transactions_with_lonlat.geojson
├── Environment_Analysis/        # Green space analysis (10 scripts)
│   ├── 01_data_preparation.R
│   ├── 02_calculate_metrics.R
│   ├── 08_gwr_price_model.R
│   ├── figures/                # 15 visualizations
│   ├── outputs/                # 19 statistical tables
│   └── ANALYSIS_SUMMARY.md     # Detailed green space findings
├── HDB/                        # Spatial statistical analysis (4 scripts)
│   ├── 01_ann_analysis.R       # Average Nearest Neighbor
│   ├── 02_morans_i_analysis.R  # Spatial autocorrelation
│   ├── 03_gwr_analysis.R       # Geographically Weighted Regression
│   ├── 04_IDW_Interpolation.R  # Inverse Distance Weighting
│   ├── figures/                # 8 spatial maps
│   ├── outputs/                # Model results
│   └── ANALYSIS_SUMMARY.md     # Detailed spatial findings
└── Point Pattern Analysis/      # L-function and G-function plots
    └── 01_L&G_Plots.R
```

## Requirements

### R Packages
```r
# Spatial data handling
sf, sp, rgdal, rgeos

# Spatial statistics
spatstat, spdep, GWmodel

# Data manipulation
dplyr, tidyr, readr

# Visualization
ggplot2, viridis, RColorBrewer, gridExtra
```

### Python (for data preparation)
```python
pandas, geopandas, shapely
```

### Installation
```r
install.packages(c("sf", "spatstat", "spdep", "GWmodel", 
                   "dplyr", "ggplot2", "viridis"))
```

## How to Run

### Complete Analysis Pipeline

1. **Data Preparation** (Python)
```bash
python Data_Preparation/create\ transaction\ data\ with\ location.py
```

2. **Environment Analysis** (R - Green Spaces)
```bash
cd Environment_Analysis
Rscript 01_data_preparation.R
Rscript 02_calculate_metrics.R
Rscript 03_statistics_analysis.R
Rscript 04_create_visualizations.R
Rscript 05_buffer_analysis.R
Rscript 06_hypothesis_testing.R
Rscript 07_spatial_autocorrelation.R
Rscript 08_gwr_price_model.R
Rscript 09_gwr_density_model.R
Rscript 10_amenities_hypothesis_testing.R
```

3. **HDB Spatial Analysis** (R - Main Analysis)
```bash
cd HDB
Rscript 01_ann_analysis.R          # ~2 minutes
Rscript 02_morans_i_analysis.R     # ~3 minutes
Rscript 03_gwr_analysis.R          # ~20-25 minutes
Rscript 04_IDW_Interpolation.R
```

4. **Supplementary Analyses**
```bash
# Buffer Analysis
Rscript Buffer\ Analysis/01_Main\ Buffer\ Analysis.R
Rscript Buffer\ Analysis/02_HDB\ Price\ Comparison.R

# Point Pattern Analysis
Rscript Point\ Pattern\ Analysis/01_L&G_Plots.R

# Individual Amenity Analysis
Rscript Amenities_Analysis/Analysis.R
```

## Main Analyses

### 1. Average Nearest Neighbor (ANN)
**Tests spatial distribution patterns**
- Observed distance: 11.1m vs Expected: 138.6m
- ANN Ratio: 0.08 (strongly clustered)
- Z-score: -115.54 (p < 0.001)

### 2. Moran's I Spatial Autocorrelation
**Tests if similar values cluster together**
- Price autocorrelation: Moran's I = 0.87 (very strong)
- Identified 3,414 significant clusters (41% of transactions)
- Density autocorrelation: Moran's I = 0.34 (moderate)

### 3. Geographically Weighted Regression (GWR)
**Models spatially-varying amenity effects**
- 22 predictors with calibrated buffer distances
- Model R² = 0.90 (vs OLS R² = 0.57)
- Reveals location-specific amenity values
- Optimal bandwidth: 1,223 neighbors

### 4. Buffer Analysis
**Service area coverage assessment**
- Only 21% of transactions within 1km of parks
- Flats within 500m-1km show $20,000 premium
- Park connector coverage better than parks (median 162m vs 1,794m)

### 5. Point Pattern Analysis
**L-function and G-function spatial tests**
- Tests for complete spatial randomness
- Identifies clustering scales

## Output Files

### Figures (300 DPI PNG)
- **Environment_Analysis/figures/**: 15 maps and plots
  - Price distributions, park proximity maps, LISA clusters
  - GWR coefficient maps, buffer zones
- **HDB/figures/**: 8 spatial analysis maps
  - ANN histogram, Moran's I LISA maps
  - GWR local R² and coefficient maps

### Statistical Tables (CSV)
- **Environment_Analysis/outputs/**: 19 tables
  - Correlations, descriptive statistics, model comparisons
- **HDB/outputs/**: Model results and test statistics

## Methodology

### Statistical Methods
- **Average Nearest Neighbor (ANN)**: Clark & Evans (1954)
- **Moran's I**: Moran (1950) 
- **LISA (Local Indicators of Spatial Association)**: Anselin (1995)
- **Geographically Weighted Regression (GWR)**: Fotheringham et al. (2002)
- **Buffer Analysis**: Service area modeling
- **Point Pattern Analysis**: Ripley's K/L-function

### Calibrated Buffer Distances
Different amenities use realistic accessibility thresholds:
- **MRT Stations**: 800m (10-min walk)
- **Bus Stops**: 200m (immediate access)
- **Hawker Centers**: 500m (5-7 min walk)
- **Schools**: 1000m (family consideration)
- **Clinics**: 800m (10-min walk)
- **Supermarkets**: 400m (daily errands)
- **Sports Facilities**: 2000m (less frequent)
- **Parks**: 1000m (recreational)
- **Park Connectors**: 200m (immediate green corridors)

## Data Sources

- **HDB Resale Transactions**: 19,394 total transactions in 2024 (filtered to 8,271 4-room flats)
- **Parks**: 25 major parks across Singapore (NParks)
- **Park Connectors**: 69 segments (NParks)
- **MRT/Bus**: LTA DataMall
- **Schools**: MOE school directory with coordinates
- **Hawkers**: NEA data
- **Clinics**: CHAS clinic registry
- **Planning Areas**: URA Master Plan 2019

## Policy Implications

1. **Location-specific planning**: One-size-fits-all policies will fail (56% performance gap)
2. **Calibrated accessibility standards**: Different amenities need different buffer distances
3. **Park connector investment**: Shows stronger correlation than individual parks
4. **Amenity saturation risk**: Mature estates may have diminishing returns
5. **Spatial inequality**: Cold spots have worse access, need targeted interventions

## Detailed Documentation

For comprehensive analysis details, see:
- `Environment_Analysis/ANALYSIS_SUMMARY.md` - Full green space analysis
- `HDB/ANALYSIS_SUMMARY.md` - Complete spatial statistics results
