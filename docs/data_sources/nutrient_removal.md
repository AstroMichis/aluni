# Crop nutrient removal and cropland nutrient balance

Three related sources describe how much nitrogen (N), phosphorus (P) and potassium (K) crops take off a field. The FAOSTAT Cropland Nutrient Balance domain (ESB) gives national annual N, P and K inputs (mineral fertilizer, manure, fixation, deposition, seed), outputs (crop harvest removal, crop residue removal) and losses for 1961-2023. Aramburu-Merlos et al. 2025 (Dryad) is the crop-residue removal dataset that FAO built into ESB from its 2025 release. Ludemann et al. (Dryad) is the global table of crop nutrient concentrations and harvest indices that turns a yield into a removal per tonne. All three are national or per-crop coefficients, not field measurements. FAOSTAT bulk files and Dryad metadata need no key; the FAOSTAT JSON API and Dryad file downloads now require authorization (see Notes).

| | |
|---|---|
| Provider | FAO Statistics Division (FAOSTAT); University of Nebraska-Lincoln and International Fertilizer Association (Aramburu-Merlos); Wageningen University and partners (Ludemann); Dryad (repository) |
| Base URL | `https://bulks-faostat.fao.org/production/` ; `https://faostatservices.fao.org/api/v1/en/` ; `https://datadryad.org/api/v2/` |
| Auth | FAOSTAT bulk ZIPs: none. FAOSTAT JSON API: Authorization header (HTTP 401 "Missing Authorization Header" without one). Dryad metadata: none. Dryad file downloads: bearer token (HTTP 401) |
| Formats | CSV inside ZIP (FAOSTAT); CSV and Markdown (Dryad) |
| Coverage | ESB: 210 countries and regions, 1961-2023. Aramburu-Merlos: 158 crops, 210 countries, 1961-2023. Ludemann: crop items by world region |
| Resolution | country x year (ESB, Aramburu-Merlos); crop x region coefficient (Ludemann) |
| Cadence / latency | ESB updated 2025-12-05 (bulk listing `DateUpdate`); Aramburu-Merlos v5 2025-12-16; Ludemann v17 2026-11-10 |
| Rate limits / quotas | not published |
| Licence | FAOSTAT: CC BY 4.0 with FAO database terms. Aramburu-Merlos and Ludemann: CC0 1.0 |
| Documentation | https://www.fao.org/faostat/en/#data/ESB ; https://doi.org/10.5061/dryad.mgqnk99d1 ; https://doi.org/10.5061/dryad.n2z34tn0x |

| Dataset | Record | Licence returned | Files |
|---|---|---|---|
| FAOSTAT Cropland Nutrient Balance (ESB) | bulk `Environment_Cropland_nutrient_budget_E_All_Data_(Normalized).zip` | CC BY 4.0 per FAO terms (not in the file) | 7,987,630-byte ZIP with the data CSV (103.6 MB, 827,796 rows) and four code lists |
| Aramburu-Merlos et al. 2025, "Global dataset on nutrient removal with crop residues" | Dryad doi:10.5061/dryad.mgqnk99d1, version 5 | `https://spdx.org/licenses/CC0-1.0.html` | `crop_residue_coefficients.csv` 21,710; `Nutrient_removal_with_crop_residue.csv` 3,909,855; `README.md` 5,382 bytes |
| Ludemann et al., "Global data on crop nutrient concentration and harvest indices" | Dryad doi:10.5061/dryad.n2z34tn0x, version 17 | `https://spdx.org/licenses/CC0-1.0.html` | 11 files incl. `Combined_crop_data.csv` 40,905,094; `Tier_1_and_2_crop_coefficients.csv` 289,394; `World_crop_coefficients_for_UN_FAO.csv` 10,828; `README.md` 10,276 bytes |

## Requests

### FAOSTAT bulk dataset list

Lists every FAOSTAT domain with its bulk file URL, size and update date.

```
GET https://bulks-faostat.fao.org/production/datasets_E.json
```

### Sample response (Captured 2026-11-15)

106,151 bytes, 69 datasets, `last-modified: Fri, 13 Nov 2026 14:49:38 GMT`. Trimmed to the ESB entry and selected fields.

