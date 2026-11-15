# Crop rotation and crop-sequence datasets (Zenodo, figshare, USDA NASS)

Open research datasets about rotation effects and observed crop sequences: a global meta-analysis of legume pre-crop effects (Zhao, Zang et al. 2022), a European grain-legume yield dataset (Antichi et al. 2023), the Harmonised LUCAS points classified by crop sequence type (Ballot, Guilpart and Jeuffroy 2022), the CropRot Sentinel-2 time-series dataset (CESBIO, 2024), EuroCrops harmonised parcel declarations (TUM, 2023), the "Precrop Payoffs" causal-ML data and code (Kluger, Di Tommaso and Lobell 2025), the Crop Generator rotation code (PIK, 2021) and the USDA NASS Crop Sequence Boundaries (field polygons with eight-year crop histories). None of these is a live API: each is a versioned deposit whose metadata (title, licence, file list, download links) is served as JSON by the Zenodo and figshare REST APIs without a key, and whose files are plain HTTP downloads. All records were read on 2026-11-15; the licence strings below are what the APIs returned that day.

| | |
|---|---|
| Provider | Zenodo (CERN), figshare (Digital Science; Springer Nature portal for the Antichi deposit), USDA National Agricultural Statistics Service (NASS) |
| Base URL | `https://zenodo.org/api/records/{id}` ; `https://api.figshare.com/v2/articles/{id}` and `/v2/collections/{id}` ; `https://www.nass.usda.gov/research-and-science/crop-sequence-boundaries` |
| Auth | none (record metadata and public file downloads) |
| Formats | JSON (metadata); CSV, R, ZIP (shapefiles, PyTorch tensors) for the files |
| Coverage | Zhao: 53 countries, 1959-2020; Antichi: 21 European countries, 1980-2020; Ballot and EuroCrops: European Union; CropRot and Kluger: France (plus other regions, see below); NASS CSB: contiguous United States, 2008-2025 |
| Resolution | experiment or plot (Zhao, Antichi), survey point (Ballot), parcel (EuroCrops, CropRot), field polygon (CSB) |
| Cadence / latency | static deposits; new versions appear under the same Zenodo concept record (`conceptrecid`) and figshare article |
| Rate limits / quotas | Zenodo answered record requests with `x-ratelimit-limit: 133` and search requests with `x-ratelimit-limit: 30` (per minute, with `retry-after`); figshare publishes none |
| Licence | per dataset, see Licence section: CC BY 4.0 (Zhao, Ballot, CropRot, Kluger), CC0 (Antichi EGLD), CC BY-SA 4.0 (EuroCrops), BSD-2-Clause (Crop Generator), US public domain (NASS CSB) |
| Documentation | https://developers.zenodo.org/ ; https://docs.figshare.com/ ; https://www.nass.usda.gov/research-and-science/crop-sequence-boundaries |

### Datasets (checked 2026-11-15)

