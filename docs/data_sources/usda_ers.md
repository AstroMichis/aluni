# USDA ERS data APIs (ARMS Data API and Geospatial APIs)

The USDA Economic Research Service (ERS) publishes the ARMS Data API, which serves tailored reports from the Agricultural Resource Management Survey (ARMS): farm business balance sheet, income statement, financial ratios, structural characteristics, debt repayment capacity, government payments, operator household income and balance sheet. Values are survey estimates by year, state (or "all"), farm type and category (economic class, farm typology, operator age, Farm Resource Region, NASS region, production specialty). The API is REST (GET/POST, JSON) plus GraphQL, behind api.data.gov key management. Database updates are released roughly annually (December releases listed for 2019 to 2024). ERS also lists ArcGIS "Geospatial APIs" (map and feature services, mostly food-environment and food-access atlases) on `gisportal.ers.usda.gov`.

| | |
|---|---|
| Provider | USDA Economic Research Service |
| Base URL | `https://api.ers.usda.gov/data/` (ARMS REST); `https://api.ers.usda.gov/data/arms/graphql` (GraphQL); `https://gisportal.ers.usda.gov/server/rest/services` (geospatial) |
| Auth | ARMS: free api.data.gov key, query parameter `api_key` (signup form on the ARMS Data API page; "A valid email address is required"). Geospatial services: none observed |
| Formats | JSON (ARMS); ArcGIS REST JSON (geospatial); CSV variable list |
| Coverage | United States, all states and selected states; years from 1996 (farm typology categories cover 1996-2011 and 2012-present) |
| Resolution | national, state, region; by category |
| Cadence / latency | database updates listed on Updates and Revisions page (e.g. December 18, 2024: new 2023 data) |
| Rate limits / quotas | not stated on the ERS pages fetched; ERS API Terms of Service says use "may be subject to certain limitations on access, calls, or use" |
| Documentation | https://www.ers.usda.gov/developer/data-apis/arms-data-api |

## Requests

All ARMS examples below are copied from the ERS ARMS Data API documentation page. Each REST resource also supports `OPTIONS`, which per the documentation "returns the endpoint schema and details on input fields".

### `/arms/state` (GET)

All states with metadata and available variables.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `api_key` | yes | api.data.gov key | `YOUR_API_KEY` |

```
GET https://api.ers.usda.gov/data/arms/state?api_key=YOUR_API_KEY
```

### `/arms/year` (GET)

All years for which data are available.

```
GET https://api.ers.usda.gov/data/arms/year?api_key=YOUR_API_KEY
```

### `/arms/surveydata` (GET, POST)

Survey estimates. "Year" is required; at least one of `report` or `variable` is also required.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `api_key` | yes | Key | `YOUR_API_KEY` |
| `year` | yes | One or more years (comma separated in GET) | `2015,2016` |
| `report` | one of report/variable | Report name, words joined by `+` in GET | `income+statement` |
| `variable` | one of report/variable | Variable id (see AllVariables) | `igcfi` |
| `state` | no | State or `all` | `all` |
| `farmtype` | no | Farm type name | `operator+households` |
| `category` | no | Category name | `collapsed+farm+typology` |
| `category_value` | no | Category value | `commercial` |
| `category2` | no | Second category | `Collapsed Farm Typology` |

```
POST https://api.ers.usda.gov/data/arms/surveydata?api_key=YOUR_API_KEY
{
 "year": [2011, 2012, 2013, 2014, 2015, 2016]
 "state": "all"
 "variable": "igcfi"
 "category": "NASS Regions"
 "category2": "Collapsed Farm Typology"
}
```

(Body copied as published; it has no commas between members.) The documentation describes it as retrieving "Gross Farm Income" for 2011-2016, all states, by NASS region and collapsed farm typology.

```
GET https://api.ers.usda.gov/data/arms/surveydata?api_key=YOUR_API_KEY&year=2015,2016&state=all&report=income+statement&farmtype=operator+households&category=collapsed+farm+typology&category_value=commercial
```

