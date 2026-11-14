# FAO ECOCROP (crop environmental requirements)

ECOCROP is an FAO database of plant characteristics and crop environmental requirements: optimal and absolute ranges of temperature, annual rainfall, soil pH, latitude, altitude and light intensity; soil depth, texture, fertility, aluminium toxicity, salinity and drainage classes; killing temperatures; photoperiod; Koppen climate zones; and growing cycle length. It covers 2568 plant taxa (count shown on the live search page on 2026-11-14). Values are expert-compiled ranges per species, not spatial data, and have no time dimension. The database is served by FAO as an HTML web application with no API; the full table is redistributed as CSV by third parties.

| | |
|---|---|
| Provider | FAO (Land and Water Division); third-party redistributions listed below |
| Base URL | `https://ecocrop.apps.fao.org/ecocrop/srv/en/` (HTML application); CSV copy at `https://raw.githubusercontent.com/OpenCLIM/ecocrop/main/EcoCrop_DB.csv` |
| Auth | none for `ecocrop.apps.fao.org` and the GitHub CSV; `ecocrop.review.fao.org` redirects to a Google sign-in page |
| Formats | HTML (FAO site); CSV (OpenCLIM GitHub); R `.rds` (Recocrop CRAN package) |
| Coverage | 2568 plant taxa, global (species-level, not spatial) |
| Resolution | one record per taxon (EcoPort code) |
| Cadence / latency | static; no update schedule published |
| Rate limits / quotas | not published |
| Documentation | https://gaez.fao.org/pages/ecocrop ; https://ecocrop.apps.fao.org/ecocrop/srv/en/home |

### Availability (checked 2026-11-14)

| Location | Status | Notes |
|---|---|---|
| `https://ecocrop.apps.fao.org/ecocrop/srv/en/home` | HTTP 200, working | Search, find-by-name, crop view and data sheet pages (Apache Tomcat). HTML only. |
| `https://ecocrop.review.fao.org/ecocrop/srv/en/home` | Redirects to Google sign-in ("Sign in to continue to ecocrop") | Linked from the GAEZ ECOCROP page. |
| `https://gaez.fao.org/pages/ecocrop` | HTTP 200 | Description page; links to the ECOCROP search and find tools. |
| `https://github.com/OpenCLIM/ecocrop` (`EcoCrop_DB.csv`) | HTTP 200 | README states "The full FAO EcoCrop database is provided as EcoCrop_DB.csv". 2568 data rows, 55 columns. Also `EcoCrop_DB_secondtrim.csv` (trimmed subset) and `Ecocrop_variable_lookup.csv` (column dictionary). Last push 2026-01-30. |
| CRAN package `Recocrop` 0.4-2 (2025-07-21, GPL >= 3) | Available | `inst/parameters/ecocrop.rds` (R serialized, readable with R `readRDS`). Its documentation describes "Default ecocrop parameters for 1710 taxa" derived from values "that used to be available on the website" of FAO. |

## Requests

### Find plant by name (FAO HTML)

Returns an HTML list of matching taxa with links to `cropView?id=<EcoPort code>`.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `name` | yes | Plant name text | `Zea mays` |
| `relation` | no | `beginsWith`, `matches` or `contains` | `beginsWith` |
| `code` | no | EcoPort code | `2175` |
| `quantity` | no | Max results: empty (all), 5, 10, 25, 50, 100 | (empty) |

```
GET https://ecocrop.apps.fao.org/ecocrop/srv/en/cropListDetails?code=&relation=beginsWith&name=Zea+mays&quantity=
```

### Sample response (Captured 2026-11-14)

HTML; matched taxa and EcoPort codes extracted from the links (markup removed):

```
Euchlaena mexicana        cropView?id=10982
Zea mays                  cropView?id=2175
Zea mays ssp. mays        cropView?id=238663
Zea mays ssp. saccharata  cropView?id=10981
```

EcoPort codes found for the reference crops with the same request: Zea mays 2175, Glycine max 1150, Triticum aestivum 2114, Medicago sativa 1428, Secale cereale 1929, Malus domestica 1407.

### Data sheet (FAO HTML)

