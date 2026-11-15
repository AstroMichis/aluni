# Harvard Growth Lab International Trade Data (Atlas of Economic Complexity, Dataverse)

The Growth Lab at Harvard University publishes the trade data behind the Atlas of Economic Complexity on Harvard Dataverse: bilateral and unilateral goods trade by country and product in HS 1992 (about 5,000 products, 1995 onwards), HS 2012, HS 2022 and SITC Revision 2 (about 700 products, 1962 onwards), plus the complexity measures derived from them (ECI, PCI, RCA, distance, opportunity gain), and a companion "Classifications Data" repository with the country and product code tables. Raw data come from UN Comtrade and are cleaned with the Bustos-Yildirim method, which uses both sides of each bilateral flow to correct inconsistent reporting. Files are large CSVs; the Dataverse native API serves the dataset metadata and the files without a login.

| | |
|---|---|
| Provider | The Growth Lab at Harvard University (Harvard Dataverse, dataverse "atlas") |
| Base URL | `https://dataverse.harvard.edu/api/` (native API); landing pages `https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/{id}` |
| Auth | none for metadata and file download (a guestbook is configured on the web pages; the API served files without it on 2026-11-15) |
| Formats | JSON (API); CSV files (`text/comma-separated-values`) |
| Coverage | HS92: 1995-2024 files (metadata says 1995-2023); SITC Rev. 2: 1962-2024 files; about 250 locations incl. groups |
| Resolution | country x partner x product x year (bilateral files); country x product x year; country x year; product x year; product detail 1, 2, 4 or 6 digits (HS) and 1, 2, 4 digits (SITC) |
| Cadence / latency | re-released about once a year; HS92 and SITC version 18.0 released 2026-04-22, Classifications version 12.0 released 2026-05-04 |
| Rate limits / quotas | none published; the file endpoint redirects to a presigned S3 URL valid for 3600 s |
| Licence | CC0 1.0 (declared in the dataset metadata of all three repositories) |
| Documentation | https://dataverse.harvard.edu/dataverse/atlas ; https://guides.dataverse.org/en/latest/api/native-api.html |

Datasets documented here:

| Dataset | DOI | Dataverse id | Version |
|---|---|---|---|
| International Trade Data (HS, 92) | `doi:10.7910/DVN/T4CHWJ` | 3425423 | 18.0 (2026-04-22) |
| International Trade Data (SITC, Rev. 2) | `doi:10.7910/DVN/H8SFD2` | 3425507 | 18.0 (2026-04-22) |
| Classifications Data | `doi:10.7910/DVN/3BAL1O` | 3425457 | 12.0 (2026-05-04) |

The dataverse also hosts HS12 and HS22 trade datasets with the same layout; they were not queried.

## Requests

### Dataset metadata and file list

Returns the latest released version: licence, citation fields, description and one entry per file with its numeric id and size.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `persistentId` | yes | DOI of the dataset | `doi:10.7910/DVN/T4CHWJ` |

```
GET https://dataverse.harvard.edu/api/datasets/:persistentId/?persistentId=doi:10.7910/DVN/T4CHWJ
```

### Sample response (Captured 2026-11-15)

18,328 bytes. Trimmed: citation fields other than title and description removed, HTML in the description removed, `files` reduced to five of the fifteen entries (the full list is in the table below).

