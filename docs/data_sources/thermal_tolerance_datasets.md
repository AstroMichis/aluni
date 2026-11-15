# Thermal tolerance and development parameters (GlobTherm, Togashi cardinal temperatures, DDRP)

Species-level temperature parameters published as open research datasets. GlobTherm (Bennett et al. 2018, Dryad, CC0) lists experimentally derived upper and lower thermal limits for 2,133 species of algae, plants, fungi and animals with the collection site of the assayed individuals; its 2019 extension (Sunday et al. 2019, Dryad, CC0) corrects errors and adds methodological covariates and the extreme air temperatures at each site. The Togashi dataset (Chaloner, Gurr and Bebber 2020, Dryad, CC0) digitizes the minimum, optimum and maximum temperatures of growth, spore germination, infection, sporulation and disease development for 695 plant-associated fungi and oomycetes from Togashi's 1949 compilation, with the disease and host plant named. The DDRP parameter files (Barker et al., Zenodo, CC BY 4.0) are the stage-specific lower and upper development thresholds, degree-day requirements and cold and heat stress limits used by USDA APHIS's Degree-Days, Risk and Phenological event mapping platform for four invasive insects. All four are static files reached through repository APIs (Dryad, Zenodo); none has a spatial or temporal dimension beyond the collection coordinates in GlobTherm.

| | |
|---|---|
| Provider | iDiv and co-authors (GlobTherm); University of Exeter (Togashi dataset); Oregon State University IPPC and USDA APHIS (DDRP), each via Dryad or Zenodo |
| Base URL | Dryad API `https://datadryad.org/api/v2/datasets/{doi}`; Zenodo API `https://zenodo.org/api/records/{id}` |
| Auth | Repository metadata: none. Dryad file downloads through `/api/v2/files/{id}/download` need a bearer token (HTTP 401) and the web `file_stream` URL returned HTTP 403 to a scripted client; Zenodo file downloads: none |
| Formats | CSV, XLSX (data); R `.params` text files (DDRP); JSON (repository metadata) |
| Coverage | global, species-level; GlobTherm 2,133 species in 43 classes, 203 orders, 525 families; Togashi 695 microbes (631 fungi, 64 oomycetes); DDRP 4 insect species |
| Resolution | one row per species (GlobTherm) or per species x process x cardinal temperature (Togashi); one file per species (DDRP) |
| Cadence / latency | static publications: GlobTherm 2019-01-26 (Dryad), extension 2019-06-18 (v2), Togashi 2020-06-16 (v4), DDRP 2020-05-18 to 2025-05-28 |
| Rate limits / quotas | Zenodo API returned `x-ratelimit-limit: 133` per minute window on each response; Dryad not published |
| Licence | GlobTherm and extension: CC0 1.0; Togashi: CC0 1.0 (Dryad API `license` field); DDRP records 15538509, 4110732, 8018595, 3832732: CC BY 4.0 (Zenodo `license.id`). See Licence |
| Documentation | https://doi.org/10.1038/sdata.2018.22 ; https://doi.org/10.1098/rstb.2019.0036 ; https://doi.org/10.1038/s41467-020-16778-5 ; https://doi.org/10.1371/journal.pone.0244005 |

| Dataset | Repository record | Data files | Licence (as read today) |
|---|---|---|---|
| GlobTherm | Dryad doi:10.5061/dryad.1cv08 (v1, 884,252 bytes); Zenodo mirror 4976423 | `GlobalTherm_upload_02_11_17.csv` 354,036 bytes; `GlobalTherm_upload_10_11_17.xlsx` 258,166; `References_1_09_2017.xlsx` 136,025 | `https://spdx.org/licenses/CC0-1.0.html` (Dryad); `cc-zero` (Zenodo) |
| Thermal tolerance across latitude and elevation (GlobTherm 2019 extension) | Dryad doi:10.5061/dryad.5002200 (v2, 928,858 bytes) | `globtherm_full_dataset_2019.csv` 464,429 bytes | CC0-1.0 |
| Fungal and Oomycete cardinal temperatures (Togashi dataset) | Dryad doi:10.5061/dryad.tqjq2bvw6 (v4, 2,424,892 bytes) | `Supplementary_Data_Togashi_FINAL.csv` 2,424,892 bytes | CC0-1.0 |
| DDRP spotted lanternfly (Lycorma delicatula) | Zenodo 15538509 (v1, 2025-05-28) | `SLF.params` 2,612 bytes; `DDRP_v3.R` 109,093; `DDRP_v3_funcs.R` 97,913 | cc-by-4.0 |
| DDRP light brown apple moth and small tomato borer | Zenodo 4110732 (v2 of concept 3832731, 2020-05-18); v1 is 3832732 | `LBAM.params` 2,968; `STB.params` 2,502; `DDRP_v2.R`; `DDRP_v2_funcs.R`; user guide PDF 466,984 | cc-by-4.0 |
| DDRP emerald ash borer (Agrilus planipennis) | Zenodo 8018595 (2023-06-08) | `EAB.params` 2,540; `DDRP_v2.R`; `DDRP_v2_funcs.R` | cc-by-4.0 |

