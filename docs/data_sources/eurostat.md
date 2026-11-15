# Eurostat API (agricultural prices and Comext trade)

Eurostat, the statistical office of the European Union, serves its database through a keyless REST API that returns JSON-stat 2.0, SDMX-ML or SDMX-CSV. Two parts matter for crop markets: the agricultural price datasets (`apri_*`: annual selling prices of crop and animal products in euro per 100 kg, price indices, input purchase prices) and Comext, the EU international trade in goods database, which has its own API host path and returns monthly or annual import and export value and quantity by reporter, partner and product (HS2 to HS6 and CN8). Coverage is the EU member states plus EFTA, candidate countries and, in Comext, every partner country. No login; a text table of contents lists every dataset code with its date range and size.

| | |
|---|---|
| Provider | Eurostat (European Commission) |
| Base URL | statistics `https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/{code}`; Comext `https://ec.europa.eu/eurostat/api/comext/dissemination/statistics/1.0/data/{code}`; catalogue `https://ec.europa.eu/eurostat/api/dissemination/catalogue/toc/txt?lang=EN`; SDMX 2.1 `https://ec.europa.eu/eurostat/api/dissemination/sdmx/2.1/` |
| Auth | none |
| Formats | JSON-stat 2.0 (`format=JSON`), SDMX-CSV (`format=SDMX-CSV`), TSV; SDMX-ML via the `sdmx/2.1` path |
| Coverage | EU-27, EFTA, candidate countries (prices); EU reporters with all partner countries (Comext) |
| Resolution | country (NUTS 0) x product x year (prices); reporter x partner x product x month or year (Comext) |
| Cadence / latency | `apri_ap_crpouta` last updated 2025-05-15 with data to 2024; Comext `DS-045409` updated 2026-11-13 |
| Rate limits / quotas | not published in the sources read; the Confluence documentation host answered one request with HTTP 503 "Too many requests coming from your IP address", see Notes |
| Licence | Commercial and non-commercial reuse authorised with source acknowledged; exceptions for third-party data, non-EU/EFTA/candidate country data, and trade declared by Switzerland, Liechtenstein (HS, SITC, BEC, NSTR) and Austria (CN8) |
| Documentation | https://wikis.ec.europa.eu/display/EUROSTATHELP/API+-+Getting+started+with+statistics+API ; https://ec.europa.eu/eurostat/help/copyright-notice |

## Requests

### Table of contents (dataset catalogue)

Returns a tab-separated text file with every folder, dataset and table: title, code, type, last data update, last structure change, data start, data end and number of values.

```
GET https://ec.europa.eu/eurostat/api/dissemination/catalogue/toc/txt?lang=EN
```

### Sample response (Captured 2026-11-15)

1,991,672 bytes (`text/plain`). Trimmed to the header and the crop-price rows.

```
"title"	"code"	"type"	"last update of data"	"last table structure change"	"data start"	"data end"	"values"
"            Agricultural prices and price indices"	"apri"	"folder"	" "	" "	" "	" "	
"                Selling prices of agricultural products (absolute prices)"	"apri_ap"	"folder"	" "	" "	" "	" "	
"                    Selling prices of crop products (absolute prices) - annual price (2000-2024)"	"apri_ap_crpouta"	"dataset"	"15.05.2025"	"14.05.2025"	"2000"	"2024"	52664
"                        Selling prices of maize"	"tag00062"	"table"	"15.05.2025"	"14.05.2025"	"2013"	"2024"	193
"                        Selling prices of barley"	"tag00060"	"table"	"15.05.2025"	"14.05.2025"	"2013"	"2024"	250
"                        Selling prices of sugar beet (unit value)"	"tag00064"	"table"	"15.05.2025"	"14.05.2025"	"2013"	"2024"	163
"                        Selling prices of main crop potatoes"	"tag00063"	"table"	"15.05.2025"	"14.05.2025"	"2013"	"2024"	299
"                        Selling prices of soft wheat"	"tag00059"	"table"	"15.05.2025"	"14.05.2025"	"2013"	"2024"	289
"                        Selling prices of oats"	"tag00061"	"table"	"15.05.2025"	"14.05.2025"	"2013"	"2024"	282
"                    Purchase prices of the means of agricultural production (absolute prices) - annual price (from 2000 onwards)"	"apri_ap_ina"	"dataset"	"15.05.2025"	"14.05.2025"	"2000"	"2024"	30319
"                    Selling prices of crop products (absolute prices) - annual - old codes - data from 1969 to 2005"	"apri_ap_hcouta"	"dataset"	"27.03.2009"	"21.12.2023"	"1969"	"2006"	56536
"                    Selling prices of crop products (absolute prices) - monthly - old codes - data from 1969 to 2006"	"apri_ap_hcoutm"	"dataset"	"27.03.2009"	"21.12.2023"	"1969-01"	"2006-09"	292541
```

