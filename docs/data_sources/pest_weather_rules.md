# Pest and disease weather rules on NASA POWER hourly data

Published weather thresholds for crop diseases and pests (late blight, the wheat rusts, Fusarium head blight, Asian soybean rust, gray leaf spot, northern corn leaf blight, tar spot, fall armyworm development) and the Magarey generic infection model, as stated in their sources, together with the NASA POWER hourly endpoint that supplies their inputs. The rules are reference material: each line gives the threshold exactly as the cited source states it, with its URL. The POWER hourly point API (MERRA-2 based, 0.5 x 0.625 degree grid, no login) returns hour-by-hour 2 m temperature, relative humidity, dew point, precipitation and wind for any point, keyed `YYYYMMDDHH`, in local solar time or UTC; the daily API (`nasa_power.md`) returns `T2M_MAX` and `T2M_MIN` for degree-day rules. A sample calculation at the end checks the captured data against the inputs each rule needs.

| | |
|---|---|
| Provider | Rules: the cited extension services, journals and tool factsheets. Weather: NASA Langley POWER project |
| Base URL | `https://power.larc.nasa.gov/api/temporal/hourly/point` ; `https://power.larc.nasa.gov/api/temporal/daily/point` |
| Auth | none |
| Formats | JSON (also CSV, NETCDF, ASCII); rules are published text |
| Coverage | POWER: global land and ocean; rules: crop-specific, see table |
| Resolution | POWER hourly: one value per hour per 0.5 x 0.625 degree cell (about 50 km); daily extremes from the same grid |
| Cadence / latency | POWER hourly and daily values appear 1-3 days after the date; hourly series start in 2001 per the POWER documentation (not re-read today) |
| Rate limits / quotas | POWER: not published; up to 20 parameters per request; the captured 2-day hourly request took 0.56 s server time |
| Licence | POWER data: NASA, free and open, no restrictions (header says "POWER Hourly API"; terms from the inventory). Rules: facts from the cited publications; the Magarey 2005 article and its Table 2 are copyright APS (inventory), the model formula is reproducible |
| Documentation | https://power.larc.nasa.gov/docs/services/api/temporal/hourly/ ; https://power.larc.nasa.gov/parameters/ ; rule sources in the table |

## Weather rule reference

All thresholds are quoted from the inventory's verified sources; none has been altered or re-derived. Temperatures in degC unless the source wrote Fahrenheit (both given). "Free moisture" and "leaf wetness" are the sources' words.