## Requests

### Dryad dataset metadata

| Parameter | Required | Description | Example |
|---|---|---|---|
| `{doi}` (path) | yes | URL-encoded DOI with `doi:` prefix | `doi%3A10.5061%2Fdryad.tqjq2bvw6` |

```
GET https://datadryad.org/api/v2/datasets/doi%3A10.5061%2Fdryad.tqjq2bvw6
GET https://datadryad.org/api/v2/versions/69468/files
```

The dataset record links its current version (`_links["stash:version"]`); `/api/v2/versions/{id}/files` lists the files. (`/api/v2/datasets/{doi}/files` returned HTTP 404.)

### Sample response (Captured 2026-11-15)

Togashi dataset record, 25,824 bytes. Trimmed to identifiers, licence, authors and the start of the abstract; `usageNotes` (the column dictionary, 4,300 characters) is summarized in Fields.

```json
{"identifier": "doi:10.5061/dryad.tqjq2bvw6", "title": "Fungal and Oomycete cardinal temperatures (the Togashi dataset)",
 "license": "https://spdx.org/licenses/CC0-1.0.html", "versionNumber": 4, "versionStatus": "submitted",
 "publicationDate": "2020-06-16", "lastModificationDate": "2020-06-16", "storageSize": 2424892, "relatedPublicationISSN": "2041-1723",
 "authors": [{"firstName": "Daniel", "lastName": "Bebber"}, {"firstName": "Thomas", "lastName": "Chaloner"}, {"firstName": "Sarah", "lastName": "Gurr"}],
 "keywords": ["Plant pathology", "Oomycota", "Phytophthora", "Fusarium spp.", "Plant pathogens", "Fungal Plant Pathogen", "cardinal temperatures", "Ecological niche", "fungal ecology", "growth rate", "oomycete"],
 "abstract": "We collated and analysed temperature responses, specifically the minimum (T min), optimum (T opt) and maximum (T max) temperatures that comprise the 'cardinal temperatures', of various biological processes for 695 plant-associated microbes (631 fungi and 64 oomycetes) reported in \"Togashi, K. (1949). Biological characters of plant pathogens: temperature relations. Meikundo\". ...",
 "relatedWorks": [{"relationship": "primary_article", "identifier": "https://doi.org/10.1038/s41467-020-16778-5"}],
 "_links": {"stash:version": {"href": "/api/v2/versions/69468"}, "stash:download": {"href": "/api/v2/datasets/doi%3A10.5061%2Fdryad.tqjq2bvw6/download"}}}
```

Files of version 69468 (849 bytes, untrimmed apart from links): `Supplementary_Data_Togashi_FINAL.csv`, 2,424,892 bytes, `text/csv`, download `/api/v2/files/339387/download`.

The GlobTherm record (doi:10.5061/dryad.1cv08, 9,317 bytes) returned `"license": "https://spdx.org/licenses/CC0-1.0.html"`, `"publicationDate": "2019-01-26"`, 16 authors (Bennett, Calosi, Clusella-Trullas, ... Morales-Castilla), primary article `https://doi.org/10.1038/sdata.2018.22`; the extension record (doi:10.5061/dryad.5002200, 5,331 bytes) returned CC0-1.0, `"versionNumber": 2`, `"publicationDate": "2019-06-18"`, 10 authors (Sunday, Bennett, ... Morales-Castilla), primary article `https://doi.org/10.1098/rstb.2019.0036`.

