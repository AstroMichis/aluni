# Copernicus: ERA5 and Sentinel-2

The European Union's Copernicus programme (with ESA and ECMWF). Two sources complement NASA's:

| Source | What | Resolution | Access | Status |
|---|---|---|---|---|
| ERA5 | Hourly reanalysis weather since 1940: temperature, rain, radiation, humidity, wind, soil temperature and moisture | 0.25° (~28 km) | Climate Data Store (CDS) API | credentials not configured |
| Sentinel-2 L2A | 10 m multispectral imagery every ~5 days, cloud-masked NDVI and other indices via server-side statistics | 10-20 m | Copernicus Data Space Ecosystem (CDSE), Sentinel Hub Statistical API | credentials not configured |

Both are optional: NASA POWER covers weather and HLS (through AppEEARS) covers 30 m vegetation, which already includes Sentinel-2 data harmonized to 30 m. Add these when 10 m in-field detail or an independent weather cross-check is needed. Samples are representative.

## ERA5 (Climate Data Store)

| | |
|---|---|
| Dataset | `reanalysis-era5-single-levels-timeseries` (point time series, CSV, fast) or `reanalysis-era5-land` (0.1°, land variables, gridded netCDF) |
| Auth | CDS personal access token (profile page); the ERA5 licence must be accepted once on the dataset page or every request fails |
| Model | queued job: submit, poll, download (seconds to minutes for the timeseries dataset) |
| Client | official `cdsapi` / `ecmwf-datastores-client` in Python; plain HTTPS works too (`PRIVATE-TOKEN` header) |
| Docs | https://cds.climate.copernicus.eu/how-to-api |

Request (timeseries dataset):

```json
{
  "variable": ["2m_temperature", "total_precipitation", "surface_solar_radiation_downwards", "2m_dewpoint_temperature"],
  "location": { "longitude": -97.50, "latitude": 40.95 },
  "date": ["2025-01-01/2025-10-31"],
  "data_format": "csv"
}
```

Sample CSV (Representative, hourly; sometimes delivered inside a zip):

```
valid_time,t2m,tp,ssrd,d2m,latitude,longitude
2025-07-04 18:00:00,302.41,0.00000,2884351.0,294.12,41.0,-97.5
2025-07-04 19:00:00,303.02,0.00041,3010562.0,294.55,41.0,-97.5
2025-07-04 20:00:00,301.87,0.00702,2410118.0,295.01,41.0,-97.5
```

Units: `t2m`, `d2m` Kelvin (minus 273.15); `tp` metres per hour (x 1000 = mm, sum per day); `ssrd` J/m² accumulated per hour (sum per day ÷ 10⁶ = MJ/m²/day). Note the coordinates snap to the 0.25° grid (41.0, -97.5).


## Sentinel-2 (Copernicus Data Space, Sentinel Hub)

| | |
|---|---|
| Token | `POST https://identity.dataspace.copernicus.eu/auth/realms/CDSE/protocol/openid-connect/token` with `grant_type=client_credentials`, `client_id`, `client_secret` (OAuth client created in the Sentinel Hub dashboard) |
| Statistics | `POST https://sh.dataspace.copernicus.eu/api/v1/statistics` |
| Data type | `sentinel-2-l2a` |
| Quota | monthly processing units on the free tier; a field-season of daily NDVI stats is a small fraction |
| Docs | https://documentation.dataspace.copernicus.eu/APIs/SentinelHub/Statistical.html |

Request body: field polygon (CRS84), time range, `aggregationInterval` (`P1D` for each acquisition), and an evalscript that computes NDVI and masks clouds with the scene classification band (`SCL` values 3 shadow, 8-10 cloud and cirrus, 11 snow). A sample response and how to read it are in `vegetation_indices.md`.

## Documentation

- CDS API: https://cds.climate.copernicus.eu/how-to-api
- ERA5 timeseries dataset: https://cds.climate.copernicus.eu/datasets/reanalysis-era5-single-levels-timeseries
- CDSE Sentinel Hub: https://documentation.dataspace.copernicus.eu/APIs/SentinelHub.html
