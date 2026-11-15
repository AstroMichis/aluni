# Insect monitoring and trap datasets (Rothamsted, USDA Ag Data Commons, CIMMYT)

Archived research deposits of insect trap and survey data: the Rothamsted Insect Survey (RIS) suction-trap and light-trap networks in Great Britain (aphid and moth catches since 1964 and aphid first-flight dates with weather covariates), USDA Ag Data Commons trapping datasets from APHIS and state agencies (Mexican fruit fly in Texas, four fruit and vine pests in California, giant African land snail in Florida, non-native scale insects of the United States) and the CIMMYT Research Data Dataverse (wheat rust nurseries and other CGIAR trials). These are static or slowly updated deposits, not live feeds. Licences differ per deposit and two of them conflict with other statements; see Licence.

| | |
|---|---|
| Provider | Rothamsted Research (RIS); USDA National Agricultural Library (Ag Data Commons, on figshare); CIMMYT (Dataverse) |
| Base URL | `https://repository.rothamsted.ac.uk/id/eprint/{id}/` ; `https://api.figshare.com/v2/articles/{id}` ; `https://data.cimmyt.org/api/` |
| Auth | none for Rothamsted and Ag Data Commons; CIMMYT Dataverse search and dataset metadata return HTTP 401 to anonymous API calls |
| Formats | CSV, TXT (Rothamsted); CSV, XLSX, PDF (Ag Data Commons); per dataset (CIMMYT) |
| Coverage | RIS: Great Britain (16 suction traps, light-trap network); Ag Data Commons: Texas, California, Florida, continental US; CIMMYT: international nursery sites |
| Resolution | trap x year or trap x day (RIS); detection records with county but no coordinates (Ag Data Commons, locations removed by agreement) |
| Cadence / latency | archived deposits (RIS deposits 2020-2022; Ag Data Commons 2024-2025); the RIS online database is live |
| Rate limits / quotas | not published |
| Licence | per deposit: CC BY 4.0, CC0, custom terms; see Licence |
| Documentation | https://insectsurvey.com/ ; https://agdatacommons.nal.usda.gov/ ; https://data.cimmyt.org/ |

| Dataset | Record | Licence shown on 2026-11-15 | Files |
|---|---|---|---|
| RIS moth and aphid catch abundance (Bell, Blumgart, Shortall 2020) | eprint 28338, doi:10.23637/rothamsted.975qz | "Available under Creative Commons: Attribution 4.0" | `Readme.txt`, `MothTidy.csv`, `AphidTidy.csv` |
| RIS UK aphid migration percentiles 1965-2018 (Bourhis, Bell, van den Bosch, Milne) | eprint 29351, doi:10.23637/rothamsted.979yv | "Available under Creative Commons: Attribution 4.0" | `aphid_training_dataset.csv` and model outputs |
| RIS Online Database | eprint 32078, doi:10.23637/rothamsted.989y5; live site `https://insectdatabase.rothamsted.ac.uk` | "Full Archive Available under Creative Commons: Attribution 4.0" | HTML archive |
| Raw Mexfly detections (USDA-APHIS-PPQ) | figshare 25212866, doi:10.15482/USDA.ADC/1522303 | `CC0` | `Raw Mexfly detections data v1.csv` 6,760 bytes; data dictionary |
| CDFA trapping distances (California Department of Food and Agriculture) | figshare 24666069, doi:10.15482/USDA.ADC/1522436 | `CC BY 4.0` | `Collected CDFA distances data v1.xlsx` 57,178 bytes; data dictionary |
| FDACS survey distances (Florida Department of Agriculture and Consumer Services) | figshare 24666102, doi:10.15482/USDA.ADC/1522435 | `CC BY 4.0` | `Collected FDACS distances data v1_1.xlsx` 1,691,341 bytes; data dictionary |
| Non-native scale insects of the United States (Schneider, Powell) | figshare 29318378, doi:10.15482/USDA.ADC/29318378.v1 | `CC0` | 13 files: `total_hosts.csv`, `region_intros.csv`, `trade_intro_data.csv`, Tables S1-S4 (PDF), figures, code |
| CIMMYT Research Data | Dataverse `cimmytdatadvn` | per dataset (not readable anonymously today) | 1,055 datasets listed |

## Requests

### Rothamsted repository record

```
GET https://repository.rothamsted.ac.uk/id/eprint/28338/
GET https://repository.rothamsted.ac.uk/id/eprint/29351/
GET https://repository.rothamsted.ac.uk/id/eprint/32078/
```

