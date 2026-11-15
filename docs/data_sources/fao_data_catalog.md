# FAO Hand-in-Hand data catalog: fall armyworm and desert locust

The FAO Hand-in-Hand (HiH) data catalog is a CKAN catalogue of FAO datasets. Each record carries a licence and links to resources, and many resources are "smart-csv" links: an FAO endpoint (`api.data.apps.fao.org/api/v2/bigquery`) that runs a SQL query against FAO's BigQuery tables and streams CSV, with no key. Two pest records are relevant here: the Fall Armyworm Monitoring and Early Warning System (FAMEWS) trap totals, which hold pheromone-trap counts with coordinates and dates entered by FAMEWS app users in Africa and Asia, and the Desert Locust observations from FAO's Desert Locust Information Service (adults, hoppers, bands, swarms, control). A CC0 extract of FAMEWS scouting and trap data (Niassy et al.) is on Zenodo. The licences shown by the catalogue on 2026-11-15 differ from the inventory and from FAO's Locust Hub; see Licence.

| | |
|---|---|
| Provider | FAO (Hand-in-Hand platform; FAMEWS; Desert Locust Information Service) |
| Base URL | catalog `https://data.apps.fao.org/catalog/api/3/action/` ; query endpoint `https://api.data.apps.fao.org/api/v2/bigquery` |
| Auth | none |
| Formats | JSON (CKAN); CSV (smart-csv and static extracts); SQL (query templates); JSON-stat (dimension schemas, served gzip-compressed) |
| Coverage | FAMEWS: 54 countries listed in the schema (Africa, Near East, South and Southeast Asia); Desert Locust: recession and invasion area, Africa to India |
| Resolution | point (trap or survey site, lat/lon) with date |
| Cadence / latency | FAMEWS and locust views are live tables; the locust static extracts are 2020 files |
| Rate limits / quotas | not published |
| Licence | per record, see Licence: FAMEWS traps and Desert Locust observations show CC BY 4.0 in the catalogue; the Fall Armyworm map layer shows CC BY-NC-SA 4.0; the FPMA record shows "License not specified" |
| Documentation | https://data.apps.fao.org/catalog/ ; https://docs.ckan.org/en/latest/api/ |

## Requests

### CKAN package_show

| Parameter | Required | Description | Example |
|---|---|---|---|
| `id` | yes | Dataset name or id | `fall-armyworm-traps-famews-global-latlon` |

```
GET https://data.apps.fao.org/catalog/api/3/action/package_show?id=fall-armyworm-traps-famews-global-latlon
GET https://data.apps.fao.org/catalog/api/3/action/package_show?id=desert-locusts-observations
GET https://data.apps.fao.org/catalog/api/3/action/package_show?id=fall-armyworm
GET https://data.apps.fao.org/catalog/api/3/action/package_show?id=domestic-market-prices-fpma
```

### Sample response (Captured 2026-11-15)

FAMEWS record, 6,052 bytes. Trimmed to licence, dates and resources; `notes` cut.

```json
{"success": true, "result": {
  "name": "fall-armyworm-traps-famews-global-latlon",
  "title": "Fall armyworm traps totals (Global) - FAMEWS",
  "license_id": "CC-BY-4.0", "license_title": "Creative Commons Attribution 4.0 International",
  "maintainer": "FAO HiH", "maintainer_email": "fao-data@fao.org",
  "metadata_created": "2022-02-16T16:10:44.851732", "metadata_modified": "2026-07-14T21:04:27.828083",
  "organization": {"title": "Food and Agriculture Organization of the United Nations"},
  "notes": "Fall Armyworm Traps totals (Trap level) Traps data are sourced by the __FAMEWS global platform__, which is an online resource for mapping data collected by the FAMEWS mobile app whenever fields are scouted or pheromone traps are checked for FAW ...",
  "resources": [
    {"name": "Fall Armyworm Traps totals", "format": "smart-csv", "url": "https://api.data.apps.fao.org/api/v2/bigquery?sql_url=https://data.apps.fao.org/catalog/dataset/13a9fda3-7f3e-4e6d-86aa-13e8c73cc0e4/resource/45c0e0ce-4581-42df-8c71-d550da9e28dd/download/famews-date-periods-traps-lat-lon-query.sql"},
    {"name": "famews-date-periods-schema.", "format": "JSON", "url": "https://data.apps.fao.org/catalog/dataset/13a9fda3-.../download/famews-date-periods-schema.json"},
    {"name": "famews-date-periods-traps-lat-lon-query", "format": "application/x-sql", "url": "https://data.apps.fao.org/catalog/dataset/13a9fda3-.../download/famews-date-periods-traps-lat-lon-query.sql"}]
}}
```