| Dataset | Record | Licence returned by the API | Files | What it holds |
|---|---|---|---|---|
| Zhao, Zang et al. 2022, legume pre-crop meta-analysis data | figshare article 20290923 (v2, 2022-08-22); paper doi:10.1038/s41467-022-32464-0 | `CC BY 4.0` | `data.csv` 2,241,324 bytes | 11,768 paired yield observations from 462 experiments in 53 countries (counts from the paper); one row per observation with site climate, soil, legume pre-crop, main crop, management and the log response ratio |
| Zhao 2022 R code | figshare article 20290959 (v1, 2022-07-13) | `CC BY 4.0` | `metaLnoL_NC.R` 82,969 bytes | Meta-analysis script |
| Antichi et al. 2023, European Grain Legume Dataset (EGLD) | figshare collection 6573760 (9 articles); dataset article 23634822; paper doi:10.1038/s41597-023-02606-0 | collection: `null`; dataset and instructions articles: `CC0` | `European Grain Legume Dataset.csv` 1,976,596 bytes; `EGLD instructions.csv` 11,899 bytes; list of sources; 4 R scripts | Grain yields of chickpea, faba bean, field pea, lentil and soybean from experiments and papers, with previous crop, sowing and harvest dates, N, P, K rates, irrigation and tillage |
| Ballot, Guilpart and Jeuffroy, Harmonised LUCAS database classified by crop sequence type | Zenodo 7016987 (v1.0, 2022-08-23) and 8123396 (v1.1); concept 7016986 | `cc-by-4.0` on both versions | `lucas_classified.csv` 3,657,663 bytes (v1.1; 5,191,012 in v1.0); a PNG map | 31,159 LUCAS points with 2012, 2015 and 2018 land cover, crop-group frequencies and a crop sequence type (`clust`) |
| CropRot (CESBIO: Dumeur, Valero, Inglada) | Zenodo 13880014 (2024-10-02) plus one record per Sentinel-2 tile: 13842625 (T30UXV), 13832554 (T32ULU), 13843322 (T31TFJ), 13847056 (T31TFM) | `cc-by-4.0` | parent record: `crop_rot_dataset.txt` 444 bytes; T30UXV: `T30UXV.zip` 10,681,852,961 bytes holding 562 `.pt` PyTorch tensor files | Sentinel-2 time series with sequential crop labels from the French RPG, built for deep-learning crop-rotation models; not a tabular rotation table |
| EuroCrops (TUM: Schneider, Chan, Korner) | Zenodo 8229128 (2023-08-09, "Version 11" per the README); concept 6866846 | `cc-by-sa-4.0` | 39 files: one ZIP of shapefiles per country or region (36.9 MB Portugal to 2.63 GB France 2018), one `.csv` class mapping per country, `HCAT2.csv`, `HCAT3.csv` | Self-declared parcel crop types from 16 EU countries harmonised to the Hierarchical Crop and Agriculture Taxonomy (HCAT); the README points to EuroCrops 2.0 at the JRC data catalogue |
| Kluger, Di Tommaso and Lobell 2025, "Precrop Payoffs" data and code | Zenodo 15579276 (2025-06-02, type Software); paper doi:10.1088/1748-9326/ae0f45 | `cc-by-4.0` | `RotationProjectZenodo.zip` 6,381,911,593 bytes | Observational crop-type and weather samples exported from Google Earth Engine (the tail of the archive lists CSVs such as `.../FranceCropTypeAndWeather/RegionsWithMergingNeeded/AuvergneRACroptype/rotation1_data_GEEexport_..._CDL_2015-2021_..._49.csv`) plus code |
| Crop Generator R code (PIK: Conradt) | Zenodo 4704561 (2021-04-20, type Software) | `bsd-2-clause-netbsd` | `crop_generator.R` 15,465 bytes | Quadratic-programming code that assigns allowed rotations to model units so that regional crop shares match statistics |
| USDA NASS Crop Sequence Boundaries (CSB) | NASS page; code at `https://github.com/USDA-REE-NASS/crop-sequence-boundaries` | US Government work (no licence string on the page) | one ZIP per eight-year window, `NationalCSB_2008-2015_rev23.zip` to `NationalCSB_2018-2025_rev23.zip` (3,758,023,527 bytes), plus `NationalCSB_2008-2023_rev23.zip` | Field polygons with the crop grown in each year of the window, derived from the Cropland Data Layer; the 2018-2025 release is dated 2026-03-27 |

## Requests

### Zenodo record metadata

Returns the record's metadata, file list and links. `{id}` is a record id; `/versions/latest` on any version redirects (HTTP 301) to the newest version of the same concept.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `{id}` (path) | yes | Zenodo record id | `13880014` |

```
GET https://zenodo.org/api/records/13880014
GET https://zenodo.org/api/records/15850408/versions/latest
```

### Sample response (Captured 2026-11-15)

CropRot parent record, 6,314 bytes. Trimmed: `metadata.description` cut after the tile links, `stats`, `revision`, `owners`, `swh`, `custom` and `metadata.resource_type` removed.