```json
{"status":"OK","data":{"id":3425423,"identifier":"DVN/T4CHWJ","persistentUrl":"https://doi.org/10.7910/DVN/T4CHWJ","publisher":"Harvard Dataverse","publicationDate":"2019-06-04","guestbookId":262,
 "latestVersion":{"versionNumber":18,"versionMinorNumber":0,"versionState":"RELEASED","releaseTime":"2026-04-22T16:48:45Z","fileAccessRequest":false,
  "license":{"name":"CC0 1.0","uri":"http://creativecommons.org/publicdomain/zero/1.0","rightsIdentifier":"CC0-1.0","rightsIdentifierScheme":"SPDX"},
  "metadataBlocks":{"citation":{"fields":[
    {"typeName":"title","value":"International Trade Data (HS, 92)"},
    {"typeName":"dsDescription","value":[{"dsDescriptionValue":{"value":"The Atlas of Economic Complexity maintains trade data in multiple international classification systems. This data set contains trade flows classified via Harmonized System (HS) 1992. ... Categorizes approximately 5,000 goods. Coverages starts in 1995. Categories break down to 1-, 2-, 4-, or 6-digit detail levels (though country reporting can be less reliable at the 6-digit level). Raw data on trade in goods is provided by United Nations Statistical Division (COMTRADE). The data is then cleaned by Growth Lab researchers using the Bustos-Yildirim Method ..."}}]},
    {"typeName":"timePeriodCovered","value":[{"timePeriodCoveredStart":{"value":"1995-01-01"},"timePeriodCoveredEnd":{"value":"2023-12-31"}}]},
    {"typeName":"productionDate","value":"2024-09-10"},{"typeName":"distributionDate","value":"2024-09-17"}]}},
  "files":[
    {"label":"hs92_country_country_product_year_6_2020_2024.csv","restricted":false,"dataFile":{"id":13685118,"filename":"hs92_country_country_product_year_6_2020_2024.csv","contentType":"text/comma-separated-values","filesize":2855413820}},
    {"label":"hs92_country_product_year_6.csv","restricted":false,"dataFile":{"id":13685115,"filesize":1014979406}},
    {"label":"hs92_country_year.csv","restricted":false,"dataFile":{"id":13685109,"filesize":363501}},
    {"label":"hs92_product_year_6.csv","restricted":false,"dataFile":{"id":13685119,"filesize":5617888}},
    {"label":"hs92_data_dictionary.csv","restricted":false,"dataFile":{"id":13685113,"filesize":3257}}
  ]}}}
```

Files in the HS92 dataset (version 18.0), ids and sizes from the same response:

| File | id | Bytes |
|---|---|---|
| `hs92_country_country_product_year_6_1995_1999.csv` | 13685106 | 1,940,426,282 |
| `hs92_country_country_product_year_6_2000_2009.csv` | 13685108 | 4,637,596,778 |
| `hs92_country_country_product_year_6_2010_2019.csv` | 13685120 | 5,595,000,168 |
| `hs92_country_country_product_year_6_2020_2024.csv` | 13685118 | 2,855,413,820 |
| `hs92_country_country_year.csv` | 13685107 | 30,767,251 |
| `hs92_country_product_year_1.csv`, `_2`, `_4`, `_6` | 13685114, 13685112, 13685110, 13685115 | 4,140,616; 38,135,675; 451,749,132; 1,014,979,406 |
| `hs92_country_year.csv` | 13685109 | 363,501 |
| `hs92_product_year_1.csv`, `_2`, `_4`, `_6` | 13685117, 13685111, 13685116, 13685119 | 12,801; 123,986; 1,589,755; 5,617,888 |
| `hs92_data_dictionary.csv` | 13685113 | 3,257 |

The SITC dataset (`doi:10.7910/DVN/H8SFD2`, also CC0 1.0, version 18.0, time period 1962-01-01 to 2023-12-31 in the metadata) has the same family of files with the `sitc_` prefix and 4-digit products, in decade files from `sitc_country_country_product_year_4_1962_1969.csv` (327,131,834 bytes) to `..._2020_2024.csv` (996,302,792 bytes). The Classifications dataset (`doi:10.7910/DVN/3BAL1O`, CC0 1.0, version 12.0) holds `classification_data_dictionary.csv`, `location_country.csv` (id 13809180, 9,677 bytes), `location_group.csv` (52,345 bytes), `product_hs92.csv` (id 13438093, 837,108 bytes), `product_hs12.csv`, `product_hs22.csv`, `product_sitc.csv` and `product_services_unilateral.csv`.

### File download

