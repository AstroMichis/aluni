# FAO GAEZ v4 (Global Agro-Ecological Zones)

GAEZ v4 is the FAO Global Agro-Ecological Zones assessment. It publishes global raster layers (5 arc-minute grid, about 9 km at the equator) of crop suitability (index and classes), agro-ecological attainable yield, crop water indicators (actual crop evapotranspiration, water deficit) and actual harvested area, yield and production, for around 50 crops. Suitability and attainable-yield layers are computed for a baseline climate (CRU TS 3.2, periods 1961-1990, 1971-2000, 1981-2010) and for future periods (2011-2040, 2041-2070, 2071-2100) under five climate models and four RCPs, by input level (High, Low), water supply (rainfed, rainfed all phases, irrigation types) and with or without CO2 fertilization. Layers are static GeoTIFF files; the data are served through an ArcGIS Hub portal, ArcGIS ImageServer services that support catalog queries and point identify, and direct file download URLs.

| | |
|---|---|
| Provider | FAO |
| Base URL | Portal `https://gaez.fao.org/`; services `https://gaez-services.fao.org/server/rest/services/`; files `https://s3.eu-west-1.amazonaws.com/data.gaezdev.aws.fao.org/` |
| Auth | none |
| Formats | GeoTIFF (single band; service `pixelType` S16 for `res05`, F32 for `res06`); JSON (ArcGIS REST) |
| Coverage | global, extent -180 to 180, -90 to 90 (EPSG:4326) |
| Resolution | 0.08333333 degrees (5 arc-minutes) for `res05` and `res06` |
| Cadence / latency | static (v4 release); time periods are 30-year climate windows or years 2000 and 2010 |
| Rate limits / quotas | not published; service info reports `maxRecordCount` 1000, `maxImageWidth` 15000, `maxImageHeight` 4100, `maxDownloadImageCount` 20 |
| Documentation | https://gaez.fao.org/ |

ImageServer services listed at `https://gaez-services.fao.org/server/rest/services?f=json` (ArcGIS Server 10.81) on 2026-11-14: `LR`, `res01`, `res02`, `res05`, `res06`, `res07` (plus folder `Utilities`). In the catalogs queried, `res05` holds suitability, attainable yield and crop water indicator layers; `res06` holds actual harvested area, yield and production layers. Both have capabilities `Catalog,Download,Image,Metadata`.

## Requests

### Catalog query (layer listing)

Returns catalog rows (one per GeoTIFF) with crop, scenario attributes, units and download URL.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `where` | yes | SQL filter on catalog fields | `crop='Maize' AND year='1981-2010' AND input_level='High' AND water_supply='Rainfed'` |
| `outFields` | no | Comma-separated fields or `*` | `name,variable,units,download_url` |
| `returnGeometry` | no | `false` omits footprint polygons | `false` |
| `returnDistinctValues` | no | `true` with one field lists its distinct values | `true` |
| `orderByFields` | no | Sort | `crop` |
| `resultRecordCount` | no | Page size (max 1000) | `100` |
| `f` | yes | Response format | `json` |

```
GET https://gaez-services.fao.org/server/rest/services/res05/ImageServer/query?where=year%3D%271981-2010%27+AND+model%3D%27CRUTS32%27+AND+input_level%3D%27High%27+AND+water_supply%3D%27Rainfed%27+AND+crop+IN+%28%27Maize%27%2C%27Soybean%27%2C%27Wheat%27%2C%27Rye%27%2C%27Alfalfa%27%29+AND+c02_fertilization%3D%27With+CO2+Fertilization%27&outFields=objectid%2Cname%2Csub_theme_name%2Cvariable%2Cyear%2Cmodel%2Crcp%2Ccrop%2Cwater_supply%2Cinput_level%2Cc02_fertilization%2Cunits%2Cdownload_url%2Cfile_id&returnGeometry=false&orderByFields=crop&f=json
```

### Sample response (Captured 2026-11-14)