```json
{
  "id": 13880014, "conceptrecid": "13880013", "doi": "10.5281/zenodo.13880014", "conceptdoi": "10.5281/zenodo.13880013",
  "created": "2024-10-02T10:07:37.496066+00:00", "modified": "2024-12-18T15:22:56.874584+00:00",
  "metadata": {
    "title": "CropRot (full dataset)", "publication_date": "2024-10-02", "access_right": "open",
    "license": {"id": "cc-by-4.0"},
    "creators": [
      {"name": "Dumeur, Iris", "affiliation": "Centre d'Études Spatiales de la Biosphère"},
      {"name": "Valero, Silvia", "affiliation": "Centre d'Études Spatiales de la Biosphère"},
      {"name": "Inglada, Jordi", "affiliation": "Centre d'Études Spatiales de la Biosphère"}],
    "related_identifiers": [
      {"relation": "isDescribedBy", "identifier": "arXiv:2407.08448"},
      {"relation": "isRequiredBy", "identifier": "https://src.koda.cnrs.fr/iris.dumeur/alise"},
      {"relation": "isDerivedFrom", "identifier": "https://src.koda.cnrs.fr/iris.dumeur/modcix."}],
    "description": "<p><strong>Official repository of the CropRot Dataset</strong></p><p>The dataset is composed of 4 repositories, each corresponding to data collected on a S2 tile. T30UXV : https://zenodo.org/uploads/13842625 T32ULU: https://zenodo.org/uploads/13832554 T31TFJ : https://zenodo.org/uploads/13843322 T31TFM : https://zenodo.org/uploads/13847056 ..."
  },
  "files": [{"key": "crop_rot_dataset.txt", "size": 444, "checksum": "md5:...", "links": {"self": "https://zenodo.org/api/records/13880014/files/crop_rot_dataset.txt/content"}}],
  "links": {"self": "https://zenodo.org/api/records/13880014", "self_html": "https://zenodo.org/records/13880014", "latest": "https://zenodo.org/api/records/13880014/versions/latest", "files": "https://zenodo.org/api/records/13880014/files"}
}
```

The same request for the tile record 13842625 returned one file, `T30UXV.zip`, `size` 10,681,852,961, `license` `cc-by-4.0`, `related_identifiers` `isPartOf 10.5281/zenodo.13880014`. A `Range: bytes=-65536` request on that file's `/content` URL returned HTTP 206 and a zip central directory of 562 entries, all `T30UXV/tensor_s2_<n>_idoe_<m>_<k>.pt` (24 to 66 MB each).

Ballot v1.0 (7016987) and v1.1 (8123396): both returned `"license": {"id": "cc-by-4.0"}`, `publication_date` `2022-08-23`, `version` `1.0` and `1.1`, two files each (`lucas_classified.csv`, `map_of_dominant_crop_sequences_in_the_European_Union_over_2012_2018.png`). Kluger 15579276: `cc-by-4.0`, `resource_type` Software, one file `RotationProjectZenodo.zip` 6,381,911,593 bytes. Crop Generator 4704561: `"license": {"id": "bsd-2-clause-netbsd"}`, one file `crop_generator.R`. EuroCrops 8229128: `cc-by-sa-4.0`, 39 files, `related_identifiers` `isNewVersionOf 10.14459/2021mp1615987`, `isSupplementedBy https://github.com/maja601/EuroCrops`.

### Zenodo file content (byte range)

Files are served at `/api/records/{id}/files/{key}/content` and honour `Range`.

```
GET https://zenodo.org/api/records/8123396/files/lucas_classified.csv/content
    Range: bytes=0-1499
```

### Sample response (Captured 2026-11-15)

HTTP 206, `text/plain; charset=utf-8`. Semicolon separated, decimal comma. Header and the first three of the 1,500 bytes' rows (the rest trimmed).

```
"point_id";"nuts0";"nuts2";"th_lat";"th_long";"LC1_2012";"LC1_2015";"LC1_2018";"cereales";"corn";"rapeseed";"sunflower";"pulses";"rootCrops";"forageLeg";"grassland";"clust"
26821846;"PT";"PT18";37,876537866;-8,702020387;"LC1_2012_mixed cereals";"LC1_2015_temporary grasslands";"LC1_2018_oats";0,333333333333333;0;0;0;0;0;0;0,333333333333333;"cereals"
27001882;"PT";"PT18";38,231864294;-8,591381992;"LC1_2012_other vegetables";"LC1_2015_dry pulses";"LC1_2018_other root crops";0;0;0;0;0,333333333333333;0,333333333333333;0;0;"pulses and cereals"
27041840;"PT";"PT18";37,872048584;-8,444053459;"LC1_2012_oats";"LC1_2015_temporary grasslands";"LC1_2018_temporary grasslands";0,333333333333333;0;0;0;0;0;0;0,666666666666667;"temporary grasslands"
```