Returns the full requirement record for one taxon as an HTML table.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `id` | yes | EcoPort code | `1407` |

```
GET https://ecocrop.apps.fao.org/ecocrop/srv/en/dataSheet?id=1407
```

### Sample response (Captured 2026-11-14)

HTML table converted to text; the "Uses" list was trimmed after the first 6 rows.

```
Malus domestica
Description
 Life form | tree | Physiology | deciduous, single stem
 Habit | erect | Category | fruits & nuts, materials, ornamentals/turf, forest/wood
 Life span | perennial | Plant attributes | grown on large scale
Ecology
                  | Optimal Min | Optimal Max | Absolute Min | Absolute Max |
 Temperat. requir.| 14 | 27 | 8 | 33        | Soil depth     | deep (>>150 cm) | medium (50-150 cm)
 Rainfall (annual)| 700 | 2500 | 500 | 3200  | Soil texture   | medium, light | heavy, medium, light
 Latitude         | 35 | 30 | 50 | 60        | Soil fertility | high | moderate
 Altitude         | --- | --- | - | 1800     | Soil salinity  | low (<4 dS/m) | low (<4 dS/m)
 Soil PH          | 6 | 7 | 4.5 | 8           | Soil drainage  | well (dry spells) | well (dry spells)
 Light intensity  | very bright | clear skies | very bright | cloudy skies
 Climate zone | subtropical humid (Cf), subtropical dry summer (Cs), subtropical dry winter (Cw), temperate oceanic (Do), temperate continental (Dc), temperate with humid winters (Df), temperate with dry winters (Dw)
 Photoperiod | short day (<12 hours), neutral day (12-14 hours), long day (>14 hours)
 Killing temp. during rest | -30 | Killing temp. early growth | -2
Cultivation
 Product. system | | Crop cycle | 180 | 320
Uses
 food & beverage | vitamins | fruits
 food & beverage | minerals | fruits
 animal food (feed) | vitamins | fruits
 animal food (feed) | minerals | fruits
 fuels | charcoal | bark
 fuels | fuelwood | bark
 ...
```

The data sheet also has a "Cropping system" table (subsystem, companion species, level of mechanization, labour intensity) and a "Uses" table (main use, detailed use, used part) that are not in the CSV.

### Full table download (OpenCLIM CSV)

One row per taxon, 55 columns, Latin-1 encoded.

| Parameter | Required | Description | Example |
|---|---|---|---|
| (none) | | Static file | |

```
GET https://raw.githubusercontent.com/OpenCLIM/ecocrop/main/EcoCrop_DB.csv
GET https://raw.githubusercontent.com/OpenCLIM/ecocrop/main/Ecocrop_variable_lookup.csv
```

### Sample rows (Captured 2026-11-14)

File size 1,622,384 bytes, 2568 rows. Trimmed: `SYNO` (synonyms) replaced by `...`; `COMNAME` cut to the first three names followed by `...`. All other values are as in the file.