Trimmed: the `fields` array (field definitions) removed; `features` reduced from 49 rows to the attainable-yield and suitability-index rows for maize, plus one row each for soybean, rye, alfalfa; wheat row from a second query with `name LIKE 'yx%'` and `crop='Wheat'`.

```json
{
  "objectIdFieldName": "objectid",
  "features": [
    {"attributes": {"objectid": 258632, "name": "yxHr_mze", "sub_theme_name": "Agro-ecological Attainable Yield ", "variable": "Average attainable yield of best occurring suitability class in grid cell", "year": "1981-2010", "model": "CRUTS32", "rcp": "Historical", "crop": "Maize", "water_supply": "Rainfed", "input_level": "High", "c02_fertilization": "With CO2 Fertilization", "units": "kg DW/ha", "download_url": "https://s3.eu-west-1.amazonaws.com/data.gaezdev.aws.fao.org/res05/CRUTS32/Hist/8110H/yxHr_mze.tif", "file_id": "000582567"}},
    {"attributes": {"objectid": 258192, "name": "ycHr_mze", "sub_theme_name": "Agro-ecological Attainable Yield ", "variable": "Average attainable yield of current cropland", "year": "1981-2010", "model": "CRUTS32", "rcp": "Historical", "crop": "Maize", "water_supply": "Rainfed", "input_level": "High", "c02_fertilization": "With CO2 Fertilization", "units": "kg DW/ha", "download_url": "https://s3.eu-west-1.amazonaws.com/data.gaezdev.aws.fao.org/res05/CRUTS32/Hist/8110H/ycHr_mze.tif", "file_id": "000583031"}},
    {"attributes": {"objectid": 257854, "name": "sxHr_mze", "sub_theme_name": "Suitability Index", "variable": "Suitability index  range (0 – 10000); all land in grid cell", "year": "1981-2010", "model": "CRUTS32", "rcp": "Historical", "crop": "Maize", "water_supply": "Rainfed", "input_level": "High", "c02_fertilization": "With CO2 Fertilization", "units": "Index", "download_url": "https://s3.eu-west-1.amazonaws.com/data.gaezdev.aws.fao.org/res05/CRUTS32/Hist/8110H/sxHr_mze.tif", "file_id": "000582405"}},
    {"attributes": {"objectid": 256754, "name": "siHr_mze", "sub_theme_name": "Suitability Class", "variable": "Crop suitability index in classes; all land in grid cell", "year": "1981-2010", "model": "CRUTS32", "rcp": "Historical", "crop": "Maize", "water_supply": "Rainfed", "input_level": "High", "c02_fertilization": "With CO2 Fertilization", "units": "Class", "download_url": "https://s3.eu-west-1.amazonaws.com/data.gaezdev.aws.fao.org/res05/CRUTS32/Hist/8110H/siHr_mze.tif", "file_id": "000582946"}},
    {"attributes": {"objectid": 258649, "name": "yxHr_soy", "sub_theme_name": "Agro-ecological Attainable Yield ", "variable": "Average attainable yield of best occurring suitability class in grid cell", "year": "1981-2010", "model": "CRUTS32", "rcp": "Historical", "crop": "Soybean", "water_supply": "Rainfed", "input_level": "High", "c02_fertilization": "With CO2 Fertilization", "units": "kg DW/ha", "download_url": "https://s3.eu-west-1.amazonaws.com/data.gaezdev.aws.fao.org/res05/CRUTS32/Hist/8110H/yxHr_soy.tif", "file_id": "000583298"}},
    {"attributes": {"objectid": 258658, "name": "yxHr_whe", "crop": "Wheat", "units": "kg DW/ha", "download_url": "https://s3.eu-west-1.amazonaws.com/data.gaezdev.aws.fao.org/res05/CRUTS32/Hist/8110H/yxHr_whe.tif"}},
    {"attributes": {"objectid": 258647, "name": "yxHr_rye", "sub_theme_name": "Agro-ecological Attainable Yield ", "variable": "Average attainable yield of best occurring suitability class in grid cell", "year": "1981-2010", "model": "CRUTS32", "rcp": "Historical", "crop": "Rye", "water_supply": "Rainfed", "input_level": "High", "c02_fertilization": "With CO2 Fertilization", "units": "kg DW/ha", "download_url": "https://s3.eu-west-1.amazonaws.com/data.gaezdev.aws.fao.org/res05/CRUTS32/Hist/8110H/yxHr_rye.tif", "file_id": "000582557"}},
    {"attributes": {"objectid": 258611, "name": "yxHr_alf", "sub_theme_name": "Agro-ecological Attainable Yield ", "variable": "Average attainable yield of best occurring suitability class in grid cell", "year": "1981-2010", "model": "CRUTS32", "rcp": "Historical", "crop": "Alfalfa", "water_supply": "Rainfed", "input_level": "High", "c02_fertilization": "With CO2 Fertilization", "units": "10kg DW/ha", "download_url": "https://s3.eu-west-1.amazonaws.com/data.gaezdev.aws.fao.org/res05/CRUTS32/Hist/8110H/yxHr_alf.tif", "file_id": "000582154"}}
  ]
}
```