Comext datasets (`DS-045409` and others) are not listed in this table of contents; they live under the `comext` API path.

### Statistics data (JSON-stat)

Returns a JSON-stat 2.0 dataset. Each dimension filter is a repeatable query parameter named after the dimension; an omitted dimension returns all its categories.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `{code}` (path) | yes | Dataset or table code | `apri_ap_crpouta`, `tag00062` |
| `format` | yes | `JSON`, `SDMX-CSV`, `TSV` | `JSON` |
| `lang` | no | `EN`, `FR`, `DE` labels | `EN` |
| `geo` | no | Country codes, repeatable | `FR`, `ES` |
| `prod_veg` | no | Product code (crop prices) | `01500000` (maize) |
| `currency` | no | `EUR` or `NAC` (national currency) | `EUR` |
| `time` | no | Year, repeatable; also `sinceTimePeriod`, `untilTimePeriod`, `lastTimePeriod` | `2024` |

```
GET https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/tag00062?format=JSON&lang=EN&time=2022&time=2023&time=2024
GET https://ec.europa.eu/eurostat/api/dissemination/statistics/1.0/data/apri_ap_crpouta?format=JSON&lang=EN&geo=FR&geo=ES&time=2024&currency=EUR
```

### Sample response (Captured 2026-11-15): selling prices of maize

5,861 bytes. Trimmed: `value` reduced from 46 entries to the countries listed, `status` reduced to two entries, `geo` labels reduced to those countries, the `extension.annotation` list cut to four items.

```json
{"version":"2.0","class":"dataset","label":"Selling prices of maize","source":"ESTAT","updated":"2025-05-15T11:00:00+0200",
 "value":{"24":30.98,"25":22.06,"26":18.82,"36":32.32,"37":25.40,"38":22.64,"45":35.65,"46":27.34,"47":22.98,"60":29.05,"61":19.01,"62":17.52,"72":24.96,"73":16.64,"74":15.45,"78":27.98,"79":23.05,"80":17.29},
 "status":{"71":"p","21":"|C"},
 "id":["freq","currency","prod_veg","geo","time"],"size":[1,1,1,41,3],
 "dimension":{
  "freq":{"label":"Time frequency","category":{"index":{"A":0},"label":{"A":"Annual"}}},
  "currency":{"label":"Currency","category":{"index":{"EUR":0},"label":{"EUR":"Euro"}}},
  "prod_veg":{"label":"Vegetable product","category":{"index":{"01500000":0},"label":{"01500000":"Maize - prices per 100 kg"}}},
  "geo":{"label":"Geopolitical entity (reporting)","category":{"index":{"EU27_2020":0,"DE":8,"ES":12,"FR":13,"IT":15,"HU":20,"PL":24,"RO":26,"TR":40},"label":{"DE":"Germany","ES":"Spain","FR":"France","IT":"Italy","HU":"Hungary","PL":"Poland","RO":"Romania"}}},
  "time":{"label":"Time","category":{"index":{"2022":0,"2023":1,"2024":2},"label":{"2022":"2022","2023":"2023","2024":"2024"}}}},
 "extension":{"lang":"EN","description":"<p>Corresponds to the absolute prices of the products. Expressed in euro per 100 kilo. Prices are net of VAT.</p>","id":"TAG00062","agencyId":"ESTAT","version":"1.0",
  "datastructure":{"id":"TAG00062","agencyId":"ESTAT","version":"19.0"},
  "annotation":[{"type":"OBS_COUNT","title":"193"},{"type":"OBS_PERIOD_OVERALL_OLDEST","title":"2013"},{"type":"OBS_PERIOD_OVERALL_LATEST","title":"2024"},{"type":"ESMS_HTML","title":"Explanatory texts (metadata)","href":"https://ec.europa.eu/eurostat/cache/metadata/en/apri_ap_esms.htm"}],
  "positions-with-no-data":{"geo":[0,1,2,3,9,10,13,16,17,21,22,29,30,31,32,33,34,35,36,37,38,39,40]}}}
```