```csv
EcoPortCode,ScientificName,AUTH,FAMNAME,SYNO,COMNAME,LIFO,HABI,LISPA,PHYS,CAT,PLAT,TOPMN,TOPMX,TMIN,TMAX,ROPMN,ROPMX,RMIN,RMAX,PHOPMN,PHOPMX,PHMIN,PHMAX,LATOPMN,LATOPMX,LATMN,LATMX,ALTMX,LIOPMN,LIOPMX,LIMN,LIMX,DEP,DEPR,TEXT,TEXTR,FER,FERR,TOX,TOXR,SAL,SALR,DRA,DRAR,KTMPR,KTMP,PHOTO,CLIZ,ABITOL,ABISUS,INTRI,PROSY,GMIN,GMAX
2175,Zea mays,L.,Liliopsida:Commelinidae:Cyperales:Gramineae,...,"maize, corn, Mais, ...",,,,,,,18,33,10,47,600,1200,400,1800,5,7,4.5,8.5,NA,NA,40,48,4000,very bright,very bright,clear skies,very bright,medium (50-150 cm),shallow (20-50 cm),,,high,low,,,low (<4 dS/m),medium (4-10 dS/m),,,NA,NA,,,,,,,65,365
1150,Glycine max,(L.) Merrill.,Magnoliopsida:Rosidae:Fabales:Leguminosae,...,"soya bean, soyabean, soybean, ...",herb,erect,annual,,pulses (grain legumes),grown on large scale,20,33,10,38,600,1500,450,1800,5.5,6.5,4.5,8.4,NA,NA,47,52,3000,very bright,very bright,very bright,clear skies,medium (50-150 cm),shallow (20-50 cm),"medium, organic","heavy, medium, light",high,low,,,low (<4 dS/m),medium (4-10 dS/m),well (dry spells),"poorly (saturated >50% of year), well (dry spells), excessive (dry/moderately dry)",NA,NA,short day (<12 hours),"tropical wet & dry (Aw), steppe or semiarid (Bs), subtropical dry summer (Cs)",,,,,75,180
2114,Triticum aestivum,L.,Liliopsida:Commelinidae:Cyperales:Gramineae,...,"wheat, bread wheat, blé, ...",grass,erect,annual,"single stem, C3 photosynthesis","cereals & pseudocereals, forage/pasture, medicinals & aromatic",grown on large scale,15,23,5,27,750,900,300,1600,6,7,5.5,8.5,30,NA,60,65,4500,very bright,very bright,cloudy skies,very bright,medium (50-150 cm),shallow (20-50 cm),"medium, organic","heavy, medium",high,moderate,,,low (<4 dS/m),medium (4-10 dS/m),well (dry spells),well (dry spells),-20,0,"neutral day (12-14 hours), long day (>14 hours)","tropical wet & dry (Aw), tropical wet (Ar), desert or arid (Bw), steppe or semiarid (Bs), subtropical humid (Cf), subtropical dry summer (Cs), subtropical dry winter (Cw), temperate oceanic (Do), temperate continental (Dc), temperate with humid winters (Df), temperate with dry winters (Dw)",,,,large scale/commercial,90,250
1428,Medicago sativa,L.,Magnoliopsida:Rosidae:Fabales:Leguminosae,...,"alfalfa, lucerne, common purple lucerne, ...",herb,"erect, prostrate/procumbent/semi-erect",perennial,,"forage/pasture, cover crop",grown on large scale,21,27,5,45,600,1200,350,2700,6.5,7.5,4.3,8.7,38,36,56,58,4000,very bright,very bright,very bright,cloudy skies,deep (>>150 cm),medium (50-150 cm),"medium, light","medium, light",high,low,,,low (<4 dS/m),medium (4-10 dS/m),well (dry spells),"well (dry spells), excessive (dry/moderately dry)",-25,0,"short day (<12 hours), neutral day (12-14 hours), long day (>14 hours)","steppe or semiarid (Bs), subtropical humid (Cf), subtropical dry summer (Cs), subtropical dry winter (Cw), temperate oceanic (Do), temperate continental (Dc), temperate with humid winters (Df), temperate with dry winters (Dw)",,,,large scale/commercial,100,210
1929,Secale cereale,L.,Liliopsida:Commelinidae:Cyperales:Gramineae,...,"rye, seigle, centeno, ...",grass,erect,annual,multi stem,"cereals & pseudocereals, forage/pasture, cover crop, environmental",grown on large scale,15,20,3,31,600,1000,400,2000,5.5,6,4.5,8.2,45,NA,60,70,4300,very bright,very bright,very bright,cloudy skies,medium (50-150 cm),shallow (20-50 cm),"heavy, medium, light","heavy, medium, light",moderate,low,,,low (<4 dS/m),high (>10 dS/m)),well (dry spells),"poorly (saturated >50% of year), well (dry spells), excessive (dry/moderately dry)",-18,-1,"short day (<12 hours), neutral day (12-14 hours)","steppe or semiarid (Bs), temperate oceanic (Do), temperate continental (Dc)",,,,large scale/commercial,110,270
1407,Malus domestica,Borkh.,Magnoliopsida:Rosidae:Rosales:Rosaceae,...,"apple, mela, appel",tree,erect,perennial,"deciduous, single stem","fruits & nuts, materials, ornamentals/turf, forest/wood",grown on large scale,14,27,8,33,700,2500,500,3200,6,7,4.5,8,35,30,50,60,1800,very bright,clear skies,very bright,cloudy skies,deep (>>150 cm),medium (50-150 cm),"medium, light","heavy, medium, light",high,moderate,,,low (<4 dS/m),low (<4 dS/m),well (dry spells),well (dry spells),-30,-2,"short day (<12 hours), neutral day (12-14 hours), long day (>14 hours)","subtropical humid (Cf), subtropical dry summer (Cs), subtropical dry winter (Cw), temperate oceanic (Do), temperate continental (Dc), temperate with humid winters (Df), temperate with dry winters (Dw)",,,,,180,320
```

