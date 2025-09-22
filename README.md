# Simple Pilot Dashboard — EdgeTX Telemetry Script

A compact telemetry screen for **Radiomaster Pocket & Boxer (128×64)** running **EdgeTX**. It displays:

- **Battery per-cell voltage** with strict, reliable cell detection (1S / 2S / 3S / 4S / 6S)
- **GPS:** satellite count + **last known** Latitude/Longitude (persists on screen after link loss)
- **RC link:** **LQ%** (ELRS/CRSF) and **RSSI** (dBm)

**Real-world uses**

- **Crash recovery / Find-my-quad:** read the last coordinates from the radio and paste into Google Maps.  
- **Pack health at a glance:** true **per-cell** voltage to judge sag and landing time.  
- **Link confidence:** track **LQ%/RSSI** for long-range and obstacle-rich flights.

---

## Requirements

- **Radio:** Radiomaster **Pocket** or **Boxer** (EdgeTX, 128×64 screen)  
- **Firmware:** EdgeTX with Lua enabled  
- **Receiver link:** ELRS/CRSF (for LQ/RSSI) or any protocol that exposes `RSSI`  
- **Flight controller:** Betaflight/INAV (for `GPS`, `Sats`, and `VFAS/VBat` telemetry)

---

## Installation

1. **Copy the script**
   - Save the file as **`spd.lua`**  
   - Place it on the SD card at:  
     `SCRIPTS/TELEMETRY/spd.lua`

2. **Discover sensors**
   - Power the quad **ON**
   - On the radio: **Model → Telemetry → Discover new sensors**
   - Confirm you see (names may vary):
     - **Battery:** `VFAS` (or `VBat`/`Batt`) — total pack volts  
     - **GPS:** `GPS` (composite) and `Sats`  
     - **Link:** `RQly` (LQ%), `1RSS` (RSSI dBm), and/or `RSSI`

3. **Assign the screen**
   - **Model → Telemetry → Screens → Screen 1 (or any free slot)**
   - **Type:** `Script` → select **`gbl`**

4. **View it**
   - From the home screen, press **PAGE** to cycle to telemetry screens.

---

## What You’ll See (top → bottom)

- **Title** (default: *Simple Pilot Dashboard*)  
- **Cell:** `X.XXV (nS)` — per-cell voltage & detected cell count  
- **GPS:** `NN sats` — blinks if sats < 6  
- **Lat:** `14.59950N`  
- **Lon:** `121.03620E`  
- **LQ / RSSI:** `LQ: 99%    RSSI: -85`

> **Lat/Lon persist** after link loss while the radio remains on (useful for locating a downed quad).

---


## Authors

- [seonski](https://www.facebook.com/seonski)


