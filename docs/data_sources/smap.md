# SMAP soil moisture

NASA's Soil Moisture Active Passive satellite measures the water in the top ~5 cm of soil every 2-3 days with an L-band radiometer. Two products matter here, both read through AppEEARS (`appeears.md`):

| Product | What it is | Depth | Resolution | Cadence | Since |
|---|---|---|---|---|---|
| `SPL3SMP_E.006` | **Measured** surface soil moisture (L3 enhanced, morning pass) | 0-5 cm | 9 km | daily, gaps between swaths | 2015-03-31 |
| `SPL4SMGP.008` | **Model + SMAP assimilation** (L4): surface, root zone, full profile, with percentiles; no gaps | 0-5 cm, 0-100 cm, profile | 9 km | 3-hourly (daily in point output) | 2015-03-31 |

L3 is a retrieval from the satellite measurement with gaps between swaths; L4 is a model analysis that assimilates SMAP data and has no gaps.

## What the app uses

`Fields::FetchSoilMoistureJob` asks AppEEARS for `SPL4SMGP.008` `Geophysical_Data_sm_rootzone` and `Geophysical_Data_sm_rootzone_pctl` at the pin over the last 12 full months, and `Weather::SoilMoisture` keeps one row per month (mean moisture and mean percentile), the latest reading, and the dry (percentile under 20) and wet (over 80) months.

Measured on 2026-11-15 (Buin, Chile, -33.60, -70.70; fixture `spec/fixtures/data_sources/smap_l4_buin.csv`, one reading a day of the real file):

- **Time:** about 45 minutes from submit to the CSV. A year of the 3-hourly L4 is about 2,900 granules, and AppEEARS spends most of the time downloading them ("Downloading" step). The job therefore polls every 5 minutes for up to 3 hours, and the field shows "Requested from NASA" meanwhile.
- **Real CSV header:** `Category,ID,Latitude,Longitude,Date,SMAP_Tile,SPL4SMGP_008_Line_Y_9.00805km,SPL4SMGP_008_Sample_X_9.00805km,SPL4SMGP_008_Geophysical_Data_sm_rootzone,SPL4SMGP_008_Geophysical_Data_sm_rootzone_pctl` (2,921 rows); dates read `2025-11-01 01:30:00 UTC`. The parser finds the columns by suffix.
- **Values:** root zone 0.17 m³/m³ at the end of summer (March) to 0.35 in October after the winter rains; June in the driest fifth of its usual range (percentile 12); August to October in the wettest.
- **Fill in the percentile:** January to March every `sm_rootzone_pctl` is `-9999` while `sm_rootzone` has values. In the driest months the product leaves the percentile undefined; the app shows those months as unknown, never as dry.

## Layers to request (Captured from `GET /api/product/{id}`)

### `SPL3SMP_E.006`

| Layer | Unit | Valid range | Fill | QA layer |
|---|---|---|---|---|
| `Soil_Moisture_Retrieval_Data_AM_soil_moisture` | m³/m³ | 0.02-0.5 | -9999 | `..._AM_retrieval_qual_flag` |
| `Soil_Moisture_Retrieval_Data_AM_retrieval_qual_flag` | bit flags | | 65534 | |
| `Soil_Moisture_Retrieval_Data_AM_vegetation_water_content` | kg/m² | 0-20 | -9999 | qual flag |
| `Soil_Moisture_Retrieval_Data_AM_surface_temperature` | K | 0-350 | -9999 | qual flag |
| `Soil_Moisture_Retrieval_Data_AM_freeze_thaw_fraction` | 0-1 | | -9999 | qual flag |

PM equivalents exist (`..._PM_soil_moisture_pm`); per the SMAP documentation, the AM (6 a.m. local) retrieval has lower error because soil and canopy temperatures are closest to equal.

### `SPL4SMGP.008`

