# FAO-56 crop tables (FAO Irrigation and Drainage Paper No. 56)

FAO Irrigation and Drainage Paper No. 56, "Crop evapotranspiration: Guidelines for computing crop water requirements" (Allen, Pereira, Raes and Smith; FAO, Rome, 1998; ISBN 92-5-104219-5), publishes per-crop tables used with the FAO Penman-Monteith reference evapotranspiration (ETo): lengths of the four growth stages (Table 11), single crop coefficients Kc ini / Kc mid / Kc end and maximum crop height (Table 12), basal crop coefficients Kcb (Table 17), maximum effective rooting depth and soil water depletion fraction p (Table 22), and salt tolerance (Table 23). The tables are static published values for crop groups and example regions, not spatial or time-series data. They are distributed as HTML pages and a PDF; there is no API.

| | |
|---|---|
| Provider | FAO (Food and Agriculture Organization of the United Nations) |
| Base URL | `https://www.fao.org/3/x0490e/` (redirects to `https://www.fao.org/4/x0490e/`) |
| Auth | none |
| Formats | HTML (one page per chapter); PDF via FAO Open Knowledge Repository |
| Coverage | about 100 crops grouped a. to o. (small vegetables, legumes, cereals, forages, fruit trees, etc.); example regions worldwide for stage lengths |
| Resolution | one row per crop (or crop sub-type / management variant) |
| Cadence / latency | static (published 1998) |
| Rate limits / quotas | not published |
| Documentation | https://www.fao.org/3/x0490e/x0490e00.htm |

### Table locations

| Table | Content | Page |
|---|---|---|
| Table 11 | Lengths of crop development stages for various planting periods and climatic regions (days) | `x0490e0b.htm` (Chapter 6) |
| Table 12 | Single (time-averaged) crop coefficients Kc and mean maximum plant heights, subhumid climate (RHmin about 45%, u2 about 2 m/s) | `x0490e0b.htm` (Chapter 6) |
| Table 17 | Basal crop coefficients Kcb, same climate conditions | `x0490e0c.htm` (Chapter 7) |
| Table 22 | Ranges of maximum effective rooting depth (Zr) and soil water depletion fraction for no stress (p) | `x0490e0e.htm` (Chapter 8) |
| Table 23 | Salt tolerance: ECe threshold, slope b, rating | `x0490e0e.htm` (Chapter 8) |

## Requests

### Chapter 6 page (Tables 11 and 12)

Static HTML page containing Tables 11 to 16 and their footnotes.

| Parameter | Required | Description | Example |
|---|---|---|---|
| (none) | | Static page | |

```
GET https://www.fao.org/3/x0490e/x0490e0b.htm
```

### Sample rows: Table 11, lengths of growth stages (Captured 2026-11-14)

Values copied from the HTML table; only rows for the reference crops are shown. Superscript footnote numbers are shown after a space (e.g. `20 2` = 20, footnote 2).

| Crop | Init. (L ini) | Dev. (L dev) | Mid (L mid) | Late (L late) | Total | Plant date | Region |
|---|---|---|---|---|---|---|---|
| Soybeans | 15 | 15 | 40 | 15 | 85 | Dec | Tropics |
| Soybeans | 20 | 30/35 | 60 | 25 | 140 | May | Central USA |
| Soybeans | 20 | 25 | 75 | 30 | 150 | June | Japan |
| Winter Wheat | 20 2 | 60 2 | 70 | 30 | 180 | December | Calif., USA |
| Winter Wheat | 30 | 140 | 40 | 30 | 240 | November | Mediterranean |
| Winter Wheat | 160 | 75 | 75 | 25 | 335 | October | Idaho, USA |
| Maize (grain) | 30 | 50 | 60 | 40 | 180 | April | East Africa (alt.) |
| Maize (grain) | 25 | 40 | 45 | 30 | 140 | Dec/Jan | Arid Climate |
| Maize (grain) | 20 | 35 | 40 | 30 | 125 | June | Nigeria (humid) |
| Maize (grain) | 20 | 35 | 40 | 30 | 125 | October | India (dry, cool) |
| Maize (grain) | 30 | 40 | 50 | 30 | 150 | April | Spain (spr, sum.); Calif. |
| Maize (grain) | 30 | 40 | 50 | 50 | 170 | April | Idaho, USA |
| Alfalfa, total season 4 | 10 | 30 | var. | var. | var. | | last -4°C in spring until first -4°C in fall |
| Alfalfa 4 1st cutting cycle | 10 | 20 | 20 | 10 | 60 | Jan Apr (last -4°C) | Calif., USA. |
| Alfalfa 4 1st cutting cycle | 10 | 30 | 25 | 10 | 75 | | Idaho, USA. |
| Alfalfa 4, other cutting cycles | 5 | 10 | 10 | 5 | 30 | Mar | Calif., USA. |
| Alfalfa 4, other cutting cycles | 5 | 20 | 10 | 10 | 45 | Jun | Idaho, USA. |
| Deciduous Orchard | 20 | 70 | 90 | 30 | 210 | March | High Latitudes |
| Deciduous Orchard | 20 | 70 | 120 | 60 | 270 | March | Low Latitudes |
| Deciduous Orchard | 30 | 50 | 130 | 30 | 240 | March | Calif., USA |