EuroCrops `HCAT3.csv` (first 1,200 bytes, same request form on record 8229128) starts `HCAT3_name,HCAT3_code` then `cereal,3301010000`, `common_soft_wheat,3301010100`, `winter_common_soft_wheat,3301010101`, `grain_maize_corn_popcorn,3301010600`, `rice,3301010700`; the preview file `.preview_DE_NRW_2021.csv` has columns `ID,FLIK,AREA_HA,CODE,CODE_TXT,USE_CODE,USE_TXT,WJ,DAT_BEARB,EC_trans_n,EC_hcat_n,EC_hcat_c` with rows such as `4597810,DENWLI0540163053,1.162,121,Winterroggen,GT,Getreide,2021,2021/03/04,Winter rye,winter_rye,3301010301`.

### Zenodo search

```
GET https://zenodo.org/api/records?q=EuroCrops&size=3&sort=mostrecent
```

### Sample response (Captured 2026-11-15)

58,556 bytes; `hits.hits[]` reduced to id, title, date and licence. The search ranks newer records by the same group first; the EuroCrops deposit itself (8229128) was found through the project README, not through this search.

```
18670815  Harmonized IACS inventory  2026-02-18  license cc-by-4.0  files 75
18632974  Brandenburg-S12-CropVal: A Sentinel-1/2 Multi-Modal Cropland Segmentation Dataset ... (Brandenburg, Germany, 2024)  2026-02-13  license cc-by-4.0  files 1
15631655  Global Pasture Watch - Grassland reference samples ... (2000-2024)  2025-06-13  license cc-by-4.0  files 7
```

### figshare article metadata

| Parameter | Required | Description | Example |
|---|---|---|---|
| `{id}` (path) | yes | figshare article id | `20290923` |

```
GET https://api.figshare.com/v2/articles/20290923
```

### Sample response (Captured 2026-11-15)

4,066 bytes. Trimmed: `authors[].id`, `custom_fields`, `timeline`, `embargo_*`, `citation`, `funding_list[].id` and `categories[].parent_id` removed; `funding` cut after the first grant.

```json
{
  "id": 20290923, "title": "data.csv", "doi": "10.6084/m9.figshare.20290923.v2", "version": 2,
  "defined_type_name": "dataset", "published_date": "2022-08-22T14:42:41Z",
  "license": {"value": 1, "name": "CC BY 4.0", "url": "https://creativecommons.org/licenses/by/4.0/"},
  "authors": [{"full_name": "Jie Zhao", "url_name": "Jie_Zhao"}],
  "categories": [{"title": "Agronomy"}],
  "tags": ["Legume", "pre-crop effect", "yield-related", "Crop Diversification", "Crop Rotation", "Agronomy"],
  "references": ["https://doi.org/10.1038/s41467-022-32464-0"],
  "description": "<p><strong>Dataset for evaluating global yield advantage and its drivers of legume-based rotations</strong></p>",
  "funding": "This study was funded by the National Natural Science Foundation of China (32101850, Zang; 32172125, Zeng), ...",
  "files": [{"id": 36749424, "name": "data.csv", "size": 2241324, "is_link_only": false, "download_url": "https://ndownloader.figshare.com/files/36749424", "computed_md5": "3b2475164c21d87a5435db67d09fc1ef", "mimetype": "text/plain"}],
  "figshare_url": "https://figshare.com/articles/dataset/data_csv/20290923",
  "url_public_html": "https://figshare.com/articles/dataset/data_csv/20290923"
}
```

### figshare file download

`download_url` redirects (HTTP 302) to a signed object-store URL that expires after 10 seconds; the redirect target honours `Range`.

```
GET https://ndownloader.figshare.com/files/36749424
    Range: bytes=0-2999
```

### Sample response (Captured 2026-11-15)

