# Data sources

Reference documentation for external data resources: one file per resource in `docs/data_sources/`. Each file contains the access details (base URL, auth, formats, coverage, resolution, cadence, limits), every documented request with its parameters, sample requests and responses, a field reference, factual notes, and links to the official documentation.

These files describe the resources only. They make no product or design decisions.

## Conventions

- **Reference site.** Samples use **40.95, -97.50** (WGS84), York County, Nebraska (state FIPS 31, county FIPS 31185, ZIP 68467) and 2024-2025 dates, unless a file states otherwise.
- **Captured** samples are real responses fetched on 2026-11-14 (or 2026-11-15 for the market, rotation, nutrient and pest files), trimmed for length only (each file says what was trimmed). Global datasets also show one non-US example, named in the file.
- **Representative** samples were not fetched (login or key required, or the endpoint failed). They follow the provider's official documentation, and the file's Notes say why.
- **Licence.** The market, rotation, nutrient and pest files carry a Licence section with the licence string the provider returned, where it was read, and any difference from the commercial-use inventories it was checked against. Verdicts: PASS (commercial reuse allowed), UNKNOWN (no grant found or conflicting statements), FAIL (listed under Evaluated and excluded).
- **NASA first.** Every file in those groups has an "Overlap with NASA sources" section. Where a NASA source serves the same variable, it is listed first in the map below; the other sources complement it.
- **Credential names** are listed below. Values are never written in these docs.

## NASA first: which source serves each need

| Need | NASA source (primary) | Complements |
|---|---|---|
| Daily and hourly weather at a field (temperature, humidity, dew point, rain, wind, radiation) | [nasa_power.md](data_sources/nasa_power.md) | Daymet, PRISM, CoCoRaHS, ERA5 |
| Rainfall at high resolution and rainy-season onset | [gpm_imerg.md](data_sources/gpm_imerg.md) | CoCoRaHS, PRISM |
| Soil moisture and water stress | [smap.md](data_sources/smap.md), [nldas_gldas.md](data_sources/nldas_gldas.md), [grace.md](data_sources/grace.md), POWER `GWET*` | OpenET, USGS water |
| Evapotranspiration | [ecostress.md](data_sources/ecostress.md), POWER `EVPTRNS` | OpenET, FAO-56 coefficients |
| Crop condition, green-up and senescence | [vegetation_indices.md](data_sources/vegetation_indices.md), [landsat.md](data_sources/landsat.md), [gibs_worldview.md](data_sources/gibs_worldview.md) | Sentinel-2, [geoglam_crop_calendars.md](data_sources/geoglam_crop_calendars.md) (expected stage) |
| Season windows (planting, harvest) | none as a product; NASA Harvest supports GEOGLAM Crop Monitor | [geoglam_crop_calendars.md](data_sources/geoglam_crop_calendars.md) |
| Pest and disease weather triggers | POWER hourly and daily inputs, documented in [pest_weather_rules.md](data_sources/pest_weather_rules.md) | thresholds from [thermal_tolerance_datasets.md](data_sources/thermal_tolerance_datasets.md) and the cited papers |
| Pest occurrence, host lists, codes | none | GBIF, FAO catalog, insect monitoring, EPPO Codes, host tables |
| Crop losses by cause | none | USDA RMA (US only) |
| Rotation effects and crop sequences | none | rotation datasets, NASS Crop Sequence Boundaries |
| Nutrient removal and balance | none | FAOSTAT ESB, Dryad coefficient tables |
| Prices, demand and trade | none | FAOSTAT, FPMA, WFP, FEWS NET, World Bank, OECD, BACI, Harvard Atlas, USDA FAS, Eurostat, AMS, NASS, ERS |
| Distance to markets and ports | none | MAP travel-time rasters, World Port Index |

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

### Global markets: prices, demand and trade

NASA publishes no price or trade data; these sources stand alone.