```json
{"Datasets": {"Dataset": [
  {"DatasetCode": "ESB", "DatasetName": "Land, Inputs and Sustainability: Cropland Nutrient Balance",
   "DateUpdate": "2025-12-05T00:00:00",
   "FileLocation": "https://bulks-faostat.fao.org/production/Environment_Cropland_nutrient_budget_E_All_Data_(Normalized).zip",
   "FileSize": "7801KB", "FileRows": 827796}
]}}
```

### FAOSTAT ESB bulk file

```
GET https://bulks-faostat.fao.org/production/Environment_Cropland_nutrient_budget_E_All_Data_(Normalized).zip
```

### Sample response (Captured 2026-11-15)

HTTP 200, `application/x-zip-compressed`, 7,987,630 bytes, `last-modified: Fri, 05 Dec 2025`. Archive contents:

```
103556950  Environment_Cropland_nutrient_budget_E_All_Data_(Normalized).csv
     5469  Environment_Cropland_nutrient_budget_E_AreaCodes.csv
      334  Environment_Cropland_nutrient_budget_E_Elements.csv
      133  Environment_Cropland_nutrient_budget_E_Flags.csv
      289  Environment_Cropland_nutrient_budget_E_ItemCodes.csv
```

Rows for the United States of America (area code 231, M49 840), year 2022, selected from the data CSV (the header is the first line; 13 of the 46 US 2022 rows shown):

```csv
Area Code,Area Code (M49),Area,Item Code,Item,Element Code,Element,Year Code,Year,Unit,Value,Flag,Note
"231","'840","United States of America","5087","Mineral fertilizers","7276","Cropland nitrogen per unit area","2022","2022","kg/ha","60.560500","E",
"231","'840","United States of America","5089","Manure applied","7276","Cropland nitrogen per unit area","2022","2022","kg/ha","10.224300","E",
"231","'840","United States of America","5078","Biological fixation","7276","Cropland nitrogen per unit area","2022","2022","kg/ha","47.322500","E",
"231","'840","United States of America","5076","Atmospheric deposition","7276","Cropland nitrogen per unit area","2022","2022","kg/ha","7.353100","E",
"231","'840","United States of America","5079","Input","7276","Cropland nitrogen per unit area","2022","2022","kg/ha","127.138600","E",
"231","'840","United States of America","5077","Crop harvest removal","7276","Cropland nitrogen per unit area","2022","2022","kg/ha","85.454200","E",
"231","'840","United States of America","5077","Crop harvest removal","7281","Cropland phosphorus per unit area","2022","2022","kg/ha","14.361800","E",
"231","'840","United States of America","5077","Crop harvest removal","7283","Cropland potassium per unit area","2022","2022","kg/ha","29.203200","E",
"231","'840","United States of America","5088","Crop residue removal","7276","Cropland nitrogen per unit area","2022","2022","kg/ha","11.596400","E",
"231","'840","United States of America","5088","Crop residue removal","7283","Cropland potassium per unit area","2022","2022","kg/ha","22.066700","E",
"231","'840","United States of America","5082","Leaching","7276","Cropland nitrogen per unit area","2022","2022","kg/ha","7.952400","E",
"231","'840","United States of America","5083","Volatilisation","7276","Cropland nitrogen per unit area","2022","2022","kg/ha","20.789800","E",
"231","'840","United States of America","5087","Mineral fertilizers","7275","Cropland nitrogen","2022","2022","t","9370781.200000","E",
```

Other area codes in `AreaCodes.csv`: Kenya `114,'404`, Mexico `138,'484`.

### FAOSTAT JSON API (ESB dimensions)

```
GET https://faostatservices.fao.org/api/v1/en/definitions/domain/ESB/element
GET https://faostatservices.fao.org/api/v1/en/definitions/domain/ESB/item
```

### Sample response (Captured 2026-11-15)

HTTP 401 from CloudFront for both, body `Missing Authorization Header` (28 bytes). The code lists below come from the bulk ZIP instead. See `faostat.md` for the API's token requirement.

### Dryad dataset metadata