### `/arms/category`, `/arms/report`, `/arms/variable`, `/arms/farmtype` (GET, POST)

Metadata lookups. Without input they list everything; with input they filter.

| Resource | Filter inputs (from docs) | Example |
|---|---|---|
| `/arms/category` | `name` (POST body) or `id` (GET, comma separated) | `GET .../arms/category?api_key=YOUR_API_KEY&id=age,ftypll` |
| `/arms/report` | `name`, ID or keyword | `POST .../arms/report?api_key=YOUR_API_KEY` body `{"name": "balance sheet"}` |
| `/arms/variable` | `report`, `name`, ID, keyword (all optional) | `POST .../arms/variable?api_key=YOUR_API_KEY` body `{"report": "Business Balance Sheet" "name": "Liabilities current debt"}` |
| `/arms/farmtype` | `name`, keyword, ID | `GET .../arms/farmtype?api_key=YOUR_API_KEY&name=operator+households` |

### Sample response (Representative)

The ERS documentation fetched does not include a response body for any resource. The documented response properties (from the Updates and Revisions page): survey data records include a `decimal_display` property; category records include `description`; report records include `desc`; farmtype records include `desc`; the `info` section no longer has `searching` and `formatting` properties. No further response structure is given in the sources fetched.

### Request without key (Captured 2026-11-14)

```
GET https://api.ers.usda.gov/data/arms/state
```

HTTP 403:

```json
{
  "error": {
    "code": "API_KEY_MISSING",
    "message": "No api_key was supplied. Get one at https://api.ers.usda.gov:443"
  }
}
```

`OPTIONS https://api.ers.usda.gov/data/arms/surveydata` without a key returned the same HTTP 403 body.

### ARMS variable list (download)

CSV of all variables by report, linked from the documentation as "AllVariables.csv".

```
GET https://www.ers.usda.gov/sites/default/files/images/arms-all-variables-december-2023.csv
```

### Sample rows (Captured 2026-11-14)

40,802 bytes, 152 data rows. First 5 rows of report "Farm Business Income Statement" (sequence 10-50); long descriptions cut with `...`.

```csv
Column1.id,Column1.name,Column1.sequence,Column1.description,Column1.unit,Column1.report
kount,Farms,10,Estimated number of farms.,Number,Farm Business Income Statement
igcfi,Gross cash farm income,20,"For farms participating in government programs, gross cash farm income is the total amount of cash received by the farm operation from the sale of agricultural products, services rendered, or government payments received during a given calendar year.",Dollars per farm,Farm Business Income Statement
iliv,Livestock income,30,"The value of all livestock and poultry sold from the farm operation net of any marketing charges. ...",Dollars per farm,Farm Business Income Statement
icrop,Crop sales,40,"The amount received from cash sales and marketing or forward contracts for all crops plus the difference between Commodity Credit Corporation crop placements and redemptions. ...",Dollars per farm,Farm Business Income Statement
igovt,Government payments,50,"Gross value of direct government payments received by farm operations during the calendar year. ...",Dollars per farm,Farm Business Income Statement
```

Rows per report: Government Payments 38, Farm Business Income Statement 31, Farm Business Balance Sheet 24, Structural Characteristics 18, Farm Business Debt Repayment Capacity 13, Farm Business Financial Ratios 11, Operator Household Balance Sheet 10, Operator Household Income 6 (+1 row spelled with a trailing space).

### Geospatial APIs (ArcGIS REST, no key)

Services listed on the ERS Geospatial APIs page include `Atlas_Reference_Data/Filter`, `Filter_2019`, `Reference`, `Reference_2019`, `Reference_Labels` (MapServer); `FARA/FARA_2010`, `FARA_2015`, `FARA_2019` (MapServer); and `Hosted/Access_25`, `Assistance25`, `Health25`, `Insecurity25`, `Local25_2`, `Prices__Taxes25`, `Restaurants25`, `Socioeconomic25`, `Stores25` (FeatureServer).

```
GET https://gisportal.ers.usda.gov/server/rest/services/FARA/FARA_2019/MapServer?f=json
```

### Sample response (Captured 2026-11-14)

