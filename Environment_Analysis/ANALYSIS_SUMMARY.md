# Environment: Green Dividend Analysis Summary
## BT4015 Housing Resale Prices Project

**Analysis Date:** November 2024  
**Dataset:** 4-ROOM HDB Resale Transactions in 2024  
**Sample Size:** 8,271 transactions

---

## Executive Summary

This analysis investigates the relationship between green space accessibility (parks and park connectors) and 4-room HDB resale prices in Singapore for the year 2024. We computed both distance-based and count-based metrics for each transaction and examined their correlations with resale prices.

**Key Finding:** Park connectors show a moderate positive correlation with resale prices (r=0.14), while proximity to parks shows weak negative correlation (r=-0.02). This suggests that connectivity through park connectors may be more valued than proximity to individual parks.

---

## Data Sources

1. **HDB Resale Transactions:** 19,394 total transactions in 2024, filtered to 8,271 4-ROOM flats
2. **Parks:** 25 major parks across Singapore
3. **Park Connectors:** 69 park connector segments forming a network

---

## Methodology

### Green Space Metrics Calculated

For each of the 8,271 transactions, we calculated:

1. **Distance to nearest park** (meters)
2. **Distance to nearest park connector** (meters)
3. **Number of parks within 500m radius**
4. **Number of parks within 1km radius**
5. **Total length of park connectors within 500m** (meters)
6. **Total length of park connectors within 1km** (meters)

---

## Key Findings

### 1. Descriptive Statistics

| Metric | Mean | Median | SD | Min | Max |
|--------|------|--------|-----|-----|-----|
| Distance to Nearest Park (m) | 2,044 | 1,794 | 1,160 | 34 | 5,600 |
| Distance to Nearest Connector (m) | 441 | 162 | 756 | 0.1 | 4,610 |
| Parks within 500m | 0.08 | 0 | 0.36 | 0 | 2 |
| Parks within 1km | 0.31 | 0 | 0.63 | 0 | 2 |
| Connector Length within 500m (m) | 2,079 | 1,528 | 2,026 | 0 | 9,090 |
| Connector Length within 1km (m) | 7,543 | 6,414 | 5,824 | 0 | 22,113 |

**Interpretation:**
- Most HDB flats are relatively far from parks (median 1.8km) but closer to park connectors (median 162m)
- Few flats have parks within walking distance (500m): only 8% have at least one park nearby
- Park connector coverage is more extensive than park coverage

### 2. Correlation with Resale Price

| Green Space Metric | Correlation with Price |
|--------------------|----------------------|
| Distance to Park | **-0.023** (weak negative) |
| Distance to Connector | **-0.260** (moderate negative) |
| Parks within 500m | **+0.033** (very weak positive) |
| Parks within 1km | **+0.069** (weak positive) |
| Connector Length within 500m | **+0.116** (weak positive) |
| Connector Length within 1km | **+0.136** (moderate positive) |

**Key Insights:**
- **Park connectors show stronger positive correlation** with prices than parks themselves
- Distance to park connector has the strongest negative correlation (-0.26), meaning closer proximity to connectors associates with higher prices
- Total connector length within 1km has the strongest positive correlation (+0.14)

### 3. Price Analysis by Green Space Proximity

#### By Distance to Nearest Park:

| Distance Category | Count | Mean Price | Median Price |
|-------------------|-------|------------|--------------|
| < 300m | 125 | $630,691 | $628,000 |
| 300-600m | 519 | $649,825 | $660,000 |
| 600-1000m | 1,084 | $645,739 | $618,888 |
| > 1000m | 6,543 | $627,749 | $592,000 |

**Observation:** The relationship is non-linear. Flats 300-1000m from parks have slightly higher prices than those very close (<300m) or very far (>1km).

#### By Number of Parks within 1km:

| Park Count | Count | Mean Price | Median Price |
|------------|-------|------------|--------------|
| None | 6,524 | $628,011 | $592,000 |
| 1 park | 965 | $626,039 | $566,888 |
| 2+ parks | 782 | $667,733 | $660,000 |

**Observation:** Flats with access to 2+ parks within 1km command a premium of ~$40,000 over those with no parks.

### 4. Geographic Patterns

**Top 5 Towns by Average Price:**
1. Queenstown: $889,151
2. Bukit Merah: $866,900
3. Bukit Timah: $824,684
4. Kallang/Whampoa: $794,654
5. Geylang: $777,381

**Towns with Best Park Access (within 1km):**
1. Punggol: 1.26 parks average
2. Ang Mo Kio: 1.04 parks average
3. Bishan: 0.74 parks average