| Threat | Crop | Rule as published | Inputs | Source |
|---|---|---|---|---|
| Late blight, Hutton criteria | Potato | Two consecutive days, each with minimum temperature >= 10 degC and at least 6 hours with relative humidity >= 90% | Hourly RH, daily Tmin | AHDB: https://potatoes.ahdb.org.uk/knowledge-library/late-blight-disease-and-its-management-in-potatoes ; IPM Decisions factsheet: https://www.ipmdecisions.net/documents/factsheet-hutton-criteria-late-blight-model/ |
| Stripe (yellow) rust | Wheat | Infection optimum 45-54 degF (7-12 degC) with 8 h of free moisture; urediniospore germination minimum / optimum / maximum 0 / 7-12 / 20-26 degC | Hourly T and wetness | UNL G2180: https://extensionpublications.unl.edu/assets/html/g2180/build/g2180.htm ; Chen 2014: https://bsppjournals.onlinelibrary.wiley.com/doi/10.1111/mpp.12116 |
| Leaf rust | Wheat | 59-68 degF (15-20 degC) and at least 6 h of free moisture | Hourly T and wetness | UNL G2180 (above) |
| Stem rust | Wheat | 59-84 degF (15-29 degC) and 6-8 h of free moisture | Hourly T and wetness | UNL G2180 (above) |
| Fusarium head blight, De Wolf model | Wheat, barley | Hours at 15-30 degC with RH >= 90% during the 10 days after anthesis (variable TRH9010); pre-anthesis variants use hours at 15-30 degC and hours of rain in the 7 days before anthesis | Hourly T, RH, rain; anthesis date | De Wolf et al. 2003: https://pubmed.ncbi.nlm.nih.gov/18944357/ ; review Matengu 2024: https://bsppjournals.onlinelibrary.wiley.com/doi/10.1111/ppa.13839 |
| Asian soybean rust | Soybean | Leaves wet at 8-28 degC (optimum 16-28 degC); at 25 degC some infection after 6 h of wetness, 12 h optimal | Hourly T and wetness | APS lesson: https://www.apsnet.org/edcenter/pdlessons/Pages/SoybeanRust.aspx |
| Gray leaf spot | Maize | 77-88 degF (25-31 degC); 11-13 h of dew or fog, or canopy RH > 90% for 12 h | Hourly T, RH | Iowa State: https://crops.extension.iastate.edu/post/update-corn-diseases-and-fungicide-decisions-iowa |
| Northern corn leaf blight | Maize | 65-75 degF (18-24 degC); more than 6 h of leaf wetness | Hourly T and wetness | Iowa State (above) |
| Tar spot | Maize | 30-day mean temperature 18-23 degC most predictive; long spells of RH > 90% were negatively associated. Older guidance: RH > 75%, 7 h of wetness per night | Daily T (30-day moving mean), hourly RH | Scientific Reports 2023: https://www.nature.com/articles/s41598-023-44338-6 |
| Fall armyworm development | Maize and others | du Plessis et al. 2020 (Table 3): egg-to-adult lower threshold 12.57 degC and 391 degree-days; per stage eggs 13.01, larvae 12.12, pupae 13.06 degC. Malekera et al. 2022: linear model 9.73 degC and 490 degree-days (Table 6); Shi nonlinear model egg-to-adult lower 13.51 degC, upper 34.13 degC. Published lower thresholds range 7.4-13.8 degC | Daily Tmin, Tmax | https://doi.org/10.3390/insects11040228 ; https://www.mdpi.com/2075-4450/13/12/1084 ; range: https://www.mpi.govt.nz/dmsdocument/45937-Pest-Risk-Assessment-Spodoptera-frugiperda-Fall-Armyworm |
| Generic infection model, Magarey et al. 2005 | Any foliar fungal pathogen with cardinal temperatures | Wetness duration required for infection W(T) = Wmin / f(T), bounded above by Wmax, where f(T) = ((Tmax - T) / (Tmax - Topt)) x ((T - Tmin) / (Topt - Tmin)) ^ ((Topt - Tmin) / (Tmax - Topt)) for Tmin < T < Tmax and 0 otherwise; infection when the observed wetness duration at mean temperature T reaches W(T) | Hourly T and wetness; per-pathogen Tmin, Topt, Tmax, Wmin, Wmax | APS case study: https://www.apsnet.org/edcenter/sites/EcologyAndEpidemiologyInR/DiseaseForecasting/Pages/CaseStudy1SimpleGenericInfectionModel.aspx ; R implementation: https://search.r-project.org/CRAN/refmans/ZeBook/html/magarey.model.html ; https://r4pde.net/prediction-disease-modeling |
| Rice blast; rice sheath blight; desert locust breeding vs soil moisture; whitefly and begomovirus | Rice; multiple | Not verified in the inventory pass: no rule recorded | | none |

The per-pathogen cardinal temperatures that the Magarey model needs are the content of the Togashi dataset (`thermal_tolerance_datasets.md`); the model's own Table 2 (Wmin, Wmax per pathogen) is under APS copyright per the inventory and is not reproduced here.

## Requests

### Hourly point (NASA POWER)

| Parameter | Required | Description | Example |
|---|---|---|---|
| `parameters` | yes | Comma-separated codes, up to 20 | `T2M,RH2M,PRECTOTCORR,T2MDEW,WS2M` |
| `community` | yes | `AG` (agroclimatology units) | `AG` |
| `latitude`, `longitude` | yes | WGS84 decimal degrees | `40.95`, `-97.50` |
| `start`, `end` | yes | `YYYYMMDD` | `20250701`, `20250702` |
| `format` | no | `JSON` (default), `CSV`, `NETCDF`, `ASCII` | `JSON` |
| `time-standard` | no | `LST` (local solar time, default) or `UTC` | `LST` |

```
GET https://power.larc.nasa.gov/api/temporal/hourly/point?parameters=T2M,RH2M,PRECTOTCORR,T2MDEW,WS2M&community=AG&latitude=40.95&longitude=-97.50&start=20250701&end=20250702&format=JSON&time-standard=LST
```

### Sample response (Captured 2026-11-15)

5,188 bytes, 48 hours x 5 parameters. Trimmed to the first six hours of 2025-07-01 and the hours 02 to 07 of 2025-07-02 (the humid pre-dawn spell), all other hours removed; `header`, `parameters` and `times` untrimmed.

