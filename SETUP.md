# Setting up the login-based sources

`farm_data.py` runs the six open sources with no setup. The sources below need free
accounts. Any source without credentials is printed as `SKIP` and the run continues.

All four accounts are free. Credentials go in environment variables or the standard
config files, never in the code.

| Source(s) | Account | What the script reads |
|---|---|---|
| SMAP soil moisture (L3 + L4 root zone), MODIS NDVI, ECOSTRESS ET (via AppEEARS); GPM IMERG daily rain | NASA Earthdata | `EARTHDATA_USERNAME` + `EARTHDATA_PASSWORD`, **or** `~/.netrc` |
| Sentinel-2 NDVI | Copernicus Data Space (CDSE) | `CDSE_CLIENT_ID` + `CDSE_CLIENT_SECRET` |
| ERA5 reanalysis | Copernicus Climate Data Store (CDS) | `~/.cdsapirc` + `pip install cdsapi` |
| County crop yields | USDA NASS QuickStats | `NASS_API_KEY` |
| OpenET evapotranspiration (17 western states only) | OpenET | `OPENET_API_KEY` |

## 1. NASA Earthdata (covers SMAP, MODIS, ECOSTRESS, IMERG)

1. Register at https://urs.earthdata.nasa.gov/users/new
2. In your Earthdata profile, open **Applications → Authorized Apps → Approve More Applications** and approve
   **NASA GESDISC DATA ARCHIVE** (required for IMERG). AppEEARS needs no extra approval.
3. Save the login in `~/.netrc` (preferred, since it keeps the password out of your shell history):
   ```
   machine urs.earthdata.nasa.gov login YOUR_USERNAME password YOUR_PASSWORD
   ```
   then `chmod 600 ~/.netrc`.

AppEEARS requests run asynchronously on NASA's servers. The first run typically waits 2–15 minutes.

## 2. Copernicus Data Space: Sentinel-2

1. Register at https://dataspace.copernicus.eu
2. Go to https://shapps.dataspace.copernicus.eu/dashboard/ → **User settings → OAuth clients → Create**.
3. Export the client ID and secret (the secret is shown only once):
   ```
   export CDSE_CLIENT_ID=...
   export CDSE_CLIENT_SECRET=...
   ```
The free tier allows a monthly processing-unit quota. One point-year of NDVI uses a very small share of it.

## 3. Copernicus Climate Data Store: ERA5

1. Register at https://cds.climate.copernicus.eu and accept the **ERA5 licence** on the dataset's
   *Download* tab (requests fail until you do).
2. Copy your API key from your CDS profile page into `~/.cdsapirc`:
   ```
   url: https://cds.climate.copernicus.eu/api
   key: YOUR-API-KEY
   ```
3. `python3 -m pip install --user "cdsapi>=0.7.2"`

ERA5 requests are queued. Expect a few minutes per request.

## 4. USDA NASS QuickStats

Request a key at https://quickstats.nass.usda.gov/api (it is emailed to you), then
`export NASS_API_KEY=...`. The script uses the crops it found in the Cropland Data Layer for the
point and pulls the last 10 years of county-level yields for each.

## 5. OpenET (western U.S. only)

Sign up at https://account.etdata.org, create an API key, then `export OPENET_API_KEY=...`.
OpenET is skipped automatically for points outside AZ, CA, CO, ID, KS, MT, NE, NV, NM, ND, OK,
OR, SD, TX, UT, WA, WY.

## Running

```
python3 farm_data.py LAT LON [START YYYYMMDD] [END YYYYMMDD] [--open-only]
```
The output JSON adds a `time_series_summary` section with one line per source and variable,
so you can directly compare related measurements, for example:

- rainfall from IMERG, NASA POWER, and ERA5
- NDVI from MODIS and Sentinel-2
- soil moisture from SMAP and NASA POWER root-zone wetness

## Dropped from the list

- **NLDAS/GLDAS**: NASA retired the Hydrology Data Rods point service and the old NLDAS OPeNDAP
  path (both return *410 Gone*). SMAP L4 root-zone soil moisture covers the same need.
- **Landsat via EarthExplorer**: this is a manual download site with no API. Landsat-based surface reflectance is
  available through AppEEARS as HLS (`HLSL30.020`) if needed. Add it to `APPEEARS_LAYERS` in
  `login_sources.py`.