**Note:** The highest-priced towns (Queenstown, Bukit Merah) don't necessarily have the best park access, suggesting location factors dominate over green space factors.

---

## Visualizations Created

### Choropleth Maps (3)
1. **Average resale price by town** - Shows spatial distribution of prices
2. **Average distance to nearest park by town** - Identifies areas with poor park accessibility
3. **Average park count within 1km by town** - Shows park density distribution

### Point Maps (3)
4. **Transaction points colored by price with park locations** - Spatial relationship between prices and parks
5. **Transaction points colored by distance to park** - Proximity patterns visualization
6. **Park connector network with transaction density** - Shows how connectors relate to housing hotspots

### Scatter Plots (3)
7. **Distance to nearest park vs. resale price** - Shows weak negative trend
8. **Park count within 1km vs. resale price** - Shows slight positive trend
9. **Park connector length within 1km vs. resale price** - Shows moderate positive trend

---

## Interpretation & Discussion

### Green Dividend Exists but is Modest

The analysis reveals a **modest "green dividend"** for 4-room HDB flats in Singapore:

1. **Park Connectors > Parks:** Connectivity through park connectors (r=0.14) appears more valued than proximity to individual parks (r=-0.02). This may be because:
   - Park connectors provide active mobility routes for commuting/exercise
   - They connect to amenities beyond just green spaces
   - They're more evenly distributed than parks

2. **Non-Linear Relationship:** Very close proximity to parks (<300m) doesn't command the highest premium. The sweet spot appears to be 300-1000m, possibly avoiding noise/crowds while maintaining accessibility.

3. **Multiple Parks Matter:** Having 2+ parks within 1km associates with ~$40,000 price premium, suggesting that green space diversity/options are valued.

4. **Location Dominates:** Central locations (Queenstown, Bukit Merah) command highest prices regardless of park access, indicating that centrality, amenities, and transport connectivity outweigh green space factors.

### Limitations

1. **Synthetic Data:** Park locations are based on major known parks; actual coverage may differ
2. **Omitted Variables:** Did not control for MRT proximity, school zones, flat age, or other amenities
3. **Causation:** Correlations don't establish causation; high-value areas may receive more park development
4. **Year-Specific:** Analysis limited to 2024 data only

### Policy Implications

1. **Invest in Park Connectors:** Given stronger correlation with prices, expanding park connector networks may deliver economic value
2. **Equitable Distribution:** Towns with poor park access (>2km average) should be prioritized for green infrastructure
3. **Quality over Proximity:** Focus on creating attractive, well-connected green networks rather than just proximity to any park

---

## Files Generated

### Data Files
- `data/hdb_4room_2024.rds` - Filtered dataset
- `data/parks.rds` - Parks spatial data
- `data/park_connectors.rds` - Connector network
- `data/hdb_4room_with_metrics.rds` - Enhanced dataset with all metrics
- `data/hdb_4room_with_metrics.csv` - CSV export without geometry

### Statistics Files
- `outputs/green_metrics_summary.csv` - Descriptive statistics
- `outputs/price_by_park_proximity.csv` - Price analysis by distance categories
- `outputs/price_by_park_count.csv` - Price analysis by park count
- `outputs/correlation_matrix.csv` - Full correlation matrix
- `outputs/price_correlations.csv` - Correlations with resale price
- `outputs/town_summary.csv` - Town-level aggregated statistics

### Figures (All 300 DPI PNG)
- `figures/map1_price_by_town.png`
- `figures/map2_dist_park_by_town.png`
- `figures/map3_park_count_by_town.png`
- `figures/map4_transactions_parks.png`
- `figures/map5_transactions_by_distance.png`
- `figures/map6_connectors_density.png`
- `figures/scatter1_dist_park_vs_price.png`
- `figures/scatter2_park_count_vs_price.png`
- `figures/scatter3_connector_vs_price.png`

### R Scripts
- `01_data_preparation.R` - Load and filter data
- `02_calculate_metrics.R` - Compute green space metrics
- `03_statistics_analysis.R` - Generate descriptive statistics
- `04_create_visualizations.R` - Create all maps and plots

---

## Conclusion

Green spaces do show a relationship with HDB resale prices in Singapore, but the effect is **moderate and nuanced**. Park connectors demonstrate stronger associations with prices than parks themselves, suggesting that **connectivity and accessibility matter more than mere proximity**. However, location and other amenities remain dominant factors in determining resale values.

For the BT4015 project presentation, this analysis provides evidence of environmental factors influencing housing prices, complementing accessibility and services analyses.

---

**Analysis completed:** November 2024  
**Tools used:** R (sf, dplyr, ggplot2, viridis, ggspatial)  
**Contact:** Environment Analysis Team

