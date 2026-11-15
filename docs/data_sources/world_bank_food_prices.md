# World Bank commodity prices (Pink Sheet), Real-Time Food Prices and Indicators API

Three World Bank resources carry crop prices and agricultural statistics. The Commodity Price Data, known as the Pink Sheet, is a monthly workbook of 89 benchmark world prices and indices since January 1960 (maize, wheat, soybeans, rice, sugar, cotton, bananas, fertilizers among them) published by the Prospects Group on the second business day of each month, with semi-annual forecasts. Real-Time Food Prices (RTFP) is a Microdata Library dataset of monthly, market-level food price estimates for 37 fragile and low-income countries, produced by machine learning from WFP and FAO survey data. The Indicators API (World Development Indicators) serves national annual agriculture statistics, most of them sourced from FAOSTAT.

| | |
|---|---|
| Provider | World Bank Group: Prospects Group (Pink Sheet), Development Data Group (RTFP, WDI) |
| Base URL | Pink Sheet files `https://thedocs.worldbank.org/en/doc/74e8be41ceb20fa0da750cda2f6b9e4e-0050012026/related/`; Data Catalog `https://datacatalogapi.worldbank.org/ddhxext/`; Microdata `https://microdata.worldbank.org/index.php/api/catalog/`; Indicators `https://api.worldbank.org/v2/` |
| Auth | none for all four |
| Formats | XLSX and PDF (Pink Sheet); JSON (catalog, microdata, indicators; indicators also XML by default without `format=json`); CSV (RTFP data file) |
| Coverage | Pink Sheet: world benchmark prices, 1960M01 to 2026M10 (802 monthly rows). RTFP: 37 countries, 3,192 markets, 2007-01 to 2026-11 (version 2026-11-02), 762,728 rows. WDI: all countries, annual |
| Resolution | Pink Sheet: one price per commodity per month (world). RTFP: market x commodity x month. WDI: country x year |
| Cadence / latency | Pink Sheet monthly, workbook `last-modified` 2026-11-03 with October 2026 as the latest row; forecasts in April and October. RTFP version 2026-11-02. WDI source `lastupdated` 2026-11-11 |
| Rate limits / quotas | Data Catalog API returned HTTP 429 with `retry-after` 21 to 36 s on three attempts; others not published |
| Licence | Pink Sheet dataset 0038238: CC BY 4.0 (catalog page, read today) under the World Bank Terms of Use for Datasets. RTFP: "published as open data", no licence named in its metadata. WDI: CC BY 4.0 dataset terms, third-party exceptions. See Licence |
| Documentation | https://www.worldbank.org/en/research/commodity-markets ; https://microdata.worldbank.org/index.php/catalog/4483 ; https://datahelpdesk.worldbank.org/knowledgebase/topics/125589-developer-information |

## Requests

### Pink Sheet monthly workbook

The commodity markets page links the current files; the document id in the path changes with the publication cycle.

| Parameter | Required | Description | Example |
|---|---|---|---|
| (none) | | Static XLSX; the annual workbook and the monthly PDF sit beside it (`CMO-Historical-Data-Annual.xlsx`, `CMO-Pink-Sheet-November-2026.pdf`, `CMO-October-2026-Forecasts.pdf`) | |

```
GET https://thedocs.worldbank.org/en/doc/74e8be41ceb20fa0da750cda2f6b9e4e-0050012026/related/CMO-Historical-Data-Monthly.xlsx
```

### Sample response (Captured 2026-11-15)