Table 11 footnote 2 (winter wheat) states: these periods "will lengthen in frozen climates according to days having zero growth potential and wheat dormancy". The same footnote gives presumed planting triggers: winter wheat fall planting when the 10-day running mean air temperature decreases to 17 °C or December 1, whichever comes first; spring wheat when it increases to 5 °C; spring maize-grain when it increases to 13 °C. Footnote 4 gives the alfalfa season in killing-frost climates as last -4 °C in spring until first -4 °C in fall.

### Sample rows: Table 12, single crop coefficients and maximum height (Captured 2026-11-14)

Kc ini is printed only on group rows and on some crop rows. FAO-56 Chapter 6 states: "For several group types only one value for K c ini is listed and it is considered to be representative of the whole group". Group rows are included below for that reason.

| Crop | Kc ini | Kc mid | Kc end | Max crop height h (m) |
|---|---|---|---|---|
| e. Legumes (Leguminosae) (group row) | 0.4 | 1.15 | 0.55 | |
| Soybeans | | 1.15 | 0.50 | 0.5-1.0 |
| i. Cereals (group row) | 0.3 | 1.15 | 0.4 | |
| Spring Wheat | | 1.15 | 0.25-0.4 10 | 1 |
| Winter Wheat - with frozen soils | 0.4 | 1.15 | 0.25-0.4 10 | 1 |
| Winter Wheat - with non-frozen soils | 0.7 | 1.15 | 0.25-0.4 10 | |
| Maize, Field (grain) (field corn) | | 1.20 | 0.60-0.35 11 | 2 |
| Alfalfa Hay - averaged cutting effects | 0.40 | 0.95 13 | 0.90 | 0.7 |
| Alfalfa Hay - individual cutting periods | 0.40 14 | 1.20 14 | 1.15 14 | 0.7 |
| Alfalfa Hay - for seed | 0.40 | 0.50 | 0.50 | 0.7 |
| Apples, Cherries, Pears 19 - no ground cover, killing frost | 0.45 | 0.95 | 0.70 18 | 4 |
| Apples, Cherries, Pears 19 - no ground cover, no frosts | 0.60 | 0.95 | 0.75 18 | 4 |
| Apples, Cherries, Pears 19 - active ground cover, killing frost | 0.50 | 1.20 | 0.95 18 | 4 |
| Apples, Cherries, Pears 19 - active ground cover, no frosts | 0.80 | 1.20 | 0.85 18 | 4 |

Table 12 footnotes used above: 10 "The higher value is for hand-harvested crops"; 11 first Kc end is for harvest at high grain moisture, second for harvest after complete field drying of the grain (to about 18% moisture, wet mass basis); 13 overall average Kc mid for hay crops averaging before and following cuttings; 14 values immediately following cutting, at full cover, and immediately before cutting; 18 Kc end values are prior to leaf drop (after leaf drop, Kc end about 0.20 for bare, dry soil or dead ground cover and about 0.50 to 0.80 for actively growing ground cover); 19 refer to Eq. 94, 97 or 98 for immature stands.

