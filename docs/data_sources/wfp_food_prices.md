# WFP food prices (HDX datasets and the DataBridges API)

The World Food Programme's Vulnerability Analysis and Mapping unit (WFP VAM) collects retail and wholesale food prices in about 3,000 markets of 98 countries and publishes them two ways. On the Humanitarian Data Exchange (HDX) it maintains a global dataset split into one CSV per year, one dataset per country with the country's full history and a markets file with coordinates, a Global Market Monitor dataset of food-basket cost changes, and a frozen legacy database (1992 to 2021). All HDX files are CC BY-IGO and are listed and downloaded through HDX's CKAN API without a login. The same unit runs the DataBridges API, which serves daily, weekly and monthly prices (retail, wholesale and farm-gate) plus the ALPS price-anomaly indicator, behind OAuth2 client credentials issued on request.

| | |
|---|---|
| Provider | WFP VAM (World Food Programme, Research, Assessment and Monitoring division) |
| Base URL | HDX CKAN API `https://data.humdata.org/api/3/action/`; files `https://data.humdata.org/dataset/{dataset uuid}/resource/{resource uuid}/download/{file}`; DataBridges `https://gateway.api.wfp.org/vam-data-bridges/v2` |
| Auth | HDX: none. DataBridges: OAuth2 client credentials (client id and secret requested from the WFP VAM team), exchanged for a bearer token; most price endpoints additionally need a named permission on the application profile |
| Formats | CSV (HDX); JSON (CKAN API); JSON or CSV (DataBridges, `format` parameter) |
| Coverage | 98 countries, about 3,000 markets; global dataset dated 1990-01-15 to 2026-11-15 on HDX; per-country datasets carry the full history (Bangladesh 1998-07-15 to 2026-09-15); legacy database 76 countries, about 1,500 markets, 1990 to 2021-08 |
| Resolution | Market x commodity x date; markets carry latitude and longitude; mostly monthly observations, some weekly |
| Cadence / latency | Global and country datasets: `data_update_frequency` 30 days, last modified 2026-11-15 (global) and 2026-11-04 (Bangladesh prices); Global Market Monitor every 14 days (last file 2026-07-15); legacy: never |
| Rate limits / quotas | HDX: not published; DataBridges: not published |
| Licence | HDX datasets: Creative Commons Attribution for Intergovernmental Organisations (CC BY-IGO), `license_id` `cc-by-igo` on all four datasets checked 2026-11-15. DataBridges: data licence not published (inventory) |
| Documentation | https://data.humdata.org/organization/wfp ; https://docs.hdx.rwlabs.org/ (HDX API) ; https://github.com/WFP-VAM/DataBridgesAPI ; https://wfp-vam.github.io/DataBridgesKnots/ |

## Requests

### HDX dataset metadata (CKAN `package_show`)

Returns the dataset record with licence, dates, update frequency, source and the list of downloadable resources.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `id` | yes | Dataset name or uuid | `global-wfp-food-prices` |

```
GET https://data.humdata.org/api/3/action/package_show?id=global-wfp-food-prices
```

### Sample response (Captured 2026-11-15)

719,594 bytes. Trimmed to the fields below and to 2 of the 40 resources (one CSV per year, 1990 to 2026, plus auxiliary files); HDX's QA and review blocks were removed.