| Resource | File | Auth | Licence verdict |
|---|---|---|---|
| FAOSTAT (producer prices, production, trade, food balances; bulk files and API) | [faostat.md](data_sources/faostat.md) | bulk none; API bearer token | PASS with FAO terms caveats |
| FAO GIEWS FPMA domestic and international food prices | [fao_fpma.md](data_sources/fao_fpma.md) | none | UNKNOWN per series (PASS for FAO-owned series) |
| WFP food prices (HDX) and DataBridges API | [wfp_food_prices.md](data_sources/wfp_food_prices.md) | HDX none; DataBridges WFP client credentials | HDX PASS (CC BY-IGO); DataBridges UNKNOWN |
| FEWS NET Data Warehouse market prices | [fews_net.md](data_sources/fews_net.md) | none for public data | API UNKNOWN; HDX archive PASS |
| World Bank Pink Sheet, Real-Time Food Prices, Indicators | [world_bank_food_prices.md](data_sources/world_bank_food_prices.md) | none | Pink Sheet PASS; RTFP UNKNOWN |
| OECD Data Explorer SDMX (OECD-FAO Agricultural Outlook) | [oecd_sdmx.md](data_sources/oecd_sdmx.md) | none | PASS (not re-read; endpoint blocked scripts on 2026-11-15) |
| CEPII BACI bilateral HS6 trade | [cepii_baci.md](data_sources/cepii_baci.md) | none | PASS (Etalab 2.0) |
| Harvard Growth Lab trade data (Dataverse) | [harvard_atlas_trade.md](data_sources/harvard_atlas_trade.md) | none | PASS (CC0) |
| USDA FAS Open Data (PSD, GATS, ESR) | [usda_fas_opendata.md](data_sources/usda_fas_opendata.md) | api.data.gov key | PSD PASS; GATS and ESR UNKNOWN |
| Eurostat and Comext | [eurostat.md](data_sources/eurostat.md) | none | PASS with listed exceptions |
| Market access: MAP travel time, World Port Index | [market_access.md](data_sources/market_access.md) | none | PASS |

### Crop rotation, calendars and nutrients

| Resource | File | Auth | Licence verdict |
|---|---|---|---|
| Rotation and crop-sequence datasets (Zhao 2022, Antichi EGLD, Ballot LUCAS, CropRot, EuroCrops, Kluger 2025, NASS Crop Sequence Boundaries) | [rotation_datasets.md](data_sources/rotation_datasets.md) | none | PASS per dataset (EuroCrops is CC BY-SA) |
| GEOGLAM Crop Monitor sub-national crop calendars | [geoglam_crop_calendars.md](data_sources/geoglam_crop_calendars.md) | none | PASS (CC BY 4.0) |
| Nutrient removal: FAOSTAT Cropland Nutrient Balance, Aramburu-Merlos 2025, Ludemann coefficients | [nutrient_removal.md](data_sources/nutrient_removal.md) | FAOSTAT bulk none; Dryad file downloads bearer token | PASS (CC BY 4.0, CC0) |

### Pests and diseases

