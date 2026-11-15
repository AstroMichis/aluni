# USDA RMA Cause of Loss (Summary of Business with month of loss)

The USDA Risk Management Agency (RMA) publishes federal crop insurance results broken down by the cause of loss: for every crop year, state, county, commodity, insurance plan, coverage category, stage and cause, the month of loss, the number of policies indemnified, liability, premium and the indemnity paid. Causes include drought, heat, excess moisture, hail, frost, wind and also Insects (code 71), Plant Disease (81), Mycotoxin (82) and Asian Soybean Rust (09), which makes it the only open, quantitative, county-level crop-loss record attributable to pests found for this review. It covers the United States only. Files are one ZIP per crop year (1989 to 2026) holding one pipe-delimited text file; there is no API.

| | |
|---|---|
| Provider | USDA Risk Management Agency (RMA) |
| Base URL | `https://pubfs-rma.fpac.usda.gov/pub/Web_Data_Files/Summary_of_Business/cause_of_loss/` ; landing page `https://www.rma.usda.gov/tools-reports/summary-of-business/cause-loss` |
| Auth | none |
| Formats | ZIP containing a pipe-delimited (`|`) text file without a header row; record layout as PDF and Word |
| Coverage | United States, by county; crop years 1989-2026 on the page (the inventory also lists indemnity-only files for 1948-1988) |
| Resolution | county x commodity x insurance plan x coverage category x stage x cause x month of loss |
| Cadence / latency | files are regenerated as claims settle: the 2024 and 2025 ZIPs were last modified 2026-11-09 |
| Rate limits / quotas | not published |
| Licence | US Government work; data.gov metadata lists CC0 (from the inventory) |
| Documentation | https://www.rma.usda.gov/tools-reports/summary-of-business/cause-loss |

## Requests

### Landing page

```
GET https://www.rma.usda.gov/tools-reports/summary-of-business/cause-loss
```

### Sample response (Captured 2026-11-15)

HTTP 200, 94,452 bytes of HTML. The page text says: "Summarized participation information broken down by the causes of loss. Each link contains a ZIP file with compressed data containing pipe (|) delimited flat-files that can be imported into any standard spreadsheet and/or database for further analysis. Record description file located in each subfolder." It links the record layout (`COL_Summary_of_Business_with_Month_All_Years.pdf`), 38 yearly ZIPs `colsom_1989.zip` to `colsom_2026.zip`, and a `Stage_Code_Listing.pdf`.

### Yearly file

| Parameter | Required | Description | Example |
|---|---|---|---|
| `{year}` (path) | yes | Crop year, 1989-2026 | `2024` |

```
GET https://pubfs-rma.fpac.usda.gov/pub/Web_Data_Files/Summary_of_Business/cause_of_loss/colsom_2024.zip
```

### Sample response (Captured 2026-11-15)

HTTP 200, `application/zip`, 5,875,576 bytes, `last-modified: Mon, 09 Nov 2026 15:03:53 GMT`. One entry, `colsom_2024.txt`, 45,491,334 bytes, 148,824 rows, 30 fields per row. (`colsom_2025.zip`: 5,359,301 bytes, same date.)

York County, Nebraska (state 31, county 185) has 81 rows for 2024. Five of them, untrimmed:

```
2024|31|NE|185|York                          |0041|Corn                          |02|RP        |A|H |11|Drought|08|AUG|2024|17|17|531.2997500000|.0000000000|292701.2200000000|40004.1100000000|15193.0900000000|24811.0200000000|.0000000000|.0000000000|.0000000000|531.2997500000|60128.8400000000|1.50
2024|31|NE|185|York                          |0041|Corn                          |02|RP        |A|H |11|Drought|09|SEP|2024|3|3|116.7100000000|.0000000000|65302.5000000000|19000.0000000000|11569.0000000000|7431.0000000000|.0000000000|.0000000000|.0000000000|124.2100000000|34228.0000000000|1.80
2024|31|NE|185|York                          |0041|Corn                          |02|RP        |A|H |01|Decline in Price|10|OCT|2024|8|8|670.0800000000|.0000000000|496852.5000000000|41283.0000000000|18700.0000000000|22583.0000000000|.0000000000|.0000000000|.0000000000|746.9450000000|21358.0000000000|.52
2024|31|NE|185|York                          |0041|Corn                          |02|RP        |A|UH|01|Decline in Price|10|OCT|2024|1|1|96.8750000000|.0000000000|70785.5000000000|4142.0000000000|2154.0000000000|1988.0000000000|.0000000000|.0000000000|.0000000000|20.0100000000|970.0000000000|.23
2024|31|NE|185|York                          |0041|Corn                          |02|RP        |A|H |11|Drought|07|JUL|2024|13|13|160.3088800000|.0000000000|96318.8000000000|15411.4000000000|7658.2000000000|7753.2000000000|.0000000000|.0000000000|.0000000000|160.3090000000|26191.6000000000|1.70
```

York County had no 2024 rows for Insects or Plant Disease; the most frequent York rows were Corn and Soybeans with Drought, Heat, Excess Moisture, Wind and Decline in Price. Elsewhere in Nebraska, for example:

```
2024|31|NE|001|Adams                         |0041|Corn                          |02|RP        |A|H |71|Insects|07|JUL|2024|1|1|1983.0050000000|.0000000000|1928389.5000000000|136667.0000000000|64233.5000000000|72433.5000000000|.0000000000|.0000000000|.0000000000|2211.9400000000|650735.0000000000|4.76
2024|31|NE|003|Antelope                      |0041|Corn                          |02|RP        |A|H |81|Plant Disease|08|AUG|2024|1|1|219.3100000000|.0000000000|208281.0000000000|19055.0000000000|8957.0000000000|10098.0000000000|.0000000000|.0000000000|.0000000000|219.3100000000|50667.0000000000|2.66
2024|31|NE|003|Antelope                      |0081|Soybeans                      |02|RP        |A|H |71|Insects|08|AUG|2024|1|1|90.8960000000|.0000000000|53752.4000000000|3324.3600000000|1728.4800000000|1595.8800000000|.0000000000|.0000000000|.0000000000|90.8960000000|13625.0400000000|4.10
```

### Record layout

```
HEAD https://www.rma.usda.gov/sites/default/files/information-tools/colsommonth_allyears-pdf.pdf
```

HTTP 200, `application/pdf`, 82,635 bytes, `last-modified: Thu, 21 Mar 2024`. The PDF was not parsed; the field list below was matched against the values (premium = producer paid + subsidy; loss ratio = indemnity / total premium) and should be confirmed against the PDF.

## Fields

| # | Field | Type | Unit | Description |
|---|---|---|---|---|
| 1 | Commodity year | integer | | Crop year |
| 2, 3 | State code, state abbreviation | string | | FIPS state (`31`), `NE` |
| 4, 5 | County code, county name | string | | FIPS county (`185`), padded name |
| 6, 7 | Commodity code, commodity name | string | | RMA commodity (`0041` Corn, `0081` Soybeans) |
| 8, 9 | Insurance plan code, abbreviation | string | | `02` `RP` (Revenue Protection); 30 plan abbreviations in 2024 (APH, YP, RP, ECO, SCO, STAX, PRV, WFRP, ...) |
| 10 | Coverage category | string | | `A` additional, `C` catastrophic |
| 11 | Stage code | string | | Stage of the crop or claim (`H`, `UH`, `P`, ...); see `Stage_Code_Listing.pdf` |
| 12, 13 | Cause of loss code, description | string | | See the list below |
| 14, 15 | Month of loss, month abbreviation | string | | `08`, `AUG` |
| 16 | Year of loss | integer | | |
| 17 | Policies earning premium | integer | | |
| 18 | Policies indemnified | integer | | |
| 19 | Net planted quantity | number | acres (or units) | |
| 20 | Net endorsed acres | number | acres | |
| 21 | Liability | number | USD | |
| 22 | Total premium | number | USD | |
| 23 | Producer paid premium | number | USD | |
| 24 | Subsidy | number | USD | |
| 25-27 | Further premium or subsidy adjustment amounts | number | USD | Zero in all sampled rows; names to confirm in the layout PDF |
| 28 | Net determined quantity | number | acres | |
| 29 | Indemnity amount | number | USD | Negative values occur (corrections) |
| 30 | Loss ratio | number | ratio | Indemnity / total premium |