HTTP 206, `text/csv`, `last-modified: Fri, 06 Nov 2026 13:38:46 GMT`. Header and the first two rows; the first column is an unnamed row index.

```csv
,Continent,Country,Lat,Lon,AI,Alt,MAP,MAT,pH,SOC,STN,ST2,PreEff,LeguSeaNo,NumCroPerYr,PreLegPur,PreLegRes,SubEff,MainCropType,IG,NonLegRes,SOCcat,ConsTill,RC,NFR,CD2,RepNL,RepL,GMC,RR_Y,wgt,vi,yi
1,Africa,Benin,8.851,1.792,0.6423,338,1254,26.2,5.7,13.5,0.725,Medium,Soybean,1,1,Seed,Remove,Rice,grain,yes,Remove,12_20,yes,1,15,1,4,4,14,1.585858586,2,0.5,0.461125955
11,Africa,Benin,6.416,2.333,0.7602,51,1175,27.4875,5.4,19.4,0.82,Coarse,Cowpea,1,2,GRM,Return,Rice,grain,no,NA,12_20,no,1,60,2,8,8,14,1.352173913,4,0.25,0.301713603
```

### figshare collection and the EGLD files

```
GET https://api.figshare.com/v2/collections/6573760
GET https://api.figshare.com/v2/collections/6573760/articles
GET https://api.figshare.com/v2/articles/23634822
GET https://ndownloader.figshare.com/files/41471280      (European Grain Legume Dataset.csv, Range: bytes=0-2499)
GET https://ndownloader.figshare.com/files/41471292      (EGLD instructions.csv, 11,899 bytes, whole file)
```

### Sample response (Captured 2026-11-15)

Collection 6573760: `title` "An experimental dataset on yields of pulses across Europe.", `doi` `10.6084/m9.figshare.c.6573760.v1`, `resource_doi` `10.1038/s41597-023-02606-0`, `published_date` `2023-10-12T09:13:42Z`, `license` `null`, `articles_count` 9, twelve authors (Antichi, Pampana, Tramacere, Biarnes, Stute, Kadziuliene, Howard, Duarte, Balodis, Bertin, Guilpart, Makowski). The articles list (7,450 bytes, trimmed to id and title): 23634822 European Grain Legume Dataset; 23634834 and 23634828 Instructions for the dataset; 23634831 and 23634837 List of sources; 23634858, 23634870, 23634864, 23634867 R scripts for the figures. Article 23634822 returned `"license": {"value": 2, "name": "CC0", "url": "https://creativecommons.org/publicdomain/zero/1.0/"}` and one file, `European Grain Legume Dataset.csv`, 1,976,596 bytes, `download_url` `https://ndownloader.figshare.com/files/41471280`.

The dataset CSV (HTTP 206, UTF-8 with BOM, trailing empty columns) begins:

```csv
id,source,experiment_ID,site_country,site_region,site_name,lat,lon,site_soil_classification_name,site_soil_texture_name,soil_texture_anomaly,site_rain,site_rain_period,site_rain_period_month,site_rain_period_year,site_temp,site_temp_period,site_temp_period_month,site_temp_period_year,organic_farming,management_evaluated,treatment_name,scientific_name,previous_crop,crop,crop_type,cultivar,precocity_group,gm,sow_dd,sow_mm,sow_yy,sow_date,har_dd,har_mm,har_yy,har_date,cycle_length,tillage,plant_density,sowing_density,row_spacing,N_rate,N_fertiliser type_1,N_fertiliser type_2,N_fertiliser type_3,N_nb_application,N_perc_from_organic_fert,P_rate,P_fertiliser_type_1,P_fertiliser_type_2,P_nb_application,P_perc_from_organic_fert,K_rate,K_fertiliser_type_1,K_fertiliser_type_2,K_nb_application,K_perc_from_organic_fert,irrigation,irrigation_quantity,herbicide_application,mechanical_weed_control,crop_protection,replicate_nb,site_nb,year_nb,moisture_at_harvest,yield,yield_se,yield_sd,yield_cv,yield_var,,,,,,,,,,,
1,LEGVALUE Experiment,011081515-001_Ingvorsen,Denmark,Oestjylland,Mundelstrup,56.20,10.12,NA,sandy loam,N,445.6,growing season,Apr-Sep,2015,8.9,annual,Jan-Dec,2015,N,Species,Ingrid,Pisum sativum L.,Hordeum vulgare,field pea,dry,Ingrid,NR,N,10,4,2015,04/10/2015,8,9,2015,09/08/2015,151,Y ,NA,NA,NA,NA,NA,NA,NA,NA,NA,NA,NA,NA,NA,NA,NA,NA,NA,NA,NA,N,NR,NA,NA,NA,4,1,1,14,4.82,NA,0.46,8.17,NA,,,,,,,,,,,
```