| Resource | File | Auth | Licence verdict |
|---|---|---|---|
| Pest and disease weather rules on NASA POWER hourly and daily data | [pest_weather_rules.md](data_sources/pest_weather_rules.md) | none | POWER open; rules cited, Magarey table UNKNOWN |
| Thermal tolerance and pathogen cardinal temperatures (GlobTherm, Togashi, DDRP) | [thermal_tolerance_datasets.md](data_sources/thermal_tolerance_datasets.md) | metadata none; Dryad downloads bearer token | PASS (CC0, CC BY 4.0) |
| EPPO Codes and Global Database | [eppo.md](data_sources/eppo.md) | EPPO Data Portal API key | Codes PASS; hosts, distribution, categorization UNKNOWN |
| Host-pest tables (NHM HOSTS, USDA Fungus-Host, GloBI) | [host_pest_datasets.md](data_sources/host_pest_datasets.md) | none | PASS (GloBI per source) |
| GBIF occurrences (and Atlas of Living Australia) | [gbif.md](data_sources/gbif.md) | none (account for async downloads) | PASS for CC0 and CC BY rows only |
| FAO data catalog: FAMEWS fall armyworm traps, Desert Locust | [fao_data_catalog.md](data_sources/fao_data_catalog.md) | none | FAMEWS PASS; Desert Locust UNKNOWN (conflict); FAW map layer FAIL |
| Insect monitoring datasets (Rothamsted, Ag Data Commons traps, CIMMYT) | [insect_monitoring_datasets.md](data_sources/insect_monitoring_datasets.md) | none; CIMMYT API needs login | PASS per deposit; RIS online database and CIMMYT UNKNOWN |
| USDA RMA Cause of Loss (insured losses by cause, incl. insects and plant disease) | [usda_rma_cause_of_loss.md](data_sources/usda_rma_cause_of_loss.md) | none | PASS (US Government work, CC0 on data.gov) |

### Evaluated and excluded (commercial use not allowed)

No files were written for these. Reasons are from the commercial-use inventories.

| Source | Reason | Where stated |
|---|---|---|
| UN Comtrade (raw data in a commercial app or API) | Commercial APIs and for-profit apps need a fee-bearing distribution licence; transformed data is free | https://uncomtrade.org/docs/re-dissemination-of-data/ |
| IMF Primary Commodity Prices | Commercial reuse needs IMF permission; bulk automated download prohibited without permission | https://imf.org/en/research/commodity-prices |
| WTO Timeseries API and tariff data | Non-commercial reproduction only; commercial use needs written permission | https://api.wto.org/timeseries/v1 |
| WITS (Comtrade and WTO data) | "internal use only"; "may not be distributed for profit or commercial advantage" | https://wits.worldbank.org/wits/registration/TermsAndCondtions.aspx |
| ITC Trade Map and Market Access Map | Bars use of content to populate another database, platform or API for redistribution or commercial service | https://account.marketanalysis.intracen.org/en/pricing/terms-and-conditions/terms |
| OEC (Observatory of Economic Complexity) | Paid tiers; terms bar redistribution or reselling of content | https://oec.world/en/resources/terms |
| CABI distribution data, Plantwise, Invasive Species Compendium | Non-commercial or on permission only | https://ckan.cabi.org/data/dataset/pest-and-pathogen-distribution-data |
| Savary et al. 2019 per-pest loss data | Available on request only | https://www.nature.com/articles/s41559-018-0793-y |
| FAO Fall Armyworm map layer, FAO Locust Hub downloads | CC BY-NC-SA; "non-commercial products or services" | https://data.apps.fao.org/catalog/dataset/fall-armyworm ; https://locust-hub-hqfao.hub.arcgis.com/ |
| IPPC website material | "No material ... may be used for the purpose of monetary gain" | https://www.ippc.int/en/resources/publications/ |
| EPPO photos | Educational use only | https://gd.eppo.int/ |
| GBIF, iNaturalist and ALA records under CC BY-NC | Non-commercial licence per record | see [gbif.md](data_sources/gbif.md) |

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
| api.data.gov key | USDA ERS, USDA FAS Open Data (header `API_KEY`) | not configured |
| EPPO Data Portal API key | EPPO API v2 (header `X-Api-Key`) | not configured |
| FAOSTAT API bearer token | FAOSTAT JSON API (bulk files need none) | not configured; no public issuance path found |
| Dryad API token | Dryad file downloads (metadata needs none) | not configured |
| WFP DataBridges client id and secret | WFP DataBridges API | not configured; requested from the WFP VAM team |
| `CDSE_CLIENT_ID`, `CDSE_CLIENT_SECRET` | Copernicus Data Space (Sentinel Hub) | not configured |
| CDS API key | ERA5 | not configured |
| USGS ERS login | Landsat M2M | not configured |