The other three records (licence, then resources, as returned):

| Record | `license_title` | `metadata_modified` | Resources |
|---|---|---|---|
| `desert-locusts-observations` | Creative Commons Attribution 4.0 International | 2026-07-14 | 26: smart-csv queries, `adults_2020.csv`, `hoppers_2020.csv`, `bands_2020.csv`, `swarms_2020.csv`, last 1/3/6-month views for adults, hoppers, bands, swarms and control, a TerriaJS map config |
| `fall-armyworm` (Crops - Plant Pests and Diseases) | Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International | 2026-07-13 | 1 TerriaJS map group |
| `domestic-market-prices-fpma` | License not specified | 2021-10-10 | a TerriaJS group and an image (see `fao_fpma.md` for the FPMA API) |

### FAMEWS query template

The smart-csv resource points at this SQL, which takes two named parameters.

```
GET https://data.apps.fao.org/catalog/dataset/13a9fda3-7f3e-4e6d-86aa-13e8c73cc0e4/resource/45c0e0ce-4581-42df-8c71-d550da9e28dd/download/famews-date-periods-traps-lat-lon-query.sql
```

### Sample response (Captured 2026-11-15)

956 bytes, untrimmed except for the last two periods.

```sql
SELECT *
FROM `fao-maps-review.fao_famews.vw_traps_lat_lon`
where (@dim_country = 'All Countries' or country=@dim_country) and
      (
       (@period = "l1w" and date >= date_add(DATE_TRUNC(current_date(), WEEK(SUNDAY)), interval -7 day) and date <= DATE_TRUNC(current_date(), WEEK(SUNDAY))) OR
       (@period = "l1m" and date >= date_add(DATE_TRUNC(current_date(), month), interval -1 month) and date < DATE_TRUNC(current_date(), month)) OR
       ...
       (@period = "all")
      )
      and ifnull(id,'') <> ''
```

The JSON-stat schema (`famews-date-periods-schema.json`, 1,236 bytes gzip-compressed) defines `period` values `l1w`, `l1m`, `l3m`, `l6m`, `l1y`, `all` and `dim_country` values for 54 countries plus "All Countries" (Algeria to Zimbabwe, including Bangladesh, India, Indonesia, Kenya, Nepal, Pakistan, Philippines, Sri Lanka, Thailand).

### BigQuery CSV endpoint

`query` takes SQL directly; `sql_url` takes a catalogued SQL file plus its parameters.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `query` | one of | URL-encoded SQL against FAO's public views | see below |
| `sql_url` | one of | URL of a catalogued `.sql` template | the FAMEWS template |

```
GET https://api.data.apps.fao.org/api/v2/bigquery?query=SELECT+*+FROM+%60fao-maps-review.fao_famews.vw_traps_lat_lon%60+WHERE+country%3D%27Kenya%27+ORDER+BY+date+DESC+LIMIT+3
```

### Sample response (Captured 2026-11-15)

HTTP 200, `text/csv`, 467 bytes, untrimmed. Kenya is the non-US example (FAMEWS has no US data).