| Layer | Unit | Valid range |
|---|---|---|
| `Geophysical_Data_sm_surface` | m³/m³ | 0-0.9 |
| `Geophysical_Data_sm_rootzone` | m³/m³ | 0-0.9 |
| `Geophysical_Data_sm_rootzone_pctl` | % (0-100) | 0-100 |
| `Geophysical_Data_sm_rootzone_wetness` | 0-1 | 0-1 |
| `Geophysical_Data_sm_profile` | m³/m³ (the catalog says W/m², which is a labeling error) | 0-0.9 |
| `Geophysical_Data_sm_profile_pctl` | % | 0-100 |
| `Geophysical_Data_land_evapotranspiration_flux` | kg/m²/s (x 86400 = mm/day) | ±0.001 |
| `Geophysical_Data_surface_temp` | K | 180-350 |

Fill is `-9999.0` for all. L4 has no QA flag per pixel; it is always "filled".

## Sample results CSV: `SPL3SMP_E.006` (Representative)

```
ID,Category,Latitude,Longitude,Date,SPL3SMP_E_006_Line_Y_9km,SPL3SMP_E_006_Sample_X_9km,SPL3SMP_E_006_Soil_Moisture_Retrieval_Data_AM_soil_moisture,SPL3SMP_E_006_Soil_Moisture_Retrieval_Data_AM_retrieval_qual_flag,SPL3SMP_E_006_Soil_Moisture_Retrieval_Data_AM_retrieval_qual_flag_Retrieval_recommended_Description,SPL3SMP_E_006_Soil_Moisture_Retrieval_Data_AM_vegetation_water_content
field-1842,York NE,40.95,-97.5,2025-06-28,509,2116,0.3124,0,Soil moisture retrieval has recommended quality,3.81
field-1842,York NE,40.95,-97.5,2025-06-29,509,2116,-9999.0,65534,Fill value,-9999.0
field-1842,York NE,40.95,-97.5,2025-06-30,509,2116,0.2871,8,Soil moisture retrieval doesn't have recommended quality,4.02
field-1842,York NE,40.95,-97.5,2025-07-01,509,2116,0.2950,0,Soil moisture retrieval has recommended quality,4.10
```

`-9999` is fill. The `Retrieval_recommended` description column states whether the retrieval has recommended quality. Valid values occur roughly every 2-3 days. Flag bit 3 (value 8) is common in mid-summer over dense corn, because vegetation water content above ~5 kg/m² weakens the signal.

## Sample results CSV: `SPL4SMGP.008` (Representative)

```
ID,Category,Latitude,Longitude,Date,SPL4SMGP_008_Line_Y_9km,SPL4SMGP_008_Sample_X_9km,SPL4SMGP_008_Geophysical_Data_sm_surface,SPL4SMGP_008_Geophysical_Data_sm_rootzone,SPL4SMGP_008_Geophysical_Data_sm_rootzone_pctl,SPL4SMGP_008_Geophysical_Data_sm_rootzone_wetness
field-1842,York NE,40.95,-97.5,2025-07-01T01:30:00,509,2116,0.2841,0.3012,58.4,0.612
field-1842,York NE,40.95,-97.5,2025-07-01T04:30:00,509,2116,0.2830,0.3011,58.2,0.611
...
field-1842,York NE,40.95,-97.5,2025-08-15T22:30:00,509,2116,0.1702,0.2263,11.8,0.402
```

L4 rows are 3-hourly (`T01:30`, `T04:30` ...).

## Notes

- One 9 km pixel covers many fields; it does not distinguish irrigated from dryland areas inside the pixel.
- SMAP is unreliable over open water, dense forest, and frozen or snow-covered ground; L3 marks those as fill.
- Do not mix SMAP m³/m³ with NASA POWER `GWET*` wetness (0-1). Compare percentiles or trends instead.
- L4 is model output that assimilates satellite data, not a direct measurement.

## Documentation

- SPL3SMP_E user guide: https://nsidc.org/data/spl3smp_e
- SPL4SMGP: https://nsidc.org/data/spl4smgp
- SMAP mission: https://smap.jpl.nasa.gov/data/
