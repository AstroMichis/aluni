# FAOSTAT (producer prices, production, trade, food balances)

FAOSTAT is the FAO Statistics Division's corporate database: country-level annual statistics for 245+ countries and territories from 1961 onward, organised in domains. The domains relevant to crop prices and demand are Producer Prices (PP, annual and monthly farm-gate prices in local currency, standard local currency and USD per tonne), Consumer Price Indices (CP), Production (QCL: area harvested, yield, production), Trade (TCL totals and TM detailed bilateral matrix), Food Balances (FBS) and Supply Utilization Accounts (SUA). It also hosts the Cropland Nutrient Balance (ESB, covered in the nutrient data file). Two access paths exist: bulk ZIP files of normalized CSV with no login, and a JSON API that answers only to requests carrying a bearer token.

| | |
|---|---|
| Provider | FAO Statistics Division (ESS) |
| Base URL | Bulk: `https://bulks-faostat.fao.org/production/`; API: `https://faostatservices.fao.org/api/v1/{lang}/` (`en`, `fr`, `es`, ...) |
| Auth | Bulk files and the bulk index: none. API: `Authorization: Bearer <JWT>` on every call. Requests without it return HTTP 401 `Missing Authorization Header`; with an invalid token HTTP 403 `Authentication Failed`. The public web app obtains a 5-minute guest token from `GET /api/v1/auth/guest`; that handshake returned HTTP 403 with an empty body to a server-side client on 2026-11-15. Signed-in users send an AWS Cognito OIDC access token |
| Formats | Bulk: ZIP containing CSV (normalized, one value per row) plus code tables; index as JSON. API: JSON |
| Coverage | Global, country level (plus regional aggregates); PP from 1991 (USA maize series), QCL from 1961; monthly producer prices where countries report them |
| Resolution | Country x item x element x year (PP also by month) |
| Cadence / latency | Per domain. Last updates in the bulk index on 2026-11-13: PP 2026-10-09, CP 2026-10-20, TCL 2026-07-24, QCL 2025-12-31, TM 2025-12-23, ESB 2025-12-05, FBS and SUA 2025-10-28 |
| Rate limits / quotas | Not published |
| Licence | CC BY 4.0 under the FAO Statistical Database Terms of Use (prohibits use "for or in conjunction with the promotion of a commercial enterprise", third-party data excepted); see Licence |
| Documentation | https://www.fao.org/faostat/en/ ; https://www.fao.org/contact-us/terms/db-terms-of-use/en/ |

## Requests

### Bulk dataset index

Lists every bulk file with its domain code, update date, size, row count and download URL.

| Parameter | Required | Description | Example |
|---|---|---|---|
| (none) | | Static JSON, regenerated with each release | |

```
GET https://bulks-faostat.fao.org/production/datasets_E.json
```

### Sample response (Captured 2026-11-15)

106,151 bytes, 69 datasets, `last-modified` 2026-11-13. Trimmed to eight datasets; the long `Topic` and `DatasetDescription` strings were removed from each.