```csv
id,date,region,sub_region,country,district,village,lat,long,faw_confirmed_count,faw_suspected_count,faw_suspected_plus_confirmed_count,other_species_count
7139,2022-03-01,Africa,Sub-Saharan Africa,Kenya,Nairobi,Nairobi,-1.219761,36.885932,0.0,0.0,0.0,0.0
Ke ooo149,2020-08-22,Africa,Sub-Saharan Africa,Kenya,Makueni,Ngosini east,-1.8079,37.7475,0.0,0.0,0.0,0.0
Ke 000149,2020-08-22,Africa,Sub-Saharan Africa,Kenya,Makueni,Ngosini east,-1.8039,37.7475,0.0,0.0,0.0,0.0
```

The most recent Kenyan trap row is dated 2022-03-01. The last-month locust view failed on both a column-list and a `SELECT *` query with HTTP 400: `"Unrecognized name: category; failed to parse view 'fao-maps-review.fao_locusts.Swarm_last_month'"` (the view definition is broken on FAO's side).

### Desert Locust static extract

```
GET https://data.apps.fao.org/catalog/dataset/088f29ea-6e33-4e9c-8779-9b64dd2450b0/resource/d9843236-6f85-4f58-a8a5-bde3d2c4fd24/download/adults_2020.csv
```

### Sample response (Captured 2026-11-15)

The server ignored the requested byte range and returned 2,171,552 bytes (`last-modified: Wed, 15 Jul 2020`). 152 columns; first 20 columns of the header and two rows:

```csv
Lon,Lat,FID,Observation Date,TmSTARTDAT,FINISHDATE,TmFINISHDA,EXACTDATE,PARTMONTH,Location Name,Impacted Area (ha),Location Reliability,Country ISO2 Code,Locust ID,Report ID,ACOMMENT,LOCPRESENT,SPECIESQRY,CONFIRMATN,BREEDING
72.49833333300010,28.64944444400000,100072,2020/01/24 00:00:00,07:49,2020/01/24 00:00:00,07:49,No,Late,10-11 SSM,100,Exact,IN,432433,RAMSES38_IND20-06.XL,Gregarious appearing,1,0,1,2
72.48083333300010,28.62305555600010,100073,2020/01/24 00:00:00,07:52,2020/01/24 00:00:00,07:52,No,Late,28 KJD,100,Exact,IN,432434,RAMSES38_IND20-06.XL,Gregarious appearing,1,0,1,2
```

The remaining columns are density, maturity, colour and phase codes for solitarious and gregarious hoppers and adults (`SHP*`, `GHP*`, `SAD*`, `GAD*`) and control fields.

### Niassy et al. FAMEWS extract (Zenodo)

```
GET https://zenodo.org/api/records/4737393
```

### Sample response (Captured 2026-11-15)

24,241 bytes; reduced to key fields. `doi` `10.5061/dryad.9kd51c5gg` (the Zenodo record mirrors the Dryad deposit), `title` "Bioecology of fall armyworm Spodoptera frugiperda (J. E. Smith), its management and potential patterns of seasonal spread in Africa", `publication_date` 2021-05-13, `"license": {"id": "cc-zero"}`, twelve creators led by Saliou Niassy (icipe), one file `Niassy_et_al_FAMEWS_Plos.xlsx` of 585,584 bytes. The description says the data come from a community-based initiative in Ethiopia, Kenya, Tanzania, Uganda, Rwanda and Burundi in which "Over 650 Community Focal Persons" recorded adult moths, crop phenology, cropping systems and management with the FAMEWS app.

## Fields

### FAMEWS traps view (`vw_traps_lat_lon`)

| Field | Type | Unit | Description |
|---|---|---|---|
| `id` | string | | Trap id as entered by the user (free text; `Ke ooo149` and `Ke 000149` both appear) |
| `date` | date | | Trap check date |
| `region`, `sub_region`, `country`, `district`, `village` | string | | Location names |
| `lat`, `long` | number | degrees | Trap position |
| `faw_confirmed_count`, `faw_suspected_count`, `faw_suspected_plus_confirmed_count` | number | moths per check | Fall armyworm catches |
| `other_species_count` | number | | Non-target catches |

### Desert Locust extracts (main columns)

| Field | Type | Unit | Description |
|---|---|---|---|
| `Lon`, `Lat` | number | degrees | Survey point |
| `Observation Date`, `FINISHDATE` | datetime | | Start and end |
| `Location Name`, `Country ISO2 Code` | string | | |
| `Impacted Area (ha)` | number | ha | |
| `Location Reliability` | string | | `Exact`, ... |
| `Locust ID`, `Report ID` | | | Source identifiers (RAMSES reports) |
| `LOCPRESENT`, `BREEDING`, `CONFIRMATN` | code | | Presence, breeding, confirmation flags |

## Licence

| Record | Catalogue licence on 2026-11-15 | Inventory | Other evidence |
|---|---|---|---|
| FAMEWS traps totals | CC BY 4.0 | CC BY 3.0 IGO (PASS) | Still an attribution licence; verdict unchanged |
| Desert Locusts Observations | CC BY 4.0 | CC BY 3.0 IGO, in conflict with the Locust Hub ("non-commercial products or services") and the Desert Locust Bulletins ("research and other non-commercial purposes") | The Locust Hub page (`https://locust-hub-hqfao.hub.arcgis.com/`, HTTP 200) is script-rendered and its terms text was not in the HTML fetched today, so the conflict was not re-checked. It stays a conflict |
| Fall Armyworm map layer | CC BY-NC-SA 4.0 | CC BY-NC-SA 3.0 IGO (FAIL) | Still non-commercial |
| FPMA domestic prices | "License not specified" | CC BY 4.0 per FAO database terms, with third-party exception | See `fao_fpma.md` |
| Niassy FAMEWS extract | CC0 (`cc-zero`, Zenodo) | CC0 (PASS) | Matches |

The FAO Statistical Database Terms of Use (see `faostat.md`) also apply to FAO datasets.

## Overlap with NASA sources

- NASA publishes no pest trap, scouting or locust survey data.
- POWER daily temperature (`nasa_power.md`) supplies the degree-day inputs for fall armyworm development thresholds (`pest_weather_rules.md`) at each trap point.
- SMAP soil moisture (`smap.md`) and IMERG rainfall (`gpm_imerg.md`) cover the soil-wetness and rain conditions that the locust forecasting literature links to breeding; no rule for that was verified (see `pest_weather_rules.md`).
- MODIS and HLS vegetation indices (`vegetation_indices.md`) show green vegetation in locust habitats.

## Notes

- FAMEWS has no data for the United States.
- `famews-date-periods-schema.json` is served gzip-compressed without a `Content-Encoding` header; decompress it before parsing.
- The static locust CSV endpoint ignores `Range` and returns the whole file.
- The last-month, 3-month and 6-month locust views behind the catalogue's smart-csv links returned HTTP 400 on 2026-11-15 because the view references a missing column.

## Documentation

- FAO HiH data catalog: https://data.apps.fao.org/catalog/
- FAMEWS traps record: https://data.apps.fao.org/catalog/dataset/fall-armyworm-traps-famews-global-latlon
- Desert Locust record: https://data.apps.fao.org/catalog/dataset/desert-locusts-observations
- FAMEWS platform: https://sti-portal.fao.org/innovations/fall-armyworm-monitoring-and-early-warning-system-famews
- FAO Locust Hub: https://locust-hub-hqfao.hub.arcgis.com/
- Niassy et al.: https://zenodo.org/records/4737393 ; https://doi.org/10.5061/dryad.9kd51c5gg
- CKAN API: https://docs.ckan.org/en/latest/api/