### NASS Crop Sequence Boundaries page and files

```
GET https://www.nass.usda.gov/research-and-science/crop-sequence-boundaries
HEAD https://www.nass.usda.gov/sites/default/files/Research_and_Science/Crop-Sequence-Boundaries/datasets/NationalCSB_2018-2025_rev23.zip
```

### Sample response (Captured 2026-11-15)

The page (HTTP 200 after a 301 from the old `index.php` URL) says, in part: "The Crop Sequence Boundaries (CSB) developed with USDA's Economic Research Service, produces estimates of field boundaries, crop acreage, and crop rotations across the contiguous United States. It uses satellite imagery with other public data and is open source ... CSB represents non-confidential single crop field boundaries over a set time frame. It does not contain personal identifying information. The boundaries captured are of crops grown only, not ownership boundaries or tax parcels ... The 2018-2025 released March 27, 2026. Current version is v2024. These datasets span 8-year time frames for all years from 2008 to current." It links eleven eight-year ZIPs (2008-2015 to 2018-2025), one sixteen-year ZIP (2008-2023), the metadata, the GitHub code and the contact `sm.nass.rdd.gib@usda.gov`. The HEAD request returned `content-type: application/zip`, `content-length: 3758023527`, `last-modified: Mon, 05 Oct 2026 16:31:44 GMT`. The GitHub README describes the three processing steps (`create`, `prep`, `distribute`) and lists ArcGIS Pro 3.1 as the tested software.

## Fields

### Zhao 2022 `data.csv` (34 columns)

The deposit carries no data dictionary. Column meanings below are read from the column names and the paper's methods; the ones marked "inferred" were not confirmed in a document.

| Field | Type | Unit | Description |
|---|---|---|---|
| (unnamed) | integer | | Row index |
| `Continent`, `Country` | string | | Site location |
| `Lat`, `Lon` | number | degrees | Site coordinates |
| `AI` | number | ratio | Aridity index (inferred) |
| `Alt` | integer | m | Altitude |
| `MAP`, `MAT` | number | mm, degC | Mean annual precipitation and temperature |
| `pH`, `SOC`, `STN` | number | pH, g/kg, g/kg | Soil pH, soil organic carbon, soil total nitrogen (units inferred) |
| `ST2` | string | class | Soil texture class (`Coarse`, `Medium`, ...) |
| `PreEff` | string | | Legume pre-crop species (`Soybean`, `Cowpea`, `Mucuna`, ...) |
| `LeguSeaNo`, `NumCroPerYr` | integer | | Number of legume seasons; crops per year |
| `PreLegPur` | string | | Legume purpose: `Seed` or `GRM` (green manure) |
| `PreLegRes`, `NonLegRes` | string | | Residue management: `Remove`, `Return`, `NA` |
| `SubEff`, `MainCropType` | string | | Main (following) crop and its type (`grain`) |
| `IG` | string | yes/no | Inferred: irrigation |
| `SOCcat` | string | class | Soil organic carbon category (`12_20`) |
| `ConsTill` | string | yes/no | Conservation tillage |
| `RC`, `CD2`, `GMC` | number | | Not documented in the deposit |
| `NFR` | number | kg N/ha | Nitrogen fertiliser rate (inferred) |
| `RepNL`, `RepL` | integer | | Replicates of the non-legume and legume treatments |
| `RR_Y` | number | ratio | Yield response ratio, legume pre-crop over non-legume control |
| `wgt`, `vi`, `yi` | number | | Meta-analysis weight, sampling variance and log response ratio |

