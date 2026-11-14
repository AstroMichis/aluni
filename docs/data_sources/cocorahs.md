# CoCoRaHS (Community Collaborative Rain, Hail and Snow Network)

CoCoRaHS is a volunteer network of observers who measure precipitation with standard 4-inch manual rain gauges and report daily (24-hour) totals, multi-day accumulations, snowfall and snow depth, hail and significant weather. Observations are point measurements at the observer's location, usually read around 7:00 am local time. The export form lists all 50 U.S. states, DC, Guam, the Northern Mariana Islands, Puerto Rico and the U.S. Virgin Islands; reports appear as soon as observers submit them. Data are exported through an open, parameterized HTTP export service (`exportreports.aspx`) that returns CSV, XML or SHEF, and a station list export.

| | |
|---|---|
| Provider | CoCoRaHS, hosted by the Colorado Climate Center, Colorado State University |
| Base URL | `https://data.cocorahs.org/export/` |
| Auth | none |
| Formats | CSV, XML, XML Compact, SHEF, SHEF Snow |
| Coverage | U.S. states and territories (export form lists 50 states, DC, Guam, Northern Mariana Islands, Puerto Rico, Virgin Islands) |
| Resolution | point observations at volunteer stations |
| Cadence / latency | one daily report per station per observation day (plus optional multi-day, hail, significant weather reports); available as soon as entered |
| Rate limits / quotas | not published |
| Documentation | export form https://data.cocorahs.org/export/exportmanager.aspx ; https://www.cocorahs.org/ |

## Requests

### Daily precipitation reports export

Returns all daily reports for a state (optionally one county) and date range.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `ReportType` | yes | `Daily`, `MultiDay`, `Hail`, `SigWx` | `Daily` |
| `Format` | yes | `XML`, `XMLCompact`, `CSV`, `SHEF`, `SHEFSnow` | `CSV` |
| `State` | yes | Two-letter state abbreviation | `NE` |
| `County` | no | Two-letter CoCoRaHS county code within the state | `YK` (York) |
| `ReportDateType` | no | `reportdate` (observation date) or `timestamp` (entry/edit time) | `reportdate` |
| `StartDate` | yes | Start date, `M/D/YYYY` | `7/1/2025` |
| `EndDate` | yes | End date, `M/D/YYYY` | `7/5/2025` |
| `TimesInGMT` | no | `True` to express times in GMT, `False` for local | `False` |
| `dtf` | no | Date-time format: `1` = `yyyy-MM-dd hh:mm tt`, `2` = `HH:mm 'UT' MMM dd yyyy`, `3` = `yyyy-MM-dd HH:mm:ss` | `1` |

```
GET https://data.cocorahs.org/export/exportreports.aspx?ReportType=Daily&dtf=1&Format=CSV&State=NE&County=YK&ReportDateType=reportdate&StartDate=7/1/2025&EndDate=7/5/2025&TimesInGMT=False
```

### Sample response: CSV (Captured 2026-11-14, trimmed)

Trimmed: only rows with observation dates 2025-07-05 and 2025-07-04 kept (2025-07-01 to 2025-07-03 rows removed). Rows are returned newest observation date first.