Service info, reduced to the layer list (first 7 of 31 layers):

```json
{"layers":[{"id":0,"name":"Low Income and Low Access at 1 and 10 miles"},{"id":1,"name":"Det"},{"id":2,"name":"Gen"},{"id":3,"name":"Low Income and Low Access at .5 and 10 miles"},{"id":4,"name":"Det"},{"id":5,"name":"Gen"},{"id":6,"name":"Low Income and Low Access at 1 and 20 miles"}, "..."]}
```

## Fields

### AllVariables CSV

| Field | Type | Unit | Description |
|---|---|---|---|
| `Column1.id` | string | | Variable id used in `variable=` (e.g. `igcfi`) |
| `Column1.name` | string | | Variable name |
| `Column1.sequence` | integer | | Display order within the report |
| `Column1.description` | string | | Definition |
| `Column1.unit` | string | | One of: 1,000 Acres; 1,000 Dollars; Acres; Dollars; Dollars per HH; Dollars per farm; Number; Number of times; Percent; Percent of farms; Ratio |
| `Column1.report` | string | | Report the row belongs to |

The same `id` can appear in several reports with different `name`, `sequence` and `unit` (e.g. `igcfi` is "Dollars per farm" in the income statement and "Dollars" in Government Payments).

### ARMS categories (from documentation, short id in parentheses)

| Category | Values |
|---|---|
| Collapsed farm typology | Residence farms, Intermediate farms, Commercial farms |
| Economic Class (`sal`) | $1,000,000 or more; $500,000 to $999,999; $250,000 to $499,999; $100,000 to $249,999; less than $100,000 |
| Farm Typology (`ftyppl`) | Retirement, Off-farm occupation, Farming occupation/lower sales, Farming occupation/moderate-sales, Midsize, Large, Very large, Nonfamily (2012 to present); 1996 through 2011 set with Residential/lifestyle |
| Operator age (`age`) | 34 or younger; 35-44; 45-54; 55-64; 65 or older |
| Farm Resource Region (`reg`) | Heartland, Northern Crescent, Northern Great Plains, Prairie Gateway, Eastern Uplands, Southern Seaboard, Fruitful Rim, Basin and Range, Mississippi Portal |
| NASS region (`n5reg`) | Atlantic, South, Midwest, Plains, West |
| Production Specialty (`spec`) | General cash grains, Wheat, Corn, Soybean, Tobacco/cotton/peanuts, Other field crops, Specialty crops (F, V, N), Cattle, Dairy, Hogs, Poultry, All other livestock |

## Notes

- No API key was used. All ARMS API calls without `api_key` returned HTTP 403 `API_KEY_MISSING`; ARMS response samples are therefore not captured and the docs fetched contain no response bodies.
- The documentation's `/arms/category` example uses `id=age,ftypll` while the category list shows Farm Typology as `ftyppl`; both are copied as published.
- The documentation's POST bodies omit commas between JSON members and would not parse as strict JSON as written.
- The ERS ARMS documentation states the data are "also available in bulk files".
- A query on `FARA/FARA_2019/MapServer/0/query` with a point geometry returned HTTP 400 "Invalid or missing input parameters." (one attempt); the FARA services are food-access layers, not crop data.
- There is no ERS API in the sources fetched for crop-level costs and returns; ARMS reports listed are farm-business and household financial reports. Production Specialty categories include Wheat, Corn and Soybean.

## Documentation

- ERS Data APIs: https://www.ers.usda.gov/developer/data-apis
- ARMS Data API: https://www.ers.usda.gov/developer/data-apis/arms-data-api
- Updates and Revisions: https://www.ers.usda.gov/developer/data-apis/arms-data-api/updates-and-revisions
- ARMS variables CSV: https://www.ers.usda.gov/sites/default/files/images/arms-all-variables-december-2023.csv
- Geospatial APIs: https://www.ers.usda.gov/developer/geospatial-apis
- API Terms of Service: https://www.ers.usda.gov/developer/api-terms-of-service
- api.data.gov: https://api.data.gov/