### Dryad file download

```
GET https://datadryad.org/api/v2/files/339387/download
GET https://datadryad.org/downloads/file_stream/339387
```

### Sample response (Captured 2026-11-15)

The API download returned HTTP 401 `{"error":"Unauthorized, must have current bearer token"}` for all three CSV files (ids 339387, 19457, 107061); the web `file_stream` URL returned HTTP 403 from the load balancer. No Dryad file content was captured; the GlobTherm CSV header below comes from the Zenodo mirror, and the Togashi and extension columns come from the records' `usageNotes`.

### GlobTherm CSV (Zenodo mirror)

```
GET https://zenodo.org/api/records/4976423
GET https://zenodo.org/api/records/4976423/files/GlobalTherm_upload_02_11_17.csv/content
```

### Sample response (Captured 2026-11-15)

Record 4976423: `"doi": "10.5061/dryad.1cv08"`, `"license": {"id": "cc-zero"}`, same three files as Dryad. First 3,000 bytes of the CSV (HTTP 206 with a `Range` header), trimmed to the header and two rows:

```csv
Genus,Species,N,Tmax,max_metric,error,error measure,Multiple measures,max_interval_after_LT0,Tmax_2,max_metric_2,error,error measure,max_interval_before_LT100,max_pretreatment,max_ramp,lat_max,long_max,elevation_max,REF_max,location_max,N,tmin,min_metric,error,error_type,Multiple measures_min,min_interval_after_LT0,N,tmin_2,min_metric_2,error,error_type,min_interval_before_LT100,min_pretreatment,ramp_min,lat_min,long_min,elevation_min,REF_min,location_min,Phylum,Class,Order,Family,Quality of UTNZ
Prochilodus,scrofa,10,35.7,ctmax,,,N,,,,,,,20,0.1,-22,-43.5,0,Barrionuevo_&_Fernandes_1995,2,10,8.23,ctmin,,,N,,,,,,,,20,0.1,-22,-43.5,0,Barrionuevo_&_Fernandes_1995,2,Chordata,Actinopteri,Characiformes,Prochilodontidae,
Cyprinodon,variegatus,100,44.2,ctmax,0.29,SD,Y,,,,,,,21,0.1,26,-97.15,0,Bennett_&_Beitinger_1997,1,70,6.9,ctmin,,,Y,,,,,,,,20,0.1,26,-97.15,0,Bennett_&_Beitinger_1997,1,Chordata,Actinopteri,Cyprinodontiformes,Cyprinodontidae,
```

Column names repeat (`N`, `error`, `error measure`) for the upper and lower limit blocks; a reader must address columns by position.

### DDRP parameter files (Zenodo)

| Parameter | Required | Description | Example |
|---|---|---|---|
| `{id}` (path) | yes | Zenodo record id | `15538509` |
| `{file}` (path) | yes | File name from the record's `files[].key` | `SLF.params` |

```
GET https://zenodo.org/api/records/15538509
GET https://zenodo.org/api/records/15538509/files/SLF.params/content
```

### Sample response (Captured 2026-11-15)

Record 15538509 (6,940 bytes), trimmed to identifiers, licence, creators and files:

```json
{"id": 15538509, "doi": "10.5281/zenodo.15538509", "conceptdoi": "10.5281/zenodo.15538508",
 "metadata": {"title": "DDRP scripts and model parameter file used for spotted lanternfly, Lycorma delicatula",
   "publication_date": "2025-05-28", "version": "1", "resource_type": {"title": "Software", "type": "software"},
   "license": {"id": "cc-by-4.0"}, "access_right": "open",
   "creators": [{"name": "Barker, Brittany"}, {"name": "Leonard, Coop"}],
   "related_identifiers": [{"relation": "references", "identifier": "10.1371/journal.pone.0244005"}, {"relation": "references", "identifier": "10.3389/finsc.2023.1239173"}]},
 "files": [{"key": "DDRP_v3_funcs.R", "size": 97913}, {"key": "SLF.params", "size": 2612}, {"key": "DDRP_v3.R", "size": 109093}]}
```

`SLF.params` (2,612 bytes, R syntax), trimmed to the threshold, degree-day and stress lines; the Pest Event Map labels and the overwintering distribution parameters were removed:

```r
# SLF, Spotted lanternfly, Lycorma delicatula - in Degs Celsius (C)
# model documentation at: http://uspest.org/wea/SLF_model_analysis.pdf
# Last updated Apr 24 2024 for DDRP v2 (cohorts)
  fullname   <- "Spotted lanternfly"
  pestof     <- "wine grapes, tree fruits, black walnut, willow, etc."
  stgorder   <- c("OE","L","P","A","E")
  owstage    <- "OE"  # OE means ow as egg
  eggLDT     <- 10
  eggUDT     <- 35
  larvaeLDT  <- 10
  larvaeUDT  <- 35
  pupaeLDT   <- 10
  pupaeUDT   <- 35
  adultLDT   <- 10
  adultUDT   <- 35
  eggDD      <- 202
  larvaeDD   <- 890 # L1-L4 nymphs - calibration II
  pupDD      <- 630 # Adult pre-OV - calib. III
  adultDD    <- 146 # 1st-OV to 50% OV
  obligate_diapause <- 1
  OWeggDD <- 202 # OW stage requires at least 202 DD to begin hatch
  calctype   <- "triangle"  # triangle similar to sine curve
  coldstress_threshold  <- -16
  coldstress_units_max1 <- 300
  coldstress_units_max2 <- 475
  heatstress_threshold   <- 37
  heatstress_units_max1  <- 115
  heatstress_units_max2  <- 175
```

The other records returned `"license": {"id": "cc-by-4.0"}` as well: 4110732 (files `LBAM.params` 2,968 bytes, `STB.params` 2,502, `DDRP_v2.R` 108,184, `DDRP_v2_funcs.R` 97,659, `DDRP_user_guide_and_platform_requirements_V4.pdf` 466,984, two cron shell scripts), 8018595 (`EAB.params` 2,540, `DDRP_v2.R` 111,741, `DDRP_v2_funcs.R` 99,719) and 3832732 (v1 of the same concept as 4110732).

## Fields

### GlobTherm (`GlobalTherm_upload_02_11_17.csv`, 47 columns)

| Field | Type | Unit | Description |
|---|---|---|---|
| `Genus`, `Species` | string | | Species name; `Phylum`, `Class`, `Order`, `Family` at the end of the row |
| `N` | integer | | Sample size (appears three times: upper block, lower block, second lower measure) |
| `Tmax`, `max_metric` | number, string | degC | Upper thermal limit and its metric (`ctmax`, `LT50`, `LT100`, `UTNZ`) |
| `error`, `error measure` | number, string | degC | Error of the estimate and its type (`SD`, `SE`); repeated per block |
| `Multiple measures` | Y/N | | Whether several measurements exist |
| `max_interval_after_LT0`, `max_interval_before_LT100` | number | | Interval descriptors for lethal-limit studies |
| `Tmax_2`, `max_metric_2` | number, string | degC | Second upper-limit estimate |
| `max_pretreatment`, `max_ramp` | number | degC, degC/min | Acclimation temperature and ramping rate of the upper assay |
| `lat_max`, `long_max`, `elevation_max` | number | degrees, m | Collection site of the individuals assayed for the upper limit |
| `REF_max`, `location_max` | string, integer | | Abbreviated citation (full list in `References_1_09_2017.xlsx`) and location code |
| `tmin`, `min_metric`, `error`, `error_type`, `Multiple measures_min`, `min_interval_after_LT0`, `tmin_2`, `min_metric_2`, `min_interval_before_LT100`, `min_pretreatment`, `ramp_min`, `lat_min`, `long_min`, `elevation_min`, `REF_min`, `location_min` | | | Same structure for the lower limit |
| `Quality of UTNZ` | string | | Quality flag for thermal neutral zone estimates (endotherms) |

Column meanings beyond the header names are described in the Scientific Data article (not read in this pass).

### GlobTherm 2019 extension (`globtherm_full_dataset_2019.csv`, from `usageNotes`)

One row per thermal limit (one upper or lower limit per species): full taxonomy; limit type (`max` or `min`); the temperature in degC; the metric (`LT50` or `LT100` lethal limits, `ct` critical limits, `TNZ` thermal neutral zone edges); latitude, longitude and elevation of collection; acclimation temperature; starting temperature and ramping rate (critical-limit studies); exposure duration (lethal-limit studies); extreme episodic environmental temperature at the site and the "acclimation offset"; reference codes. Header not captured (download blocked).