| Parameter | Required | Description | Example |
|---|---|---|---|
| `{doi}` (path) | yes | URL-encoded DOI | `doi%3A10.5061%2Fdryad.mgqnk99d1` |

```
GET https://datadryad.org/api/v2/datasets/doi%3A10.5061%2Fdryad.mgqnk99d1
```

### Sample response (Captured 2026-11-15)

3,621 bytes. Trimmed: `_links` reduced, author emails and ROR ids removed.

```json
{
  "identifier": "doi:10.5061/dryad.mgqnk99d1", "id": 174650,
  "title": "Global dataset on nutrient removal with crop residues",
  "storageSize": 3936947, "versionNumber": 5, "publicationDate": "2025-12-16",
  "license": "https://spdx.org/licenses/CC0-1.0.html",
  "authors": [
    {"firstName": "Fernando", "lastName": "Aramburu-Merlos", "affiliation": "University of Nebraska-Lincoln"},
    {"firstName": "Fatima", "lastName": "Tenorio", "affiliation": "University of Nebraska-Lincoln"},
    {"firstName": "Ya Li", "lastName": "Lim", "affiliation": "University of Nebraska-Lincoln"},
    {"firstName": "Walter", "lastName": "Carciochi", "affiliation": "University of Nebraska-Lincoln"},
    {"firstName": "Achim", "lastName": "Dobermann", "affiliation": "International Fertilizer Association"},
    {"firstName": "Patricio", "lastName": "Grassini", "affiliation": "University of Nebraska-Lincoln"}],
  "keywords": ["Nitrogen", "Phosphorus", "Potassium", "Crop nutrient", "crop residue management"],
  "abstract": "<p>This dataset provides global, annual estimates of how much nitrogen, phosphorus, and potassium are removed from cropland through the off-field removal of crop residues. It covers 210 countries from 1961 to 2023, based on information from official statistics, expert knowledge, and published sources. The dataset has been integrated into the FAO Cropland Nutrient Balance Database as of the 2025 release ...</p>",
  "_links": {"stash:version": {"href": "/api/v2/versions/414282"}, "stash:download": {"href": "/api/v2/datasets/doi%3A10.5061%2Fdryad.mgqnk99d1/download"}}
}
```

The Ludemann record (`doi%3A10.5061%2Fdryad.n2z34tn0x`, 16,280 bytes) returned `license` `https://spdx.org/licenses/CC0-1.0.html`, `versionNumber` 17, `publicationDate` `2026-11-10`, `storageSize` 41,328,385, seven authors (Ludemann, Hijbeek, van Loon, Murrell, Wang, Dobermann, van Ittersum) and `relatedWorks` including `https://www.fao.org/faostat/en/#data/ESB`, the primary article doi:10.5194/essd-16-525-2024 and code at `https://github.com/ludemannc/Tier_1_2_crop_coefficients.git`.

### Dryad file list (per version)

`/datasets/{doi}/files` returned HTTP 404; the file list is served per version.

```
GET https://datadryad.org/api/v2/versions/414282/files
```

### Sample response (Captured 2026-11-15)

2,109 bytes, `count` 3. Reduced to path, size and type:

```
crop_residue_coefficients.csv            21710  text/csv  /api/v2/files/4513686/download
Nutrient_removal_with_crop_residue.csv 3909855  text/csv  /api/v2/files/4513685/download
README.md                                 5382  text/markdown  /api/v2/files/4513689/download
```

### Dryad file download

```
GET https://datadryad.org/api/v2/files/4513686/download
```

### Sample response (Captured 2026-11-15)

HTTP 401, `{"error":"Unauthorized, must have current bearer token"}`. The web route `https://datadryad.org/downloads/file_stream/4513686` returned HTTP 403 to a script. The whole-dataset ZIP (`/datasets/{doi}/download`) also returned 401. File contents were therefore not read.

## Fields

### FAOSTAT ESB (normalized CSV)