```
ObservationDate,ObservationTime,EntryDateTime,StationNumber,StationName,Latitude,Longitude,TotalPrecipAmt,NewSnowDepth,NewSnowSWE,TotalSnowDepth,TotalSnowSWE,DateTimeStamp
2025-07-05, 07:00 AM, 2025-07-06 08:45 PM, york008, Benedict 3.5 W, 41.0186, -97.672, 0.72, NA, NA, NA, NA, 2025-07-07 01:45 AM
2025-07-05, 07:00 AM, 2025-07-05 01:08 PM, York5448, Lushton 1.76 WNW, 40.7398698, -97.74991264, 0.07, NA, NA, NA, NA, 2026-04-24 09:35 PM
2025-07-05, 07:00 AM, 2025-07-08 07:50 AM, York6838, McCool Junction 0.12 ESE, 40.74286958, -97.59855771, 0.25, NA, NA, NA, NA, 2026-04-24 09:35 PM
2025-07-05, 07:00 AM, 2025-07-05 08:19 AM, York5458, York 1.62 S, 40.8478763, -97.59079589, 0.13, NA, NA, NA, NA, 2026-04-24 09:35 PM
2025-07-05, 07:00 AM, 2025-07-05 08:27 AM, York5696, Henderson 0.12 ESE, 40.77873862, -97.80923545, 0.42, NA, NA, NA, NA, 2025-07-05 01:37 PM
2025-07-05, 07:00 AM, 2025-07-06 08:03 AM, York4375, Polk 5.76 S, 40.99204279, -97.78035402, 1.25, NA, NA, NA, NA, 2026-04-24 09:35 PM
2025-07-05, 07:00 AM, 2025-07-05 06:28 AM, york034, McCool Junction 1.1 ENE, 40.751, -97.5785, 0.30, NA, NA, NA, NA, 2026-04-24 09:35 PM
2025-07-05, 07:00 AM, 2025-07-05 07:33 AM, york019, Waco 3.6 E, 40.8868, -97.3948, 0.10, NA, NA, NA, NA, 2026-04-24 09:35 PM
2025-07-05, 07:00 AM, 2025-07-05 07:25 AM, york042, Bradshaw 4.1 NW , 40.930286, -97.79734, 1.33, NA, NA, NA, NA, 2025-07-05 12:37 PM
2025-07-05, 07:00 AM, 2025-07-05 07:57 AM, york044, York 1.1 ENE, 40.876687, -97.573797, 0.11, NA, NA, NA, NA, 2025-07-05 01:15 PM
2025-07-05, 07:00 AM, 2025-07-05 09:49 AM, york023, Stromsburg 6.8 SE, 41.0357, -97.5205, 0.20, NA, NA, NA, NA, 2025-07-05 03:15 PM
2025-07-05, 07:00 AM, 2025-07-07 05:21 PM, york036, McCool Junction 0.7 S  , 40.734039, -97.598011, 0.37, NA, NA, NA, NA, 2025-07-07 10:37 PM
2025-07-05, 07:00 AM, 2025-07-07 09:08 PM, york024, Henderson 2.5 N, 40.816, -97.806, 0.65, NA, NA, NA, NA, 2026-04-24 09:35 PM
2025-07-05, 06:45 AM, 2025-07-05 06:51 AM, york005, York 3.3 N, 40.9156, -97.5985, 0.28, NA, NA, NA, NA, 2026-04-24 09:35 PM
2025-07-05, 07:00 AM, 2025-07-05 10:38 AM, york002, York 1.0 E, 40.8683, -97.574, 0.12, NA, NA, NA, NA, 2025-07-05 04:15 PM
2025-07-04, 07:00 AM, 2025-07-04 07:10 AM, york005, York 3.3 N, 40.9156, -97.5985, 0.00, NA, NA, NA, NA, 2026-04-24 09:35 PM
2025-07-04, 07:00 AM, 2025-07-05 10:39 AM, york002, York 1.0 E, 40.8683, -97.574, 0.00, NA, NA, NA, NA, 2025-07-05 04:15 PM
2025-07-04, 07:00 AM, 2025-07-07 09:08 PM, york024, Henderson 2.5 N, 40.816, -97.806, 0.00, NA, NA, NA, NA, 2026-04-24 09:35 PM
2025-07-04, 07:00 AM, 2025-07-07 05:22 PM, york036, McCool Junction 0.7 S  , 40.734039, -97.598011, 0.00, NA, NA, NA, NA, 2026-04-24 09:35 PM
2025-07-04, 07:00 AM, 2025-07-05 09:50 AM, york023, Stromsburg 6.8 SE, 41.0357, -97.5205, 0.00, NA, NA, NA, NA, 2026-04-24 09:35 PM
2025-07-04, 07:00 AM, 2025-07-08 07:50 AM, York6838, McCool Junction 0.12 ESE, 40.74286958, -97.59855771, T, NA, NA, NA, NA, 2026-04-24 09:35 PM
2025-07-04, 07:00 AM, 2025-07-04 06:58 AM, york019, Waco 3.6 E, 40.8868, -97.3948, 0.00, NA, NA, NA, NA, 2026-04-24 09:35 PM
2025-07-04, 07:00 AM, 2025-07-04 06:44 AM, york034, McCool Junction 1.1 ENE, 40.751, -97.5785, 0.00, NA, NA, NA, NA, 2026-04-24 09:35 PM
2025-07-04, 07:00 AM, 2025-07-05 08:20 AM, York5458, York 1.62 S, 40.8478763, -97.59079589, 0.00, NA, NA, NA, NA, 2025-07-05 01:37 PM
2025-07-04, 07:00 AM, 2025-07-05 08:27 AM, York5696, Henderson 0.12 ESE, 40.77873862, -97.80923545, 0.00, NA, NA, NA, NA, 2026-04-24 09:35 PM
2025-07-04, 07:00 AM, 2025-07-04 08:15 AM, York4375, Polk 5.76 S, 40.99204279, -97.78035402, 0.00, NA, NA, NA, NA, 2025-07-04 01:15 PM
2025-07-04, 07:00 AM, 2025-07-04 07:53 PM, york008, Benedict 3.5 W, 41.0186, -97.672, 0.00, NA, NA, NA, NA, 2026-04-24 09:35 PM
```

