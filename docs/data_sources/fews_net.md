# FEWS NET Data Warehouse (market prices API)

The Famine Early Warning Systems Network (FEWS NET, funded by USAID) runs the FEWS NET Data Warehouse (FDW), a REST API over its market price, cross-border trade, food insecurity classification and geographic unit data. Market prices are weekly or monthly observations for named markets (with coordinates) and products coded in the UN Central Product Classification (CPC v2), in local currency and converted to USD per common unit, with ready-made comparisons to the previous month, previous years and multi-year averages. Public data is served without authentication; signed-in users with permissions can see more. HDX mirrors the staple-food price series per country as CC BY datasets whose resources point back at the same API.

| | |
|---|---|
| Provider | FEWS NET (Famine Early Warning Systems Network) |
| Base URL | `https://fdw.fews.net/api/` |
| Auth | None for public data ("Requests without any authentication may succeed but will only return public data"); session or token authentication for restricted data (FDW account; single sign-on users create a password in the Data Explorer profile) |
| Formats | `json`, `csv` (UTF-8 with BOM), `xml`, `html`, chosen with `?format=` or a URL extension (`marketpricefacts.csv`); `geojson` and `kml` on spatial endpoints |
| Coverage | 21,348 market x product price series in 84 countries (series list fetched 2026-11-15), all with `data_usage_policy: Public`; FEWS NET's presence countries in Africa, Central Asia, the Middle East, Latin America and the Caribbean; 25 series for the United States (import parity benchmarks) |
| Resolution | Market point (latitude, longitude, `fnid`) x product (CPC v2 code) x period; weekly or monthly collection |
| Cadence / latency | Latest `last_period_date` seen 2026-11-11; the Biu, Nigeria maize record for October 2026 was `modified` 2026-11-15 |
| Rate limits / quotas | Not published; the unfiltered series list is a 20.4 MB response and the help page asks for filtered or paginated requests |
| Licence | No named licence: attribution required, "FEWS NET publishes all data according to permissions provided by the original source institution, and all data sources are fully attributed" (re-read 2026-11-15); HDX copies are CC BY; see Licence |
| Documentation | https://help.fews.net/fdw/fews-net-api ; https://help.fews.net/fdw/prices ; https://fews.net/data-attribution |

## Requests

### Series list (`marketproduct`)

Returns one record per market x product x unit x price type series, with the source document, date range and point count. The same filters as `marketpricefacts` apply; without filters the whole list is returned.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `format` | no | `json`, `csv`, `xml`, `html` | `json` |
| `country_code` | no | ISO 3166-1 alpha-2, repeatable | `NG` |
| `product` | no | Product name or description match | `maize` |

```
GET https://fdw.fews.net/api/marketproduct/?format=json&country_code=NG&product=maize
```

### Sample response (Captured 2026-11-15)

Fetched without filters: 20,374,917 bytes, 21,348 records, served by uvicorn. Trimmed to one record (white maize, retail, Biu market in Borno State, Nigeria) and the `aliases` list cut to three entries. Tallies over the whole list: `price_type` Retail 18,830, Wholesale 1,840, Wage 477, Producer 94, Export 91, Spot 16; `product_source` Local 17,062, Import 4,205, Export 81; `is_staple_food` true 1,086.

```json
[{"id":25407,"name":"Biu, Nigeria (Open Ended): R01122AC / Maize Grain (White): Kilogram: NGN: Retail: Local","country":"Nigeria","fewsnet_region":"West Africa","geographic_group":"Western Africa","fnid":"NG0000M003","market_name":"Biu, Nigeria","cpcv2":"R01122AC","product_name":"Maize Grain (White)","unit":"kg","price_type":"Retail","currency":"NGN","product_source":"Local","is_staple_food":false,"data_source_document":"Famine Early Warning Systems Network (FEWS NET), Nigeria, Price (weekly)","data_source_organization":"FEWS NET","data_usage_policy":"Public","first_period_date":"2015-01-21","last_period_date":"2026-11-11","datapoint_count":563,"datasourcedocument":282,"market":57793,"product":"R01122AC","description":"","scientific_name":"Zea mays indentata","aliases":"['maize grain - kg', 'maize (white)', 'white maize', ...]"}]
```