Returns the file. The API answers with HTTP 303 to a presigned Amazon S3 URL (`X-Amz-Expires=3600`); the S3 URL accepts GET and `Range` but refuses HEAD.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `{id}` (path) | yes | Numeric file id from the dataset metadata | `13685113` |
| `format` | no | `original` returns the file as deposited | `original` |

```
GET https://dataverse.harvard.edu/api/access/datafile/13685113?format=original
```

### Sample response (Captured 2026-11-15): data dictionary

`hs92_data_dictionary.csv`, 3,257 bytes, untrimmed except that the long `notes` texts for `export_rca`, `eci`, `distance`, `cog`, `coi`, `pci` and `growth_proj` are cut after the first clause.

```csv
column_name,data_type,description,notes
country_id,integer,Numerical country identification code assigned by the Growth Lab,Augmented version of UN M49 codes.
country_iso3_code,string,Three letter country identification code,Augmented version of ISO 3166-1 alpha-3 codes.
partner_country_id,integer,Numerical country identification code assigned by the Growth Lab,Augmented version of UN M49 codes. Values correspond to identical countries as country ID field.
partner_iso3_code,string,Three letter country identification code,Augmented version of ISO 3166-1 alpha-3 codes. ...
product_id,integer,Numerical product ID code assigned by the Growth Lab,Product IDs are valid only within their classification. The same product IDs are used in different classifications to refer to different products.
product_hs92_code,string,Product code using HS 1992,
year,integer,Year of record,
export_value,integer,Export value in current USD,
import_value,integer,Import value in current USD,
global_market_share,float,Global market share,Proportion of a given product a country exports in relation to global exports of that product.
export_rca,float,Revealed Comparative Advantage,"RCA measures whether a country is an exporter of a product ... (RCA > 1)."
eci,float,Economic Complexity Index,"A measure of the knowledge in a society as expressed in the products it makes. ..."
distance,float,Distance,"A country's ability to enter in to a new product. ..."
cog,float,Complexity Opportunity Outlook Gain,"Measures opportunities for future diversification in entering a product, ..."
coi,float,Economic Complexity Opportunity Index,"A measure of how many complex products are near a country's current set of productive capabilities. ..."
diversity,integer,Diversity,A measure of how many different types of products a country is able to make. Sum of the number of products with RCA >= 1.
pci,float,Product Complexity Index,Ranks the diversity and sophistication of the productive know-how required to produce a product. ...
growth_proj,float,Economic Complexity Growth Projection,"A prediction of how much a country will grow over the following 10 years ..."
```

### Sample response (Captured 2026-11-15): first rows of three files

Fetched with `Range: bytes=0-599` (HTTP 206); rows cut at the range end.

`hs92_country_country_product_year_6_2020_2024.csv` (bilateral, HS6):

```csv
country_id,country_iso3_code,partner_country_id,partner_iso3_code,product_id,product_hs92_code,year,export_value,import_value
4,AFG,8,ALB,10037,999999,2024,0,44186
4,AFG,24,AGO,6627,382390,2021,47679,0
4,AFG,24,AGO,8051,690890,2021,2701,0
4,AFG,24,AGO,5255,071332,2022,32665,0
```

`hs92_country_product_year_1.csv` (unilateral, HS section level):

```csv
country_id,country_iso3_code,product_id,product_hs92_code,year,export_value,import_value,global_market_share,distance,cog,pci
4,AFG,1,0,1995,49349742,43907244,0.000116,0.916,1.071,-0.493
4,AFG,1,0,1996,35800111,68127349,8.2e-05,0.925,1.088,-0.521
```

`location_country.csv` (Classifications Data):

```csv
country_id,country_iso3_code,country_name,country_name_short,in_rankings,former_country
533,ABW,Aruba,Aruba,False,False
4,AFG,Afghanistan,Afghanistan,True,False
24,AGO,Angola,Angola,True,False
```

`product_hs92.csv` (Classifications Data, first 900 bytes): columns `product_id,product_hs92_code,product_level,product_name,product_name_short,product_parent_id,product_id_hierarchy,show_feasibility,natural_resource,green_product`; level 1 rows are Atlas sections (`2,1,1,"Vegetables, animals, wood and paper",Agriculture,...`), level 2 rows are HS chapters (`100,01,2,Live animals,...`).