### Daily reports export, XML

```
GET https://data.cocorahs.org/export/exportreports.aspx?ReportType=Daily&dtf=1&Format=XML&State=NE&County=YK&ReportDateType=reportdate&StartDate=7/5/2025&EndDate=7/5/2025&TimesInGMT=False
```

### Sample response: XML (Captured 2026-11-14, trimmed)

Trimmed: first two of 15 `DailyPrecipReport` elements kept.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Cocorahs>
  <DailyPrecipReports>
    <DailyPrecipReport>
      <ObservationDate>2025-07-05</ObservationDate>
      <ObservationTime>07:00 AM</ObservationTime>
      <EntryDateTime>2025-07-05 10:38 AM</EntryDateTime>
      <StationNumber>york002</StationNumber>
      <StationName>York 1.0 E</StationName>
      <Latitude>40.8683</Latitude>
      <Longitude>-97.574</Longitude>
      <TotalPrecipAmt>0.12</TotalPrecipAmt>
      <NewSnowDepth>NA</NewSnowDepth>
      <SnowCorePrecipAmt>NA</SnowCorePrecipAmt>
      <TotalSnowDepth>NA</TotalSnowDepth>
      <TotalSnowSWE>NA</TotalSnowSWE>
      <DateTimeStamp>2025-07-05 04:15 PM</DateTimeStamp>
    </DailyPrecipReport>
    <DailyPrecipReport>
      <ObservationDate>2025-07-05</ObservationDate>
      <ObservationTime>06:45 AM</ObservationTime>
      <EntryDateTime>2025-07-05 06:51 AM</EntryDateTime>
      <StationNumber>york005</StationNumber>
      <StationName>York 3.3 N</StationName>
      <Latitude>40.9156</Latitude>
      <Longitude>-97.5985</Longitude>
      <TotalPrecipAmt>0.28</TotalPrecipAmt>
      <NewSnowDepth>NA</NewSnowDepth>
      <SnowCorePrecipAmt>NA</SnowCorePrecipAmt>
      <TotalSnowDepth>NA</TotalSnowDepth>
      <TotalSnowSWE>NA</TotalSnowSWE>
      <DateTimeStamp>2026-04-24 09:35 PM</DateTimeStamp>
    </DailyPrecipReport>
  </DailyPrecipReports>