```json
{"Datasets": {"Dataset": [
  {"DatasetCode":"PP","DatasetName":"Prices: Producer Prices","Contact":"Food and Agriculture Organization of the United Nations (FAO): Statistics Division (ESS), Social and Economic Statistics Team","Email":"faostat@fao.org","DateUpdate":"2026-10-09T00:00:00","CompressionFormat":"zip","FileType":"csv","FileSize":"11411KB","FileRows":1319583,"FileLocation":"https://bulks-faostat.fao.org/production/Prices_E_All_Data_(Normalized).zip"},
  {"DatasetCode":"CP","DatasetName":"Prices: Consumer Price Indices","DateUpdate":"2026-10-20T00:00:00","FileSize":"2090KB","FileRows":266292,"FileLocation":"https://bulks-faostat.fao.org/production/ConsumerPriceIndices_E_All_Data_(Normalized).zip"},
  {"DatasetCode":"QCL","DatasetName":"Production: Crops and livestock products","DateUpdate":"2025-12-31T00:00:00","FileSize":"33127KB","FileRows":4209110,"FileLocation":"https://bulks-faostat.fao.org/production/Production_Crops_Livestock_E_All_Data_(Normalized).zip"},
  {"DatasetCode":"TCL","DatasetName":"Trade: Crops and livestock products","DateUpdate":"2026-07-24T00:00:00","FileSize":"267104KB","FileRows":17143873,"FileLocation":"https://bulks-faostat.fao.org/production/Trade_CropsLivestock_E_All_Data_(Normalized).zip"},
  {"DatasetCode":"TM","DatasetName":"Trade: Detailed trade matrix","DateUpdate":"2025-12-23T00:00:00","FileSize":"410792KB","FileRows":52410630,"FileLocation":"https://bulks-faostat.fao.org/production/Trade_DetailedTradeMatrix_E_All_Data_(Normalized).zip"},
  {"DatasetCode":"FBS","DatasetName":"Food Balances: Food Balances (2010-)","DateUpdate":"2025-10-28T00:00:00","FileSize":"53556KB","FileRows":4820497,"FileLocation":"https://bulks-faostat.fao.org/production/FoodBalanceSheets_E_All_Data_(Normalized).zip"},
  {"DatasetCode":"SUA","DatasetName":"Food and Diet: Availability (based on supply utilization accounts)","DateUpdate":"2025-10-28T00:00:00","FileSize":"4727KB","FileRows":743139,"FileLocation":"https://bulks-faostat.fao.org/production/Supply_Utilization_Accounts_Food_and_Diet_E_All_Data_(Normalized).zip"},
  {"DatasetCode":"ESB","DatasetName":"Land, Inputs and Sustainability: Cropland Nutrient Balance","DateUpdate":"2025-12-05T00:00:00","FileSize":"7801KB","FileRows":827796,"FileLocation":"https://bulks-faostat.fao.org/production/Environment_Cropland_nutrient_budget_E_All_Data_(Normalized).zip"}
]}}
```

### Bulk download: Producer Prices (normalized)

| Parameter | Required | Description | Example |
|---|---|---|---|
| (none) | | Static ZIP; the `_(Normalized)` variant has one value per row, the `All_Data` variant without the suffix has one column per year | |

```
GET https://bulks-faostat.fao.org/production/Prices_E_All_Data_(Normalized).zip
```

### Sample response (Captured 2026-11-15)

11,684,078 bytes, `content-type: application/x-zip-compressed`, `last-modified` 2026-10-09. ZIP listing (untrimmed):

```
214286652  Prices_E_All_Data_(Normalized).csv
     5139  Prices_E_AreaCodes.csv
      166  Prices_E_Elements.csv
      152  Prices_E_Flags.csv
     8840  Prices_E_ItemCodes.csv
```

Rows for maize in the United States of America (area 231, item 56) and Mexico (area 138). Trimmed to the header, the 2022 annual value and January to March 2022 in local currency, the USD annual values 2022 to 2024 for both countries; the full file has 1,319,583 rows.

```csv
Area Code,Area Code (M49),Area,Item Code,Item Code (CPC),Item,Element Code,Element,Year Code,Year,Months Code,Months,Unit,Value,Flag
"231","'840","United States of America","56","'0112","Maize (corn)","5530","Producer Price (LCU/tonne)","2022","2022","7021","Annual value","LCU","263.800000","A"
"231","'840","United States of America","56","'0112","Maize (corn)","5530","Producer Price (LCU/tonne)","2022","2022","7001","January","LCU","219.700000","A"
"231","'840","United States of America","56","'0112","Maize (corn)","5530","Producer Price (LCU/tonne)","2022","2022","7002","February","LCU","239.800000","A"
"231","'840","United States of America","56","'0112","Maize (corn)","5530","Producer Price (LCU/tonne)","2022","2022","7003","March","LCU","258.300000","A"
"231","'840","United States of America","56","'0112","Maize (corn)","5532","Producer Price (USD/tonne)","2022","2022","7021","Annual value","USD","263.800000","A"
"231","'840","United States of America","56","'0112","Maize (corn)","5532","Producer Price (USD/tonne)","2023","2023","7021","Annual value","USD","179.100000","A"
"231","'840","United States of America","56","'0112","Maize (corn)","5532","Producer Price (USD/tonne)","2024","2024","7021","Annual value","USD","171.300000","A"
"138","'484","Mexico","56","'0112","Maize (corn)","5532","Producer Price (USD/tonne)","2022","2022","7021","Annual value","USD","322.000000","A"
"138","'484","Mexico","56","'0112","Maize (corn)","5532","Producer Price (USD/tonne)","2023","2023","7021","Annual value","USD","352.300000","A"
"138","'484","Mexico","56","'0112","Maize (corn)","5532","Producer Price (USD/tonne)","2024","2024","7021","Annual value","USD","310.600000","A"
```

