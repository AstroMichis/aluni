# FAO GIEWS FPMA (Food Price Monitoring and Analysis) price API

The FPMA Tool of FAO's Global Information and Early Warning System publishes retail and wholesale food price series for individual markets in 138 countries, plus 90 international export benchmark series (grains, rice, oilseeds, sugar, dairy, bananas). The tool's own JSON API is keyless: one call lists every series with its market, commodity, source and currency, another returns the full price history of a series by UUID, with each observation in local currency, in real terms and in USD. Series are compiled from national statistics offices, ministries, market information systems and partners such as WFP VAM and FEWS NET; the originating provider is named on every series.

| | |
|---|---|
| Provider | FAO, Global Information and Early Warning System (GIEWS), Markets and Trade Division |
| Base URL | `https://fpma.fao.org/giews/v4/global/price_module/api/v1/` (Django REST framework; paths without a trailing slash redirect 301 to the slash form) |
| Auth | none |
| Formats | JSON |
| Coverage | 4,848 domestic series in 138 countries and 90 international series (counts returned on 2026-11-15); 3,898 RETAIL and 950 WHOLESALE domestic series |
| Resolution | One series per market x commodity x price type; observations daily, weekly or monthly, with a `calculated` monthly aggregate alongside weekly series |
| Cadence / latency | Series end dates seen: weekly 2026-10-30, monthly 2026-10-01, on 2026-11-15; each series carries its own `periodicity` start and end dates |
| Rate limits / quotas | Not published; the full domestic list is a 4.0 MB response |
| Licence | CC BY 4.0 under the FAO Statistical Database Terms of Use (FPMA is listed in Annex 1), with the third-party exception: each series names its `source_name`, and third-party series need that provider's consent for redistribution; see Licence |
| Documentation | https://fpma-documentation.web.app/ ; https://www.fao.org/giews/food-prices/home/en/ |

## Requests

### API root

Lists the endpoints.

```
GET https://fpma.fao.org/giews/v4/global/price_module/api/v1/
```

### Sample response (Captured 2026-11-15)

Untrimmed (1,082 bytes).

```json
{"PriceType":"http://fpma.fao.org/giews/v4/global/price_module/api/v1/PriceType/","FxRate":"http://fpma.fao.org/giews/v4/global/price_module/api/v1/FxRate/","Market":"http://fpma.fao.org/giews/v4/global/price_module/api/v1/Market/","Commodity":"http://fpma.fao.org/giews/v4/global/price_module/api/v1/Commodity/","Source":"http://fpma.fao.org/giews/v4/global/price_module/api/v1/Source/","MeasureUnit":"http://fpma.fao.org/giews/v4/global/price_module/api/v1/MeasureUnit/","Price":"http://fpma.fao.org/giews/v4/global/price_module/api/v1/Price/","Cpi":"http://fpma.fao.org/giews/v4/global/price_module/api/v1/Cpi/","FpmaSerie":"http://fpma.fao.org/giews/v4/global/price_module/api/v1/admin/FpmaSerie/","FpmaSerieDomestic":"http://fpma.fao.org/giews/v4/global/price_module/api/v1/FpmaSerieDomestic/","FpmaSerieInternational":"http://fpma.fao.org/giews/v4/global/price_module/api/v1/FpmaSerieInternational/","FpmaSeriePrice":"http://fpma.fao.org/giews/v4/global/price_module/api/v1/FpmaSeriePrice/","PriceUpload":"http://fpma.fao.org/giews/v4/global/price_module/api/v1/PriceUpload/"}
```

### Domestic series list

Returns every domestic series (metadata only, no prices). Filter by country with `iso3_country_code`.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `iso3_country_code` | no | ISO 3166-1 alpha-3 country code; the whole list (4,848 series) is returned without it | `MEX` |

```
GET https://fpma.fao.org/giews/v4/global/price_module/api/v1/FpmaSerieDomestic/?iso3_country_code=MEX
```

### Sample response (Captured 2026-11-15)

The filtered request returned 27,162 bytes, `count` 29 (Mexico). Trimmed to two of the 29 results, both white maize wholesale series from the national market information system SNIIM. The unfiltered request returned 4,020,910 bytes with `count` 4848 and `next: null` (no pagination).

