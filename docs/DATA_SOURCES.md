# Data sources

Reference documentation for external data resources: one file per resource in `docs/data_sources/`. Each file contains the access details (base URL, auth, formats, coverage, resolution, cadence, limits), every documented request with its parameters, sample requests and responses, a field reference, factual notes, and links to the official documentation.

These files describe the resources only. They make no product or design decisions.

## Conventions

- **Reference site.** Samples use **40.95, -97.50** (WGS84), York County, Nebraska (state FIPS 31, county FIPS 31185, ZIP 68467) and 2024-2025 dates, unless a file states otherwise.
- **Captured** samples are real responses fetched on 2026-11-14, trimmed for length only (each file says what was trimmed).
- **Representative** samples were not fetched (login or key required, or the endpoint failed). They follow the provider's official documentation, and the file's Notes say why.
- **Credential names** are listed below. Values are never written in these docs.

## Connected in the app

NASA POWER, FAO GAEZ, SSURGO, USGS 3DEP (EPQS), the Cropland Data Layer and the FCC Census Block API are fetched for every field pin (`docs/FIELDS.md`); NASA GIBS is shown as a picture URL; FAO ECOCROP is a dataset extracted into `config/ecocrop.yml`.

## Index

### Weather and climate

| Resource | File | Auth |
|---|---|---|
| NASA POWER (daily, monthly, climatology) | [nasa_power.md](data_sources/nasa_power.md) | none |
| Daymet (ORNL single-pixel) | [daymet.md](data_sources/daymet.md) | none |
| PRISM Climate Data (Oregon State) | [prism.md](data_sources/prism.md) | none |
| GPM IMERG precipitation | [gpm_imerg.md](data_sources/gpm_imerg.md) | Earthdata |
| CoCoRaHS community precipitation | [cocorahs.md](data_sources/cocorahs.md) | none |
| ERA5 reanalysis and Sentinel-2 statistics (Copernicus) | [copernicus.md](data_sources/copernicus.md) | CDS / CDSE account |
| NLDAS and GLDAS land data assimilation | [nldas_gldas.md](data_sources/nldas_gldas.md) | Earthdata |
| USDA Plant Hardiness Zone Map | [plant_hardiness.md](data_sources/plant_hardiness.md) | none |

### Soil moisture, water and evapotranspiration

| Resource | File | Auth |
|---|---|---|
| SMAP soil moisture (L3, L4) | [smap.md](data_sources/smap.md) | Earthdata (via AppEEARS) |
| ECOSTRESS and MODIS thermal / ET | [ecostress.md](data_sources/ecostress.md) | Earthdata (via AppEEARS) |
| OpenET | [openet.md](data_sources/openet.md) | OpenET API key |
| GRACE / GRACE-FO and drought indicators | [grace.md](data_sources/grace.md) | Earthdata (files); indicators none |
| USGS water: streamflow and groundwater | [usgs_water.md](data_sources/usgs_water.md) | none |

### Vegetation, imagery and land cover

| Resource | File | Auth |
|---|---|---|
| Vegetation indices (MODIS, HLS, phenology) | [vegetation_indices.md](data_sources/vegetation_indices.md) | Earthdata (via AppEEARS) |
| Landsat (STAC, M2M) | [landsat.md](data_sources/landsat.md) | none for STAC; USGS ERS for M2M |
| Sentinel-2 open catalogs (CDSE STAC/OData, Earth Search) | [sentinel2_stac.md](data_sources/sentinel2_stac.md) | none for search |
| NAIP aerial imagery | [naip.md](data_sources/naip.md) | none |
| NASA Worldview / GIBS map layers | [gibs_worldview.md](data_sources/gibs_worldview.md) | none |
| NLCD / Annual NLCD land cover | [nlcd.md](data_sources/nlcd.md) | none |
| LANDFIRE vegetation and fuels | [landfire.md](data_sources/landfire.md) | none (LFPS jobs need an email) |
| GEDI canopy and biomass | [gedi.md](data_sources/gedi.md) | Earthdata (files) |
| Cropland Data Layer (CropScape) | [cropland_cdl.md](data_sources/cropland_cdl.md) | none |

### Soil and terrain

| Resource | File | Auth |
|---|---|---|
| SSURGO via Soil Data Access (also Web Soil Survey) | [ssurgo.md](data_sources/ssurgo.md) | none |
| Terrain: USGS 3DEP elevation, SRTM / NASADEM | [terrain.md](data_sources/terrain.md) | none (3DEP); Earthdata (SRTM via AppEEARS) |

### Crop characteristics

| Resource | File | Auth |
|---|---|---|
| FAO ECOCROP crop requirements | [ecocrop.md](data_sources/ecocrop.md) | none |
| FAO-56 crop coefficient tables | [fao56_crop_coefficients.md](data_sources/fao56_crop_coefficients.md) | none |
| USDA PLANTS Database | [usda_plants.md](data_sources/usda_plants.md) | none |
| FAO GAEZ v4 suitability and yield | [gaez.md](data_sources/gaez.md) | none |
| Cover crop selector tools | [cover_crop_selectors.md](data_sources/cover_crop_selectors.md) | see file |

### Agricultural statistics, markets and research data

| Resource | File | Auth |
|---|---|---|
| USDA NASS QuickStats | [nass_quickstats.md](data_sources/nass_quickstats.md) | NASS API key |
| USDA AMS Market News | [ams_market_news.md](data_sources/ams_market_news.md) | AMS API key |
| USDA ERS data APIs | [usda_ers.md](data_sources/usda_ers.md) | api.data.gov key |
| USDA Ag Data Commons | [ag_data_commons.md](data_sources/ag_data_commons.md) | none |

### Access layers and helpers

| Resource | File | Auth |
|---|---|---|
| NASA AppEEARS (point/area extraction for 190+ products) | [appeears.md](data_sources/appeears.md) | Earthdata |
| NASA Earthdata CMR Search (catalog of all NASA collections and granules) | [earthdata_cmr.md](data_sources/earthdata_cmr.md) | none |
| FCC Census Block (point to county/state) | [fcc_census_block.md](data_sources/fcc_census_block.md) | none |

## Credentials (names only)

| Name | Used by | Status on 2026-11-14 |
|---|---|---|
| `EARTHDATA_USERNAME`, `EARTHDATA_PASSWORD` | AppEEARS, GES DISC (IMERG, NLDAS/GLDAS), PO.DAAC (GRACE), ORNL DAAC files, Cloud OPeNDAP | configured; IMERG needs the NASA GESDISC DATA ARCHIVE app approved in the Earthdata profile |
| `OPENET_API_KEY` | OpenET | configured |
| `NASS_API_KEY` | NASS QuickStats | not configured |
| AMS Market News API key | AMS Market News | not configured |
| api.data.gov key | USDA ERS | not configured |
| `CDSE_CLIENT_ID`, `CDSE_CLIENT_SECRET` | Copernicus Data Space (Sentinel Hub) | not configured |
| CDS API key | ERA5 | not configured |
| USGS ERS login | Landsat M2M | not configured |