```json
{"success": true, "result": {
  "name": "global-wfp-food-prices", "title": "Global - Food Prices",
  "license_id": "cc-by-igo", "license_title": "Creative Commons Attribution for Intergovernmental Organisations (CC BY-IGO)",
  "dataset_date": "[1990-01-15T00:00:00 TO 2026-11-15T23:59:59]", "data_update_frequency": "30",
  "dataset_source": "WFP", "methodology": "Registry",
  "caveats": "Although the frequency of updates is set to every month, updates may occur more or less frequently",
  "notes": "This dataset contains Countries, Commodities and Markets data, sourced from the World Food Programme Price Database. The World Food Programme Price Database covers foods such as maize, rice, beans, fish, and sugar for 98 countries and some 3000 markets. It is updated weekly but contains to a large extent monthly data. The data goes back as far as 1992 for a few countries, although many countries started reporting from 2003 or thereafter.",
  "num_resources": 40, "metadata_modified": "2026-11-15T10:15:07.734982", "total_res_downloads": 45330,
  "organization": {"title": "WFP - World Food Programme"},
  "tags": ["economics", "food security", "indicators", "markets"],
  "resources": [
    {"name": "Global WFP food prices 2026", "format": "CSV", "url": "https://data.humdata.org/dataset/31579af5-3895-4002-9ee3-c50857480785/resource/502190c6-0d3d-4b84-977e-ef062f053662/download/wfp_food_prices_global_2026.csv", "size": 44125751, "last_modified": "2026-11-15T10:14:39.782764", "description": "Prices data for 2026"},
    {"name": "Global WFP food prices 2025", "format": "CSV", "url": "https://data.humdata.org/dataset/31579af5-3895-4002-9ee3-c50857480785/resource/d62af4be-cff6-437b-89a3-67f8fa4c53bf/download/wfp_food_prices_global_2025.csv", "size": 59512363, "last_modified": "2026-11-15T10:14:39.783380", "description": "Prices data for 2025"}
  ]
}}
```

Yearly files seen: 2026 44.1 MB, 2025 59.5 MB, 2024 60.7 MB, 2023 66.9 MB, 2022 68.3 MB, 2021 67.3 MB.

### Global prices CSV (one file per year)

| Parameter | Required | Description | Example |
|---|---|---|---|
| (none) | | Static CSV; the download URL answers HTTP 302 to a time-limited signed Amazon S3 URL and supports `Range` requests | |

```
GET https://data.humdata.org/dataset/31579af5-3895-4002-9ee3-c50857480785/resource/502190c6-0d3d-4b84-977e-ef062f053662/download/wfp_food_prices_global_2026.csv
```

### Sample response (Captured 2026-11-15)