```json
{"count":29,"next":null,"previous":null,"results":[
 {"uuid":"1130611a-0df1-48b0-8a90-6bc3d4e6b595","iso3_country_code":"MEX","country_name":"Mexico","periodicity":[{"period":"weekly","end_date":"2026-10-30","start_date":"2000-01-07"},{"period":"monthly","end_date":"2026-10-01","calculated":true,"start_date":"2000-01-01"}],"market":1883,"market_name":"Culiacán","market_info":"Sinaloa: Central de Abasto de Culiacán","market_type":"State capital","admin_unit":"Sinaloa state (1)","admin_unit2":"","commodity":3044,"commodity_name":"Maize (white, Sinaloa)","commodity_info":"","commodity_image":null,"commodity_code":"100590_3","commodity_start_date":1,"alternative_code":"","alternative_name":"","source":385,"source_name":"Sistema Nacional de Información e Integración de Mercados","source_url":"http://www.economia-sniim.gob.mx/nuevo/","price_type_id":13,"price_type":"WHOLESALE","currency":"MXN","measure_unit":3653,"measure_unit_label":"Kg","conversion_factor":1.0},
 {"uuid":"9a646429-95bb-4324-a1be-eba180dff344","iso3_country_code":"MEX","country_name":"Mexico","periodicity":[{"period":"weekly","end_date":"2026-10-30","start_date":"2000-01-07"},{"period":"monthly","end_date":"2026-10-01","calculated":true,"start_date":"2000-01-01"}],"market":1884,"market_name":"Guadalajara","market_info":"Jalisco: Mercado de Abasto de Guadalajara","market_type":"State capital","admin_unit":"Jalisco state (1)","admin_unit2":"","commodity":3046,"commodity_name":"Maize (white, Jalisco)","commodity_info":"","commodity_image":null,"commodity_code":"100590_1","commodity_start_date":1,"alternative_code":"","alternative_name":"","source":385,"source_name":"Sistema Nacional de Información e Integración de Mercados","source_url":"http://www.economia-sniim.gob.mx/nuevo/","price_type_id":13,"price_type":"WHOLESALE","currency":"MXN","measure_unit":3653,"measure_unit_label":"Kg","conversion_factor":1.0}
]}
```

The United States of America has 7 domestic series, all monthly wholesale fruit prices at New York (bananas, papayas, pineapples, ...) sourced from USDA Market News, 2013-01 to 2026-10; the reference site's grain markets are not in FPMA. Source tally over all 4,848 series (top eight): "Various via WFP VAM" 794, FEWS NET 271, Ministry of Consumer Affairs 240, "Vulnerability Analysis and Mapping (VAM) - WFP" 229, FSNIS 152, State Statistics Service of Ukraine 126, European Commission DG AGRI 112, National Bureau of Statistics 105.

### Price series by UUID

Returns every observation of one series.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `{uuid}` (path) | yes | Series `uuid` from a series list | `1130611a-0df1-48b0-8a90-6bc3d4e6b595` |

```
GET https://fpma.fao.org/giews/v4/global/price_module/api/v1/FpmaSeriePrice/1130611a-0df1-48b0-8a90-6bc3d4e6b595/
```

### Sample response (Captured 2026-11-15)

251,360 bytes; 1,538 datapoints (1,220 weekly, 318 calculated monthly) from 2000-01-01 to 2026-10-30 for white maize, wholesale, Culiacán. Trimmed to the three most recent weekly points and the six most recent monthly points; the response lists newest first.