### Rows used by config/crops/agronomy.yml (Captured 2026-11-15)

Read from `x0490e0b.htm` (Tables 11 and 12) for the catalog crops. In Table 12 the "Kc ini" of most rows is printed in an image, so a blank initial takes the crop group row (as the maize row does). Where a value is printed as a range, `agronomy.yml` uses its midpoint, or the dry-harvest end for grain legumes, and each `row` text says which.

| Crop (Table 12 row) | Kc ini (group) | Kc mid | Kc end | Table 11 row: Init / Dev / Mid / Late, plant date, region |
|---|---|---|---|---|
| Sorghum (grain) | 0.3 (cereals) | 1.00-1.10 | 0.55 | 20 / 35 / 40 / 30, May/June, USA |
| Spring Wheat | 0.3 (cereals) | 1.15 | 0.25-0.4 | 20 / 25 / 60 / 30, March/April, 35-45 degrees latitude |
| Oats | 0.3 (cereals) | 1.15 | 0.25 | 20 / 25 / 60 / 30, March/April, 35-45 degrees latitude |
| Barley | 0.3 (cereals) | 1.15 | 0.25 | 20 / 25 / 60 / 30, March/April, 35-45 degrees latitude |
| Rice | 1.05 | 1.20 | 0.90-0.60 | 30 / 30 / 80 / 40, May, Tropics |
| Millet | 0.3 (cereals) | 1.00 | 0.30 | 20 / 30 / 55 / 35, April, Central USA |
| Beans, dry | 0.4 | 1.15 | 0.35 | 20 / 30 / 40 / 20, May/June, continental climates |
| Groundnut | 0.4 (legumes) | 1.15 | 0.60 | 35 / 45 / 35 / 25, May/June, Mediterranean |
| Peas, dry | 0.4 (legumes) | 1.15 | 0.30 | 15 / 25 / 35 / 15, May, Europe |
| Cowpeas | 0.4 (legumes) | 1.05 | 0.60-0.35 | 20 / 30 / 30 / 20, March, Mediterranean |
| Potato | 0.5 (roots and tubers) | 1.15 | 0.75 | 25 / 30 / 45 / 30, April, Europe |
| Tomato | 0.6 (solanum) | 1.15 | 0.70-0.90 | 35 / 40 / 50 / 30, April/May, California |
| Sunflower | 0.35 (oil crops) | 1.0-1.15 | 0.35 | 25 / 35 / 45 / 25, April/May, Mediterranean and California |
| Cabbage | 0.7 (small vegetables) | 1.05 | 0.95 | 40 / 60 / 50 / 15, September, California desert |
| Sweet potato | 0.5 (roots and tubers) | 1.15 | 0.65 | 20 / 30 / 60 / 40, April, Mediterranean |
| Onions, dry | 0.7 (small vegetables) | 1.05 | 0.75 | 15 / 25 / 70 / 40, April, Mediterranean |
| Sugar Beet | 0.35 | 1.20 | 0.70 | 30 / 45 / 90 / 15, March, California |
| Cotton | 0.35 (fibre crops) | 1.15-1.20 | 0.70-0.50 | 30 / 50 / 60 / 55, March-May, Egypt, Pakistan and California |

Not used: chick pea and canola have no Table 11 row; sugarcane, cassava, coffee and alfalfa are perennial or planted with the rains, so the single-season model does not fit them.

Table 11 rows are northern-hemisphere plantings. `Crops::WaterNeed` moves the default planting month by six months south of 15 degrees S; a farmer's own planting month always wins.

### Chapter 7 page (Table 17)

```
GET https://www.fao.org/3/x0490e/x0490e0c.htm
```

### Sample rows: Table 17, basal crop coefficients Kcb (Captured 2026-11-14)

