# USDA AMS Market News (MyMarketNews / MARS API)

USDA Agricultural Marketing Service (AMS) Market News publishes market reports (prices, volumes, bids) for grain, hay, livestock, fruit and vegetables, and other commodities, at elevator, terminal, shipping-point, auction and national level. Reports are issued daily, weekly or on other schedules as PDF or text documents identified by a numeric "slug" id; structured report data are served by the MyMarketNews API (MARS, `marsapi.ams.usda.gov`), which requires a key. A small set of "public" MARS endpoints lists published and corrected reports without a key.

| | |
|---|---|
| Provider | USDA Agricultural Marketing Service, Market News |
| Base URL | `https://marsapi.ams.usda.gov/services/` |
| Auth | Report data endpoints: key required (requests without one return HTTP 403 "Access is denied"); key issuance is through MyMarketNews (`https://mymarketnews.ams.usda.gov/`; registration page not fetched). Public listing endpoints (`/services/v3.1/public/...`) and `/services/help`: none |
| Formats | JSON or text (`format=json` / `txt`) for public listings; report files PDF, TXT, ZIP |
| Coverage | United States markets |
| Resolution | per report (market location / region) |
| Cadence / latency | per report; 354 reports published on 2026-11-14 by 16:15 MST, 763 in the 7 days to that time |
| Rate limits / quotas | not published in sources fetched |
| Documentation | https://marsapi.ams.usda.gov/services/help/more ; https://mymarketnews.ams.usda.gov/mymarketnews-api (unreachable on 2026-11-14, see Notes) |

## Requests

### API endpoint list (public)

Returns the list of endpoints with security level and parameters.

```
GET https://marsapi.ams.usda.gov/services/help/more
```

### Sample response (Captured 2026-11-14)

Untrimmed.

```json
[{"api":"/services/help","description":"List API endpoints","security":"Public"},
 {"api":"/services/help/more","description":"List API endpoints with documentation","security":"Public"},
 {"api":"/services/v3.1/public/listCorrectedReports?format=","description":"List all Corrected Reports for the current date","parameters":{"format":"the String, valid values: [txt,json], default value: txt"},"security":"Public"},
 {"api":"/services/v3.1/public/listCorrectedReports/{nbrOfDays}?format=","description":"List latest Corrected Reports within n-days, where @param nbrOfDays is a 'number of days' or 'all' for all days","parameters":{"format":"the String, valid values: [txt,json], default value: txt"},"security":"Public"},
 {"api":"/services/v3.1/public/listPublishedReport/{slug_id}?format=","description":"Get latest Published Report info for slug id","parameters":{"format":"the String, valid values: [txt,json], default value: txt"},"security":"Public"},
 {"api":"/services/v3.1/public/listPublishedReports?format=","description":"List all Published Reports for the current date","parameters":{"format":"the String, valid values: [txt,json], default value: txt"},"security":"Public"},
 {"api":"/services/v3.1/public/listPublishedReports/{nbrOfDays}?format=","description":"List latest Published Reports within n-days, where @param nbrOfDays is a 'number of days' or 'all' for all days","parameters":{"format":"the String, valid values: [txt,json], default value: txt"},"security":"Public"}]
```

### Published reports within n days (public)

| Parameter | Required | Description | Example |
|---|---|---|---|
| `{nbrOfDays}` (path) | no (omit for current date) | Number of days, or `all` | `7` |
| `format` | no | `txt` (default) or `json` | `json` |

```
GET https://marsapi.ams.usda.gov/services/v3.1/public/listPublishedReports/7?format=json
```

### Sample response (Captured 2026-11-14)

228,621 bytes, `numberOfReports` 763 (717 pdf, 44 txt, 2 zip). Trimmed to 3 of 763 report entries (grain and apple-region fruit examples).

```json
{"createdDate":"2026-11-14 16:18:17 MST","numberOfReports":763,"reports":[
 {"id":2850,"fileName":"ams_2850","fileExtension":"pdf","publishedDate":"2026-11-13 13:36:06 MST","publishedDateMilliseconds":1794602166117,"reportBeginDate":"2026-11-13","reportEndDate":"2026-11-13","reportTitle":"Iowa Daily Cash Grain Bids","correction":false,"final":true},
 {"id":3043,"fileName":"ams_3043","fileExtension":"pdf","publishedDate":"2026-11-13 14:10:43 MST","publishedDateMilliseconds":1794604243597,"reportBeginDate":"2026-11-13","reportEndDate":"2026-11-13","reportTitle":"Iowa-Southern Minnesota Barge Terminal Grain Bids","correction":false,"final":true},
 {"id":2412,"fileName":"ya_fv110","fileExtension":"pdf","publishedDate":"2026-11-13 14:28:21 MST","publishedDateMilliseconds":1794605301490,"reportBeginDate":"2026-11-13","reportEndDate":"2026-11-13","reportTitle":"YAKIMA Shipping Point Fruit Prices (YA_FV110)","correction":false,"final":true}
]}
```

Other crop-related report ids seen in the same listing: 3225 Nebraska Daily Elevator Grain Bids; 3192 Illinois Grain Bids; 3463 Indiana Grain Bids; 2886 Kansas Daily Grain Bids; 3186 South Dakota Daily Grain Bids; 3878 North Dakota Daily Grain Bids; 3046 Minneapolis Daily Grain Report; 3223 Kansas City Board of Trade Daily Wheat Bids; 2920 National Weekly Non-GMO/GE Grain Report; 3511 National Grain and Oilseed Processor Feedstuff Report; 3420 Daily Market Rates (Grain/Miscellaneous Commodities) (txt); hay: 2769 Montana, 2707 Texas, 3095 Oklahoma, 3058 Washington-Oregon (Columbia Basin), 3056 Idaho, 3926 Nevada (Bi-Weekly) Direct Hay Reports; fruit: 2402 Phoenix, 2390 Fresno Shipping Point Fruit Prices, 2306 Los Angeles, 2281 Baltimore Terminal Market Fruit Prices.