### Price time series (`marketpricefacts`)

| Parameter | Required | Description | Example |
|---|---|---|---|
| `format` | no | `json`, `csv`, `xml`, `html` | `json` |
| `country_code` | no | ISO 3166-1 alpha-2, repeatable (`country_code=KE&country_code=ET`) | `NG` |
| `country` | no | Country name (slower than the code) | `Nigeria` |
| `cpcv2` | no | CPC v2 code; a prefix matches all children (`R01122` matches `R01122AB` and `R01122AC`) | `R01122AC` |
| `product` | no | Product name match | `maize` |
| `price_type` | no | `Assembly`, `Retail`, `Wholesale`, `Producer`, `Export`, `Spot`, `Wage` | `Retail` |
| `product_source` | no | `Local`, `Import`, `Export` | `Local` |
| `market` | no | Market id (`market` in the series list) | `57793` |
| `dataseries` | no | Series id (`id` in the series list) | `25407` |
| `datasourcedocument` | no | Source document id | `282` |
| `start_date`, `end_date` | no | Records current on or after / on or before, `YYYY-MM-DD` | `2025-01-01` |
| `as_of_date` | no | Records current at a date | `2025-06-30` |
| `collection_date` | no | Records collected on a date (mostly for forecasts) | |

```
GET https://fdw.fews.net/api/marketpricefacts/?format=json&country_code=NG&product=R01122AC&market=57793&start_date=2025-01-01
```

### Sample response (Captured 2026-11-15)

85,051 bytes, 44 records (2025-01-31 to 2026-10-31; `status` Aggregated 26, Collected 14, No Data 4). The `product=R01122AC` filter matched both the retail (per kg) and the wholesale (per 100 kg) series at this market. Trimmed to the most recent record, which is the wholesale series; the retail record for January 2025 had `value` 511.65 NGN/kg, `common_currency_price` 0.3306 USD/kg, `availability_description` "Above average".

```json
{"geographic_group":"Western Africa","fewsnet_region":"West Africa","fewsnet_region_code":901,"country":"Nigeria","country_code":"NG","admin_1":"Borno","admin_2":"Biu","fnid":"NG0000M003","market":"Biu",
 "cpcv2":"R01122AC","cpcv2_description":"Maize grain (corn), other, white","product":"Maize Grain (White)",
 "source_organization":"FEWS NET","source_document":"Famine Early Warning Systems Network (FEWS NET), Nigeria, Price (weekly)","collection_status":"Published",
 "period_date":"2026-10-31","start_date":"2026-10-01","price_type":"Wholesale","product_source":"Local","unit":"100_kg","unit_type":"Weight","currency":"NGN",
 "status":"Aggregated","value":30210.0,"availability":null,"availability_description":null,
 "common_unit":"kg","common_currency":"USD","exchange_rate":0.000750406,"common_unit_price":302.1,"common_currency_price":0.2266976526,
 "value_one_month_ago":31016.0,"value_one_year_ago":20600.0,"value_two_years_ago":74400.0,"value_three_years_ago":27055.0,"value_four_years_ago":17060.0,"value_five_years_ago":13695.0,"value_one_year_ahead":null,
 "two_year_average":47500.0,"five_year_average":30562.0,
 "pct_change_from_one_month_ago":-2.598658756770699,"pct_change_from_one_year_ago":46.6504854368932,"pct_change_from_two_year_average":-36.4,"pct_change_from_five_year_average":-1.1517570839604738,
 "id":null,"datacollectionperiod":null,"datacollection":null,"datasourcedocument":282,"datasourceorganization":1,"market_id":57793,"dataseries":25467,
 "dataseries_name":"Biu, Nigeria (Open Ended): R01122AC / Maize Grain (White): 100 kg: NGN: Wholesale: Local","dataseries_specialization_type":"/MarketProduct/","specialization_type":"/MarketPrice/",
 "data_usage_policy":"Public","created":"2026-10-12T00:43:50","modified":"2026-11-15T01:59:29","status_changed":"2026-11-02T01:07:42","collection_status_changed":"2026-11-10T08:21:15","collection_schedule":"Monthly",
 "longitude":12.1928,"latitude":10.6137,"is_staple_food":false}
```

