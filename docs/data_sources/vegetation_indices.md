# Vegetation indices (NDVI, EVI and friends)

Satellite vegetation indices (NDVI, EVI and related) and phenology products available for a point:

| Source | Product | Resolution | Revisit | Since | Access | Status |
|---|---|---|---|---|---|---|
| MODIS Terra | `MOD13Q1.061` (Aqua: `MYD13Q1.061`) | 250 m | 16-day composite (8-day when Terra and Aqua combined) | 2000 | AppEEARS (Earthdata) | ready |
| Harmonized Landsat Sentinel-2 | `HLSL30_VI.020`, `HLSS30_VI.020` | 30 m | 2-3 days combined, cloud-limited | 2013 / 2015 | AppEEARS (Earthdata) | ready |
| Sentinel-2 L2A | Sentinel Hub Statistical API | 10 m | 5 days, cloud-limited | 2017 | Copernicus Data Space | credentials not configured (`copernicus.md`) |
| MODIS phenology | `MCD12Q2.061` | 500 m | yearly | 2001 | AppEEARS (Earthdata) | ready |
| MODIS LAI/FPAR | `MCD15A3H.061` | 500 m | 4 day | 2002 | AppEEARS (Earthdata) | ready |



## What the app uses: MODIS normal (`Fields::VegetationNormal`)

`Fields::FetchAppeearsJob` (source `modis`) asks AppEEARS for `MOD13Q1.061` `_250m_16_days_NDVI` and `_250m_16_days_pixel_reliability` at the pin since 2001. Measured on 2026-11-15 at Buin, Chile (fixture `spec/fixtures/data_sources/modis_mod13q1_buin.csv`): about 20 minutes once the task left the queue; 596 rows from 2000-12-18 to 2026-09-14; values already scaled (0.2682, not 2682); `pixel_reliability` 0 (good) and 1 (marginal) are kept. The usual NDVI there runs from 0.19 (May) to 0.24 (October), a peri-urban spot; no month of the last year was 0.1 under its normal.

## Layers (Captured from the AppEEARS catalog)

### `MOD13Q1.061`

| Layer | Scale | Fill | Valid | QA |
|---|---|---|---|---|
| `_250m_16_days_NDVI` | 0.0001 (already applied in CSV) | -3000 | -0.2 to 1.0 | `_250m_16_days_VI_Quality` |
| `_250m_16_days_EVI` | 0.0001 | -3000 | -0.2 to 1.0 | same |
| `_250m_16_days_pixel_reliability` | | -1 | 0 good, 1 marginal, 2 snow/ice, 3 cloudy | |
| `_250m_16_days_VI_Quality` | | 65535 | | |
| `_250m_16_days_composite_day_of_the_year` | | -1 | 1-366 | actual acquisition day within the 16-day window |

### `HLSS30_VI.020` / `HLSL30_VI.020`

Precomputed indices, scale 0.0001 (`TVI` 0.01): `NDVI`, `EVI`, `SAVI`, `MSAVI`, `NDMI` (canopy water), `NDWI` (surface water), `NBR`, `NBR2` (burn and residue), `TVI`. Cloud and shadow screening uses `Fmask` from the matching reflectance product (`HLSL30.020` / `HLSS30.020`) (a separate product).

| Index | What it measures |
|---|---|
| `NDVI` | Green biomass; saturates above ~0.85 in dense corn |
| `EVI` | Like NDVI but keeps working in dense canopies; better for peak-season comparisons |
| `NDMI` | Canopy water content: drops before NDVI does under drought stress |
| `NBR2` | Crop residue and tillage: high after no-till harvest, low on tilled bare soil |
| `SAVI` / `MSAVI` | NDVI corrected for bare soil: better early season and for sparse cover crops |

### `MCD12Q2.061` (phenology, one row per year)

`Greenup`, `MidGreenup`, `Maturity`, `Peak`, `Senescence`, `MidGreendown`, `Dormancy` (day numbers since 1970-01-01; convert to dates), `EVI_Amplitude`, `EVI_Area` (season-integrated greenness), `NumCycles` (2 means a double crop or cover crop showed up).

## Sample results CSV: `MOD13Q1.061` (Representative)

A soybean year at the reference field (CDL 2025 = Soybeans):

```
ID,Category,Latitude,Longitude,Date,MODIS_Tile,MOD13Q1_061__250m_16_days_NDVI,MOD13Q1_061__250m_16_days_EVI,MOD13Q1_061__250m_16_days_pixel_reliability,MOD13Q1_061__250m_16_days_VI_Quality_MODLAND_Description
field-1842,York NE,40.95,-97.5,2025-04-07,h10v04,0.2214,0.1102,0,VI produced with good quality
field-1842,York NE,40.95,-97.5,2025-05-09,h10v04,0.2487,0.1311,0,VI produced with good quality
field-1842,York NE,40.95,-97.5,2025-06-10,h10v04,0.4120,0.2408,0,VI produced with good quality
field-1842,York NE,40.95,-97.5,2025-07-12,h10v04,0.8302,0.5913,0,VI produced with good quality
field-1842,York NE,40.95,-97.5,2025-08-13,h10v04,0.8714,0.6420,1,"VI produced, but check other QA"
field-1842,York NE,40.95,-97.5,2025-09-14,h10v04,0.6033,0.3871,0,VI produced with good quality
field-1842,York NE,40.95,-97.5,2025-10-16,h10v04,0.2602,0.1395,0,VI produced with good quality
field-1842,York NE,40.95,-97.5,2025-11-17,h10v04,0.2311,0.1204,3,Pixel not produced due to other reasons than clouds
```

`pixel_reliability`: 0 good data, 1 marginal, 2 snow/ice, 3 cloudy.

## Sample: Sentinel-2 via Statistical API (Representative)

Shown for when CDSE credentials exist. Daily intervals with no clear image come back with `sampleCount == noDataCount`.

```json
{
  "data": [
    { "interval": { "from": "2025-07-10T00:00:00Z", "to": "2025-07-11T00:00:00Z" },
      "outputs": { "ndvi": { "bands": { "B0": { "stats": {
        "min": 0.7712, "max": 0.9035, "mean": 0.8621, "stDev": 0.0241, "sampleCount": 3600, "noDataCount": 0 } } } } } },
    { "interval": { "from": "2025-07-15T00:00:00Z", "to": "2025-07-16T00:00:00Z" },
      "outputs": { "ndvi": { "bands": { "B0": { "stats": {
        "min": "NaN", "max": "NaN", "mean": "NaN", "stDev": "NaN", "sampleCount": 3600, "noDataCount": 3600 } } } } } }
  ],
  "status": "OK"
}
```

`stDev` across the field is a free **within-field variability** signal (high values point to wet spots, compaction, or uneven emergence).

## Notes

- 250 m MODIS pixels cover ~6 hectares and mix field edges, roads and neighbours. Use them for "normal" curves, not for one field's precise value.
- Clouds: HLS and Sentinel-2 can go several weeks without a clear acquisition.
- NDVI does not identify crop type.

## Documentation

- MOD13Q1: https://lpdaac.usgs.gov/products/mod13q1v061/
- HLS: https://lpdaac.usgs.gov/products/hlss30v002/
- MCD12Q2: https://lpdaac.usgs.gov/products/mcd12q2v061/
- Sentinel Hub Statistical API: https://documentation.dataspace.copernicus.eu/APIs/SentinelHub/Statistical.html