</Cocorahs>
```

### Station list export

Returns station metadata for a state and county.

| Parameter | Required | Description | Example |
|---|---|---|---|
| `State` | yes | Two-letter state abbreviation | `NE` |
| `County` | no | CoCoRaHS county code | `YK` |
| `Format` | yes | Output format (only `CSV` was tested) | `CSV` |

```
GET https://data.cocorahs.org/export/exportstations.aspx?State=NE&County=YK&Format=CSV
```

### Sample response (Captured 2026-11-14, trimmed)

Trimmed: first 6 stations kept.

```
StationNumber,StationName,StationType,State,County,City,Latitude,Longitude,Elevation,StationStatus,CreationDate,DateTimeStamp
york002, York 1.0 E, NeRAIN, NE, York, York, 40.8683, -97.574, 1650, Reporting, 2004-04-20 07:00 AM, 2008-08-14 07:35 PM
york003, York 0.6 SW, NeRAIN, NE, York, York, 40.862163, -97.593465, 1640, Closed, 2004-04-20 07:00 AM, 2008-08-14 07:35 PM
york005, York 3.3 N, NeRAIN, NE, York, York, 40.9156, -97.5985, 1618, Reporting, 2004-05-05 07:00 AM, 2008-08-14 07:35 PM
york006, York 1.0 ESE, NeRAIN, NE, York, York, 40.8621, -97.5739, 1647, Closed, 2004-05-10 07:00 AM, 2008-08-14 07:35 PM
york007, York 0.3 NE, NeRAIN, NE, York, York, 40.8713, -97.5886, 1657, Closed, 2004-05-10 07:00 AM, 2008-08-14 07:35 PM
york008, Benedict 3.5 W, NeRAIN, NE, York, Benedict, 41.0186, -97.672, 1732, Reporting, 2004-05-10 07:00 AM, 2020-09-25 06:16 PM
```

## Fields

| Field | Type | Unit | Description |
|---|---|---|---|
| `ObservationDate` | date | | Date the gauge was read (the 24 h ending at `ObservationTime`) |
| `ObservationTime` | time | local or GMT (per `TimesInGMT`) | Time the gauge was read |
| `EntryDateTime` | datetime | | When the observer entered the report |
| `StationNumber` | string | | Station identifier as returned by the export (see Notes) |
| `StationName` | string | | Nearest town plus distance (miles) and direction |
| `Latitude`, `Longitude` | float | degrees | Station location |
| `TotalPrecipAmt` | string/float | inches | 24 h precipitation (rain plus melted snow). `T` = trace, `NA` = not reported |
| `NewSnowDepth` | string/float | inches | New snowfall since last observation |
| `NewSnowSWE` (CSV) / `SnowCorePrecipAmt` (XML) | string/float | inches | Water equivalent of new snow core |
| `TotalSnowDepth` | string/float | inches | Total snow on the ground |
| `TotalSnowSWE` | string/float | inches | Water equivalent of total snowpack core |
| `DateTimeStamp` | datetime | | Last time the record was created or edited |
| `StationType` (stations) | string | | Station program/type label (for example `NeRAIN`) |
| `Elevation` (stations) | integer | feet (values about 1,600 to 1,730 for York County, consistent with feet) | Station elevation |
| `StationStatus` (stations) | string | | `Reporting` or `Closed` |
| `CreationDate` (stations) | datetime | | Station registration date |

Special values: `T` = trace (less than 0.01 in), `NA` = not available / not measured.

## Notes

- Values are in U.S. customary units (inches); the export does not convert.
- CSV values have a leading space after each comma, and some station names have trailing spaces (for example `Bradshaw 4.1 NW `).
- `StationNumber` values in this export are lowercase or mixed-case county-based codes (`york002`, `York5448`), not the hyphenated form (for example `NE-YK-2`) shown on the CoCoRaHS website; the PRISM station file lists the same stations as `YORK002`.
- `DateTimeStamp` changes when a report is edited; many 2025 rows carry `2026-04-24 09:35 PM`, indicating a later bulk update.
- The query parameter names were taken from the export form fields on `exportmanager.aspx` (report types, formats, date-time formats, report date type, GMT flag). The form itself is an ASP.NET postback page that builds an export link; the direct `exportreports.aspx` URL above returned data without a login. Driving the form programmatically to read the link it generates was attempted and abandoned (the script hung, no response captured).
- Multi-day, hail and significant-weather report types use the same endpoint with `ReportType=MultiDay|Hail|SigWx`; they were not captured.
- There is no radius or point search: filtering is by state and county, so stations near a point must be selected from the station list by coordinates.

## Documentation

- Export manager (form listing all options): https://data.cocorahs.org/export/exportmanager.aspx
- CoCoRaHS home and observer guides: https://www.cocorahs.org/