```json
{"uuid":"1130611a-0df1-48b0-8a90-6bc3d4e6b595","datapoints":[
 {"id":11313873,"price_value":10.0,"price_value_real":5.01,"price_value_dollar":0.54,"conversion_factor":1.0,"date":"2026-10-30","periodicity":"weekly","comment":""},
 {"id":11313872,"price_value":10.0,"price_value_real":5.01,"price_value_dollar":0.54,"conversion_factor":1.0,"date":"2026-10-23","periodicity":"weekly","comment":""},
 {"id":11313871,"price_value":10.0,"price_value_real":5.01,"price_value_dollar":0.54,"conversion_factor":1.0,"date":"2026-10-16","periodicity":"weekly","comment":""},
 {"id":11469544,"price_value":10.0,"price_value_real":5.01,"price_value_dollar":0.54,"conversion_factor":1.0,"date":"2026-10-01","periodicity":"monthly","comment":""},
 {"id":11469543,"price_value":10.0,"price_value_real":5.03,"price_value_dollar":0.58,"conversion_factor":1.0,"date":"2026-09-01","periodicity":"monthly","comment":""},
 {"id":11469542,"price_value":8.75,"price_value_real":4.42,"price_value_dollar":0.51,"conversion_factor":1.0,"date":"2026-08-01","periodicity":"monthly","comment":""},
 {"id":11469541,"price_value":8.0,"price_value_real":4.05,"price_value_dollar":0.46,"conversion_factor":1.0,"date":"2026-07-01","periodicity":"monthly","comment":""},
 {"id":11469540,"price_value":8.0,"price_value_real":4.05,"price_value_dollar":0.46,"conversion_factor":1.0,"date":"2026-06-01","periodicity":"monthly","comment":""},
 {"id":11469539,"price_value":8.0,"price_value_real":4.04,"price_value_dollar":0.46,"conversion_factor":1.0,"date":"2026-05-01","periodicity":"monthly","comment":""}
]}
```

Values in this sample: MXN 10.00 per kg wholesale, USD 0.54 per kg, in October 2026.

### International series list

Returns the export benchmark series (same object shape as the domestic list; `iso3_country_code` is `IPS`, `country_name` is `INTERNATIONAL PRICES`, `market_name` is the exporting country or hub).

```
GET https://fpma.fao.org/giews/v4/global/price_module/api/v1/FpmaSerieInternational/
```

### Sample response (Captured 2026-11-15)

73,516 bytes, `count` 90. Trimmed to three cereal series and to the fields that differ from the domestic example.

```json
{"count":90,"next":null,"previous":null,"results":[
 {"uuid":"3fefffb8-a60a-43f6-9f70-b71479f44a04","iso3_country_code":"IPS","country_name":"INTERNATIONAL PRICES","market_name":"Argentina","market_type":"Export","commodity_name":"Maize (Up River)","commodity_code":"CMM100500","source_name":"International Grains Council","price_type":"EXPORT","currency":"USD","measure_unit_label":"tonne","conversion_factor":0.001,"periodicity":[{"period":"weekly","end_date":"2026-10-30","start_date":"2005-01-07"},{"period":"monthly","end_date":"2026-10-01","calculated":true,"start_date":"2005-01-01"}]},
 {"uuid":"125add71-051b-4102-a018-72f59d4c3f1e","iso3_country_code":"IPS","market_name":"Canada (St Lawrence)","commodity_name":"Wheat (CWRS, 13.5%)","commodity_code":"CMM100102","source_name":"International Grains Council","price_type":"EXPORT","currency":"USD","measure_unit_label":"tonne","periodicity":[{"period":"monthly","end_date":"2026-10-01","start_date":"2000-01-01"}]},
 {"uuid":"2984e2ac-ce7d-4025-aa11-42a3f8a8c81c","iso3_country_code":"IPS","market_name":"Thailand (Bangkok)","commodity_name":"Rice (Parboiled 100%)","commodity_code":"CMM100605","source_name":"Thai Rice Exporters Association","price_type":"EXPORT","currency":"USD","measure_unit_label":"tonne","periodicity":[{"period":"monthly","end_date":"2026-10-01","start_date":"2000-01-01"}]}
]}
```

Sources of the 90 international series: Oil World 15, International Grains Council 14, Thai Rice Exporters Association 7, FAO rice price update 7, Bloomberg/Green Markets via the World Bank Pink Sheet 5, USDA 5, Dairy Market News (USDA) 4, APK-Inform 4, and 16 others with 1 to 3 series each. The USDA "Maize (US No. 2, White)" series at Kentucky ends 2020-04-01.

## Fields

### Series object (domestic and international lists)

