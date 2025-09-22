-- gbl.lua - Pilot Dashboard (GPS • Cell • RC Link + Lat/Lon persist)
-- Radiomaster Pocket & Boxer (EdgeTX 128x64)
-- Battery reading uses VFAS -> A2 -> RxBt (unchanged). Simple, strict cell detection.
-- by Seonski

----------------------------------------------------------------
-- USER OPTIONS
----------------------------------------------------------------
local TITLE = "Simple Pilot Dashboard"
local FORCE_CELLS = 0          -- 0 = auto; or set 1/2/3/4/6 to lock.
local LOW_SATS_BLINK = 6       -- blink sats if below this

-- Per-cell validity window (keeps things simple & correct)
local MIN_CELL_V = 3.2
local MAX_CELL_V = 4.35
local NOM_CELL_V = 3.8

-- Allowed packs we care about
local ALLOWED = {1,2,3,4,6}

----------------------------------------------------------------
-- Cached sensor IDs (set in init)
----------------------------------------------------------------
local id_VFAS, id_A2, id_RxBt
local id_Sats, id_RQly, id_1RSS, id_RSSI
local id_GPS

----------------------------------------------------------------
-- Runtime values (updated in background)
----------------------------------------------------------------
local perCellV = nil
local cellsDetected = 0
local lastCells = 0
local sats = 0
local linkLQ = nil
local linkRSSI = nil

-- Last known GPS (kept even if link drops while radio stays on)
local lastLat, lastLon = nil, nil
local latStr, lonStr = "--", "--"

----------------------------------------------------------------
-- Helpers
----------------------------------------------------------------
local function gi(name)
  local fi = getFieldInfo(name)
  if fi then return fi.id end
  return nil
end

local function gv(id)
  if not id then return nil end
  local v = getValue(id)
  if type(v) == "number" then return v end
  return nil
end

local function roundInt(x)
  if not x then return nil end
  if x >= 0 then return math.floor(x + 0.5) end
  return -math.floor(-x + 0.5)
end

-- Choose a cell count with strict rules and no funny business.
local function chooseCells(totalV)
  if not totalV or totalV <= 0 then return 0 end
  if FORCE_CELLS and FORCE_CELLS > 0 then return FORCE_CELLS end

  -- 1) Keep previous if still sane
  if lastCells and lastCells > 0 then
    local per = totalV / lastCells
    if per >= MIN_CELL_V and per <= MAX_CELL_V then
      return lastCells
    end
  end

  -- 2) Try allowed counts; per-cell must be within [MIN, MAX]
  local bestN, bestErr = 0, 1e9
  for i=1,#ALLOWED do
    local n = ALLOWED[i]
    local per = totalV / n
    if per >= MIN_CELL_V and per <= MAX_CELL_V then
      local err = math.abs(per - NOM_CELL_V)
      -- tiny bias to stick with the lastCells if it’s valid
      if lastCells > 0 and n == lastCells then err = err * 0.75 end
      if err < bestErr then bestErr, bestN = err, n end
    end
  end
  if bestN > 0 then return bestN end

  -- 3) Nothing fit strictly: snap nearest to total/nominal, limited to ALLOWED
  local rough = roundInt(totalV / NOM_CELL_V) or 0
  local nearest, bestDiff = 0, 1e9
  for i=1,#ALLOWED do
    local d = math.abs(ALLOWED[i] - rough)
    if d < bestDiff then bestDiff, nearest = d, ALLOWED[i] end
  end
  return nearest
end

local function updatePerCell()
  -- Same sensor chain as your working version: VFAS -> A2 -> RxBt
  local total = gv(id_VFAS) or gv(id_A2) or gv(id_RxBt)
  if not total then
    perCellV, cellsDetected = nil, 0
    return
  end
  local n = chooseCells(total)
  if not n or n <= 0 then
    perCellV, cellsDetected = nil, 0
    return
  end
  perCellV = total / n
  cellsDetected = n
  lastCells = n
end

local function formatLat(lat)
  local hemi = "N"
  if lat < 0 then hemi = "S"; lat = -lat end
  return string.format("%.5f%s", lat, hemi)
end

local function formatLon(lon)
  local hemi = "E"
  if lon < 0 then hemi = "W"; lon = -lon end
  return string.format("%.5f%s", lon, hemi)
end

----------------------------------------------------------------
-- EdgeTX lifecycle
----------------------------------------------------------------
local function init_func()
  -- battery sensors (same names as your working code)
  id_VFAS = gi("VFAS")
  id_A2   = gi("A2")
  id_RxBt = gi("RxBt")

  -- link + sats
  id_Sats = gi("Sats")
  id_RQly = gi("RQly")
  id_1RSS = gi("1RSS")
  id_RSSI = gi("RSSI")

  -- GPS composite {lat, lon}
  id_GPS  = gi("GPS")
end

local function bg_func()
  -- Battery / per-cell
  updatePerCell()

  -- Sats
  local s = gv(id_Sats)
  sats = s and roundInt(s) or 0

  -- Link (prefer CRSF/ELRS)
  local lq = gv(id_RQly)
  local r1 = gv(id_1RSS)
  if lq then
    linkLQ = roundInt(lq)
    linkRSSI = r1 and roundInt(r1) or nil
  else
    local rssiP = gv(id_RSSI)
    linkLQ = rssiP and roundInt(rssiP) or nil
    linkRSSI = r1 and roundInt(r1) or nil
  end

  -- GPS (keep last known good coords)
  if id_GPS then
    local g = getValue(id_GPS)
    if type(g) == "table" and g.lat and g.lon and g.lat ~= 0 then
      lastLat, lastLon = g.lat, g.lon
      latStr, lonStr = formatLat(lastLat), formatLon(lastLon)
    end
  end
end

local function run_func(event)
  lcd.clear()
  lcd.drawText(6, 2, TITLE, INVERS)

  -- Row 1: Cell
  if perCellV then
    lcd.drawText(4, 12, string.format("Cell: %.2fV", perCellV), 0)
  else
    lcd.drawText(4, 12, "Cell: --.-V", 0)
  end
  if cellsDetected and cellsDetected > 0 then
    lcd.drawText(100, 12, "(" .. tostring(cellsDetected) .. "S)", 0)
  end

  -- Row 2: GPS (sats)
  local sFlags = (sats < LOW_SATS_BLINK) and BLINK or 0
  lcd.drawText(4, 22, "GPS:", sFlags)
  lcd.drawText(40, 22, tostring(sats) .. " sats", sFlags)

  -- Row 3: Lat
  lcd.drawText(4, 32, "Lat:", 0)
  lcd.drawText(34, 32, latStr or "--", 0)

  -- Row 4: Lon
  lcd.drawText(4, 42, "Lon:", 0)
  lcd.drawText(34, 42, lonStr or "--", 0)

  -- Row 5: LQ + RSSI (one row)
  lcd.drawText(4, 52, "LQ:", 0)
  if linkLQ then lcd.drawText(24, 52, tostring(linkLQ) .. "%", 0) else lcd.drawText(24, 52, "--", 0) end
  lcd.drawText(68, 52, "RSSI:", 0)
  if linkRSSI then lcd.drawText(104, 52, tostring(linkRSSI), 0) else lcd.drawText(104, 52, "--", 0) end

  return 0
end

return { run = run_func, init = init_func, background = bg_func }