### Latest published report for one slug (public)

| Parameter | Required | Description | Example |
|---|---|---|---|
| `{slug_id}` (path) | yes | Report id | `3225` |
| `format` | no | `txt` (default) or `json` | `json` |

```
GET https://marsapi.ams.usda.gov/services/v3.1/public/listPublishedReport/3225?format=json
```

### Sample response (Captured 2026-11-14)

Untrimmed.

```json
{"createdDate":"2026-11-14 16:18:27 MST","numberOfReports":1,"reports":[{"id":3225,"fileName":"ams_3225","fileExtension":"pdf","publishedDate":"2026-11-13 13:01:47 MST","publishedDateMilliseconds":1794600107527,"reportBeginDate":"2026-11-13","reportEndDate":"2026-11-13","reportTitle":"Nebraska Daily Elevator Grain Bids","correction":false,"final":true}]}
```

Same request with default `txt` format (Captured 2026-11-14, untrimmed); the text form includes the report file URL:

```
Date Created: 2026-11-14 16:18:27 MST
       Total: 1 reports

Id        Published Date              Published Date(msec)  Report Begin Date  Report End Date    Correction  Report                                                        Report Title
    3225  2026-11-13 13:01:47 MST     1794600107527         2026-11-13         2026-11-13                     https://www.ams.usda.gov/mnreports/ams_3225.pdf               Nebraska Daily Elevator Grain Bids
```

### Corrected reports within n days (public)

```
GET https://marsapi.ams.usda.gov/services/v3.1/public/listCorrectedReports/7?format=json
```

### Sample response (Captured 2026-11-14)

15,158 bytes, `numberOfReports` 51; first entry only:

```json
{"createdDate":"2026-11-14 16:18:29 MST","numberOfReports":51,"reports":[{"id":1891,"fileName":"ams_1891","fileExtension":"pdf","publishedDate":"2026-11-13 11:47:01 MST","publishedDateMilliseconds":1794595621687,"reportBeginDate":"2026-11-12","reportEndDate":"2026-11-12","reportTitle":"Winter Livestock - Pratt, KS","correction":true,"final":true}, "..."]}
```

### Report list and report data (key required)

The keyed report endpoints live under `/services/v1.2/`. Requests without a key were refused:

```
GET https://marsapi.ams.usda.gov/services/v1.2/reports
GET https://marsapi.ams.usda.gov/services/v1.2/reports/3225
```

### Sample response (Captured 2026-11-14, no key)

HTTP 403 for both requests:

```json
{"dateTime":"2026-11-14T16:16:50.2513959","detail":"Attempt to access the protected resource. Please use HELP LINK for more information: https://marsapi.ams.usda.gov/services/help","errorCode":403,"message":"Access is denied","status":"403 - Forbidden"}
```

Response shapes for the keyed report list and report data endpoints are not included here: the MyMarketNews API documentation pages could not be fetched (see Notes) and `/services/help` lists only the public endpoints.

## Fields

### Public report listing

| Field | Type | Unit | Description |
|---|---|---|---|
| `createdDate` | string | `YYYY-MM-DD HH:MM:SS MST` | Time the listing was generated |
| `numberOfReports` | integer | | Count of entries in `reports` |
| `reports[].id` | integer | | Report slug id |
| `reports[].fileName` | string | | File base name (e.g. `ams_3225`, `ya_fv110`) |
| `reports[].fileExtension` | string | | `pdf`, `txt`, `zip` |
| `reports[].publishedDate` | string | `YYYY-MM-DD HH:MM:SS MST` | Publication time |
| `reports[].publishedDateMilliseconds` | integer | ms since Unix epoch | Publication time |
| `reports[].reportBeginDate`, `reportEndDate` | string | `YYYY-MM-DD` | Period covered |
| `reports[].reportTitle` | string | | Title |
| `reports[].correction` | boolean | | Whether the entry is a correction |
| `reports[].final` | boolean | | Final flag |

The `txt` format adds a `Report` column with the file URL (`https://www.ams.usda.gov/mnreports/<fileName>.<fileExtension>`).

## Notes

- `https://mymarketnews.ams.usda.gov/mymarketnews-api`: first attempt timed out; second attempt (with `/api-endpoints`) closed the connection without response ("Remote end closed connection without response"). The keyed API documentation was therefore not read.
- `https://www.ams.usda.gov/mnreports/ams_3225.pdf`: two HEAD attempts failed with "EOF occurred in violation of protocol" (TLS); `https://mymarketnews.ams.usda.gov/filerepo/reports/ams_3225.pdf` timed out. No report file content was captured.
- No key was used. `GET /services/v1.2/reports` and `/services/v1.2/reports/3225` returned HTTP 403 "Access is denied".
- Times in public listings are in MST (Mountain Standard Time) as labelled.
- `listPublishedReports/{nbrOfDays}` returns the latest publication per report id within the window, per the endpoint description.

## Documentation

- MARS API endpoint list: https://marsapi.ams.usda.gov/services/help/more
- MyMarketNews: https://mymarketnews.ams.usda.gov/
- MyMarketNews API page: https://mymarketnews.ams.usda.gov/mymarketnews-api
- AMS Market News: https://www.ams.usda.gov/market-news
