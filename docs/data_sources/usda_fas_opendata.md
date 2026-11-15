# USDA FAS Open Data API (PSD, GATS, ESR)

The USDA Foreign Agricultural Service (FAS) serves three databases through one JSON API, "FAS Open Data Services": PSD (Production, Supply and Distribution: official USDA supply and demand balances by commodity, country and marketing year, since 1960 for most commodities, the series behind the monthly WASDE), GATS (Global Agricultural Trade System: US Census import and export statistics by partner and HS10 product, and UN Comtrade-sourced trade by reporter at HS6), and ESR (US Weekly Export Sales of agricultural commodities by destination). Every call needs an api.data.gov key sent as a request header. On 2026-11-15 the swagger description was public; data calls without a key were refused and the api.data.gov `DEMO_KEY` was not accepted, so the data samples here are Representative.

| | |
|---|---|
| Provider | USDA Foreign Agricultural Service |
| Base URL | `https://apps.fas.usda.gov/OpenData/api/` (swagger: `https://apps.fas.usda.gov/OpenData/swagger/docs/v1`) |
| Auth | api.data.gov API key in the `API_KEY` request header (sign-up at https://api.data.gov/signup/); no key returns HTTP 403 `"Bad API Key"` |
| Formats | JSON (`application/json`, `text/json`) or XML (`application/xml`, `text/xml`) by `Accept` header |
| Coverage | PSD: United States and key producing and consuming countries, world aggregates, most commodities since 1960; GATS: US trade with all partners (Census) and UN Comtrade reporters at HS6; ESR: US export sales by destination country |
| Resolution | PSD: commodity x country x marketing year x attribute; GATS: partner x HS10 (Census) or reporter x HS6 (UN Trade) x year x month; ESR: commodity x destination x week |
| Cadence / latency | PSD: monthly with WASDE (data.gov `accrualPeriodicity` R/P1M); ESR: weekly; GATS: monthly as Census releases; each API has `dataReleaseDates` endpoints to detect revisions |
| Rate limits / quotas | api.data.gov default of 1,000 requests per hour per key (inventory, secondary source; not confirmed in FAS documentation) |
| Licence | PSD: CC BY 4.0 per the data.gov catalogue record (re-read 2026-11-15); GATS and ESR: not stated |
| Documentation | https://apps.fas.usda.gov/opendatawebV2/ ; swagger JSON above |

## Requests

### API description (swagger 2.0, public)

```
GET https://apps.fas.usda.gov/OpenData/swagger/docs/v1
```

### Sample response (Captured 2026-11-15)

40,895 bytes. Trimmed to the header, the security definition and the path list (summaries shortened); the full document lists 37 GET paths, all with `produces` JSON and XML and a `200 OK` response typed as an untyped object.

```json
{"swagger":"2.0","info":{"version":"v1","title":"FAS Open Data Services","description":"<h1>ESR, GATS and PSD Data APIs</h1>"},
 "host":"apps.fas.usda.gov","basePath":"/OpenData","schemes":["https"],
 "securityDefinitions":{"apiKey":{"type":"apiKey","description":"API Key Authentication","name":"API_KEY","in":"header"}},
 "paths":{
  "/api/esr/regions":{}, "/api/esr/countries":{}, "/api/esr/commodities":{}, "/api/esr/unitsOfMeasure":{}, "/api/esr/datareleasedates":{},
  "/api/esr/exports/commodityCode/{commodityCode}/allCountries/marketYear/{marketYear}":{},
  "/api/esr/exports/commodityCode/{commodityCode}/countryCode/{countryCode}/marketYear/{marketYear}":{},
  "/api/gats/census/data/exports/dataReleaseDates":{}, "/api/gats/census/data/imports/dataReleaseDates":{},
  "/api/gats/UNTrade/data/exports/dataReleaseDates":{}, "/api/gats/UNTrade/data/imports/dataReleaseDates":{},
  "/api/gats/regions":{}, "/api/gats/countries":{}, "/api/gats/commodities":{}, "/api/gats/HS6Commodities":{}, "/api/gats/unitsOfMeasure":{}, "/api/gats/customsDistricts":{},
  "/api/gats/censusImports/partnerCode/{partnerCode}/year/{year}/month/{month}":{},
  "/api/gats/censusExports/partnerCode/{partnerCode}/year/{year}/month/{month}":{},
  "/api/gats/censusReExports/partnerCode/{partnerCode}/year/{year}/month/{month}":{},
  "/api/gats/customsDistrictExports/partnerCode/{partnerCode}/year/{year}/month/{month}":{},
  "/api/gats/customsDistrictImports/partnerCode/{partnerCode}/year/{year}/month/{month}":{},
  "/api/gats/customsDistrictReExports/partnerCode/{partnerCode}/year/{year}/month/{month}":{},
  "/api/gats/UNTradeImports/reporterCode/{reporterCode}/year/{year}":{},
  "/api/gats/UNTradeExports/reporterCode/{reporterCode}/year/{year}":{},
  "/api/gats/UNTradeReExports/reporterCode/{reporterCode}/year/{year}":{},
  "/api/psd/commodity/{commodityCode}/dataReleaseDates":{},
  "/api/psd/commodity/{commodityCode}/country/all/year/{marketYear}":{},
  "/api/psd/commodity/{commodityCode}/country/{countryCode}/year/{marketYear}":{},
  "/api/psd/commodity/{commodityCode}/world/year/{marketYear}":{},
  "/api/psd/regions":{}, "/api/psd/countries":{}, "/api/psd/commodities":{}, "/api/psd/unitsOfMeasure":{}, "/api/psd/commodityAttributes":{}
 }}
```

Endpoint summaries from the swagger (verbatim fragments): PSD "Returns a set of records with Forecast number for a given Commodity Code (Ex, 0440000 for Corn) and a given Market Year (Ex, 2017) for a given Country (Ex, BR for Brazil). PSD Database has data for most commodities since year 1960."; ESR "Given Commodity Code (Ex: 104 for Wheat - White ), Country Code (Ex:1220 for Canada) and MarketYear (Ex: 2017) this API End point will return a list of US Export records"; GATS Census "Given Partner Code (Ex: CH for China) and YearMonth (Ex: 201001 ...) ... Imports into USA as reported by US Census Bureau"; GATS UN Trade "Given Reporter Code (Ex IN for India), and Import Year ... as reported by UN COMTrade ... at a HS6 Code Level"; the `dataReleaseDates` endpoints "Use this information to query for only the ... data that has changed since last invocation".

### Requests without a valid key (Captured 2026-11-15)

```
GET https://apps.fas.usda.gov/OpenData/api/psd/commodities                       -> 403 Forbidden   "Bad API Key"
GET https://apps.fas.usda.gov/OpenData/api/psd/commodities  (API_KEY: DEMO_KEY)  -> 500 Internal Server Error   {"message":"An error has occurred."}
```

Both bodies untrimmed (13 and 36 bytes, `application/json`).

### PSD lookups (key required)

| Parameter | Required | Description | Example |
|---|---|---|---|
| `API_KEY` (header) | yes | api.data.gov key | |

```
GET https://apps.fas.usda.gov/OpenData/api/psd/commodities
GET https://apps.fas.usda.gov/OpenData/api/psd/countries
GET https://apps.fas.usda.gov/OpenData/api/psd/commodityAttributes
GET https://apps.fas.usda.gov/OpenData/api/psd/unitsOfMeasure
```

### PSD data for one commodity, country and marketing year (key required)

| Parameter | Required | Description | Example |
|---|---|---|---|
| `{commodityCode}` (path) | yes | 7-digit PSD commodity code | `0440000` (corn) |
| `{countryCode}` (path) | yes | PSD country code, or `all`; the `world` path aggregates | `US`, `BR` |
| `{marketYear}` (path) | yes | Marketing year | `2024` |

```
GET https://apps.fas.usda.gov/OpenData/api/psd/commodity/0440000/country/US/year/2024
GET https://apps.fas.usda.gov/OpenData/api/psd/commodity/0440000/country/all/year/2024
GET https://apps.fas.usda.gov/OpenData/api/psd/commodity/0440000/world/year/2024
GET https://apps.fas.usda.gov/OpenData/api/psd/commodity/0440000/dataReleaseDates
```

### Sample response (Representative)

The swagger types every response as a plain object, so field names below come from the public client implementations cited in the inventory (earthrise-media food-security notebook, xippios sdk-usda-psd) and were not verified against a keyed response today. One record per commodity, country, marketing year and attribute (production, area harvested, yield, beginning stocks, imports, exports, domestic consumption, ending stocks, ...), with the attribute and unit resolved through the lookup endpoints.

```json
[
  {"commodityCode":"0440000","countryCode":"US","marketYear":2024,"calendarYear":2024,"month":"11","attributeId":4,"unitId":2,"value":<number>},
  {"commodityCode":"0440000","countryCode":"US","marketYear":2024,"calendarYear":2024,"month":"11","attributeId":28,"unitId":8,"value":<number>}
]
```

Lookup shapes (same caveat): commodities `[{"commodityCode":"0440000","commodityName":"Corn"}]`; countries `[{"countryCode":"US","countryName":"United States","regionCode":"NA","gencCode":"USA"}]`; attributes `[{"attributeId":4,"attributeName":"Area Harvested"}]`; units `[{"unitId":2,"unitDescription":"(1000 HA)"}]`.

### GATS and ESR data (key required)

```
GET https://apps.fas.usda.gov/OpenData/api/gats/censusImports/partnerCode/MX/year/2024/month/5
GET https://apps.fas.usda.gov/OpenData/api/gats/UNTradeExports/reporterCode/US/year/2023
GET https://apps.fas.usda.gov/OpenData/api/esr/exports/commodityCode/104/countryCode/1220/marketYear/2024
```

Census endpoints return US import, export and re-export records by partner at HS10 (and by customs district), one month per call; UN Trade endpoints return a reporter's annual HS6 trade; ESR returns weekly export sales records of one commodity to one destination (or all) for a marketing year. Response field names were not verified today.

## Fields

PSD record (Representative, see caveat above):

| Field | Type | Unit | Description |
|---|---|---|---|
| `commodityCode` | string | | 7-digit PSD commodity code (`0440000` corn, `2222000` soybeans, `0410000` wheat per PSD Online conventions; confirm with `/psd/commodities`) |
| `countryCode` | string | | PSD country code (`US`, `BR`); `/psd/countries` also gives the region code and GENC code |
| `marketYear` | integer | marketing year | Local marketing year of the commodity |
| `calendarYear`, `month` | integer, string | | Release month of the estimate |
| `attributeId` | integer | | Attribute (production, imports, exports, ending stocks, yield, area ...) via `/psd/commodityAttributes` |
| `unitId` | integer | | Unit via `/psd/unitsOfMeasure` (thousand metric tons, thousand hectares, ...) |
| `value` | number | per `unitId` | Estimate |

## Licence

PSD: the data.gov catalogue record "Production, Supply, and Distribution Database" (identifier USDA-26341, publisher Foreign Agricultural Service, `accrualPeriodicity` R/P1M, `modified` 2014-04-01) lists `"license": "https://creativecommons.org/licenses/by/4.0"` in its JSON-LD and in the distribution entry, re-read on 2026-11-15 from `https://catalog.data.gov/dataset/production-supply-and-distribution-database` (the CKAN API path `api/3/action/package_show` returned 404 on that host). Verdict in the inventory: PASS for PSD; GATS and ESR carry no licence statement that was found (STILL UNKNOWN). As US federal government works the underlying statistics are not subject to US copyright, but FAS states no licence for those two APIs.

## Overlap with NASA sources

NASA publishes no supply-demand balances, export sales or customs statistics. PSD's production and yield estimates sit beside NASA Harvest and the GEOGLAM Crop Monitor (crop conditions that inform such estimates), NASA POWER (`nasa_power.md`) for the weather of a marketing year and the MODIS and HLS vegetation indices (`vegetation_indices.md`); national yield and area statistics for the United States are in `nass_quickstats.md`.

## Notes

- Keys: api.data.gov issues them (HEAD on https://api.data.gov/signup/ returned 200 on 2026-11-15); the inventory's secondary source gives the quota as 1,000 requests per hour per key. `DEMO_KEY` returned HTTP 500 rather than a quota or auth message.
- The swagger contains no response schemas and no example payloads, so the record shapes could not be documented from official material.
- The `dataReleaseDates` endpoints exist for each API so that clients fetch only revised commodities and years; PSD forecasts for several years are revised at each release.
- The OpenData portal page (`https://apps.fas.usda.gov/opendatawebV2/`) is a JavaScript application; its text was not read.
- The inventory's secondary source gives the base path as `/OpenData/api/psd/...` and `/api/esr/...`, which matches the swagger.

## Documentation

- FAS Open Data portal: https://apps.fas.usda.gov/opendatawebV2/
- Swagger description: https://apps.fas.usda.gov/OpenData/swagger/docs/v1
- PSD Online: https://apps.fas.usda.gov/psdonline/
- data.gov record (licence): https://catalog.data.gov/dataset/production-supply-and-distribution-database
- api.data.gov key sign-up: https://api.data.gov/signup/
