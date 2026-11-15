# GEOGLAM Crop Monitor sub-national crop calendars

The GEOGLAM Crop Monitor Sub-National Crop Calendars are expert crop calendars for wheat (winter and spring), maize, rice, soybeans, sorghum, millet, beans and teff, drawn for sub-national regions built from FAO GAUL administrative level 1 units and published as one shapefile per version on Zenodo under CC BY 4.0. Each region carries, in half-month steps, one of five phenological stages: Planting through Early Vegetative, Vegetative through Reproductive, Ripening through Harvest, End of Harvest, and Out of Season. Where a country has several cropping seasons they are numbered by production size. The calendars are produced by the GEOGLAM Crop Monitor team at the University of Maryland with the GEOGLAM Secretariat and national partners; NASA Harvest states that it "supports GEOGLAM through various community-driven efforts including production of GEOGLAM's monthly Crop Monitor reports". There is no API: the deposit is a 554 MB ZIP whose metadata is served by the Zenodo REST API without a key.

| | |
|---|---|
| Provider | GEOGLAM Crop Monitor (University of Maryland, Department of Geographical Sciences; GEOGLAM Secretariat, Geneva); hosted on Zenodo |
| Base URL | `https://zenodo.org/api/records/{id}` (concept record 10949971; v1.3 = 15850408, v1.4 = 18763008) |
| Auth | none |
| Formats | ESRI shapefile (`.shp`, `.shx`, `.dbf`, `.prj`, `.cpg`, `.sbn`, `.sbx`) plus `ReadMe_GEOGLAM_CM4EW_Calendars.txt`, inside one ZIP |
| Coverage | Global, sub-national regions built from GAUL admin-1 units, grouped so that over 90% of national production is covered |
| Resolution | one polygon per crop, season and region; half-month time steps |
| Cadence / latency | versioned deposits: v1.3 published 2025-07-09, v1.4 published 2026-02-24 (concept DOI 10.5281/zenodo.10949971) |
| Rate limits / quotas | Zenodo: `x-ratelimit-limit: 133` per minute on record requests |
| Licence | CC BY 4.0 (`cc-by-4.0` on v1.3 and v1.4) |
| Documentation | https://zenodo.org/records/18763008 ; https://www.cropmonitor.org/ |

## Requests

### Record metadata (one version)

| Parameter | Required | Description | Example |
|---|---|---|---|
| `{id}` (path) | yes | Zenodo record id | `15850408` |

```
GET https://zenodo.org/api/records/15850408
```

### Sample response (Captured 2026-11-15)

6,797 bytes. Trimmed: `stats`, `revision`, `owners`, `swh`, `custom`, `metadata.resource_type` and the second half of `metadata.description` removed.

```json
{
  "id": 15850408, "conceptrecid": "10949971", "doi": "10.5281/zenodo.15850408", "conceptdoi": "10.5281/zenodo.10949971",
  "created": "2025-07-09T18:07:26.873878+00:00",
  "metadata": {
    "title": "GEOGLAM Crop Monitor Sub-National Crop Calendars",
    "publication_date": "2025-07-09", "version": "1.3", "access_right": "open",
    "license": {"id": "cc-by-4.0"},
    "creators": [
      {"name": "Becker-Reshef, Inbal", "affiliation": "GEOGLAM Secretariat, Geneva, Switzerland"},
      {"name": "Barker, Brian", "affiliation": "Department of Geographic Science, University of Maryland College Park"},
      {"name": "Mobley, Kara", "affiliation": "Department of Geographic Science, University of Maryland College Park"},
      {"name": "Justice, Christina", "affiliation": "Department of Geographic Science, University of Maryland College Park"},
      {"name": "Sanchez Galvez, Antonio", "affiliation": "Department of Geographic Science, University of Maryland College Park"},
      {"name": "Sahajpal, Ritvik", "affiliation": "Department of Geographic Science, University of Maryland College Park"}],
    "keywords": ["Agriculture", "Calendar", "Wheat", "Winter Wheat", "Spring Wheat", "Maize", "Corn", "Rice", "Soybean", "Sorghum", "Millet", "Beans", "Teff"],
    "description": "<p>The GEOGLAM Crop Monitor Sub-National Crop Calendars are based on a combination of the best available data from different international agencies, national ministries, and expert knowledge of the country partners from GEOGLAM Crop Monitors. The crops covered are wheat, maize, rice, soybeans, sorghum, millet, beans, and teff. In locations where there are multiple cropping seasons, the seasons are numbered with the first being the largest producing season followed by the next largest, and so on. The crop calendars consist of five different phenological stages ... The sub-national regions were built using the administrative level 1 FAO GAUL units as the basic building blocks ...</p>"
  },
  "files": [{"key": "GEOGLAM_CM4EW_Calendars_V1.3.zip", "size": 554054666, "links": {"self": "https://zenodo.org/api/records/15850408/files/GEOGLAM_CM4EW_Calendars_V1.3.zip/content"}}],
  "links": {"self": "https://zenodo.org/api/records/15850408", "self_html": "https://zenodo.org/records/15850408", "latest": "https://zenodo.org/api/records/15850408/versions/latest"}
}
```

The rest of the description says the regions group "areas with similar phenological development timelines", capture ">90% of national production", and that "the crop calendars are displayed in bi-monthly steps" (twice a month).