### Sample response (Captured 2026-11-15)

HTTP 200 HTML (74,899, 60,375 and 51,189 bytes). Text extracted from eprint 28338: "Bell, James, Blumgart, Dan and Shortall, Chris (2020) Rothamsted Insect Survey, Moth and Aphid catch abundance data. 10.23637/rothamsted.975qz [Data Collection] ... This dataset contains Moth and Aphid catch abundance data from the Rothamsted Insect Survey light-trap and suction trap networks. The dataset is a supplement to Bell et al (2020) (https://doi.org/10.1111/icad.12412) ... Readme.txt Documentation Available under Creative Commons: Attribution 4.0 ... MothTidy.csv Data Available under Creative Commons: Attribution 4.0". Eprint 29351 describes "a measure of aphid arrival, the day of 1% detection (D1D), i.e. the Julian day at which 1% of the yearly aphid abundance has been captured" with keywords "Aphidoidea; Phenology; Weather; Land use; Trapping; Pest monitoring". Eprint 32078 says "The Rothamsted Insect Survey (RIS) has been running two trap networks since 1964".

### Rothamsted CKAN

```
GET https://data.rothamsted.ac.uk/api/3/action/package_show?id=uk-aphid-migration-percentiles-covariates
```

Failed on 2026-11-15: the host name `data.rothamsted.ac.uk` did not resolve (DNS `getaddrinfo` error). The repository pages above carry the same records.

### Ag Data Commons record (figshare API)

| Parameter | Required | Description | Example |
|---|---|---|---|
| `{id}` (path) | yes | figshare article id | `25212866` |

```
GET https://api.figshare.com/v2/articles/25212866
POST https://api.figshare.com/v2/articles/search   {"search_for":"FDACS distances data","page_size":3}
```

### Sample response (Captured 2026-11-15)

16,226 bytes; reduced to key fields.

```json
{
  "id": 25212866, "doi": "10.15482/USDA.ADC/1522303", "version": 1,
  "title": "Data from: Quantifying Insect Dispersal Distances from Trapping Detections Data to Predict Delimiting Survey Radii, raw Mexfly data",
  "published_date": "2024-02-15T23:05:38Z", "defined_type_name": "dataset",
  "license": {"value": 2, "name": "CC0", "url": "https://creativecommons.org/publicdomain/zero/1.0/"},
  "authors": [{"full_name": "USDA-APHIS-Plant Protection and Quarantine (PPQ)"}],
  "resource_doi": "10.1111/jen.12940",
  "tags": ["insect detection", "trapping", "rate of spread"],
  "files": [
    {"id": 44529506, "name": "Raw Mexfly detections data v1.csv", "size": 6760, "download_url": "https://ndownloader.figshare.com/files/44529506"},
    {"id": 44529509, "name": "Data Dictionary for Raw Mexfly detections data v1.csv", "size": 27342, "download_url": "https://ndownloader.figshare.com/files/44529509"}],
  "description": "Trapping survey detections data for Mexfly, Anastrepha ludens, with latitudes and longitudes and other spatial identifications removed, to protect private properties from being identified. Data are from Texas, 2016-2019 ..."
}
```

The file itself (`download_url`, HTTP 302 to a signed S3 URL, then 200, `text/csv`) begins:

```csv
Date collected,County Name,Property Type
4/7/2016,Zapata,Residential
4/25/2016,Zapata,Residential
6/3/2016,Webb,Residential
10/3/2016,Cameron,Grove
11/7/2016,Willacy,Dooryard
```

The data dictionary defines `Date collected` ("Day the trap was checked for insects", Date), `County Name` and `Property Type` ("Dooryard, Grove, Port-of-entry, Residential").

The CDFA record covers European grapevine moth (Lobesia botrana, 2011-2013), Japanese beetle (Popillia japonica, 2010-2019), Medfly (Ceratitis capitata, 2015-2019) and Oriental fruit fly (Bactrocera dorsalis, 2015-2019), with coordinates removed per agreement. The FDACS record holds giant African land snail (Lissachatina fulica) detections in Florida 2011-2020. The scale insect record supplements Schneider and Powell (doi:10.1007/s10530-026-03784-9) and covers species, host associations, pest status, introduction rates and economic impact.

### CIMMYT Dataverse