### Togashi dataset (`Supplementary_Data_Togashi_FINAL.csv`, from `usageNotes`)

Long format: one row per species x process x cardinal temperature.

| Field | Type | Unit | Description |
|---|---|---|---|
| `CLASS` | string | | `Fungi` or `Oomycete` |
| `SPECIES_FINAL`, `AUTHOR_FINAL`, `SOURCE_FINAL` | string | | Current species name, authority and the nomenclature source used (`SF` Index/Species Fungorum, `MB` MycoBank; `LEG`/`ILL` legitimacy) |
| `STRAIN` | string | | Strain as recorded by Togashi (1949) |
| `SPECIES_TOGASHI`, `AUTHOR_TOGASHI`, `SPECIES_TOGASHI_ALT`, `SPECIES_TOGASHI_NON` | string | | Name as printed in 1949, its authority, corrected spellings and nonsynonymous names |
| `SOURCE_VERIFICATION`, `AUTHOR_VERIFICATION` | string | | Source and authority used to verify the 1949 name |
| `NONSYNOM_REM`, `NONSYNOM_ALT`, `NONSYNOM_REC` | string | | Handling of data recorded under nonsynonymous names (removed, recorded "as X", source record) |
| `TITLE_INFO`, `TITLE_MATCH`, `SPECIES_CHANGED`, `AMBIGUOUS` | string | | Provenance checks against the titles of the original publications; `AMBIGUOUS = Y` rows were dropped in the paper's subset analysis |
| `SPORE` | string | | Spore type, when the process concerns spores |
| `PROCESS` | string | | Biological process: growth in culture, spore germination, infection, sporulation, fructification, disease development |
| `CARDINAL` | string | | `min`, `opt` or `max` |
| `TEMPERATURE` | number | degC | The cardinal temperature |
| `DETAILS`, `UNCERTAINTY` | string | | Notes; `>` and `<` mark values the authors varied by plus or minus 2.5 degC in sensitivity analyses |
| `TEMPERATURE_REFERENCE` | string | | Original publication cited by Togashi |
| `DISEASE` | string | | Plant disease caused by the pathogen |
| `HOST_PLANT` | string | | Host on which the pathogen was observed |

The inventory gives N = 8,656 rows. Whether the 15,982-host table of the related paper is included beyond `HOST_PLANT` is not known (not downloaded).

### DDRP `.params` file

| Field | Type | Unit | Description |
|---|---|---|---|
| `fullname`, `pestof` | string | | Common name and host summary |
| `stgorder`, `owstage` | vector, string | | Life stage order (`OE` overwintering egg, `L` larva, `P` pupa, `A` adult, `E` egg) and overwintering stage |
| `eggLDT`, `larvaeLDT`, `pupaeLDT`, `adultLDT` | number | degC | Lower development thresholds per stage |
| `eggUDT`, `larvaeUDT`, `pupaeUDT`, `adultUDT` | number | degC | Upper development thresholds per stage |
| `eggDD`, `larvaeDD`, `pupDD`, `adultDD`, `OWeggDD` | number | degree-days (degC) | Degree-days to complete each stage; overwintering requirement |
| `calctype` | string | | Degree-day method (`triangle`, sine-like) |
| `obligate_diapause` | 0/1 | | Whether diapause is obligate |
| `coldstress_threshold`, `coldstress_units_max1`, `coldstress_units_max2` | number | degC, cold degree-days | Cold stress onset and the accumulations at which "most" and "all" individuals die |
| `heatstress_threshold`, `heatstress_units_max1`, `heatstress_units_max2` | number | degC, heat degree-days | Heat stress equivalents |
| `*EventDD`, `*EventLabel`, `PEMnumgens` | number, string | degree-days | Pest Event Map settings |
| `distro_mean`, `distro_var`, `xdist1`, `xdist2`, `distro_shape` | number, string | degree-days | Overwintering emergence distribution (DDRP v2 and later) |

## Licence