Cause of loss codes and descriptions present in the 2024 file:

```
01 Decline in Price            09 Asian Soybean Rust          11 Drought
12 Heat                        13 Failure of Irrigation Supply 14 Failure of Irrigation Equipment
15 Inability to Prepare Land for Irrigation                    21 Hail
22 Excess Sun                  31 Excess Moisture/Precipitation/Rain
41 Frost  42 Freeze  43 Cold Winter  44 Cold Wet Weather  45 Insufficient Chilling Hours
46 Tropical Storm  47 Hurricane  51 Flood  52 Low Salinity Caused by Excessive Rainfall
55 ARPI/SCO/ECO/STAX/MP/PACE Crops Only   61 Wind/Excess Wind   62 Hot Wind   63 Cyclone
64 Tornado  66 Oxygen Depletion  71 Insects  81 Plant Disease  82 Mycotoxin
85 Federal or State Ordered Destruction  86 Quarantine  87 Falling Numbers  91 Fire
92 Hurricane/Tropical Depression  93 Wildlife  97 Earthquake  98 Volcanic Eruption
99 Other (Snow, Lightning, Etc.)  XX All Other Causes
```

## Licence

US Government work. The inventory reads the data.gov record as `"license": "https://creativecommons.org/publicdomain/zero/1.0/"` (CC0, PASS). The data.gov CKAN API (`catalog.data.gov/api/3/action/package_show?id=cause-of-loss-historical-files`) returned HTTP 404 on 2026-11-15, so the licence string was not re-read today.

## Overlap with NASA sources

- NASA publishes no crop-insurance or crop-loss records.
- NASA serves the weather and land conditions behind the weather causes for the same county and month: POWER temperature, precipitation and soil wetness (`nasa_power.md`), SMAP soil moisture (`smap.md`), GRACE drought indicators (`grace.md`) and MODIS or HLS vegetation indices (`vegetation_indices.md`).
- Insects, Plant Disease and Mycotoxin causes have no NASA counterpart. `pest_weather_rules.md` documents the weather rules that use POWER inputs.

## Notes

- The rows count insured losses only; uninsured acres and losses below a policy's deductible do not appear.
- A row is an aggregate of policies, not one farm.
- Indemnity amounts and loss ratios can be negative when earlier payments are corrected.
- The inventory names the AgRisk Viewer (USDA Southwest Climate Hub and New Mexico State University) as a 1989-2024 single-download copy. Its documented URL `https://agrisk.jornada.nmsu.edu/rma/rma-data-viewer.html` returned HTTP 404; the site root (`https://agrisk.jornada.nmsu.edu/`, HTTP 200) hosts the viewer and says its data come from "cause of loss historical data files, and (2) summary of business reports" on the RMA site.

## Documentation

- Cause of Loss page: https://www.rma.usda.gov/tools-reports/summary-of-business/cause-loss
- Record layout (all years): https://www.rma.usda.gov/sites/default/files/information-tools/colsommonth_allyears-pdf.pdf
- Stage codes: https://pubfs-rma.fpac.usda.gov/pub/Web_Data_Files/Summary_of_Business/cause_of_loss/Stage_Code_Listing.pdf
- data.gov record: https://catalog.data.gov/dataset/cause-of-loss-historical-files
- AgRisk Viewer: https://agrisk.jornada.nmsu.edu/