For alfalfa, maize and rye the query returned 14 layers per crop with these prefixes: `yx`, `yc`, `yl`, `sx`, `su`, `sx1`, `sx2`, `sx3`, `sc`, `si`, `wdl`, `wdc`, `etc`, `etl` prefixes (see Fields).

### Point value (identify)

Returns the pixel value of one layer at a point. The layer is selected with a lock-raster mosaic rule using its catalog `objectid`.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `geometry` | yes | Point JSON, lon/lat | `{"x":-97.5,"y":40.95}` |
| `geometryType` | yes | | `esriGeometryPoint` |
| `mosaicRule` | yes (to pick one layer) | Lock raster by objectid | `{"mosaicMethod":"esriMosaicLockRaster","lockRasterIds":[258632]}` |
| `returnCatalogItems` | no | | `false` |
| `f` | yes | | `json` |

```
GET https://gaez-services.fao.org/server/rest/services/res05/ImageServer/identify?geometry=%7B%22x%22%3A-97.5%2C%22y%22%3A40.95%7D&geometryType=esriGeometryPoint&mosaicRule=%7B%22mosaicMethod%22%3A%22esriMosaicLockRaster%22%2C%22lockRasterIds%22%3A%5B258632%5D%7D&returnCatalogItems=false&f=json
```

### Sample response (Captured 2026-11-14)

Untrimmed. Layer `yxHr_mze` (maize, rainfed, high input, 1981-2010), unit kg DW/ha.

```json
{"objectId":0,"name":"Pixel","value":"6867","location":{"x":-97.5,"y":40.950000000000003,"spatialReference":{"wkid":4326,"latestWkid":4326}},"properties":null,"catalogItems":null,"catalogItemVisibilities":[]}
```

### File download

Each catalog row's `download_url` is a GeoTIFF.

```
GET https://s3.eu-west-1.amazonaws.com/data.gaezdev.aws.fao.org/res05/CRUTS32/Hist/8110H/yxHr_mze.tif
```

HEAD on 2026-11-14: HTTP 200, `image/tiff`, 2,903,733 bytes (file not downloaded).

### Actual area, yield and production (`res06`)

Same query interface; fields `Name`, `sub_theme_name`, `variable`, `year`, `crop`, `water_supply`, `units`, `download_url`, `file_id`.

```
GET https://gaez-services.fao.org/server/rest/services/res06/ImageServer/query?where=crop%3D%27Maize%27&outFields=Name,sub_theme_name,variable,year,water_supply,units,download_url&returnGeometry=false&f=json
```

### Sample response (Captured 2026-11-14)

First 3 of the returned rows, attributes only:

```json
{"OBJECTID": 523, "Name": "mze_2000_har", "sub_theme_name": "Area, Yield and Production", "variable": "Harvested area", "year": "2000", "water_supply": "Irrigated", "units": "1000 ha", "download_url": " https://s3.eu-west-1.amazonaws.com/data.gaezdev.aws.fao.org/res06/I/2000/mze_2000_har.tif"}
{"OBJECTID": 524, "Name": "mze_2000_prd", "sub_theme_name": "Area, Yield and Production", "variable": "Production", "year": "2000", "water_supply": "Irrigated", "units": "1000 t", "download_url": " https://s3.eu-west-1.amazonaws.com/data.gaezdev.aws.fao.org/res06/I/2000/mze_2000_prd.tif"}
{"OBJECTID": 525, "Name": "mze_2000_yld", "sub_theme_name": "Area, Yield and Production", "variable": "Yield", "year": "2000", "water_supply": "Irrigated", "units": "t/ha", "download_url": " https://s3.eu-west-1.amazonaws.com/data.gaezdev.aws.fao.org/res06/I/2000/mze_2000_yld.tif"}
```

## Fields

### `res05` catalog fields

| Field | Type | Unit | Description |
|---|---|---|---|
| `objectid` | integer | | Catalog item id (used in `lockRasterIds`) |
| `name` | string | | Layer code (see naming below) |
| `filepath` | string | | Server path, e.g. `\res05\CRUTS32\Hist\8110H\yxHr_mze.tif` |
| `sub_theme_name` | string | | `Agro-ecological Attainable Yield ` (trailing space as returned), `Suitability Index`, `Suitability Class`, `Crop Water Indicators` |
| `variable` | string | | Variable description |
| `file_description` | string | | Long description of the layer |
| `year` | string | | `1961-1990`, `1971-2000`, `1981-2010`, `2011-2040`, `2041-2070`, `2071-2100` |
| `model` | string | | `CRUTS32` (historical), `GFDL-ESM2M`, `HadGEM2-ES`, `IPSL-CM5A-LR`, `MIROC-ESM-CHEM`, `NorESM1-M`, `ENSEMBLE` |
| `rcp` | string | | `Historical`, `RCP2.6`, `RCP4.5`, `RCP6.0`, `RCP8.5` |
| `crop` | string | | Crop name (50 distinct values, listed in Notes) |
| `water_supply` | string | | `Rainfed`, `Rainfed All Phases ` (trailing space), `Irrigation`, `Gravity Irrigation`, `Sprinkler Irrigation`, `Drip Irrigation` |
| `input_level` | string | | `High`, `Low` |
| `c02_fertilization` | string | | `With CO2 Fertilization`, `Without CO2 Fertilization` (field name spelled `c02` with a zero) |
| `units` | string | | Units of the pixel values (table below) |
| `renderer` | string | | Recommended renderer name |
| `download_url` | string | | GeoTIFF URL |
| `file_id` | string | | File identifier |

### `res05` variables (distinct `sub_theme_name` / `variable` / `units`)

| Prefix (from names observed) | Variable | Units observed |
|---|---|---|
| `yx` | Average attainable yield of best occurring suitability class in grid cell | kg DW/ha, 10kg DW/ha, kg lint/ha, kg oil/ha, kg sugar/ha |
| `yc` | Average attainable yield of current cropland | same set |
| `yl` | Output density (potential production divided by total grid cell area) | same set |
| `sx` | Suitability index range (0 - 10000); all land in grid cell | Index |
| `su` | Suitability index range (0 - 10000); current cropland in grid cell | Index |
| `sx1` | Share of grid cell assessed as VS or S (range 0 - 10000) | Index |
| `sx2` | Share of VS+S+MS land in grid cell (range 0 - 10000) | Index |
| `sx3` | Share of VS+S+MS+mS land in grid cell (range 0 - 10000) | Index |
| `si` | Crop suitability index in classes; all land in grid cell | Class |
| `sc` | Crop suitability index in classes; current cropland in grid cell | Class |
| `etl` | Actual crop evapotranspiration (excluding irrigation), average for grid cell | mm |
| `etc` | Actual crop evapotranspiration (excluding irrigation), for current cropland | mm |
| `wdl` | Water deficit/net irrigation requirement during crop cycle, total grid cell | mm |
| `wdc` | Water deficit/net irrigation requirement during crop cycle, current cropland | mm |