- **GlobTherm (Dryad 1cv08) and its Zenodo mirror (4976423): CC0 1.0.** Dryad API `license` = `https://spdx.org/licenses/CC0-1.0.html`; Zenodo `license.id` = `cc-zero` (both re-read 2026-11-15). Matches the inventory (PASS).
- **2019 extension (Dryad 5002200): CC0 1.0.** Dryad API `license` = CC0-1.0 (re-read 2026-11-15). Matches the inventory (PASS).
- **Togashi dataset (Dryad tqjq2bvw6): CC0 1.0.** The inventory relied on Dryad's platform policy because the record page showed no licence string; the Dryad API returns `"license": "https://spdx.org/licenses/CC0-1.0.html"` for this record (re-read 2026-11-15), so the licence is stated on the record itself. PASS, now confirmed directly.
- **DDRP parameter files: CC BY 4.0.** Zenodo `license.id` = `cc-by-4.0` on 15538509 (as in the inventory) and also on 4110732, 8018595 and 3832732 (re-read 2026-11-15). The inventory listed 4110732 and 8018595 as UNKNOWN; both are CC BY 4.0. The PLOS ONE paper (10.1371/journal.pone.0244005) is CC0 per the inventory (not re-read). Attribution to the Zenodo record is the condition.

## Overlap with NASA sources

- NASA POWER supplies the temperature series these parameters are applied to: hourly and daily `T2M`, daily `T2M_MAX` and `T2M_MIN` (`nasa_power.md`, `pest_weather_rules.md`). The DDRP thresholds and degree-day requirements, the Togashi cardinal temperatures and the GlobTherm limits are organism constants that NASA does not publish.
- GlobTherm's `lat_max`/`long_max` and the 2019 extension's site extreme temperatures describe where a species was assayed, not where it occurs; they can be compared with POWER climatology for a field but do not replace an occurrence dataset.
- DDRP itself runs on PRISM daily temperature grids (United States); the parameter files are independent of that input and can be applied to any daily `Tmin`/`Tmax` source, including POWER.

## Notes

- Dryad file downloads were not possible for a scripted client: the API needs a bearer token (HTTP 401) and the browser download route answered HTTP 403. The Dryad website serves the same files to a browser session. The GlobTherm CSV was read from the Zenodo mirror instead.
- GlobTherm's CSV has duplicate header names (`N`, `error`, `error measure`) across the upper and lower limit blocks.
- `References_1_09_2017.xlsx` appears twice in the Dryad file list of GlobTherm (ids 19456 and 19458).
- Zenodo rate-limit headers were returned on every call (`x-ratelimit-limit: 133`, `x-ratelimit-remaining` decreasing, `retry-after` 20-60 s).
- DDRP concept record 3832731 has two versions: 3832732 (v1) and 4110732 (v2, includes the user guide PDF). Record 15538509 uses DDRP v3 scripts while its parameter file header says "for DDRP v2 (cohorts)".
- The Togashi metadata notes that cardinal temperatures estimated from prose carry a note in `DETAILS`, and that `UNCERTAINTY` flags values perturbed in the paper's sensitivity analysis.

## Documentation

- GlobTherm data: https://doi.org/10.5061/dryad.1cv08 ; mirror https://zenodo.org/records/4976423 ; article: Bennett et al. 2018, Scientific Data 5:180022, https://doi.org/10.1038/sdata.2018.22
- 2019 extension data: https://doi.org/10.5061/dryad.5002200 ; article: Sunday et al. 2019, Phil. Trans. R. Soc. B 374:20190036, https://doi.org/10.1098/rstb.2019.0036
- Togashi dataset: https://doi.org/10.5061/dryad.tqjq2bvw6 ; article: Chaloner, Gurr and Bebber 2020, Nature Communications 11:2955, https://doi.org/10.1038/s41467-020-16778-5
- Dryad API: https://datadryad.org/api/v2/docs/
- DDRP records: https://zenodo.org/records/15538509 ; https://zenodo.org/records/4110732 ; https://zenodo.org/records/8018595 ; https://zenodo.org/records/3832732 ; article: Barker et al. 2020, PLOS ONE 15(12):e0244005, https://doi.org/10.1371/journal.pone.0244005 ; spotted lanternfly model: https://doi.org/10.3389/finsc.2023.1239173
- Zenodo REST API: https://developers.zenodo.org/