### Ballot `lucas_classified.csv` (17 columns)

From the record description, which documents every variable.

| Field | Type | Unit | Description |
|---|---|---|---|
| `point_id` | integer | | LUCAS point id (inherited from the Harmonised LUCAS database, doi:10.2905/f85907ae-d123-471f-a44a-8cca993485a2) |
| `nuts0`, `nuts2` | string | | NUTS country and region codes |
| `th_lat`, `th_long` | number | degrees | Theoretical point coordinates |
| `LC1_2012`, `LC1_2015`, `LC1_2018` | string | | Land cover observed at the point in each survey year |
| `cereales`, `corn`, `rapeseed`, `sunflower`, `pulses`, `rootCrops`, `forageLeg`, `grassland` | number | fraction 0-1 | Temporal frequency of each crop group over the three surveys (the header spells "cereales") |
| `clust` | string | | Crop sequence type (`cereals`, `pulses and cereals`, `temporary grasslands`, ...) |

### EGLD `European Grain Legume Dataset.csv` (73 named columns)

`EGLD instructions.csv` documents each column; the main ones:

| Field | Type | Unit | Description |
|---|---|---|---|
| `id`, `source`, `experiment_ID` | | | Entry id; `Paper`, `Experiment LEGATO` or `Experiment LEGVALUE`; experiment or paper id |
| `site_country`, `site_region`, `site_name`, `lat`, `lon` | | degrees | Site |
| `site_soil_classification_name`, `site_soil_texture_name` | string | | USDA soil class; texture class |
| `site_rain`, `site_rain_period`, `site_temp`, `site_temp_period` | number, string | mm, degC | Rainfall and mean temperature for the stated period |
| `organic_farming`, `management_evaluated`, `treatment_name` | | Y/N | Management |
| `scientific_name`, `previous_crop`, `crop`, `crop_type`, `cultivar` | string | | Legume species (Latin), previous crop (Latin), common name, type (`dry`/`green` pea; faba bean `horse`/`pigeon`/`broad`) |
| `sow_date`, `har_date`, `cycle_length` | date, integer | mm/dd/yyyy, days | Sowing and harvest |
| `N_rate`, `P_rate`, `K_rate` | number | kg N, P, K per ha | Fertiliser totals, with type and application-count columns |
| `irrigation`, `irrigation_quantity` | string, number | Y/N, mm | |
| `yield` | number | t dry matter per ha | Grain yield with moisture removed (`moisture_at_harvest` in %) |
| `yield_se`, `yield_sd`, `yield_cv`, `yield_var` | number | | Dispersion of the mean yield |

### EuroCrops harmonised attributes

| Field | Type | Unit | Description |
|---|---|---|---|
| `EC_trans_n` | string | | Original crop name translated into English |
| `EC_hcat_n` | string | | HCAT name (`winter_rye`, `green_silo_maize`) |
| `EC_hcat_c` | integer | | 10-digit hierarchical HCAT code (`3301010301`) |

National columns (for example `FLIK`, `AREA_HA`, `CODE_TXT`, `WJ` in North Rhine-Westphalia) vary by country.

## Licence

| Dataset | Licence as read on 2026-11-15 | Where read | Notes |
|---|---|---|---|
| Zhao 2022 data and code | `CC BY 4.0` (figshare `license.name`) | figshare API, re-read today | Matches the inventory |
| Antichi EGLD | `CC0` on the dataset and instructions articles; the collection object has `license: null` | figshare API, re-read today | The inventory had the dataset licence as unknown (article CC BY 4.0); the files are CC0 |
| Ballot LUCAS crop sequence types | `cc-by-4.0` on v1.0 and v1.1 | Zenodo API, re-read today | The inventory had v1.1 unverified; it is CC BY 4.0 |
| CropRot | `cc-by-4.0` on the parent and the T30UXV tile record | Zenodo API, re-read today | |
| EuroCrops | `cc-by-sa-4.0` (Zenodo); README badge "CC BY-SA 4.0"; the README adds "Please also reference the countries' dependent source", and the inventory notes national licences vary (Austria CC-BY-AT 4.0, Netherlands CC0) | Zenodo API and GitHub README, re-read today | ShareAlike applies to derived works |
| Kluger 2025 data and code | `cc-by-4.0` | Zenodo API, re-read today | The inventory had the record licence as not seen |
| Crop Generator | `bsd-2-clause-netbsd` | Zenodo API, re-read today | The inventory had it as unknown |
| NASS CSB | No licence string on the page; USDA NASS data are US Government works | NASS page, re-read today | The inventory lists it as public domain |