| Crop | Kcb ini | Kcb mid | Kcb end |
|---|---|---|---|
| e. Legumes (Leguminosae) (group row) | 0.15 | 1.10 | 0.50 |
| Soybeans | | 1.10 | 0.30 |
| i. Cereals (group row) | 0.15 | 1.10 | 0.25 |
| Spring Wheat | | 1.10 | 0.15-0.3 10 |
| Winter Wheat | 0.15-0.5 11 | 1.10 | 0.15-0.3 10 |
| Maize - Field (grain) (field corn) | 0.15 | 1.15 | 0.50, 0.15 12 |
| Alfalfa Hay - individual cutting periods | 0.30 14 | 1.15 14 | 1.10 14 |
| Alfalfa Hay - for seed | 0.30 | 0.45 | 0.45 |
| Apples, Cherries, Pears 20 - no ground cover, killing frost | 0.35 | 0.90 | 0.65 19 |
| Apples, Cherries, Pears 20 - no ground cover, no frosts | 0.50 | 0.90 | 0.70 19 |
| Apples, Cherries, Pears 20 - active ground cover, killing frost | 0.45 | 1.15 | 0.90 19 |
| Apples, Cherries, Pears 20 - active ground cover, no frosts | 0.75 | 1.15 | 0.80 19 |

Table 17 footnote 1: Kcb values represent a dry soil surface and are for use with the dual Kcb + Ke approach only; maximum crop height is taken from Table 12. Footnote 11: the two winter wheat Kcb ini values are for less than 10% ground cover and for the dormant winter period if vegetation fully covers the ground but conditions are non-frozen. Footnote 19: after leaf drop, Kcb end about 0.15 for bare, dry soil or dead ground cover and about 0.45 to 0.75 for actively growing ground cover.

### Chapter 8 page (Tables 22 and 23)

```
GET https://www.fao.org/3/x0490e/x0490e0e.htm
```

### Sample rows: Table 22, rooting depth and depletion fraction (Captured 2026-11-14)

| Crop | Maximum root depth 1 (m) | Depletion fraction 2 p (for ET about 5 mm/day) |
|---|---|---|
| Soybeans | 0.6-1.3 | 0.50 |
| Spring Wheat | 1.0-1.5 | 0.55 |
| Winter Wheat | 1.5-1.8 | 0.55 |
| Maize, Field (grain) (field corn) | 1.0-1.7 | 0.55 |
| Alfalfa - for hay | 1.0-2.0 | 0.55 |
| Alfalfa - for seed | 1.0-3.0 | 0.60 |
| Apples, Cherries, Pears | 1.0-2.0 | 0.50 |

Table 22 footnote 1: the larger Zr values are for soils with no significant layering or other characteristics restricting rooting depth; the smaller values may be used for irrigation scheduling and the larger for modelling soil water stress or rainfed conditions. Footnote 2: p applies for ETc about 5 mm/day and can be adjusted as `p = p_table22 + 0.04 (5 - ETc)`, p as a fraction and ETc in mm/day.

### Sample rows: Table 23, salt tolerance (Captured 2026-11-14)

| Crop | ECe threshold (dS/m) | b (%/dS/m) | Rating |
|---|---|---|---|
| Soybeans | 5.0 | 20.0 | MT |
| Maize | 1.7 | 12.0 | MS |
| Wheat (Triticum aestivum) | 6.0 | 7.1 | MT |
| Alfalfa | 2.0 | 7.3 | MS |
| Deciduous orchard - Apples | - | - | S |

Table 23 footnotes: ECe threshold is the average root zone salinity at which yield starts to decline, measured as electrical conductivity of the saturation extract in dS/m at 25 °C; b is the percentage yield reduction per 1 dS/m increase beyond the threshold; ratings T = Tolerant, MT = Moderately Tolerant, MS = Moderately Sensitive, S = Sensitive. Primary sources cited: FAO Irrigation and Drainage Papers No. 29 and No. 48.

## Fields