Decoded (index = geo position x 3 + time position), euro per 100 kg of maize, net of VAT:

| geo | 2022 | 2023 | 2024 |
|---|---|---|---|
| DE | 30.98 | 22.06 | 18.82 |
| ES | 32.32 | 25.40 | 22.64 |
| IT | 35.65 | 27.34 | 22.98 |
| HU | 29.05 | 19.01 | 17.52 |
| PL | 24.96 | 16.64 | 15.45 |
| RO | 27.98 | 23.05 | 17.29 |

`FR` (geo position 13) and the EU aggregates are in `positions-with-no-data`: no absolute maize price is published for France in this table.

### Sample response (Captured 2026-11-15): crop prices, France and Spain, 2024

`apri_ap_crpouta`, 10,492 bytes, 98 `prod_veg` categories, 65 values. Trimmed to the dimension codes of five products and their decoded values; every French cell was empty.

```
prod_veg codes (label): 01110000 Soft wheat - prices per 100 kg; 01120000 Durum wheat; 01200000 Rye; 01300000 Barley;
  01400000 Oats; 01500000 Maize; 01600000 Rice; 01910000 Sorghum; 02110000 Rape; 02120000 Sunflowers; 02130000 Soya;
  02210000 Dried peas; 02220000 Dried beans; 02400000 Sugar beet: unit value - prices per 1000 kg; 04121000 Tomatoes in the open;
  04122000 Tomatoes under glass; ... 08100000 Extra virgin olive oil - prices per 100 litres
decoded 2024 values, EUR:  soft wheat ES=21.85 FR=none; maize ES=22.64 FR=none; soya ES=none FR=none;
  sugar beet (per 1000 kg) ES=56.4 (status p) FR=none; tomatoes under glass ES=69.7 FR=none
```

### Comext trade data (JSON-stat)

Same JSON-stat shape on the `comext` path. `DS-045409` is "EU trade since 1988 by HS2-4-6 and CN8".

| Parameter | Required | Description | Example |
|---|---|---|---|
| `{code}` (path) | yes | Comext dataset | `DS-045409` |
| `reporter` | no | Declaring EU country | `FR` |
| `partner` | no | Partner country | `US` |
| `product` | no | HS2, HS4, HS6 or CN8 code | `100590` |
| `flow` | no | `1` import, `2` export | `1` |
| `indicators` | no | `VALUE_IN_EUROS`, `QUANTITY_IN_100KG`, repeatable | |
| `time` | no | `YYYY-MM` (monthly) or `YYYY` (annual), repeatable | `2024-01` |
| `format`, `lang` | yes, no | as above | `JSON`, `EN` |

```
GET https://ec.europa.eu/eurostat/api/comext/dissemination/statistics/1.0/data/DS-045409?format=JSON&lang=EN&reporter=FR&partner=US&product=100590&flow=1&indicators=VALUE_IN_EUROS&indicators=QUANTITY_IN_100KG&time=2024-01&time=2024-02
```

### Sample response (Captured 2026-11-15)

2,105 bytes; untrimmed except the `annotation` list (seven timestamp and metadata entries, all dated 2026-11-13T11:00:00+0100).

