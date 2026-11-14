# ECOSTRESS and MODIS: heat and evapotranspiration

Crop water use and heat stress, measured from thermal infrared. ECOSTRESS (on the International Space Station) sees individual fields at 70 m but on an irregular schedule; MODIS sees every day at 500 m-1 km with a 25-year record. Both are read through AppEEARS (`appeears.md`).

| Product | What it is | Resolution | Cadence | Since |
|---|---|---|---|---|
| `ECO_L2T_LSTE.002` | Land surface temperature (LST) and emissivity | 70 m | every 1-5 days, varying time of day (ISS orbit) | 2018-07-09 |
| `ECO_L3T_JET.002` | Evapotranspiration (JET ensemble): instantaneous and daily | 70 m | same overpasses | 2018-07-10 |
| `MOD11A2.061` | MODIS land surface temperature, day and night | 1 km | 8 day | 2000-02-18 |
| `MOD16A2GF.061` | MODIS actual ET and potential ET, gap-filled | 500 m | 8 day | 2000-01-01 |

## Layers (Captured from the AppEEARS catalog)

### `ECO_L2T_LSTE.002`

| Layer | Unit | Fill | Notes |
|---|---|---|---|
| `LST` | K (subtract 273.15) | NaN | QA layers: `QC`, `cloud` |
| `LST_err` | K | NaN | carry as uncertainty |
| `QC` | | | |
| `cloud` | 1 = cloud | 255 | 1 = flagged |
| `water` | 1 = water | 255 | 1 = flagged |

### `ECO_L3T_JET.002`

| Layer | Unit | Notes |
|---|---|---|
| `ETdaily` | **W/m²** (daytime mean latent heat), not mm | convert: mm/day ≈ W/m² x 0.0353 (that is x 86400 s ÷ 2.45 MJ/kg ÷ 10⁶) |
| `ETinstUncertainty` | W/m² | |
| `cloud`, `water` | 1 = cloud / water | 1 = flagged |

### `MOD11A2.061`

| Layer | Unit | Scale | Fill |
|---|---|---|---|
| `LST_Day_1km` | K | 0.02 (applied in CSV) | 0 |
| `LST_Night_1km` | K | 0.02 | 0 |
| `QC_Day`, `QC_Night` | bits | | 0 |

### `MOD16A2GF.061`

| Layer | Unit | Scale | Fill |
|---|---|---|---|
| `ET_500m` | kg/m²/8 day = mm per 8 days | 0.1 | 32767 |
| `PET_500m` | mm per 8 days | 0.1 | 32767 |
| `ET_QC_500m` | bits | | 255 |

Values of 3270-3276 after scaling are land-cover codes (water, urban, barren), not ET. Per the MOD16 user guide, values above 3270 (scaled 32761-32767) are fill classes.

## Sample results CSV: `ECO_L2T_LSTE.002` (Representative)

```
ID,Category,Latitude,Longitude,Date,ECO_L2T_LSTE_002_LST,ECO_L2T_LSTE_002_LST_err,ECO_L2T_LSTE_002_cloud,ECO_L2T_LSTE_002_water
field-1842,York NE,40.95,-97.5,2025-07-03T19:42:11,306.84,0.91,0,0
field-1842,York NE,40.95,-97.5,2025-07-08T14:05:37,301.12,0.88,0,0
field-1842,York NE,40.95,-97.5,2025-07-11T22:51:03,NaN,NaN,1,0
field-1842,York NE,40.95,-97.5,2025-07-19T17:28:49,309.60,1.02,0,0
```

Timestamps are **UTC overpass times** and vary every pass. 19:42 UTC is 2:42 p.m. CDT (hot afternoon), 14:05 UTC is 9:05 a.m. Compare passes only within similar local-time windows, or the "hotspot" is just the time of day.

## Sample results CSV: `ECO_L3T_JET.002` (Representative)

```
ID,Category,Latitude,Longitude,Date,ECO_L3T_JET_002_ETdaily,ECO_L3T_JET_002_ETinstUncertainty,ECO_L3T_JET_002_cloud
field-1842,York NE,40.95,-97.5,2025-07-03T19:42:11,198.4,31.2,0
field-1842,York NE,40.95,-97.5,2025-07-19T17:28:49,214.9,28.7,0
```

198.4 W/m² x 0.0353 ≈ **7.0 mm/day**, a typical peak-season soybean ET in Nebraska.

## Sample results CSV: `MOD16A2GF.061` (Representative)

```
ID,Category,Latitude,Longitude,Date,MOD16A2GF_061_ET_500m,MOD16A2GF_061_PET_500m,MOD16A2GF_061_ET_QC_500m
field-1842,York NE,40.95,-97.5,2025-07-04,41.3,52.8,0
field-1842,York NE,40.95,-97.5,2025-07-12,44.1,57.2,0
field-1842,York NE,40.95,-97.5,2025-08-13,29.6,55.9,0
```

`ET / PET` = **evaporative stress ratio**: 0.78 in early July (crop drinking freely), 0.53 by mid-August (crop holding back water: stress).

## Notes

- ECOSTRESS acquisitions are irregular in time (ISS orbit, clouds).
- Land surface temperature is the temperature of leaves and soil, not air. 
- OpenET (`openet.md`) provides 30 m monthly ET for 17 western states from Landsat; ECOSTRESS and MODIS ET are global.

## Documentation

- ECOSTRESS data: https://ecostress.jpl.nasa.gov/data
- ECO_L2T_LSTE: https://lpdaac.usgs.gov/products/eco_l2t_lstev002/
- MOD16A2GF: https://lpdaac.usgs.gov/products/mod16a2gfv061/
- MOD11A2: https://lpdaac.usgs.gov/products/mod11a2v061/