```json
{
  "type": "Feature",
  "geometry": { "type": "Point", "coordinates": [-97.5, 40.95, 491.1] },
  "properties": { "parameter": {
    "T2M":         { "2025070100": 20.09, "2025070101": 19.74, "2025070102": 18.98, "2025070103": 18.07, "2025070104": 17.34, "2025070105": 17.44,
                     "2025070202": 19.02, "2025070203": 18.62, "2025070204": 18.53, "2025070205": 18.98, "2025070206": 20.18, "2025070207": 22.44 },
    "RH2M":        { "2025070100": 67.89, "2025070101": 67.67, "2025070102": 69.78, "2025070103": 72.79, "2025070104": 74.99, "2025070105": 77.83,
                     "2025070202": 78.14, "2025070203": 83.65, "2025070204": 86.58, "2025070205": 87.12, "2025070206": 85.64, "2025070207": 80.77 },
    "PRECTOTCORR": { "2025070100": 0.0,   "2025070101": 0.0,   "2025070102": 0.0,   "2025070103": 0.0,   "2025070104": 0.0,   "2025070105": 0.0,
                     "2025070202": 1.6,   "2025070203": 2.37,  "2025070204": 2.02,  "2025070205": 0.7,   "2025070206": 0.04,  "2025070207": 0.01 },
    "T2MDEW":      { "2025070100": 14.01, "2025070101": 13.62, "2025070102": 13.36, "2025070103": 13.14, "2025070104": 12.89, "2025070105": 13.55,
                     "2025070202": 15.16, "2025070203": 15.83, "2025070204": 16.26, "2025070205": 16.82, "2025070206": 17.72, "2025070207": 18.99 },
    "WS2M":        { "2025070100": 0.94,  "2025070101": 0.95,  "2025070102": 1.04,  "2025070103": 1.09,  "2025070104": 1.11,  "2025070105": 0.98,
                     "2025070202": 2.05,  "2025070203": 1.98,  "2025070204": 2.04,  "2025070205": 2.53,  "2025070206": 3.21,  "2025070207": 3.16 }
  } },
  "header": {
    "title": "NASA/POWER Source Native Resolution Hourly Data",
    "api": { "version": "v2.10.4", "name": "POWER Hourly API" },
    "sources": ["MERRA2", "POWER"], "fill_value": -999.0, "time_standard": "LST",
    "start": "20250701", "end": "20250702"
  },
  "messages": [],
  "parameters": {
    "T2M":         { "units": "C",       "longname": "Temperature at 2 Meters" },
    "RH2M":        { "units": "%",       "longname": "Relative Humidity at 2 Meters" },
    "PRECTOTCORR": { "units": "mm/hour", "longname": "Precipitation Corrected" },
    "T2MDEW":      { "units": "C",       "longname": "Dew/Frost Point at 2 Meters" },
    "WS2M":        { "units": "m/s",     "longname": "Wind Speed at 2 Meters" }
  },
  "times": { "data": 0.562, "process": 0.03 }
}
```

Shape notes: keys are `YYYYMMDDHH` with `HH` 00-23; `header.time_standard` echoes the request. Hourly `PRECTOTCORR` is in mm/hour (the daily API gives mm/day): the 24 hourly values of 2025-07-02 sum to 7.48 mm against 7.47 mm in the daily sample of `nasa_power.md`. The 2 m dew point is a separate parameter (`T2MDEW`); POWER publishes no leaf wetness or canopy humidity variable.

### Hourly point in UTC (Captured 2026-11-15)

Same point and 2025-07-01, `parameters=T2M`, `time-standard=UTC` (914 bytes, trimmed to the first eight hours):

```json
{ "properties": { "parameter": { "T2M": {
  "2025070100": 25.84, "2025070101": 23.0, "2025070102": 21.03, "2025070103": 20.46,
  "2025070104": 20.2,  "2025070105": 20.2, "2025070106": 20.09, "2025070107": 19.74 } } },
  "header": { "time_standard": "UTC" } }
```

`time-standard` is honoured: the LST hour `2025070100` (20.09 degC) is the UTC hour `2025070106`, a 6-hour offset for longitude -97.5.

### Daily extremes (NASA POWER)

```
GET https://power.larc.nasa.gov/api/temporal/daily/point?parameters=T2M_MAX,T2M_MIN,T2M,RH2M&community=AG&latitude=40.95&longitude=-97.50&start=20250701&end=20250702&format=JSON
```

### Sample response (Captured 2026-11-15)

840 bytes; `header` and `parameters` removed (same structure as `nasa_power.md`).

```json
{ "properties": { "parameter": {
  "T2M_MAX": { "20250701": 30.17, "20250702": 32.53 },
  "T2M_MIN": { "20250701": 17.34, "20250702": 18.53 },
  "T2M":     { "20250701": 24.11, "20250702": 25.78 },
  "RH2M":    { "20250701": 57.06, "20250702": 67.25 }
} } }
```