```json
{"version":"2.0","class":"dataset","label":"EU trade since 1988 by HS2-4-6 and CN8","source":"ESTAT","updated":"2026-11-13T11:00:00+0100",
 "value":{"6":73.17,"7":56.24,"4":9671,"5":13867},
 "id":["freq","reporter","partner","product","flow","indicators","time"],"size":[2,1,1,1,1,2,2],
 "dimension":{
  "freq":{"label":"Frequency","category":{"index":{"A":0,"M":1},"label":{"A":"Annual","M":"Monthly"}}},
  "reporter":{"label":"REPORTER","category":{"index":{"FR":0},"label":{"FR":"France (incl. Saint Barthélemy 'BL' -> 2012; incl. French Guiana 'GF', Guadeloupe 'GP', Martinique 'MQ', Réunion 'RE' from 1997; incl. Mayotte 'YT' from 2014)"}}},
  "partner":{"label":"PARTNER","category":{"index":{"US":0},"label":{"US":"United States (incl. Navassa Island (part of 'UM') from 1995 -> 2000)"}}},
  "product":{"label":"PRODUCT","category":{"index":{"100590":0},"label":{"100590":"Maize (excl. seed for sowing)"}}},
  "flow":{"label":"FLOW","category":{"index":{"1":0},"label":{"1":"IMPORT"}}},
  "indicators":{"label":"INDICATORS","category":{"index":{"VALUE_IN_EUROS":0,"QUANTITY_IN_100KG":1},"label":{"VALUE_IN_EUROS":"VALUE_IN_EUROS","QUANTITY_IN_100KG":"QUANTITY_IN_100KG"}}},
  "time":{"label":"TIME_PERIOD","category":{"index":{"2024-01":0,"2024-02":1},"label":{"2024-01":"2024-01","2024-02":"2024-02"}}}},
 "extension":{"lang":"EN","id":"DS-045409","agencyId":"ESTAT","version":"1.0","datastructure":{"id":"DS-045409","agencyId":"ESTAT","version":"6.7"},
  "annotation":[{"type":"ESMS_HTML","title":"Explanatory texts (metadata)","href":"https://ec.europa.eu/eurostat/cache/metadata/en/ext_go_detail_sims.htm"}],
  "positions-with-no-data":{"freq":[0],"reporter":[],"partner":[],"product":[],"flow":[],"indicators":[],"time":[]}}}
```

Decoded: French imports of maize (100590) from the United States, monthly frequency (`freq` position 1; the annual position has no data for monthly periods): 2024-01 value 9,671 EUR and 73.17 x 100 kg; 2024-02 value 13,867 EUR and 56.24 x 100 kg.

### Failed requests (Captured 2026-11-15)

```
GET .../sdmx/2.1/dataflow/ESTAT/apri_ap_crpouta?references=all&format=JSON
  -> 400 {"error":[{"status":400,"id":140,"label":"ERR_JSONSTAT_RETURN_DETAILS: Only option supported in returnDetails for json-stat format is references=none without processConstraints, use SDMX instead."}]}
GET https://wikis.ec.europa.eu/display/EUROSTATHELP/API+-+Getting+started+with+statistics+API
  -> 307 webgate.ec.europa.eu/fpfis/wikis/... -> 302 login.action -> 303 EU Login -> 503 "Too many requests coming from your IP address !$"
```

## Fields

JSON-stat 2.0 dataset (both APIs):

| Field | Type | Unit | Description |
|---|---|---|---|
| `id` | array | | Dimension ids in order |
| `size` | array | | Number of categories per dimension, same order |
| `value` | object | per dataset | Observations keyed by the flattened row-major index over `size` (string keys); missing cells are absent |
| `status` | object | | Flags keyed like `value`: `p` provisional, `C`/`c` confidential, `e` estimated, `b` break in series (Eurostat flag conventions) |
| `dimension.<id>.category.index` | object | | Code to position |
| `dimension.<id>.category.label` | object | | Code to label |
| `extension.positions-with-no-data` | object | | Per dimension, positions with no observation in the response |
| `extension.annotation` | array | | `OBS_COUNT`, `OBS_PERIOD_OVERALL_OLDEST`/`LATEST`, `UPDATE_DATA`, `ESMS_HTML` (metadata link) |
| `updated` | string | ISO 8601 | Last data update |

Crop prices (`apri_ap_crpouta`, `tag000xx`): `prod_veg` 8-digit product code; values in euro (or national currency with `currency=NAC`) per 100 kg, per 1000 kg for sugar beet, per 100 litres for wine and olive oil, net of VAT. Comext (`DS-045409`): `reporter`, `partner` ISO-2 style geonomenclature codes, `product` HS2/HS4/HS6 or CN8 text codes, `flow` 1 or 2, `indicators` value in euro or quantity in 100 kg (supplementary units exist for some products), `time` month or year.