### Other endpoints (from the help page, not called)

| Domain | Time series endpoint | Series list endpoint | Domain filters |
|---|---|---|---|
| Cross border trade | `tradeflowquantityvalue/` | `tradeflowquantity/` | `source`, `destination` (country name or alpha-2), `cpcv2`, `product`, `trade_type` (`Formal`, `Informal`) |
| Acute food insecurity classification | `ipcphase/` | `ipcclassification/` | `scenario` (`CS`, `ML1`, `ML2`), `preference=best` |
| Food insecure population estimates | `ipcpopulationsize/` | `ipcpopulation/` | `scenario` (`CS`, `FIPE6`), `phase` (`2`, `3%2b`) |
| Geographic units (tabular) | `geographicunit/` | | `unit_type` (`admin1`, `admin2`, `fsc_admin`, `fsc_admin_lhz`, `idp_camp`, `livelihood_zone`, `market`), `latlon=lat,lon` (shapes intersecting a point) |
| Geographic units (spatial) | `feature/` (geojson, kml) | | join on `fnid` |
| Geographic unit relationships | `geographicunitrelationship/` | | |

### HDX mirror (CKAN `package_show`)

```
GET https://data.humdata.org/api/3/action/package_show?id=fewsnet_staple_food_price_data_for_nigeria_weekly_282
```

### Sample response (Captured 2026-11-15)

6,912 bytes, trimmed. The three resources are live links into the FDW API rather than hosted files (`size` 0).

```json
{"name": "fewsnet_staple_food_price_data_for_nigeria_weekly_282", "title": "Nigeria Weekly FEWS NET Staple Food Price Data",
 "license_id": "cc-by", "license_title": "Creative Commons Attribution International (CC BY)",
 "dataset_date": "[2003-10-29T00:00:00 TO *]", "data_update_frequency": "-1", "dataset_source": "FEWS NET", "archived": false,
 "methodology_other": "The mean price for key commodities collected from multiple vendors in the selected markets, collected by FEWS NET enumerators on a regular schedule (typically monthly).",
 "notes": "Nigeria Weekly staple food price data collected by FEWS NET since 2003.",
 "resources": [
  {"name": "FEWS NET Staple Food Price Data for Nigeria", "format": "CSV", "url": "https://fdw.fews.net/api/marketpricefacts/?dataset=FEWS_NET_Staple_Food_Price_Data&country=NG&format=csv&fields=website&end_date", "size": 0, "last_modified": "2025-02-03T01:02:21.007649"},
  {"name": "FEWS NET Staple Food Price Data for Nigeria", "format": "JSON", "url": "https://fdw.fews.net/api/marketpricefacts/?dataset=FEWS_NET_Staple_Food_Price_Data&country=NG&format=json&fields=website&end_date", "size": 0, "last_modified": "2025-02-03T01:02:21.007649"}
 ]}
```

## Fields

### `marketpricefacts` record

| Field | Type | Unit | Description |
|---|---|---|---|
| `country`, `country_code` | string | | Country name and ISO alpha-2 |
| `fewsnet_region`, `fewsnet_region_code`, `geographic_group` | string, integer | | FEWS NET region and UN geographic group |
| `admin_1`, `admin_2`, `market`, `market_id`, `fnid` | string, integer | | Administrative units, market name, market id, FEWS NET geographic unit id |
| `latitude`, `longitude` | decimal | degrees | Market point |
| `cpcv2`, `cpcv2_description`, `product` | string | | CPC v2 code (FEWS NET extension such as `R01122AC`), description, product label |
| `price_type` | string | | `Retail`, `Wholesale`, `Producer`, `Export`, `Spot`, `Wage`, `Assembly` |
| `product_source` | string | | `Local`, `Import`, `Export` |
| `period_date`, `start_date` | string | `YYYY-MM-DD` | End and start of the period the value covers |
| `collection_schedule` | string | | `Weekly`, `Monthly` |
| `unit`, `unit_type`, `currency` | string | | Reported unit (`kg`, `100_kg`, `day`), unit type, ISO 4217 |
| `value` | decimal | currency per unit | Reported price |
| `status` | string | | `Collected`, `Aggregated` (weekly to monthly), `No Data` |
| `collection_status` | string | | `Published` |
| `availability`, `availability_description` | decimal, string | | Trader-reported availability score and label (e.g. "Above average"), when collected |
| `common_unit`, `common_currency`, `exchange_rate`, `common_unit_price`, `common_currency_price` | string, decimal | | Normalised price per kg and per USD (`exchange_rate` is USD per unit of local currency) |
| `value_one_month_ago` ... `value_five_years_ago`, `value_one_year_ahead` | decimal | currency per unit | Comparison values on the same series |
| `two_year_average`, `five_year_average` | decimal | currency per unit | Averages of the same month in previous years |
| `pct_change_from_one_month_ago`, `pct_change_from_one_year_ago`, `pct_change_from_two_year_average`, `pct_change_from_five_year_average` | decimal | percent | Pre-computed changes |
| `source_organization`, `source_document`, `datasourcedocument`, `datasourceorganization` | string, integer | | Provenance |
| `dataseries`, `dataseries_name` | integer, string | | Series id and label |
| `data_usage_policy` | string | | `Public` on every record and series seen |
| `created`, `modified`, `status_changed`, `collection_status_changed` | string | ISO timestamp | Record lifecycle |
| `is_staple_food` | boolean | | Staple flag |