ECOCROP has no separate winter wheat record; `Triticum aestivum` (bread wheat) is the record shown.

## Fields

Column descriptions are from `Ecocrop_variable_lookup.csv` (OpenCLIM). Units for temperature, rainfall, latitude and altitude are from the FAO ECOCROP field help pages (`helpShow?id=2000..2003`); the crop cycle unit (days) is from the Recocrop `ecocropPars` documentation.

| Field | Type | Unit | Description |
|---|---|---|---|
| `EcoPortCode` | integer | | EcoPort code; the `id` used in FAO URLs |
| `ScientificName` | string | | Scientific name |
| `AUTH` | string | | Authority |
| `FAMNAME` | string | | Family (class:subclass:order:family) |
| `SYNO` | string | | Synonyms, comma separated |
| `COMNAME` | string | | Common names in several languages, comma separated |
| `LIFO` | string (list) | | Life form (e.g. herb, grass, tree) |
| `HABI` | string (list) | | Habit (lookup says "Habitat"; FAO site labels it "Habit": erect, prostrate/procumbent/semi-erect, climber/scrambler/scadent, acaulescent) |
| `LISPA` | string (list) | | Life span (annual, biennial, perennial) |
| `PHYS` | string (list) | | Physiology (e.g. deciduous, single stem, multi stem, C3 photosynthesis) |
| `CAT` | string (list) | | Category (e.g. cereals & pseudocereals, pulses, forage/pasture, cover crop, fruits & nuts) |
| `PLAT` | string (list) | | Plant attributes (e.g. grown on large scale) |
| `TOPMN` | number | °C | Optimal minimum temperature |
| `TOPMX` | number | °C | Optimal maximum temperature |
| `TMIN` | number | °C | Absolute minimum temperature |
| `TMAX` | number | °C | Absolute maximum temperature |
| `ROPMN` | number | mm/year | Optimal minimum annual rainfall |
| `ROPMX` | number | mm/year | Optimal maximum annual rainfall |
| `RMIN` | number | mm/year | Absolute minimum annual rainfall |
| `RMAX` | number | mm/year | Absolute maximum annual rainfall |
| `PHOPMN` | number | pH | Optimal minimum soil pH |
| `PHOPMX` | number | pH | Optimal maximum soil pH |
| `PHMIN` | number | pH | Absolute minimum soil pH |
| `PHMAX` | number | pH | Absolute maximum soil pH |
| `LATOPMN` | number | degrees | Optimal minimum latitude |
| `LATOPMX` | number | degrees | Optimal maximum latitude |
| `LATMN` | number | degrees | Absolute minimum latitude |
| `LATMX` | number | degrees | Absolute maximum latitude |
| `ALTMX` | number | m above sea level | Absolute maximum altitude |
| `LIOPMN` | string | class | Optimal minimum light intensity (very bright, clear skies, cloudy skies, ...) |
| `LIOPMX` | string | class | Optimal maximum light intensity |
| `LIMN` | string | class | Absolute minimum light intensity |
| `LIMX` | string | class | Absolute maximum light intensity |
| `DEP` | string | class | Optimal soil depth: shallow (20-50 cm), medium (50-150 cm), deep (>>150 cm) |
| `DEPR` | string | class | Absolute soil depth (same classes) |
| `TEXT` | string (list) | class | Optimal soil texture: heavy, medium, light, organic |
| `TEXTR` | string (list) | class | Absolute soil texture |
| `FER` | string | class | Optimal soil fertility: low, moderate, high |
| `FERR` | string | class | Absolute soil fertility |
| `TOX` | string | class | Optimal soil aluminium toxicity |
| `TOXR` | string | class | Absolute soil aluminium toxicity |
| `SAL` | string | class | Optimal soil salinity: low (<4 dS/m), medium (4-10 dS/m), high (>10 dS/m) |
| `SALR` | string | class | Absolute soil salinity |
| `DRA` | string (list) | class | Optimal soil drainage: poorly (saturated >50% of year), well (dry spells), excessive (dry/moderately dry) |
| `DRAR` | string (list) | class | Absolute soil drainage |
| `KTMPR` | number | °C | Killing temperature during rest |
| `KTMP` | number | °C | Killing temperature early growth |
| `PHOTO` | string (list) | class | Photoperiod: short day (<12 hours), neutral day (12-14 hours), long day (>14 hours) |
| `CLIZ` | string (list) | class | Climate zone (Koppen letters in parentheses, e.g. "temperate continental (Dc)") |
| `ABITOL` | string | | Abiotic tolerance |
| `ABISUS` | string | | Abiotic susceptibility |
| `INTRI` | string | | Introduction risk |
| `PROSY` | string | | Production system (e.g. large scale/commercial) |
| `GMIN` | integer | days | Minimum crop cycle |
| `GMAX` | integer | days | Maximum crop cycle |