```
GET https://data.cimmyt.org/api/search?q=rust+nursery&type=dataset&per_page=3
GET https://data.cimmyt.org/api/datasets/:persistentId?persistentId=hdl:11529/10548483
GET https://data.cimmyt.org/api/dataverses/cimmytdatadvn
GET https://data.cimmyt.org/api/dataverses/cimmytdatadvn/contents
```

### Sample response (Captured 2026-11-15)

Search: HTTP 401 `{"status":"ERROR","message":"Only authenticated users can perform the requested operation"}`. Dataset metadata: HTTP 401 `{"status":"ERROR","message":"User :guest is not permitted to perform requested action."}`. Dataverse info: HTTP 200, `"name":"CIMMYT Research Data"`, `"description":"Free, open access repository of research studies developed by CIMMYT scientists."`. Contents: HTTP 200, 324,178 bytes, 1,055 datasets and 1 sub-dataverse, each with `persistentUrl` (`https://hdl.handle.net/11529/...`) and `publicationDate` but no licence.

## Fields

### RIS aphid migration (`aphid_training_dataset.csv`, from the record text)

| Field | Type | Unit | Description |
|---|---|---|---|
| Species, trap, year | | | 14 aphid species, suction-trap site, year (881 trap-year samples per the inventory) |
| D1D | integer | Julian day | Day of 1% detection of the yearly catch |
| Weather and land-use covariates | number | | On a 5 km grid (the record cites CORINE land cover) |

Column names were not read; the CSV was not downloaded.

### Ag Data Commons Mexfly detections

| Field | Type | Unit | Description |
|---|---|---|---|
| `Date collected` | date | M/D/YYYY | Trap check date |
| `County Name` | string | | Texas county |
| `Property Type` | string | | Dooryard, Grove, Port-of-entry, Residential |

## Licence

| Dataset | Shown on 2026-11-15 | Inventory | Note |
|---|---|---|---|
| RIS catch abundance (28338) | CC BY 4.0 (repository page) | CC BY 4.0, PASS | Matches |
| RIS aphid migration (29351) | CC BY 4.0 (repository page) | CC0, PASS | Repository now shows CC BY 4.0; attribution required |
| RIS Online Database (32078) | CC BY 4.0 (repository page) | Conflict: RIS evidence to the UK Parliament says CC BY-NC 4.0 | The conflict stands; the Parliament document was not re-read |
| Mexfly, scale insects | CC0 (figshare API) | CC0, PASS | Matches |
| CDFA, FDACS | CC BY 4.0 (figshare API) | CC BY 4.0 / "Creative Commons Attribution", PASS | Matches |
| CIMMYT datasets | not readable anonymously | 953 datasets "Custom Terms" (non-exclusive, non-transferable), 20 CC0 | Treat as custom terms per dataset |

## Overlap with NASA sources

- NASA publishes no insect trap or survey records.
- POWER daily and hourly temperature and humidity (`nasa_power.md`) cover the weather that aphid flight timing and insect degree-day models use, for any trap location and year since 1981 (see `pest_weather_rules.md`).
- MODIS and HLS vegetation indices (`vegetation_indices.md`) and the NLCD and Cropland Data Layer (`nlcd.md`, `cropland_cdl.md`, the latter USDA) describe land use around a trap.

## Notes

- The Ag Data Commons trap datasets have coordinates removed; the finest location is the county (Texas) or none (California, Florida).
- The RIS CKAN host did not resolve; repository pages were used instead.
- CIMMYT's Dataverse refused anonymous search and metadata calls on 2026-11-15, although the web site describes itself as open access; the listing endpoint still works.
- The US National Insect Collection Database (doi:10.15482/USDA.ADC/1327283, US Public Domain per the inventory) and the USFS Region 3 insect and disease survey (forests) were not fetched.

## Documentation

- Rothamsted Insect Survey: https://insectsurvey.com/ ; repository https://repository.rothamsted.ac.uk/
- RIS deposits: https://doi.org/10.23637/rothamsted.975qz ; https://doi.org/10.23637/rothamsted.979yv ; https://doi.org/10.23637/rothamsted.989y5
- Ag Data Commons: https://agdatacommons.nal.usda.gov/ ; figshare API https://docs.figshare.com/
- Trap datasets paper (J. Appl. Entomol.): https://doi.org/10.1111/jen.12940
- CIMMYT Research Data: https://data.cimmyt.org/ ; Dataverse API https://guides.dataverse.org/en/latest/api/