587,760 bytes, `last-modified` 2026-11-03. Sheets: `Monthly Prices`, `Monthly Indices`, `Description`, `Index Weights` (plus a hidden `Mismatch Details`). The `Monthly Prices` sheet has 808 rows: rows 1 to 4 are titles ("World Bank Commodity Price Data (The Pink Sheet)", "monthly prices in nominal US dollars", "Updated on November 03, 2026"), row 5 holds series names, row 6 units, rows 7 to 808 the months `1960M01` to `2026M10`. The 89 series in column order: Crude oil (average, Brent, Dubai, WTI), Coal (Australian, South African), Natural gas (US, Europe, LNG Japan, index), Cocoa, Coffee (Arabica, Robusta), Tea (avg 3 auctions, Colombo, Kolkata, Mombasa), Coconut oil, Groundnuts, Fish meal, Groundnut oil, Palm oil, Palm kernel oil, Soybeans, Soybean oil, Soybean meal, Rapeseed oil, Sunflower oil, Barley, Maize, Sorghum, Rice (Thai 5%, Thai 25%, Thai A.1, Viet Namese 5%), Wheat (US SRW, US HRW), Banana (Europe, US), Orange, Beef, Chicken, Lamb, Shrimps, Sugar (EU, US, world), Tobacco, Logs (Cameroon, Malaysian), Sawnwood (Cameroon, Malaysian), Plywood, Cotton A Index, Rubber (TSR20, RSS3), Phosphate rock, DAP, TSP, Urea, Potassium chloride, Aluminum, Iron ore, Copper, Lead, Tin, Nickel, Zinc, Gold, Platinum, Silver. Agricultural columns of the last three rows, read from the sheet XML (an ellipsis is the workbook's own marker for a missing value):

```
Series:   Soybeans Soybean oil Soybean meal Barley Maize Sorghum Rice,Thai 5% Rice,Thai 25% Rice,Viet 5% Wheat,US SRW Wheat,US HRW Banana,US Orange Sugar,world Cotton,A Index DAP   Urea  Potassium chloride
Unit:     $/mt     $/mt        $/mt         $/mt   $/mt  $/mt    $/mt         $/mt          $/mt         $/mt         $/mt         $/kg      $/kg   $/kg        $/kg           $/mt  $/mt  $/mt
2026M08:  482      1639        406          ...    224   ...     471          447           410.9        263.2        330          1.10      0.77   0.38        2.11           793.5 390   386.9
2026M09:  524      1615        447          ...    239.6 ...     482          461           418.5        278.6        347          1.12      0.79   0.41        2.1            800.6 407.5 367.5
2026M10:  515      1546        453          ...    226.5 ...     489          472           413.9        260.3        317          1.18      0.75   0.43        2.0            803.1 420   357.5
```

The `Description` sheet gives each series' specification and source, for example "Wheat (Canada), no. 1, Western Red Spring (CWRS), in store, St. Lawrence, export price" and "Rice (Thailand), 5% broken, white rice (WR), milled, indicative price based on weekly surveys of export transactions, government standard, f.o.b. Bangkok"; sources named include the US Department of Agriculture, the International Grains Council feeds via Thomson Reuters Datastream, Cotton Outlook and the IMF.

### Data Catalog record for the dataset

| Parameter | Required | Description | Example |
|---|---|---|---|
| `dataset_unique_id` | yes | Catalog id | `0038238` |

```
GET https://datacatalogapi.worldbank.org/ddhxext/DatasetView?dataset_unique_id=0038238
```

### Sample response (Captured 2026-11-15)

Three attempts, each HTTP 429 (untrimmed):

```json
{ "statusCode": 429, "message": "Rate limit is exceeded. Try again in 36 seconds." }
```

The HTML catalog page `https://datacatalog.worldbank.org/search/dataset/0038238` (redirects to `/0038238/commodity-prices-history-and-projections`) was fetched instead; its text states: "Commodity prices are updated in the second business day of the month. Commodity price forecasts are updated twice a year (April and October)", "Temporal Coverage 1960 - 2030", "Periodicity Annual", "Classification : Public", "License : Creative Commons Attribution 4.0", "Metadata last updated on May 14, 2025", contact data@worldbank.org.

### Real-Time Food Prices: study metadata (Microdata Library API)

| Parameter | Required | Description | Example |
|---|---|---|---|
| `{idno}` (path) | yes | Study id string; the numeric catalog id (4483) returns `IDNO-NOT-FOUND` | `WLD_2021_RTFP_v02_M` |

```
GET https://microdata.worldbank.org/index.php/api/catalog/WLD_2021_RTFP_v02_M
GET https://microdata.worldbank.org/index.php/api/catalog/WLD_2021_RTFP_v02_M/data_files
```

### Sample response (Captured 2026-11-15)

Study record 118,553 bytes, trimmed to the fields below (nested DDI metadata flattened; the 37-country `nation` list cut to three). The data_files response is untrimmed (350 bytes).

```json
{"status":"success","dataset":{"id":4483,"doi":"https://doi.org/10.48529/2ZH0-JF55","idno":"WLD_2021_RTFP_v02_M","type":"survey",
 "title":"Monthly food price estimates by product and market","subtitle":"37 countries, 3192 markets, 2007/01/01-2026/11/01, version 2026/11/02",
 "year_start":2007,"year_end":2026,"nation":"Afghanistan, Armenia, Burundi...and 34 more","authoring_entity":"Bo Pieter Johannes Andrée",
 "changed":"2026-11-05T13:38:26-05:00","varcount":816,"data_access_type":"open","data_class_code":"public","data_class_title":"Public use",
 "metadata":{"study_desc":{
   "study_info":{"nation":[{"name":"Afghanistan","abbreviation":"AFG"},{"name":"Armenia","abbreviation":"ARM"},{"name":"Burundi","abbreviation":"BDI"}],"coll_dates":[{"start":"2007/01/01","end":"2026/11/01"}],
     "abstract":"... The estimates are generated using a machine-learning approach that imputes ongoing subnational price surveys, often with accuracy similar to direct measurement of prices. ..."},
   "method":{"data_collection":{"sources":[{"name":"World Food Programme (WFP)","origin":"https://data.humdata.org/organization/wfp?vocab_Topics=prices"},{"name":"Food and Agriculture Organization (FAO)","origin":"https://fpma.fao.org/giews/fpmat4/#/dashboard/tool/domestic","characteristics":"Local exchange rates and implied exchange rates data derived from commodity pairs published by FAO through the Food Price Monitoring and Analysis (FMPA) Tool"}]}},
   "version_statement":{"version_date":"2026/11/02","version_resp":"FCV Data Platform"},
   "data_access":{"dataset_use":{"restrictions":"The estimates presented in this dataset are all based on publicly-available data. The dataset of price estimates is published as open data.","cit_req":"Please cite this dataset as follows: Andrée, B. P. J. (2021). Monthly food price estimates by product and market (Version 2026-11-02). WLD_2021_RTFP_v02_M. Washington, DC: World Bank Microdata Library. https://doi.org/10.48529/2ZH0-JF55"}}}}}}
```

```json
{"datafiles":{"WLD_2021_RTFP_MKT":{"id":192169,"sid":4483,"file_id":"WLD_2021_RTFP_MKT","file_name":"WLD_RTFP_mkt_2026-11-02.csv","description":"Monthly price estimates at market/commodity level (all available countries)","case_count":762728,"var_count":816,"producer":null,"data_checks":null,"version":"2026/11/02","notes":null,"metadata":null}}}
```

The CSV itself is downloaded through the study's "Get Microdata" page on the Microdata Library (not fetched); the inventory records it as Open/High/Low/Close monthly estimates per geo-referenced market.

### Indicators API (World Development Indicators)

| Parameter | Required | Description | Example |
|---|---|---|---|
| `{country}` (path) | yes | ISO alpha-3 or alpha-2, `all`, or several separated by `;` | `USA` |
| `{indicator}` (path) | yes | Indicator code | `AG.PRD.CREL.MT` |
| `format` | no | `json`, `xml` (default), `jsonstat` | `json` |
| `date` | no | Year or range `YYYY:YYYY` | `2020:2023` |
| `per_page`, `page` | no | Paging (default 50 per page) | `100` |

```
GET https://api.worldbank.org/v2/country/USA/indicator/AG.PRD.CREL.MT?format=json&date=2020:2023
GET https://api.worldbank.org/v2/indicator/AG.PRD.CREL.MT?format=json
```

### Sample response (Captured 2026-11-15)

Data (981 bytes, untrimmed) and indicator metadata (702 bytes, untrimmed).

```json
[{"page":1,"pages":1,"per_page":50,"total":4,"sourceid":"2","lastupdated":"2026-11-11"},
 [{"indicator":{"id":"AG.PRD.CREL.MT","value":"Cereal production (metric tons)"},"country":{"id":"US","value":"United States"},"countryiso3code":"USA","date":"2023","value":462631157.55,"unit":"","obs_status":"","decimal":0},
  {"indicator":{"id":"AG.PRD.CREL.MT","value":"Cereal production (metric tons)"},"country":{"id":"US","value":"United States"},"countryiso3code":"USA","date":"2022","value":408899960.3,"unit":"","obs_status":"","decimal":0},
  {"indicator":{"id":"AG.PRD.CREL.MT","value":"Cereal production (metric tons)"},"country":{"id":"US","value":"United States"},"countryiso3code":"USA","date":"2021","value":450200713.33,"unit":"","obs_status":"","decimal":0},
  {"indicator":{"id":"AG.PRD.CREL.MT","value":"Cereal production (metric tons)"},"country":{"id":"US","value":"United States"},"countryiso3code":"USA","date":"2020","value":433259869.82,"unit":"","obs_status":"","decimal":0}]]
```

```json
[{"page":1,"pages":1,"per_page":"50","total":1},
 [{"id":"AG.PRD.CREL.MT","name":"Cereal production (metric tons)","unit":"","source":{"id":"2","value":"World Development Indicators"},"sourceNote":"Production data on cereals relate to crops harvested for dry grain only. Cereal crops harvested for hay or harvested green for food, feed, or silage and those used for grazing are excluded.","sourceOrganization":"FAO electronic files and web site, Food and Agriculture Organization of the United Nations (FAO), uri: https://www.fao.org/faostat/en/#data/QCL, publisher: Food and Agriculture Organization of the United Nations (FAO)","topics":[{"id":"1","value":"Agriculture & Rural Development  "}]}]]
```

## Fields

### Pink Sheet `Monthly Prices` sheet

| Field | Type | Unit | Description |
|---|---|---|---|
| column A, rows 7+ | string | `YYYYMmm` | Month label (`2026M10`) |
| row 5 | string | | Series name (89 series, columns B to BT) |
| row 6 | string | | Unit per series: `($/mt)` metric ton, `($/kg)`, `($/bbl)`, `($/mmbtu)`, `(cents/sheet)`, `($/cubic meter)`, `(2010=100)` for indices |
| cells | decimal or `…` | nominal USD | Monthly average price; `…` marks no data (Barley and Sorghum are empty in 2026) |

`Monthly Indices` holds the aggregate indices (Energy, Non-energy, Agriculture, Beverages, Food, Grains, Oils and Meals, Other food, Raw materials, Fertilizers, Metals and minerals, Precious metals; 2010 = 100); `Index Weights` lists each commodity's share; `Description` has one row per series with specification and source.

### RTFP study metadata

`id`, `idno`, `doi`, `title`, `subtitle`, `year_start`, `year_end`, `nation`, `authoring_entity`, `changed`, `varcount`, `data_access_type`, `data_class_code`; DDI blocks `study_desc.study_info` (`nation[]`, `coll_dates[]`, `abstract`), `study_desc.method.data_collection.sources[]`, `study_desc.version_statement`, `study_desc.data_access.dataset_use` (`restrictions`, `disclaimer`, `cit_req`). Data file record: `file_id`, `file_name`, `description`, `case_count`, `var_count`, `version`.

### Indicators API

| Field | Type | Unit | Description |
|---|---|---|---|
| `[0].page`, `pages`, `per_page`, `total`, `sourceid`, `lastupdated` | integer, string | | Paging header and source refresh date |
| `[1][].indicator.id`, `.value` | string | | Indicator code and name |
| `[1][].country.id`, `.value`, `countryiso3code` | string | | ISO alpha-2, name, alpha-3 |
| `[1][].date` | string | year | Observation year |
| `[1][].value` | decimal or null | per indicator | Value |
| `[1][].unit`, `obs_status`, `decimal` | string, integer | | Usually empty; `decimal` is the display precision |

## Licence

World Bank Terms of Use for Datasets (re-read 2026-11-15 at https://www.worldbank.org/ext/en/legal/terms-conditions/datasets): "Unless specifically labeled otherwise, these Datasets are provided to you under a Creative Commons Attribution 4.0 International License (CC BY 4.0), with the additional terms below" (a mandatory mediation-then-arbitration clause for disputes, and the attribution format "The World Bank: Dataset name: Data source (if known)"). The same page says "You may use our application programming interfaces ("APIs") to facilitate access to the Datasets" and that "Some datasets and indicators are provided by third parties, and may not be redistributed or reused without the consent of the original data provider". The general site terms (https://www.worldbank.org/ext/en/legal/terms-conditions, re-read today) say the site is for "non-commercial purposes only, unless otherwise stated" and that APIs may be used "to facilitate certain non-commercial uses of the Materials"; the dataset terms state that "Where these Dataset Terms conflict with the general Terms and Conditions, these Dataset Terms shall prevail." The Pink Sheet dataset's catalog page shows "License : Creative Commons Attribution 4.0" (read today; inventory verdict PASS). RTFP's metadata says the estimates are "published as open data" and points to "the license details" without naming one; its Microdata Library catalog entry was not checked for a licence string (inventory verdict STILL UNKNOWN). The Commodity Markets Outlook report is a separate publication under CC BY 3.0 IGO (inventory, not re-read).

## Overlap with NASA sources

NASA publishes no commodity prices or national production statistics. The Pink Sheet gives the world benchmark price of the crops whose growing conditions NASA POWER, IMERG, SMAP and MODIS/HLS describe, and RTFP gives local market estimates for 37 countries where WFP and FAO survey data exist. WDI's agricultural indicators are national annual aggregates sourced from FAOSTAT QCL (see `faostat.md`), the statistic that the NASA Harvest / GEOGLAM Crop Monitor crop-condition assessments anticipate during the season.

## Notes

- The inventory's XLSX URL (document id `5d903e848db1d1b83e0ec8f744e55570-0350012021`) still answers HTTP 200 but is a stale copy: 765,246 bytes, `last-modified` 2025-01-03. The commodity markets page links the current id `74e8be41ceb20fa0da750cda2f6b9e4e-0050012026` (587,760 bytes, `last-modified` 2026-11-03). Read the links from the page rather than fixing the id.
- The Data Catalog API rate-limited every attempt (HTTP 429, `retry-after` 36, 21 and 35 s) from a fresh client with no prior calls that day; the HTML page carried the same metadata.
- The Microdata Library API addresses studies by `idno` (`WLD_2021_RTFP_v02_M`), not by the numeric id in the web URL (`/catalog/4483` returned `{"status":"failed","message":"IDNO-NOT-FOUND"}`).
- RTFP values are model estimates, not observations: "Predicted data for missing entries are based on exchange rates, and price data available either at other market locations or from related price items" (inventory, from the study description).
- Inventory counts of Pink Sheet series (67 or 70) differ from the 89 named columns in the current `Monthly Prices` sheet because the sheet includes energy, metals and fertilizers and several series that are empty in recent months.
- The Indicators API defaults to XML; `format=json` returns a two-element array (paging header, then rows).

## Documentation

- Commodity Markets (Pink Sheet files and CMO reports): https://www.worldbank.org/en/research/commodity-markets
- Data Catalog record: https://datacatalog.worldbank.org/search/dataset/0038238/commodity-prices-history-and-projections
- RTFP study page: https://microdata.worldbank.org/index.php/catalog/4483
- Microdata Library API: https://microdata.worldbank.org/index.php/api
- Indicators API developer information: https://datahelpdesk.worldbank.org/knowledgebase/topics/125589-developer-information
- Terms of Use for Datasets: https://www.worldbank.org/ext/en/legal/terms-conditions/datasets
- General Terms and Conditions: https://www.worldbank.org/ext/en/legal/terms-conditions