## Overlap with NASA sources

NASA publishes no rotation trial data, crop-sequence classifications or legume pre-crop effects. The datasets here are agronomic experiments and national parcel declarations. Beside them, NASA POWER (`nasa_power.md`) serves the daily weather of any experiment site or growing season, the MODIS and HLS vegetation indices (`vegetation_indices.md`) give observed green-up and senescence for a field, and GEOGLAM Crop Monitor calendars (`geoglam_crop_calendars.md`) give the expected season windows. The Cropland Data Layer that the NASS Crop Sequence Boundaries are built from is a USDA product (`cropland_cdl.md`), not a NASA one, although it uses Landsat and Sentinel imagery.

## Notes

- Zenodo rate limits were visible in the response headers: 133 record requests per minute and 30 search requests per minute, with `retry-after` counting down the window.
- figshare `download_url` answers with a 302 to a signed URL valid for 10 seconds; follow the redirect immediately.
- The Zhao `data.csv` was modified on the figshare side on 2026-11-06 (`last-modified` header) although the article version is still v2 of 2022-08-22.
- CropRot is a deep-learning dataset: 562 PyTorch tensor files per tile (10.7 GB for T30UXV), labelled from the French RPG; the record text points to the `modcix` repository and a notebook for reading it. It is not a table of rotations.
- The Kluger archive (6.38 GB) was not downloaded; its structure was read from the zip central directory with a `Range: bytes=-65536` request, which parsed 173 entries, all CSV files under `RotationProjectZenodo/RotationProjectObservationalData/...` (with macOS `__MACOSX` duplicates).
- The Zenodo search for "EuroCrops" did not return the EuroCrops record in the top results; the record id came from the project README, which also announces EuroCrops 2.0 at `https://data.jrc.ec.europa.eu/dataset/b9fb9e67-78a9-4327-9d59-39a928d812d3` (not fetched).
- The NASS Crop Sequence Boundaries ZIP for 2018-2025 is 3.76 GB; only headers were requested.
- Angus et al. 2015 break-crop data and the Fruchtfolge model were not fetched (the inventory lists Fruchtfolge as MIT-licensed code that needs a paid GAMS licence at run time).

## Documentation

- Zenodo REST API: https://developers.zenodo.org/
- figshare API: https://docs.figshare.com/
- Zhao, Zang et al. 2022, Nature Communications: https://doi.org/10.1038/s41467-022-32464-0 ; data https://figshare.com/articles/dataset/data_csv/20290923 ; code https://figshare.com/articles/software/Code_R/20290959
- Antichi et al. 2023, Scientific Data: https://doi.org/10.1038/s41597-023-02606-0 ; collection https://doi.org/10.6084/m9.figshare.c.6573760.v1
- Ballot, Guilpart and Jeuffroy: https://zenodo.org/records/7016987 ; https://zenodo.org/records/8123396 ; paper (ESSD 2023) https://doi.org/10.5194/essd-15-5651-2023
- CropRot: https://zenodo.org/records/13880014 ; arXiv:2407.08448
- EuroCrops: https://zenodo.org/records/8229128 ; https://github.com/maja601/EuroCrops ; Scientific Data article https://doi.org/10.1038/s41597-023-02517-0
- Kluger, Di Tommaso and Lobell 2025, Environmental Research Letters: https://doi.org/10.1088/1748-9326/ae0f45 ; https://zenodo.org/records/15579276
- Crop Generator: https://zenodo.org/records/4704561
- USDA NASS Crop Sequence Boundaries: https://www.nass.usda.gov/research-and-science/crop-sequence-boundaries ; https://github.com/USDA-REE-NASS/crop-sequence-boundaries
