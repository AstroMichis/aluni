# Field station (Sonda / Probe)

Product and architecture proposal for the field station shown on `/devices` (`DevicesController`, `app/views/devices/`). Nothing below is built yet except that page. This is the plan the hardware, firmware and the Rails ingestion follow when the team picks it up.

## Product

| | Lite | Pro |
|---|---|---|
| For | Fields near a house or WiFi | Distant fields with cellular coverage |
| Connectivity | WiFi 2.4 GHz, Bluetooth (setup) | WiFi, Bluetooth, LTE-M / NB-IoT with a soldered multi-carrier eSIM |
| Location | From the app (the field's pin) | Built-in GNSS fixes the pin itself |
| Sensors | Soil moisture + temperature at 10 and 30 cm, air temperature + humidity | Lite + tipping-bucket rain gauge (0.2 mm), radiation, SDI-12 / RS485 expansion port |

Common to both: a solar panel (5 W), a LiFePO4 battery with an MPPT charger, an IP67 UV-stabilised polycarbonate enclosure with a vent, M12 sealed probe connectors and a pole mount. Readings every 15 minutes, sent hourly in batches. The battery lasts weeks without sun.

## Hardware

| Block | Part | Why |
|---|---|---|
| MCU | Espressif ESP32-S3 | WiFi + BLE, secure boot v2, flash encryption; the Arduino or ESP-IDF toolchain |
| Cellular + GNSS (Pro) | Quectel BG95-M3 (LTE-M / NB-IoT / GNSS), MFF2 eSIM | Low-power rural coverage; GNSS gives the exact field pin |
| Identity | Microchip ATECC608B secure element | ECC P-256 private key generated and kept inside the chip |
| Offline buffer | 16 MB SPI NOR flash, ring buffer (LittleFS) | Months of 15-minute readings |
| Clock | RV-3028 RTC with backup | Correct timestamps while offline |
| Soil | Capacitive moisture at two depths with temperature at each (never resistive probes, which corrode) | Irrigation decisions; compared with SMAP |
| Air | Sensirion SHT45 in a radiation shield | Frost, disease and heat risk; compared with NASA POWER and Meteomatics |
| Rain (Pro) | Tipping bucket, 0.2 mm | Ground truth for GPM IMERG |

## Data path: store and forward

1. Measure every 15 minutes, **always write to flash first**, with a monotonically increasing `seq` per device.
2. Every hour, try WiFi, then cellular, and send pending readings oldest first in batches.
3. The server answers with the highest `seq` it has stored, and the device frees its buffer up to that point.
4. No network: keep measuring and keep buffering. The batch upload resumes on its own.

Readings are idempotent on `(device_id, seq)`. A replayed or repeated batch is a no-op.

## Security

- **Factory enrolment:** each device's public key, read from its secure element, is registered in `devices` before it ships. The server accepts only enrolled devices.
- **Claiming:** the QR code on the enclosure carries the device id and a one-time claim code. The farmer scans it in the app and picks a `Field`; the claim binds device, user and field. Without the physical code, nobody can claim the device.
- **Transport:** HTTPS to `aluni.us` through Cloudflare, with the root CA pinned in firmware.
- **Message authentication:** each batch body is signed by the secure element (ECDSA P-256) over `device_id`, `sent_at`, `first_seq..last_seq` and the body digest. The server verifies with the enrolled public key, rejects a `sent_at` skew over 10 minutes, and rejects a `seq` it already has.
- **Firmware:** secure boot and flash encryption on. OTA updates are signed images with A/B partitions and automatic rollback.
- **Revocation:** unpair or block a device from the app; the server drops its key.

## Rails side (to build)

Follows the inbound pattern in `docs/INTEGRATIONS.md`:

- `POST /api/v1/devices/readings` (an `ActionController::API` controller): caps the body size and verifies the signature with `ActiveSupport::SecurityUtils`-style constant-time checks before parsing. It stores the batch and enqueues a job; it never computes advice in the request.
- Tables:
  - `devices`: `serial`, `public_key`, `field_id`, `claimed_by`, `status`, `last_seen_at`, `firmware_version`, `battery`, `rssi`.
  - `device_readings`: `device_id`, `seq`, `measured_at`, `metric`, `value`, with a unique index on `(device_id, seq, metric)`.
- Validation: physical ranges per metric (soil moisture 0..100 %, air −50..60 °C, and so on). An out-of-range value is stored as flagged, not dropped.
- Protection: Rack::Attack per device and per IP, and a `devices` entry in the Platform switch so ingestion can be paused.
- In the app:
  - a device card on the field (status, battery, last reading);
  - alerts (frost, dry soil, rain recorded);
  - "Your sensor next to the satellite" charts, pairing readings with SMAP, IMERG, NASA POWER and Meteomatics for the field's pin.

## Open questions for the team

- Cellular data plan and eSIM provider (cost per device per month).
- Enclosure and probe sourcing versus a custom PCB for the first batch.
- Calibration procedure per soil texture (the `Field.soil.texture` already captured in onboarding can select the curve).
- LoRa gateway for farms with many stations: same protocol, one uplink.