### Latest version

```
GET https://zenodo.org/api/records/15850408/versions/latest
```

### Sample response (Captured 2026-11-15)

HTTP 301 to `https://zenodo.org/api/records/18763008`, then HTTP 200, 6,794 bytes. Differences from v1.3: `id` 18763008, `doi` `10.5281/zenodo.18763008`, `publication_date` `2026-02-24`, `version` `1.4`, one file `GEOGLAM_CM4EW_Calendars_V1.4.zip` of 554,053,946 bytes. Same creators, keywords, licence and description.

### Archive contents (byte range on the ZIP)

The ZIP was not downloaded. A suffix `Range` request returned the zip central directory, which lists the entries.

```
GET https://zenodo.org/api/records/18763008/files/GEOGLAM_CM4EW_Calendars_V1.4.zip/content
    Range: bytes=-65536
```

### Sample response (Captured 2026-11-15)

HTTP 206. Entries parsed from the central directory (uncompressed size in bytes):

```
          5  GEOGLAM_CM4EW_Calendars_V1.4/GEOGLAM_CM4EW_Calendars_V1.4.cpg
    2096192  GEOGLAM_CM4EW_Calendars_V1.4/GEOGLAM_CM4EW_Calendars_V1.4.dbf
        145  GEOGLAM_CM4EW_Calendars_V1.4/GEOGLAM_CM4EW_Calendars_V1.4.prj
      51580  GEOGLAM_CM4EW_Calendars_V1.4/GEOGLAM_CM4EW_Calendars_V1.4.sbn
       1260  GEOGLAM_CM4EW_Calendars_V1.4/GEOGLAM_CM4EW_Calendars_V1.4.sbx
  845673236  GEOGLAM_CM4EW_Calendars_V1.4/GEOGLAM_CM4EW_Calendars_V1.4.shp
      42548  GEOGLAM_CM4EW_Calendars_V1.4/GEOGLAM_CM4EW_Calendars_V1.4.shx
       4432  GEOGLAM_CM4EW_Calendars_V1.4/ReadMe_GEOGLAM_CM4EW_Calendars.txt
```

The `.shx` index size (42,548 bytes, 100-byte header plus 8 bytes per shape) corresponds to about 5,300 features.

### Crop Monitor web site

```
GET https://cropmonitor.org/
```

### Sample response (Captured 2026-11-15)

HTTP 301 to `https://www.cropmonitor.org/`, then HTTP 200, 365,545 bytes of Squarespace HTML titled "GEOGLAM Crop Monitor". The page is script-rendered; no data API or calendar download link was found in the HTML. The NASA Harvest home page (`https://www.nasaharvest.org/`, HTTP 200) contains the sentence quoted in the introduction.

## Fields

The attribute table (`.dbf`) and the README inside the ZIP were not read, so attribute names are not listed. The record description fixes the content model:

| Field (conceptual) | Type | Unit | Description |
|---|---|---|---|
| Sub-national region | polygon | | Built from FAO GAUL admin-1 units; one feature per crop, season and region |
| Crop | string | | wheat (winter, spring), maize, rice, soybeans, sorghum, millet, beans, teff |
| Season number | integer | | 1 = largest producing season, 2 = next, and so on |
| Stage per half-month | class | | Planting through Early Vegetative; Vegetative through Reproductive; Ripening through Harvest; End of Harvest; Out of Season (24 steps per year) |

## Licence

Creative Commons Attribution 4.0 International: `"license": {"id": "cc-by-4.0"}` on records 15850408 (v1.3) and 18763008 (v1.4), re-read from the Zenodo API on 2026-11-15. The inventory recorded the same licence for v1.3 and noted a newer version; v1.4 carries the same licence. Attribution to the creators and the DOI is the condition.

## Overlap with NASA sources

- NASA publishes no crop calendar product. This is the closest NASA-linked source: NASA Harvest states on its site that it supports GEOGLAM, including the monthly Crop Monitor reports.
- MODIS and HLS vegetation indices and the MODIS land surface phenology product (`vegetation_indices.md`) give the observed green-up, peak and senescence of a specific field; the calendars give the expected regional stage.
- NASA POWER (`nasa_power.md`) gives daily weather inside each calendar window.
- GPM IMERG (`gpm_imerg.md`) gives the rainfall onset that sets planting dates in rain-fed regions.

## Notes

- The ZIP is 554 MB and holds one shapefile whose `.shp` is 845.7 MB uncompressed. Only the last 64 KB was fetched.
- The README (4,432 bytes) is inside the ZIP, so its attribute descriptions were not read.
- ESA WorldCereal (`https://esa-worldcereal.org/`) publishes global 10 m crop-type and season maps under CC BY 4.0 (from the inventory; not fetched). It is a satellite classification product, not an expert calendar.

## Documentation

- Zenodo record (v1.4): https://zenodo.org/records/18763008
- Zenodo record (v1.3): https://zenodo.org/records/15850408 ; concept DOI https://doi.org/10.5281/zenodo.10949971
- GEOGLAM Crop Monitor: https://www.cropmonitor.org/
- NASA Harvest: https://www.nasaharvest.org/
- GEOGLAM: https://earthobservations.org/geoglam.php