| Field | Type | Unit | Description |
|---|---|---|---|
| `Area Code`, `Area Code (M49)`, `Area` | integer, string | | FAOSTAT area code, UN M49 code (prefixed with `'`), name |
| `Item Code`, `Item` | integer, string | | Budget component: 5087 Mineral fertilizers, 5089 Manure applied, 5078 Biological fixation, 5076 Atmospheric deposition, 5086 Seed, 5079 Input, 5077 Crop harvest removal, 5088 Crop residue removal, 5080 Outputs, 5082 Leaching, 5083 Volatilisation, 5081 Nutrient balance |
| `Element Code`, `Element` | integer, string | | 7275/7276 nitrogen (total, per area), 7280/7281 phosphorus, 7282/7283 potassium, 7290/7291/7292 use efficiency |
| `Year Code`, `Year` | integer | | 1961-2023 |
| `Unit` | string | | `t`, `kg/ha`, `%` |
| `Value` | number | per `Unit` | |
| `Flag` | string | | A official, E estimated, I imputed, X external |
| `Note` | string | | |

### Dryad datasets

File columns were not read because downloads require a token. From the record abstracts: Aramburu-Merlos gives country x year residue N, P, K removal (`Nutrient_removal_with_crop_residue.csv`) and per-crop residue coefficients (`crop_residue_coefficients.csv`). Ludemann gives nutrient concentrations of crop products and residues and harvest indices per crop item and region (`Tier_1_and_2_crop_coefficients.csv`, `World_crop_coefficients_for_UN_FAO.csv`), with the observations they derive from in `Combined_crop_data.csv` and column dictionaries in the `Meta_data_*.csv` files.

## Licence

| Dataset | Licence | Where read | Notes |
|---|---|---|---|
| FAOSTAT ESB | CC BY 4.0 under the FAO Statistical Database Terms of Use, which also bar use "in conjunction with the promotion of a commercial enterprise" | from the inventory, not re-read | See `faostat.md` |
| Aramburu-Merlos 2025 | CC0 1.0 (`license` field) | Dryad API, re-read 2026-11-15 | The inventory inferred CC0 from Dryad platform policy; the API states it explicitly |
| Ludemann | CC0 1.0 (`license` field) | Dryad API, re-read 2026-11-15 | Matches the inventory |
| OMAFRA crop removal values (fieldcropnews.com) | unknown | not fetched (see Notes) | The inventory quotes wheat 19.1-20.9 kg N, 9.1-10.4 kg P2O5 and 5.78-6.22 kg K2O per tonne; grain corn 11.5-17.7 kg N/t; soybean 62.3-66.7 kg N/t, and says to cite rather than copy |

## Overlap with NASA sources

- NASA publishes no nutrient concentration, removal or nutrient balance tables.
- NASA serves the yield-side drivers only: POWER weather and soil wetness (`nasa_power.md`), MODIS and HLS vegetation indices (`vegetation_indices.md`) and GEDI biomass (`gedi.md`).
- Removal per field needs a yield, which comes from the farmer or from NASS QuickStats county yields (`nass_quickstats.md`), multiplied by these coefficients.

## Notes

- The FAOSTAT JSON API at `faostatservices.fao.org` answered HTTP 401 "Missing Authorization Header" to keyless requests on 2026-11-15; the bulk files at `bulks-faostat.fao.org` remain open.
- Dryad v2 now requires a bearer token for file downloads, including CC0 files. Metadata and file lists stay public. Dryad documents OAuth client credentials for API accounts at https://github.com/datadryad/dryad-app/blob/main/documentation/apis/README.md (not fetched).
- The OMAFRA page `https://fieldcropnews.com/2025/05/crop-removal-values/` was not fetched in this pass: the request was blocked by the session's permission policy.
- ESB values carry flag `E` (estimated) for the United States in 2022.

## Documentation

- FAOSTAT Cropland Nutrient Balance: https://www.fao.org/faostat/en/#data/ESB
- FAOSTAT bulk list: https://bulks-faostat.fao.org/production/datasets_E.json
- Aramburu-Merlos et al. 2025: https://doi.org/10.5061/dryad.mgqnk99d1
- Ludemann et al. 2024, Earth System Science Data 16:525: https://doi.org/10.5194/essd-16-525-2024 ; data https://doi.org/10.5061/dryad.n2z34tn0x
- Dryad API: https://datadryad.org/api/v2/docs
- OMAFRA crop removal values: https://fieldcropnews.com/2025/05/crop-removal-values/