Missing values: numeric columns use `NA`; text columns use an empty string. On the FAO data sheet, missing killing temperatures display as "no input" and missing latitude/altitude as `-` or `---`. List-valued columns are comma-separated strings inside one CSV field.

## Notes

- The FAO site has no API, JSON or CSV export; all access on `ecocrop.apps.fao.org` is HTML pages.
- `ecocrop.review.fao.org` (the address given on the GAEZ ECOCROP page) redirected to a Google account sign-in on 2026-11-14; it was not used.
- The `Zea mays` record (2175) has empty life form, habit, life span, category, texture, drainage, photoperiod and climate zone, and `NA` killing temperatures, on both the live FAO data sheet and the CSV.
- Latitude values are stored as given; for some records the optimal range is not inside the absolute range (e.g. Malus domestica `LATOPMN`=35, `LATOPMX`=30, `LATMN`=50, `LATMX`=60). FAO help for the latitude search field says it "is new and information has not yet been entered for all plants"; the altitude help says the same.
- `SALR` for Secale cereale contains the literal value `high (>10 dS/m))` with a doubled closing parenthesis.
- The CSV is Latin-1 encoded (e.g. byte `0xE5` in "blål..."); reading it as UTF-8 produces replacement characters in `COMNAME`/`SYNO`.
- The GitHub repository `OpenCLIM/ecocrop` has no licence file (GitHub API `license: null`, 2026-11-14). FAO website content terms are on the FAO terms page linked below.
- Recocrop's `ecocrop.rds` is R-only; its documentation states that the precipitation thresholds in `ecocropPars()` are derived monthly values and the killing-temperature parameters are `KTMP-1` and `KTMP+1`, so they differ from the raw FAO columns.
- The FAO search page offers an "Available field days" input that has no corresponding column in the CSV.

## Documentation

- FAO ECOCROP application: https://ecocrop.apps.fao.org/ecocrop/srv/en/home
- FAO GAEZ ECOCROP page: https://gaez.fao.org/pages/ecocrop
- Field help pages: https://ecocrop.apps.fao.org/ecocrop/srv/en/helpShow?id=2000 (ids 2000-2015, 2050-2054)
- OpenCLIM CSV and variable lookup: https://github.com/OpenCLIM/ecocrop (paper: https://doi.org/10.1002/cli2.70007 ; Zenodo: https://zenodo.org/doi/10.5281/zenodo.10843625)
- Recocrop (CRAN, GPL >= 3): https://github.com/cropmodels/Recocrop/ ; https://cran.r-project.org/package=Recocrop
- FAO terms of use and copyright: https://www.fao.org/contact-us/terms/en/