## Licence

Eurostat "Copyright notice and free re-use of data", re-read on 2026-11-15 (`https://ec.europa.eu/eurostat/help/copyright-notice`): "Reuse of statistical data, metadata, publications, and other dissemination tools published on this website for commercial or non-commercial purposes is authorised provided the source is acknowledged" and "There is no special procedure or requirement for a written licence. Just download the material and use it, unless the material is listed in the exceptions above." The exceptions that may not be reused commercially: data identified as belonging to sources other than Eurostat; co-publications; "Data for countries other than Member States of the European Union (EU), Member States of the European Free Trade Association (EFTA), official EU acceding and candidate countries. Examples are data for the United States of America, Japan or China. In such cases, the user will need to eliminate these data from the tables before reusing them commercially"; trade data declared by Liechtenstein and Switzerland from 1995 in HS, SITC, BEC, NSTR and national classifications; trade data declared by Austria at CN8. Modifications must be stated and a non-responsibility disclaimer added. Citation form for datasets: "Source: [DOI of the Eurostat dataset], [access date]"; `apri_ap_crpouta` carries DOI 10.2908/APRI_AP_CRPOUTA in its `DISSEMINATION_DOI_XML` annotation. Verdict in the inventory: PASS with exceptions.

## Overlap with NASA sources

NASA publishes no producer prices and no customs trade statistics. The crop price and trade series here sit beside the NASA crop-condition sources for Europe: NASA Harvest and the GEOGLAM Crop Monitor (country-level condition), NASA POWER (`nasa_power.md`) for season weather, and the MODIS and HLS vegetation indices (`vegetation_indices.md`); none of them carries a price.

## Notes

- The first request to the copyright page failed with an OpenSSL "unexpected eof while reading" while inflating the gzip body; sending `Accept-Encoding: identity` fixed it. The data endpoints answered without that header.
- The Eurostat documentation wiki (`wikis.ec.europa.eu`) redirected to EU Login and then returned HTTP 503 "Too many requests coming from your IP address" after about eight requests to `ec.europa.eu` hosts within three minutes; the API hosts themselves never refused a request. No published quota was found in the material read.
- `apri_ap_crpouta` ends in 2024 (updated 2025-05-15); `tag00062` showed `DISSEMINATION_TIMESTAMP_DATA` 2026-01-05, with the same 2024 end. France publishes no absolute crop prices in these tables; the EU and euro-area aggregates are also empty.
- JSON-stat `value` keys are string indices over the row-major product of `size`; decode with the `category.index` positions. Cells with a status but no value (for example `|C`, confidential) appear only in `status`.
- Comext `freq` returns both `A` and `M`; `positions-with-no-data.freq` tells which one is empty for the requested periods. Quantity is in units of 100 kg (73.17 means 7,317 kg).
- The `sdmx/2.1` structure endpoints need an SDMX format (XML or `SDMX-CSV`), not `format=JSON`.
- The HS6 code `100590` is "Maize (excl. seed for sowing)" in Eurostat's labels, consistent with the BACI usage in `cepii_baci.md`.

## Documentation

- API getting started: https://wikis.ec.europa.eu/display/EUROSTATHELP/API+-+Getting+started+with+statistics+API
- API detailed guidelines (statistics): https://wikis.ec.europa.eu/display/EUROSTATHELP/API+Statistics+-+data+query
- Comext and international trade API: https://wikis.ec.europa.eu/display/EUROSTATHELP/API+-+Detailed+guidelines+-+API+Statistics
- Copyright notice: https://ec.europa.eu/eurostat/help/copyright-notice
- Agricultural prices metadata (ESMS): https://ec.europa.eu/eurostat/cache/metadata/en/apri_ap_esms.htm
- International trade in goods metadata: https://ec.europa.eu/eurostat/cache/metadata/en/ext_go_detail_sims.htm
- Database browser: https://ec.europa.eu/eurostat/databrowser/
