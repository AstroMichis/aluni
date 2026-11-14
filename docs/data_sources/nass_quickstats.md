# USDA NASS QuickStats

The official U.S. agricultural statistics: yields, planted and harvested acres, production and prices by crop, year, state and county.

**Status: credential not configured** (`NASS_API_KEY`). Samples below are representative.

| | |
|---|---|
| Endpoint | `GET https://quickstats.nass.usda.gov/api/api_GET/` |
| Auth | `key` query parameter (free key emailed from https://quickstats.nass.usda.gov/api) |
| Format | `format=JSON` (also CSV, XML) |
| Limit | 50,000 rows per request; `GET /api/get_counts/` with the same filters returns the row count |
| Other | `GET /api/get_param_values/?param=commodity_desc` lists valid values for any filter |
| Docs | https://quickstats.nass.usda.gov/api |

## Request: county yields

County comes from the FCC Census Block API (no auth), which also gives state for OpenET coverage checks:

```
GET https://geo.fcc.gov/api/census/block/find?latitude=40.95&longitude=-97.50&format=json
```

```json
{"Block":{"FIPS":"311859696001175","bbox":[-97.501802,40.9445,-97.482658,40.959102]},"County":{"FIPS":"31185","name":"York County"},"State":{"FIPS":"31","code":"NE","name":"Nebraska"},"status":"OK","executionTime":"0"}
```
(Captured)

```
GET /api/api_GET/?key=$NASS_API_KEY
    &source_desc=SURVEY&sector_desc=CROPS&commodity_desc=CORN
    &statisticcat_desc=YIELD&agg_level_desc=COUNTY
    &state_alpha=NE&county_ansi=185
    &year__GE=2015&format=JSON
```

`county_ansi` is the last 3 digits of the county FIPS. Operators: `__GE`, `__LE`, `__LT`, `__GT`, `__LIKE`, `__NE`.

## Sample response (Representative, trimmed)

```json
{
  "data": [
    {
      "year": 2024, "reference_period_desc": "YEAR",
      "state_alpha": "NE", "county_name": "YORK", "county_ansi": "185",
      "commodity_desc": "CORN", "class_desc": "ALL CLASSES",
      "prodn_practice_desc": "IRRIGATED", "util_practice_desc": "GRAIN",
      "statisticcat_desc": "YIELD", "unit_desc": "BU / ACRE",
      "short_desc": "CORN, GRAIN, IRRIGATED - YIELD, MEASURED IN BU / ACRE",
      "Value": "228.4", "CV (%)": ""
    },
    {
      "year": 2024, "county_name": "YORK",
      "prodn_practice_desc": "NON-IRRIGATED", "util_practice_desc": "GRAIN",
      "short_desc": "CORN, GRAIN, NON-IRRIGATED - YIELD, MEASURED IN BU / ACRE",
      "Value": "171.9"
    },
    {
      "year": 2023, "county_name": "YORK",
      "prodn_practice_desc": "ALL PRODUCTION PRACTICES", "util_practice_desc": "GRAIN",
      "short_desc": "CORN, GRAIN - YIELD, MEASURED IN BU / ACRE",
      "Value": "(D)"
    }
  ]
}
```

- `Value` is a **string with thousands separators** (`"1,234"`); strip commas.
- `(D)` = withheld to avoid disclosing individual operations, `(NA)` = not available, `(Z)` = less than half the unit.
- Several rows per year: pick by `prodn_practice_desc` (IRRIGATED, NON-IRRIGATED, ALL PRODUCTION PRACTICES) and `util_practice_desc` (GRAIN vs. SILAGE for corn).
- County estimates lag: the previous year appears around February-March; some years and crops have no county estimate at all.

## Query parameters by statistic

| Question | `statisticcat_desc` | `unit_desc` | Level |
|---|---|---|---|
| Yield history per crop | `YIELD` | `BU / ACRE`, `TONS / ACRE` (hay), `LB / ACRE` (cotton) | COUNTY |
| How common a crop is locally | `AREA PLANTED`, `AREA HARVESTED` | `ACRES` | COUNTY |
| Irrigated share | `AREA HARVESTED` with `prodn_practice_desc=IRRIGATED` | `ACRES` | COUNTY |
| Prices received | `PRICE RECEIVED` | `$ / BU`, `$ / TON` | STATE, monthly (`freq_desc=MONTHLY`) |
| Cover crop and practice adoption | `source_desc=CENSUS` (every 5 years) | `ACRES` | COUNTY |

Commodity names for rotation crops: `CORN`, `SOYBEANS`, `WHEAT` (class `WINTER`/`SPRING, (EXCL DURUM)`), `SORGHUM`, `OATS`, `BARLEY`, `HAY` (class `ALFALFA`), `SUNFLOWER`, `DRY BEANS`, `RYE`.

## Documentation

- QuickStats API: https://quickstats.nass.usda.gov/api
- Parameter definitions: https://quickstats.nass.usda.gov/param_define
- FCC Census Block API: https://geo.fcc.gov/api/census/