| Field | Type | Unit | Description |
|---|---|---|---|
| `uuid` | string | | Series identifier used by `FpmaSeriePrice/{uuid}/` |
| `iso3_country_code`, `country_name` | string | | ISO alpha-3 and name; `IPS` / `INTERNATIONAL PRICES` for benchmarks |
| `periodicity[]` | array | | One entry per available frequency: `period` (`daily`, `weekly`, `monthly`), `start_date`, `end_date`, `calculated` (true when the monthly series is derived from higher-frequency data) |
| `market`, `market_name`, `market_info`, `market_type` | integer, string | | Market id, name, free-text note, type (e.g. `State capital`, `National capital city`, `Provincial average`, `Export`) |
| `admin_unit`, `admin_unit2` | string | | Administrative units of the market |
| `commodity`, `commodity_name`, `commodity_info`, `commodity_code` | integer, string | | Commodity id, label and code (HS6-based such as `100590_3`, or `CMM...` for international series) |
| `source`, `source_name`, `source_url` | integer, string | | Originating data provider |
| `price_type_id`, `price_type` | integer, string | | `RETAIL` (12), `WHOLESALE` (13), `EXPORT` (11) |
| `currency` | string | | ISO 4217 |
| `measure_unit`, `measure_unit_label`, `conversion_factor` | integer, string, decimal | | Unit of the price (`Kg`, `tonne`) and the factor applied to the reported unit |

### Datapoint object (`FpmaSeriePrice`)

| Field | Type | Unit | Description |
|---|---|---|---|
| `id` | integer | | Observation id |
| `date` | string | `YYYY-MM-DD` | Observation date (first of month for monthly points) |
| `periodicity` | string | | `daily`, `weekly` or `monthly` |
| `price_value` | decimal | local currency per unit | Nominal price |
| `price_value_real` | decimal | local currency per unit | Price in real terms as labelled by the API (deflated with the country CPI served by the `Cpi` endpoint; the base period is not stated in the response) |
| `price_value_dollar` | decimal | USD per unit | Converted with the `FxRate` series |
| `conversion_factor` | decimal | | Unit conversion applied |
| `comment` | string | | Free text, usually empty |

## Licence

FAO Statistical Database Terms of Use (re-read 2026-11-15 at https://www.fao.org/contact-us/terms/db-terms-of-use/en/): CC BY 4.0 for datasets of the databases listed in Annex 1, which names the "Food Price Monitoring and Analysis (FPMA) Tool"; additional terms prohibit use "for or in conjunction with the promotion of a commercial enterprise" and state that third-party data "may not be redistributed or reused without the consent of the original data provider". Every FPMA series carries `source_name` and `source_url`, which is where that check happens: 794 series are "Various via WFP VAM", 271 are FEWS NET, 229 are WFP VAM directly, and national statistics offices and ministries supply most of the rest. The inventory verdict is STILL UNKNOWN per series (PASS only for FAO-owned series). The developer documentation site (https://fpma-documentation.web.app/, fetched today) is a Docusaurus landing page with Tutorial and Docs sections and did not state separate API terms on its home page.

## Overlap with NASA sources

NASA publishes no market price data. FPMA's role beside the NASA sources in this folder is the demand and value side: NASA POWER, IMERG and SMAP describe the weather and soil of the field, MODIS and HLS the crop's vegetation, NASA Harvest and the GEOGLAM Crop Monitor the in-season crop condition; FPMA gives the market price of the harvested commodity in the nearest reporting market. For the Nebraska reference site FPMA has no grain series; USDA AMS Market News (`ams_market_news.md`) and NASS (`nass_quickstats.md`) cover that.

## Notes

- The `iso3=` filter in the inventory is not honoured: `?iso3=MEX` returned the full list (count 4848). `?iso3_country_code=MEX` returned 29 series.
- Series lists return everything in one response (`next: null`); the domestic list is 4.0 MB.
- Monthly points on weekly series are marked `calculated: true` in the series' `periodicity` and are returned mixed with the weekly points in `FpmaSeriePrice`; separate them on the `periodicity` field of each datapoint.
- `conversion_factor` 0.001 on international series means the source quotes per tonne and the API stores per kg.
- Paths without a trailing slash redirect (HTTP 301) to the slash form; follow redirects or request the slash form directly.
- Counts in this file were observed on 2026-11-15 and change as series are added or closed.

## Documentation

- FPMA Tool: https://fpma.fao.org/giews/fpmat4/
- FPMA developer documentation: https://fpma-documentation.web.app/
- GIEWS food prices home: https://www.fao.org/giews/food-prices/home/en/
- FAO Statistical Database Terms of Use: https://www.fao.org/contact-us/terms/db-terms-of-use/en/
- Digital Public Goods registry entry: https://www.digitalpublicgoods.net/r/food-price-monitoring-and-analysis-fpma-tool