### HEAD on a presigned file URL (Captured 2026-11-15)

```
GET  https://dataverse.harvard.edu/api/access/datafile/13685106?format=original  -> 303 https://dvn-cloud-iqss.s3.amazonaws.com/10.7910/DVN/T4CHWJ/...&X-Amz-Expires=3600&...
HEAD on that S3 URL -> 403 Forbidden (application/xml, empty body)
```

## Fields

Bilateral HS6 files (`hs92_country_country_product_year_6_*.csv`):

| Field | Type | Unit | Description |
|---|---|---|---|
| `country_id`, `partner_country_id` | integer | | Growth Lab country ids (augmented UN M49) |
| `country_iso3_code`, `partner_iso3_code` | string | | Augmented ISO 3166-1 alpha-3 (`USA`) |
| `product_id` | integer | | Growth Lab product id, valid within HS92 only |
| `product_hs92_code` | string | | HS 1992 6-digit code; `999999` is the unspecified-product bucket; keep leading zeros (`071332`) |
| `year` | integer | year | |
| `export_value`, `import_value` | integer | current USD | Reconciled flow from `country` to `partner` (export) and from `partner` to `country` (import) |

Unilateral files add `global_market_share`, `export_rca`, `distance`, `cog`, `pci` (country x product) and `eci`, `coi`, `diversity`, `growth_proj` (country x year); see the data dictionary above. Classification files: `location_country.csv` (`country_id`, `country_iso3_code`, `country_name`, `country_name_short`, `in_rankings`, `former_country`) and `product_hs92.csv` (`product_id`, `product_hs92_code`, `product_level` 1/2/4/6, `product_name`, `product_parent_id`, `product_id_hierarchy`).

## Licence

CC0 1.0 Universal, read today in the `latestVersion.license` block of all three dataset records (`"name":"CC0 1.0","uri":"http://creativecommons.org/publicdomain/zero/1.0"`), with `termsOfAccess` null and `fileAccessRequest` false. The inventory notes that the accompanying Scientific Data article (Nature, 2025, "Tackling Discrepancies in Trade Data") is CC BY-NC-ND, which applies to the article text and not to the Dataverse files. Verdict in the inventory: PASS.

## Overlap with NASA sources

NASA publishes no trade data. These files have no NASA counterpart; the NASA crop-condition sources that sit beside them are NASA Harvest and the GEOGLAM Crop Monitor, NASA POWER (`nasa_power.md`) and the MODIS and HLS vegetation indices (`vegetation_indices.md`).

## Notes

- The dataset metadata declares `timePeriodCovered` 1995-2023 while version 18.0's file names and rows run to 2024 (a 2024 row appears in the first 600 bytes of the 2020-2024 bilateral file).
- `guestbookId` 262 is set on the datasets; the web download dialog shows a guestbook, but the API download endpoint returned the files directly.
- The S3 redirect refuses HEAD; use the `filesize` from the dataset metadata, or a `Range` GET, to size files.
- Bilateral HS6 files are 1.9 to 5.6 GB each; the country x product x year files at 1, 2 and 4 digits (4 to 452 MB) and the product x year files (13 KB to 5.6 MB) are the small entry points.
- Codes are "augmented": the Atlas adds locations and product nodes that are not in the official M49, ISO or HS lists, so the Classifications files are the key to join on.

## Documentation

- Atlas dataverse: https://dataverse.harvard.edu/dataverse/atlas
- HS92 trade data: https://doi.org/10.7910/DVN/T4CHWJ
- SITC Rev. 2 trade data: https://doi.org/10.7910/DVN/H8SFD2
- Classifications Data: https://doi.org/10.7910/DVN/3BAL1O
- Dataverse native API guide: https://guides.dataverse.org/en/latest/api/native-api.html
- Growth Lab method paper (Scientific Data 2025): https://www.nature.com/articles/s41597-025-06488-2