The USA maize USD annual series runs 1991 to 2024 without gaps. Code tables from the same ZIP (untrimmed for Elements and Flags; items and areas trimmed to the reference crops and countries):

```csv
Element Code,Element
5530,Producer Price (LCU/tonne)
5531,Producer Price (SLC/tonne)
5532,Producer Price (USD/tonne)
5539,Producer Price Index (2014-2016 = 100)

Flag, Description
A,Official value
B,Time series break
E,Estimated value
I,Value imputed by a receiving agency
X,Value from external organization

Item Code,CPC Code,Item
56,'0112,Maize (corn)
446,'01290.01,Green corn (maize)
236,'0141,Soya beans
15,'0111,Wheat

Area Code,M49 Code,Area
138,'484,Mexico
231,'840,United States of America
```

### JSON API: dimension lists and data

The web application at `fao.org/faostat` reads every domain through this API. Parameter names below are those the web application sends; the response shape was not captured because every call was refused (see Notes).

| Parameter | Required | Description | Example |
|---|---|---|---|
| `{lang}` (path) | yes | `en`, `fr`, `es`, `zh`, `ru`, `ar` | `en` |
| `area` | no | Area codes, comma separated | `231` |
| `item` | no | Item codes | `56` |
| `element` | no | Element codes | `5532` |
| `year` | no | Years, comma separated | `2022,2023` |
| `show_codes` | no | Include code columns | `true` |
| `output_type` | no | `objects` or `arrays` | `objects` |

```
GET https://faostatservices.fao.org/api/v1/en/definitions/domain/
GET https://faostatservices.fao.org/api/v1/en/definitions/domain/PP/item
GET https://faostatservices.fao.org/api/v1/en/data/PP?area=231&item=56&element=5532&year=2022,2023&show_codes=true&output_type=objects
```

### Sample response (Captured 2026-11-15)

All three requests, untrimmed. Without a header (HTTP 401, served by CloudFront):

```
Missing Authorization Header
```

With `Authorization: Bearer test` (HTTP 403):

```
Authentication Failed
```