The daily `T2M_MAX` and `T2M_MIN` equal the maximum and minimum of the 24 hourly `T2M` values of each day in this capture (30.17 / 17.34 and 32.53 / 18.53).

## Sample calculation on the captured data

A check of the data shape against the inputs the rules name, computed from the captured hourly and daily values for 40.95, -97.50. It is not a product rule and says nothing about actual disease or pest pressure at the site.

| Date (LST) | Hours with RH2M >= 90% | Maximum hourly RH2M (%) | Hours with RH2M >= 80% | Minimum hourly T2M (degC) | Daily T2M_MIN (degC) | Hutton day (Tmin >= 10 and >= 6 h RH >= 90)? |
|---|---|---|---|---|---|---|
| 2025-07-01 | 0 | 77.83 | 0 | 17.34 | 17.34 | no (humidity condition not met) |
| 2025-07-02 | 0 | 87.12 | 5 (02:00-06:00 to 07:00) | 18.53 | 18.53 | no (humidity condition not met) |

Simple-average degree-days per day, DD = max(0, (T2M_MAX + T2M_MIN) / 2 - base), for the fall armyworm lower thresholds in the table:

| Date | T2M_MAX | T2M_MIN | Mean (degC) | DD, base 12.57 (du Plessis 2020) | DD, base 9.73 (Malekera 2022 linear) | DD, base 13.51 (Malekera 2022 Shi) |
|---|---|---|---|---|---|---|
| 2025-07-01 | 30.17 | 17.34 | 23.76 | 11.19 | 14.03 | 10.25 |
| 2025-07-02 | 32.53 | 18.53 | 25.53 | 12.96 | 15.80 | 12.02 |

Hourly rain on 2025-07-02 fell between 00:00 and 13:00 LST (7.48 mm in total, 2.37 mm in the 03:00 hour), which is the kind of input the pre-anthesis De Wolf variant ("hours of rain") counts; the captured window is too short for a 7- or 10-day accumulation, and no anthesis date applies to a bare point.

## Fields

### POWER hourly parameters used by the rules

| Field | Type | Unit | Description |
|---|---|---|---|
| `T2M` | number | degC | Air temperature at 2 m, hourly mean |
| `RH2M` | number | % | Relative humidity at 2 m |
| `T2MDEW` | number | degC | Dew or frost point at 2 m |
| `PRECTOTCORR` | number | mm/hour | Bias-corrected total precipitation for the hour |
| `WS2M` | number | m/s | Wind speed at 2 m |
| `T2M_MAX`, `T2M_MIN` (daily API) | number | degC | Daily maximum and minimum 2 m temperature |
| `header.time_standard` | string | | `LST` or `UTC`, as requested |
| `header.fill_value` | number | | `-999.0` marks missing hours |

### Rule inputs and their POWER proxy

| Rule input (source wording) | Direct POWER variable | Proxy named by the rule sources |
|---|---|---|
| Relative humidity >= 90% hours (Hutton, De Wolf, gray leaf spot) | `RH2M` hourly | none needed |
| Minimum daily temperature (Hutton) | `T2M_MIN` daily or min of hourly `T2M` | none needed |
| Hours at a temperature range (rusts, FHB, GLS, NCLB, soybean rust) | `T2M` hourly | none needed |
| Hours of free moisture or leaf wetness (rusts, NCLB, soybean rust, Magarey) | none: POWER publishes no leaf wetness | Not specified by the cited sources; the Hutton and gray leaf spot sources use RH >= 90% as their humidity criterion, and the Iowa State text names "dew or fog" alongside RH > 90% for gray leaf spot only |
| Hours of rain (De Wolf pre-anthesis) | `PRECTOTCORR` hourly > 0 | none needed |
| Daily Tmin, Tmax (fall armyworm degree-days) | `T2M_MIN`, `T2M_MAX` daily | none needed |
| 30-day mean temperature (tar spot) | `T2M` daily, averaged | none needed |

## Licence

