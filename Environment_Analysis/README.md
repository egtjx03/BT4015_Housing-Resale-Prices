# Environment Analysis: Green Dividend

Analysis of the relationship between green spaces (parks and park connectors) and 4-room HDB resale prices in 2024.

## Quick Start

Run the R scripts in order:

```r
# 1. Prepare data (filter for 2024 and 4-ROOM, load green spaces)
source("01_data_preparation.R")

# 2. Calculate green space metrics for each transaction
source("02_calculate_metrics.R")

# 3. Generate descriptive statistics and correlations
source("03_statistics_analysis.R")

# 4. Create all visualizations (maps and plots)
source("04_create_visualizations.R")
```

## Directory Structure

```
Environment_Analysis/
├── README.md                          # This file
├── ANALYSIS_SUMMARY.md               # Complete analysis findings and interpretation
├── 01_data_preparation.R             # Load and filter datasets
├── 02_calculate_metrics.R            # Calculate distance and count metrics
├── 03_statistics_analysis.R          # Generate statistics and correlations
├── 04_create_visualizations.R        # Create all maps and plots
├── data/                             # Generated data files
│   ├── hdb_4room_2024.rds           # Filtered 4-ROOM transactions (2024)
│   ├── parks.rds                     # Parks spatial data (25 locations)
│   ├── park_connectors.rds           # Park connector network (69 segments)
│   ├── hdb_4room_with_metrics.rds   # Full dataset with all metrics
│   └── hdb_4room_with_metrics.csv   # CSV export (no geometry)
├── outputs/                          # Statistics tables
│   ├── green_metrics_summary.csv     # Descriptive statistics for all metrics
│   ├── price_by_park_proximity.csv   # Price by distance categories
│   ├── price_by_park_count.csv       # Price by number of parks nearby
│   ├── correlation_matrix.csv        # Full correlation matrix
│   ├── price_correlations.csv        # Correlations with resale price
│   └── town_summary.csv              # Town-level aggregated stats
└── figures/                          # All visualizations (PNG, 300 DPI)
    ├── map1_price_by_town.png        # Choropleth: Average price by town
    ├── map2_dist_park_by_town.png    # Choropleth: Distance to park by town
    ├── map3_park_count_by_town.png   # Choropleth: Park count by town
    ├── map4_transactions_parks.png   # Point map: Transactions + parks
    ├── map5_transactions_by_distance.png  # Point map: Color by distance
    ├── map6_connectors_density.png   # Park connectors + density heatmap
    ├── scatter1_dist_park_vs_price.png    # Distance to park vs price
    ├── scatter2_park_count_vs_price.png   # Park count vs price
    └── scatter3_connector_vs_price.png    # Connector length vs price
```

## Key Findings

- **Sample:** 8,271 4-ROOM HDB transactions in 2024
- **Green spaces:** 25 parks, 69 park connector segments

### Correlations with Resale Price

| Metric | Correlation |
|--------|-------------|
| Distance to park connector | **-0.26** (moderate) |
| Connector length within 1km | **+0.14** (moderate) |
| Parks within 1km | **+0.07** (weak) |
| Distance to park | **-0.02** (negligible) |

**Key Insight:** Park connectors show stronger association with prices than parks themselves, suggesting connectivity matters more than proximity.

### Price Premium

- Flats with **2+ parks within 1km**: ~**$40,000 premium** over flats with no nearby parks
- Optimal distance to park: **300-1000m** (balances accessibility and avoiding crowds)

## Requirements

### R Packages

```r
install.packages(c(
  "sf",           # Spatial data handling
  "dplyr",        # Data manipulation
  "geojsonsf",    # Read GeoJSON
  "httr",         # HTTP requests
  "jsonlite",     # JSON parsing
  "tidyr",        # Data tidying
  "ggplot2",      # Visualization
  "viridis",      # Color palettes
  "scales",       # Axis formatting
  "ggspatial",    # Map annotations
  "units"         # Unit conversions
))
```

## Data Processing Pipeline

### Step 1: Data Preparation
- Load 19,394 total 2024 transactions
- Filter to 8,271 4-ROOM flats
- Load/create parks and park connector spatial data
- Ensure consistent CRS (WGS84)

### Step 2: Metric Calculation
For each transaction, calculate:
- Distance to nearest park
- Distance to nearest park connector
- Parks within 500m and 1km
- Park connector length within 500m and 1km

### Step 3: Statistical Analysis
- Descriptive statistics for all metrics
- Price analysis by proximity categories
- Correlation analysis
- Town-level aggregations

### Step 4: Visualization
- 3 choropleth maps (by town)
- 3 point maps (spatial patterns)
- 3 scatter plots (correlations)

## Usage Notes

1. **Run time:** Script 2 (metrics calculation) takes longest (~5-10 minutes)
2. **Memory:** Requires ~2GB RAM for spatial operations
3. **Output size:** Figures are high-resolution (300 DPI) for publication

## Interpretation

See `ANALYSIS_SUMMARY.md` for detailed findings, discussion, and policy implications.

**TL;DR:** Green spaces matter, but park connectors > individual parks, and location still dominates.