### Layer naming observed

`<prefix><input><water>[0]_<crop>`:

| Part | Values observed | Meaning (from catalog attributes of the same rows) |
|---|---|---|
| `<input>` | `H`, `L` | `input_level` High, Low |
| `<water>` | `r`, `a` | `water_supply` Rainfed, Rainfed All Phases |
| `0` | present / absent | `Without CO2 Fertilization` / `With CO2 Fertilization` (e.g. `yxHr0_mze` vs `yxHr_mze`) |
| `<crop>` | `mze`, `soy`, `whe`, `rye`, `alf` | Maize, Soybean, Wheat, Rye, Alfalfa |

Folder codes in `filepath` / `download_url`: `<model>/<rcp folder>/<period><input>`; rcp folders `Hist`, `rcp2p6`, `rcp4p5`, `rcp6p0`, `rcp8p5`; period codes observed for maize `yxHr_mze`: `6190`, `7100`, `8110` (historical), `2020s`, `2050s`, `2080s` (future), followed by `H` or `L`.

### `res06` variables

| Variable | Units |
|---|---|
| Harvested area | 1000 ha |
| Production | 1000 t; mln GK$ |
| Yield | t/ha; 1000 GK$/ha |
| Total crop production volume (sub-theme "Aggregate Crop Production Value") | 1000 GK$ |

`res06` names: `<crop>_<year>_<har|prd|yld>`; `water_supply` `Irrigated` or `Rainfed` (folder `I` / `R`), years `2000`, `2010`.

Identify returns the pixel value as a string. No-data values are not given in the service info (`noDataValue: null`).

## Notes

- `https://gaez-data.fao.org/` returned HTTP 503 (Service Unavailable) on 2026-11-14; the portal at `https://gaez.fao.org/` (ArcGIS Hub, HTTP 200) and the ImageServer services worked.
- The 50 crops in `res05`: Alfalfa, Banana, Barley, Biomass sorghum, Buckwheat, Cabbage, Carrot, Cassava, Chickpea, Citrus, Cocoa, Coconut, Coffee, Cotton, Cowpea, Dry pea, Dryland rice, Flax, Foxtail millet, Gram, Groundnut, Jatropha, Maize, Miscanthus, Napier grass, Oat, Oil palm, Olive, Onion, Pearl millet, Phaseolus bean, Pigeonpea, Rapeseed, Reed canary grass, Rubber, Rye, Sorghum, Soybean, Sugarbeet, Sugarcane, Sunflower, Sweet potato, Switchgrass, Tea, Tobacco, Tomato, Wetland rice, Wheat, White potato, Yam. Apple is not among them; there is no separate winter wheat crop value.
- Attainable yield units differ by crop (e.g. alfalfa `10kg DW/ha`, maize `kg DW/ha`).
- Some text values carry a trailing space (`Agro-ecological Attainable Yield `, `Rainfed All Phases `) and `res06` `download_url` values start with a space; exact-match `where` clauses must include them.
- A query for maize `yx` layers with `model='ENSEMBLE'` returned 0 rows, and `water_supply LIKE '%Irrigation%'` with `name LIKE 'yx%'` for maize returned 0 rows, although both values appear in the distinct-value lists.
- No licence text was found on the GAEZ portal pages or service metadata fetched (`licenseInfo: null`, `copyrightText` empty); FAO terms of use are linked below.

## Documentation

- GAEZ v4 portal: https://gaez.fao.org/
- ArcGIS REST services directory: https://gaez-services.fao.org/server/rest/services
- `res05` service: https://gaez-services.fao.org/server/rest/services/res05/ImageServer
- `res06` service: https://gaez-services.fao.org/server/rest/services/res06/ImageServer
- ArcGIS ImageServer query / identify reference: https://developers.arcgis.com/rest/services-reference/enterprise/query-image-service/ ; https://developers.arcgis.com/rest/services-reference/enterprise/identify-image-service/
- FAO terms of use: https://www.fao.org/contact-us/terms/en/