### `marketproduct` record

`id`, `name`, `country`, `fewsnet_region`, `geographic_group`, `fnid`, `market_name`, `cpcv2`, `product_name`, `unit`, `price_type`, `currency`, `product_source`, `is_staple_food`, `data_source_document`, `data_source_organization`, `data_usage_policy`, `first_period_date`, `last_period_date`, `datapoint_count`, `datasourcedocument`, `market`, `product`, `description`, `scientific_name`, `aliases`.

## Licence

The FEWS NET Data Attribution page (re-read 2026-11-15 at https://fews.net/data-attribution) names no licence. It states that "FEWS NET publishes all data according to permissions provided by the original source institution, and all data sources are fully attributed", that the content "is not official United States Government information", and asks users to email data.policy@fews.net with questions. Every record carries `source_organization` and `source_document`, and `data_usage_policy` was `Public` on all 21,348 series. The HDX mirrors of the staple-food price series are published as CC BY (`license_id: cc-by`, read today). The inventory verdict is STILL UNKNOWN for the API and PASS (static) for the HDX datasets.

## Overlap with NASA sources

NASA publishes no market prices; this is the demand and value complement to the NASA weather, soil moisture and vegetation sources in this folder, joined on the market's `latitude`/`longitude`. FEWS NET separately publishes agroclimatology products (rainfall, NDVI and water-requirement satisfaction indices) built with NASA and NOAA inputs through its science partners; those are a different FDW domain and are not described here. The United States appears only through 25 benchmark series (import parity references), so the Nebraska reference site has no FEWS NET market; AMS Market News covers it (`ams_market_news.md`).

## Notes

- The inventory reported HDX saying "The FEWS NET Data Warehouse is currently unavailable"; on 2026-11-15 both API calls answered HTTP 200 and the HDX Nigeria record was not archived (`archived: false`), with resources linking into the live API.
- The unfiltered `marketproduct` list is 20.4 MB; the help page recommends filtering by `country_code` and `start_date` or paginating.
- `product=R01122AC` (a code passed to the name-matching `product` filter) matched both the retail and wholesale series of that product at the market; use `cpcv2` for exact code matching and `price_type` to separate them.
- `status: "No Data"` records exist in the time series with `value` absent; `status: "Aggregated"` marks monthly values computed from weekly collections.
- The HDX resource URLs embed `format=csv|json|xlsx` and `fields=website`, showing that `fields` and `dataset` are accepted query parameters of `marketpricefacts`, though the help page does not document them.
- Responses are served by uvicorn (Python ASGI); no rate-limit headers were returned.

## Documentation

- FEWS NET API help: https://help.fews.net/fdw/fews-net-api
- API authentication: https://help.fews.net/fdw/api-authentication
- Prices domain: https://help.fews.net/fdw/prices
- Data attribution and terms: https://fews.net/data-attribution
- FEWS NET Data Explorer: https://fews.net/data
- HDX FEWS NET organisation: https://data.humdata.org/organization/fews-net