First 3,000 bytes (HTTP 206), trimmed to the header and six rows. 17 columns; there is no HXL tag row (HDX's file check records `is_hxlated: false`).

```csv
countryiso3,date,admin1,admin2,market,market_id,latitude,longitude,category,commodity,commodity_id,unit,priceflag,pricetype,currency,price,usdprice
AFG,2026-05-15,Badakhshan,Argo,Badakhshan,3690,37.04,70.46,cereals and tubers,Bread,55,KG,actual,Retail,AFN,77,1.2
AFG,2026-05-15,Badakhshan,Argo,Badakhshan,3690,37.04,70.46,cereals and tubers,Rice (high quality),247,KG,actual,Retail,AFN,131,2.05
AFG,2026-05-15,Badakhshan,Argo,Badakhshan,3690,37.04,70.46,cereals and tubers,Wheat,84,KG,actual,Retail,AFN,27,0.42
AFG,2026-05-15,Badakhshan,Argo,Badakhshan,3690,37.04,70.46,non-food,Exchange rate,305,USD/LCU,actual,Retail,AFN,63.75,1
AFG,2026-05-15,Badakhshan,Argo,Badakhshan,3690,37.04,70.46,oil and fats,Oil (cooking),82,KG,actual,Retail,AFN,111,1.74
AFG,2026-05-15,Badghis,Jawand,Badghis,3220,35.14,63.73,cereals and tubers,Wheat,84,KG,actual,Retail,AFN,25.25,0.4
```

### Country dataset and markets file (Bangladesh, the non-US example)

```
GET https://data.humdata.org/api/3/action/package_show?id=wfp-food-prices-for-bangladesh
GET https://data.humdata.org/dataset/c76eabb7-fdb5-43b7-a5c4-09091bb8acde/resource/60852e15-3e4c-43eb-abf0-650e83c8eb91/download/wfp_markets_bgd.csv
```

### Sample response (Captured 2026-11-15)

Metadata (36,098 bytes) trimmed to the fields that differ from the global dataset:

```json
{"name": "wfp-food-prices-for-bangladesh", "title": "Bangladesh - Food Prices",
 "license_id": "cc-by-igo", "dataset_date": "[1998-07-15T00:00:00 TO 2026-09-15T23:59:59]", "data_update_frequency": "30",
 "dataset_source": "Bangladesh Milk producer's Co-Operative Union Ltd, Bangladesh via FAO: GIEWS, DAM, Department of Agricultural Marketing, Department of Agriculture Marketing (DAM), FPMA, WFP Market Data Collection, Website of Department of Agricultural Marketing",
 "num_resources": 2,
 "resources": [
  {"name": "Bangladesh - Food Prices", "format": "CSV", "url": "https://data.humdata.org/dataset/c76eabb7-fdb5-43b7-a5c4-09091bb8acde/resource/966ab7ac-56d6-4dac-8eba-dfe815d59a52/download/wfp_food_prices_bgd.csv", "size": 4519727, "last_modified": "2026-11-04T01:13:39.317937", "description": "Food prices data"},
  {"name": "Bangladesh - Markets", "format": "CSV", "url": "https://data.humdata.org/dataset/c76eabb7-fdb5-43b7-a5c4-09091bb8acde/resource/60852e15-3e4c-43eb-abf0-650e83c8eb91/download/wfp_markets_bgd.csv", "size": 9460, "last_modified": "2026-10-18T11:01:51.282263", "description": "Markets data"}
 ]}
```

Markets CSV (9,460 bytes), trimmed to the header and five rows:

```csv
market_id,market,countryiso3,admin1,admin2,latitude,longitude
112,Barisal Division,BGD,Barisal,Barisal,22.7,90.37
116,Dhaka Division,BGD,Dhaka,Dhaka,23.72,90.41
2574,Dhaka,BGD,Dhaka,Dhaka,23.81,90.41
3032,Mymensing Sadar,BGD,Mymensingh,Mymensingh,24.75,90.41
3143,Balukhali Bazar,BGD,Chittagong,Cox'S Bazar,21.18,92.16
```

### Global Market Monitor

```
GET https://data.humdata.org/api/3/action/package_show?id=global-market-monitor
```

### Sample response (Captured 2026-11-15)

56,654 bytes, trimmed to the fields below and the two resources.

```json
{"name": "global-market-monitor", "title": "WFP Global Market Monitor", "license_id": "cc-by-igo",
 "dataset_date": "[2021-05-19T00:00:00 TO 2026-07-15T23:59:59]", "data_update_frequency": "14", "dataset_source": "WFP - World Food Programme",
 "methodology": "Food Basket Cost Changes \nThe impact calculation assumes that each food basket provides 2,100 kcal a day, and that the proportional caloric contribution is a proxy of the relative importance of the item in the food basket. ...",
 "resources": [
  {"name": "global-market-monitor.csv", "format": "CSV", "size": 3170492, "last_modified": "2026-07-15T22:12:14.070667", "description": "Dataset of the change in food basket prices at the country level, updated every other week. Markets are monitored across a range of countries globally, and percent changes in the cost of food baskets between time periods with available data are classified as negative (<0%), normal (0-3%), moderate (3-10%), high (10-25%), and severe (>25%). "},
  {"name": "global-market-monitor_subnational.csv", "format": "CSV", "size": 33409473, "last_modified": "2026-07-15T22:12:14.071263", "description": "Subnational view of the global dataset of the change in food basket prices at the country level, updated every other week."}
 ]}
```

### Legacy Global Food Prices Database (frozen)

```
GET https://data.humdata.org/api/3/action/package_show?id=wfp-food-prices
```

### Sample response (Captured 2026-11-15)

18,531 bytes, trimmed.

```json
{"name": "wfp-food-prices", "title": "Global Food Prices Database (WFP)", "license_id": "cc-by-igo",
 "dataset_date": "[1990-01-01T00:00:00 TO 2021-08-15T23:59:59]", "data_update_frequency": "-1", "num_resources": 1,
 "notes": "This no longer updated dataset contains Global Food Prices data from the World Food Programme covering foods such as maize, rice, beans, fish, and sugar for 76 countries and some 1,500 markets. ... This dataset has been replaced by a new and ongoing global food prices dataset ...",
 "resources": [{"name": "Global Food Prices Database (WFP)", "format": "CSV", "url": "https://data.humdata.org/dataset/4fdcd4dc-5c2f-43af-a1e4-93c9b6539a27/resource/12d7c8e3-eff9-4db0-93b7-726825c4fe9a/download/wfpvam_foodprices.csv", "size": 225787557, "last_modified": "2021-08-22T08:27:33.221716"}]}
```

### DataBridges API: monthly market prices

Credentials are required, so no call was made. The description below is taken from the generated client documentation in the WFP-VAM/DataBridgesAPI repository (README and `docs/MarketPricesApi.md`, fetched 2026-11-15, API version v2, package version 9.0.0). Authentication: a client id and secret are exchanged for a token (the client's `WfpApiToken(api_key, api_secret).refresh()`), sent as a bearer token. The `/MarketPrices/PriceMonthly` endpoint "is restricted, it requires the permission: vamdatabridges_marketprices-pricemonthly_get"; `PriceDaily`, `PriceWeekly`, `PriceRaw` and `Alps` carry their own permission names. Monthly data "is the lowest frequency available and the most complete data source"; price flags distinguish `actual` (collected monthly), `aggregate` (daily or weekly averaged to monthly), `imputed` (Amelia-II estimates of missing values) and `forecasted` (six months ahead). A country code is mandatory.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `country_code` | yes | ISO 3166-1 alpha-3 or VAM admin0code | `BGD` |
| `market_id` | no | Market id from `/Markets/GeoJSONList` | `2574` |
| `commodity_id` | no | Commodity id from `/Commodities/List` | |
| `price_type_name` | no | `retail`, `wholesale` or `farmgate` | `retail` |
| `currency_id` | no | Currency id from `/Currency/List` | |
| `price_flag` | no | `actual`, `aggregate`, `estimated`, `forecasted` | `actual` |
| `start_date`, `end_date` | no | RFC 3339 dates | `2025-01-01` |
| `latest_value_only` | no | boolean | `false` |
| `page` | no | Page number (paged results) | `1` |
| `format` | no | `json` (default) or `csv` | `json` |
| `env` | no | `prod` (api.vam.wfp.org) or `dev` | `prod` |

```
GET https://gateway.api.wfp.org/vam-data-bridges/v2/MarketPrices/PriceMonthly?country_code=BGD&price_type_name=retail&start_date=2025-01-01&format=json&page=1
Authorization: Bearer <token obtained with the client id and secret>
```

### Sample response (Representative)

The client docs name the return type `ViewExtendedMonthlyAggregatedPricePagedResult` (a paged result with a list of monthly aggregated price rows) but the repository's model files were not read, so no field-level sample is given. Related endpoints documented in the same README: `/Commodities/List`, `/Commodities/Categories/List`, `/CommodityUnits/List`, `/CommodityUnits/Conversion/List`, `/Currency/List`, `/Currency/UsdIndirectQuotation`, `/Markets/GeoJSONList`, `/MarketPrices/PriceDaily`, `/MarketPrices/PriceWeekly`, `/MarketPrices/PriceRaw`, `/MarketPrices/Alps`, `/EconomicData/IndicatorList`, `/EconomicData/{indicatorName}`.

## Fields

### Global and country prices CSV

| Field | Type | Unit | Description |
|---|---|---|---|
| `countryiso3` | string | | ISO 3166-1 alpha-3 |
| `date` | string | `YYYY-MM-DD` | Observation date (15th of the month for monthly data) |
| `admin1`, `admin2` | string | | Administrative units of the market |
| `market`, `market_id` | string, integer | | Market name and WFP market id |
| `latitude`, `longitude` | decimal | degrees | Market coordinates (WGS84), two decimals |
| `category` | string | | `cereals and tubers`, `pulses and nuts`, `oil and fats`, `miscellaneous food`, `non-food`, ... |
| `commodity`, `commodity_id` | string, integer | | Commodity label and id |
| `unit` | string | | `KG`, `L`, `Day`, `USD/LCU`, ... |
| `priceflag` | string | | Only `actual` appeared in the sample; the DataBridges documentation describes the flag vocabulary as `actual` (collected monthly), `aggregate` (daily or weekly averaged to monthly), `imputed` (filter value `estimated`) and `forecasted` |
| `pricetype` | string | | `Retail`, `Wholesale`, `Farm Gate` |
| `currency` | string | | ISO 4217 local currency |
| `price` | decimal | local currency per unit | Nominal price |
| `usdprice` | decimal | USD per unit | Converted price |

### Markets CSV

`market_id`, `market`, `countryiso3`, `admin1`, `admin2`, `latitude`, `longitude`.

### CKAN `package_show` result (fields used above)

`name`, `title`, `license_id`, `license_title`, `dataset_date` (CKAN range string), `data_update_frequency` (days; `-1` never), `dataset_source`, `methodology`, `caveats`, `notes`, `num_resources`, `metadata_modified`, `last_modified`, `organization.title`, `tags[].name`, `resources[]` (`name`, `format`, `url`, `size` bytes, `last_modified`, `description`).

## Licence

HDX records `license_id: cc-by-igo` / "Creative Commons Attribution for Intergovernmental Organisations (CC BY-IGO)" on the global, Bangladesh, Global Market Monitor and legacy datasets (read today from the CKAN responses). The inventory verdict is PASS. The Bangladesh record lists upstream sources (FAO GIEWS, the Department of Agricultural Marketing, WFP collection) yet WFP publishes the compiled file under CC BY-IGO. For DataBridges the inventory found no published data licence (STILL UNKNOWN); the generated client code is AGPL-3.0 (inventory, not re-read; it governs the code, not the data).

## Overlap with NASA sources

NASA publishes no market prices; this is the demand and value complement to NASA POWER (weather), IMERG (rain), SMAP (soil moisture), MODIS and HLS (vegetation) and the NASA Harvest / GEOGLAM Crop Monitor crop-condition assessments. Market coordinates in the WFP files are the join to any NASA point service. The United States is not among WFP's 98 countries, so the Nebraska reference site has no WFP series; AMS Market News covers it (`ams_market_news.md`).

## Notes

- HDX download URLs redirect (HTTP 302) to signed `s3.us-east-1.amazonaws.com/hdx-production-filestore/...` URLs with an `Expires` parameter; the redirect target supports `Range` (HTTP 206 returned for the first 3,000 bytes).
- The inventory described the files as HXL-tagged; the 2026 global file begins directly with the header row, and HDX's own file check stores `is_hxlated: false` and `hxl_headers: null` for both the global and the Bangladesh resources.
- The global dataset is split by year (one CSV per year 1990 to 2026) rather than "last two years" as an earlier HDX description said; per-country datasets still hold the complete history in one file.
- HDX returned `last_modified` 2026-11-15 for the global dataset at 10:14 UTC, the same day as this capture.
- All four package_show requests were made one at a time; no rate limiting was observed.
- The DataBridges endpoints were not called; the repository README notes that household survey endpoints need a separate authorisation from the data controller named in the docs.

## Documentation

- HDX, WFP organisation page: https://data.humdata.org/organization/wfp
- Global dataset: https://data.humdata.org/dataset/global-wfp-food-prices
- Country datasets: https://data.humdata.org/dataset/?dataseries_name=WFP+-+Food+Prices
- Global Market Monitor: https://data.humdata.org/dataset/global-market-monitor
- Legacy database: https://data.humdata.org/dataset/wfp-food-prices
- HDX CKAN API: https://docs.hdx.rwlabs.org/
- DataBridges client and endpoint docs: https://github.com/WFP-VAM/DataBridgesAPI
- DataBridges Knots (credential request, wfp.vaminfo@wfp.org): https://wfp-vam.github.io/DataBridgesKnots/
- VAM Resource Centre, DataBridges: https://vamresources.manuals.wfp.org/docs/data-bridges