- **NASA POWER:** free and open NASA data with no restrictions (inventory: "POWER: hourly and daily, no restrictions"; POWER's own terms not re-read today). Attribution to the POWER project is requested in its documentation.
- **Rule thresholds:** facts quoted from the cited extension bulletins (University of Nebraska-Lincoln, Iowa State), AHDB, the IPM Decisions factsheet, the APS Education Center lesson and open-access journals (Insects 2020 and 2022 are MDPI open access; Scientific Reports 2023 is open access). The De Wolf 2003 and Magarey 2005 articles are copyright APS; their formulas and thresholds are cited, not reproduced beyond the parameters above. From the inventory, not re-read today.
- **Magarey Table 2 (per-pathogen Wmin, Wmax):** rights unknown per the inventory; not included.

## Overlap with NASA sources

- Every meteorological input named by these rules is served by NASA POWER: hourly `T2M`, `RH2M`, `T2MDEW`, `PRECTOTCORR`, `WS2M` and daily `T2M_MAX`, `T2M_MIN`, `PRECTOTCORR`, `RH2M`. No other provider is needed for the weather side; Daymet and PRISM (`daymet.md`, `prism.md`) offer finer daily grids over North America but no hourly humidity.
- What NASA does not publish, and these rules add, is the organism side: the threshold values, the hours required and the degree-day totals. The species parameters they depend on come from the Togashi dataset and DDRP files (`thermal_tolerance_datasets.md`).
- POWER's limits for this use: one value per 50 km cell, so neighbouring fields share the same hours; no leaf wetness or canopy humidity, so the "free moisture" rules have no direct variable; hourly values for the trailing days can be revised (re-fetch the last 7 days); the record starts in 2001 for hourly data.
- GPM IMERG (`gpm_imerg.md`) gives 30-minute precipitation at 0.1 degree for the rain-hours inputs if finer rainfall is wanted; it adds nothing for temperature or humidity.

## Notes

- The rule table reproduces the inventory's verified thresholds; where a source gives Fahrenheit, the Celsius conversion is the one printed by the inventory.
- Fall armyworm lower thresholds differ between studies (7.4 to 13.8 degC across the literature per the New Zealand MPI assessment); the table lists three published values and the calculation shows all three.
- The Magarey formula is written as implemented in the ZeBook R package (`magarey.model`) and the APS case study; both describe f(T) as a beta function of the cardinal temperatures and cap W(T) at Wmax.
- POWER hourly requests: the two-day request returned in 0.56 s of server data time; `fill_value` is `-999.0`; the hourly `community=AG` request accepted `time-standard` as a query parameter with a hyphen.
- The captured days (1-2 July 2025) met neither the Hutton humidity condition nor a six-hour spell at RH >= 90%; this is a property of those two days, not of the method.
- Rules for rice blast, rice sheath blight, desert locust and whitefly were not verified by the inventory and are absent here.

## Documentation

- POWER hourly API: https://power.larc.nasa.gov/docs/services/api/temporal/hourly/
- POWER parameter dictionary: https://power.larc.nasa.gov/parameters/
- POWER methodology: https://power.larc.nasa.gov/docs/methodology/
- Hutton criteria: https://potatoes.ahdb.org.uk/knowledge-library/late-blight-disease-and-its-management-in-potatoes ; https://www.ipmdecisions.net/documents/factsheet-hutton-criteria-late-blight-model/
- Wheat rusts: University of Nebraska-Lincoln G2180, https://extensionpublications.unl.edu/assets/html/g2180/build/g2180.htm ; Chen 2014, Molecular Plant Pathology 15:433, https://doi.org/10.1111/mpp.12116
- Fusarium head blight: De Wolf, Madden and Lipps 2003, Phytopathology 93:428, https://pubmed.ncbi.nlm.nih.gov/18944357/ ; Matengu et al. 2024, Plant Pathology, https://doi.org/10.1111/ppa.13839
- Asian soybean rust: https://www.apsnet.org/edcenter/pdlessons/Pages/SoybeanRust.aspx
- Gray leaf spot and northern corn leaf blight: https://crops.extension.iastate.edu/post/update-corn-diseases-and-fungicide-decisions-iowa
- Tar spot: https://www.nature.com/articles/s41598-023-44338-6
- Fall armyworm: du Plessis et al. 2020, Insects 11:228, https://doi.org/10.3390/insects11040228 ; Malekera et al. 2022, Insects 13:1084, https://www.mdpi.com/2075-4450/13/12/1084 ; New Zealand MPI pest risk assessment, https://www.mpi.govt.nz/dmsdocument/45937-Pest-Risk-Assessment-Spodoptera-frugiperda-Fall-Armyworm
- Magarey generic infection model: https://www.apsnet.org/edcenter/sites/EcologyAndEpidemiologyInR/DiseaseForecasting/Pages/CaseStudy1SimpleGenericInfectionModel.aspx ; https://search.r-project.org/CRAN/refmans/ZeBook/html/magarey.model.html ; https://r4pde.net/prediction-disease-modeling
