import geopandas as gpd
import pandas as pd
import re
import json
from pathlib import Path

# Load transaction data and HDB location data
geo = gpd.read_file("C:/Users/egtay/Downloads/HDBExistingBuilding.geojson")  # GeoJSON file
trans = pd.read_csv("C:/Users/egtay/Downloads/Telegram Desktop/combined_resale_data.csv")      # Resale flat transactions

# Define output paths
CSV_OUT     = Path("transactions_with_lonlat.csv")
GEOJSON_OUT = Path("transactions_with_lonlat.geojson")

# Extract postal code from Description
pat = re.compile(r"<th>\s*POSTAL_COD\s*</th>\s*<td>\s*([0-9]{6})\s*</td>", re.I | re.S)
geo["POSTAL_COD"] = geo.get("Description", "").astype(str).str.extract(pat)
geo = geo.dropna(subset=["POSTAL_COD"]).copy()
geo["POSTAL_COD"] = geo["POSTAL_COD"].astype(str).str.extract(r"(\d{6})", expand=False).str.zfill(6)

# One representative point (lat/long) per postal code
geo_one   = geo.dissolve(by="POSTAL_COD", as_index=True).reset_index()
geo_wgs84 = geo_one.to_crs(4326)
rep_pts   = geo_wgs84.geometry.representative_point()  
postal_xy = pd.DataFrame({
    "postal_code": geo_wgs84["POSTAL_COD"].astype(str).str.zfill(6),
    "longitude":   rep_pts.x,
    "latitude":    rep_pts.y,
})

# Clean transaction columns and merge lat/long
trans.columns = trans.columns.str.strip()
trans["postal_code"] = (
    trans["postal_code"].astype(str).str.extract(r"(\d{6})", expand=False).str.zfill(6)
)

trans_with_xy = trans.merge(postal_xy, on="postal_code", how="left")

# keep only rows that have a valid postal and lon/lat
trans_with_xy = trans_with_xy.dropna(subset=["postal_code", "longitude", "latitude"]).copy()
trans_with_xy = trans_with_xy[trans_with_xy["postal_code"].str.strip() != ""]

# export CSV
trans_with_xy.to_csv(CSV_OUT, index=False)
print(f"CSV written: {CSV_OUT.resolve()}  | rows: {len(trans_with_xy)}")

# export GeoJSON
def row_to_feature(row: pd.Series) -> dict:
    props = row.to_dict()
    lon = float(props.pop("longitude"))
    lat = float(props.pop("latitude"))
    return {
        "type": "Feature",
        "geometry": {"type": "Point", "coordinates": [lon, lat]},
        "properties": props,
    }

features = [row_to_feature(r) for _, r in trans_with_xy.iterrows()]
fc = {"type": "FeatureCollection", "features": features}

with open(GEOJSON_OUT, "w", encoding="utf-8") as f:
    json.dump(fc, f, ensure_ascii=False)

print(f"GeoJSON written: {GEOJSON_OUT.resolve()}  | features: {len(features)}")

# Check output
print("\nSample:")
print(trans_with_xy[[
    "month","town","flat_type","block","street_name",
    "postal_code","longitude","latitude"
]].head().to_string(index=False))