`GET https://faostatservices.fao.org/api/v1/auth/guest` (the web app's anonymous handshake, which answers `{"token": "<JWT>"}` to the browser and is cached for 300,000 ms): HTTP 403 Forbidden, empty body.

## Fields

Normalized bulk CSV (all domains share this layout; the `Months Code` and `Months` columns exist in PP and CP only).

| Field | Type | Unit | Description |
|---|---|---|---|
| `Area Code` | integer | | FAOSTAT area code (231 United States of America, 138 Mexico) |
| `Area Code (M49)` | string | | UN M49 code with a leading apostrophe to keep leading zeros (`'840`) |
| `Area` | string | | Area name |
| `Item Code` | integer | | FAOSTAT item code (56 maize, 15 wheat, 236 soya beans) |
| `Item Code (CPC)` | string | | CPC 2.1 code with a leading apostrophe (`'0112`) |
| `Item` | string | | Item name |
| `Element Code`, `Element` | integer, string | | Measure (PP: 5530 LCU/tonne, 5531 SLC/tonne, 5532 USD/tonne, 5539 index 2014-2016 = 100) |
| `Year Code`, `Year` | integer | | Calendar year |
| `Months Code`, `Months` | integer, string | | 7001 to 7012 January to December; 7021 `Annual value` |
| `Unit` | string | | `LCU`, `SLC`, `USD`, index |
| `Value` | decimal | per `Unit` | Six decimals in the file |
| `Flag` | string | | `A` official, `B` series break, `E` estimated, `I` imputed by receiving agency, `X` external organization |

Bulk index (`datasets_E.json`): `DatasetCode`, `DatasetName`, `Topic`, `DatasetDescription`, `Contact`, `Email`, `DateUpdate` (ISO date), `CompressionFormat`, `FileType`, `FileSize` (string in KB), `FileRows`, `FileLocation`.

## Licence

FAO Statistical Database Terms of Use (re-read 2026-11-15 at https://www.fao.org/contact-us/terms/db-terms-of-use/en/): "Unless specified otherwise in their metadata or webpage, all datasets disseminated through FAO corporate statistical databases (see examples in Annex 1) are licensed under the Creative Commons Attribution-4.0 International licence (CC BY 4.0) ... as complemented by the Terms of Use outlined below." Annex 1 lists FAOSTAT and the FPMA Tool. Additional terms that matter for redistribution: (1) "Datasets shall not be used for or in conjunction with the promotion of a commercial enterprise and/or its product(s) or services (s), and/or in any way that suggests that FAO endorses any specific company, products or services"; (2) third-party data "may not be redistributed or reused without the consent of the original data provider", with such conditions "included in the dataset metadata or webpage"; (3) citation format "FAO. [YYYY]. [Name of database: Name of dataset]. [Accessed on [DD Month YYYY]]. [URL] Licence: CC-BY-4.0." The inventory verdict is PASS with these caveats.

## Overlap with NASA sources

NASA publishes no price, trade or food-balance statistics; nothing in this file duplicates a NASA API. The production side of FAOSTAT (QCL area, yield, production) is a national annual statistic, while NASA Harvest and the GEOGLAM Crop Monitor publish in-season crop condition assessments and the MODIS, HLS and SMAP products in this folder give the field-level vegetation, soil moisture and weather record that explains a season's yield. The World Bank's WDI cereal production indicator is itself sourced from FAOSTAT QCL (see `world_bank_food_prices.md`).

## Notes

- The API refused every server-side request on 2026-11-15: HTTP 401 `Missing Authorization Header` without a token, HTTP 403 `Authentication Failed` with an arbitrary bearer value, HTTP 403 (empty body) on the guest-token handshake `GET /api/v1/auth/guest`. The handshake mechanism was read from the web application's `FAOSTATAPIClient.js` (`base_url`, `guest_token_url`, `use_auth_header: true`, token stored for 300,000 ms, `Bearer` scheme). No token value is recorded here.
- The legacy host `https://fenixservices.fao.org/faostat/api/v1/en/definitions/domain/` returned HTTP 521 (Cloudflare "Web server is down") with `retry-after: 120`.
- The bulk index and bulk ZIPs are served from Amazon S3 with no authentication; the PP ZIP downloaded in full (11.7 MB) and the CSV inside is 214 MB.
- PP carries monthly producer prices for countries that report them (USA maize has `Months Code` 7001 to 7012 plus the 7021 annual value); most other domains are annual only.
- `SLC` (standard local currency) differs from `LCU` for countries that changed currency; USD values use FAO's annual exchange rates.
- Code columns for M49 and CPC carry a leading apostrophe in the CSV; strip it before joining to other sources.
- Bulk files are republished whole at each domain update; `DateUpdate` in `datasets_E.json` is the change signal.

## Documentation

- FAOSTAT: https://www.fao.org/faostat/en/
- Bulk index: https://bulks-faostat.fao.org/production/datasets_E.json
- FAO Statistical Database Terms of Use: https://www.fao.org/contact-us/terms/db-terms-of-use/en/
- Web app API client (handshake and header behaviour): https://www.fao.org/faostat/en/src/js/FAOSTATAPIClient.js