| Field | Type | Unit | Description |
|---|---|---|---|
| Crop | string | | Crop name as printed, with management variant on indented "-" rows; group rows start with a letter (a. to o.) |
| L ini | integer | days | Length of initial stage (Table 11) |
| L dev | integer | days | Length of crop development stage (Table 11) |
| L mid | integer | days | Length of mid-season stage (Table 11) |
| L late | integer | days | Length of late season stage (Table 11) |
| Total | integer | days | Total growing period (Table 11) |
| Plant date | string | month | Planting month for the example (Table 11) |
| Region | string | | Climatic region or location of the example (Table 11) |
| Kc ini | number or range | dimensionless | Single crop coefficient, initial stage (Table 12) |
| Kc mid | number or range | dimensionless | Single crop coefficient, mid-season stage (Table 12) |
| Kc end | number or range | dimensionless | Single crop coefficient at end of late season (Table 12) |
| h | number or range | m | Mean maximum plant height (Table 12) |
| Kcb ini / Kcb mid / Kcb end | number or range | dimensionless | Basal crop coefficients for the dual coefficient method (Table 17) |
| Zr | range | m | Maximum effective rooting depth (Table 22) |
| p | number | fraction | Soil water depletion fraction for no stress, at ETc about 5 mm/day (Table 22) |
| ECe threshold | number | dS/m | Root zone salinity at which yield starts to decline (Table 23) |
| b | number | % per dS/m | Yield reduction slope beyond the threshold (Table 23) |
| Rating | string | class | T, MT, MS, S (Table 23) |

Blank cells: Kc ini, Kcb ini and h are blank on many crop rows (group value or value on another row applies as described in the text). Ranges are written `a-b`; some cells hold two values separated by `/` or `,` with a footnote explaining each. `var.` means variable; `-` or `--` means no value. Footnote markers are superscripts in the source and appear as trailing numbers in plain-text extraction.

## Notes

- Kc values in Tables 12 and 17 are for a sub-humid climate (RHmin about 45%, wind speed u2 about 2 m/s) and non-stressed, well-managed crops; Chapter 6 gives the climate adjustment for other conditions (Equation 62 for Kc mid, Equation 65 for Kc end).
- Table 11 text states that the stage lengths "are useful only as a general guide and for comparison purposes" and are examples for the listed regions and planting periods.
- Cereal rye (Secale cereale) does not appear in Tables 11, 12, 17, 22 or 23. "Rye Grass hay" (Table 12: Kc ini 0.95, Kc mid 1.05, Kc end 1.00, h 0.3; Table 22: Zr 0.6-1.0 m, p 0.60) and "Rye-grass (perennial)" (Table 23: 5.6 dS/m, 7.6 %/dS/m, MT) are ryegrass, a different species.
- There is no separate row named "apple" in Tables 11 and 23 apart from the "Deciduous Orchard" stage lengths and the "Deciduous orchard - Apples" salt row; apple coefficients are in the combined row "Apples, Cherries, Pears".
- In Table 12 the "Winter Wheat - with non-frozen soils" height cell is blank in the HTML; the "with frozen soils" row shows 1 m.
- In the HTML header of Table 12 the "Kc ini" column heading is empty in the extracted text (it is rendered with subscripts); column order is Crop, Kc ini, Kc mid, Kc end, h.
- `https://www.fao.org/3/x0490e/x0490e.pdf` redirected to the FAO Open Knowledge Repository home page on 2026-11-14; the publication record is at the OKR handle below.
- The publication carries "© FAO 1998" and "All rights reserved" with reproduction requiring permission of the copyright owner (from the title page, `x0490e00.htm`).

## Documentation

- FAO-56 table of contents (HTML): https://www.fao.org/3/x0490e/x0490e00.htm
- Chapter 6 (Tables 11-16): https://www.fao.org/3/x0490e/x0490e0b.htm
- Chapter 7 (Tables 17-19): https://www.fao.org/3/x0490e/x0490e0c.htm
- Chapter 8 (Tables 22-24): https://www.fao.org/3/x0490e/x0490e0e.htm
- FAO Open Knowledge Repository record: https://openknowledge.fao.org/handle/20.500.14283/X0490E
- Citation: Allen, R.G., Pereira, L.S., Raes, D., Smith, M. 1998. Crop evapotranspiration: Guidelines for computing crop water requirements. FAO Irrigation and Drainage Paper 56. FAO, Rome. ISBN 92-5-104219-5.
- FAO terms of use: https://www.fao.org/contact-us/terms/en/
