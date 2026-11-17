-- =============================================================
--  MyWindowWidget - weather in the Clock card (Clock\Clock.ini)
--  ENCODING: this file is saved as UTF-16 LE (with BOM) on purpose,
--  like Calendar.lua. Rainmeter then runs it in Unicode mode, so the
--  place name (Korean, ...) and the ° sign arrive as UTF-8.
--
--  @Resources\Scripts\Weather.ps1 (location, place name, Open-Meteo)
--  runs in a hidden window through the RunCommand measure
--  MeasureWeatherRun and writes @Resources\Cache\weather.txt (format:
--  Weather.ps1 header). OnDone() reads it. The script runs at load
--  when the cache is older than WeatherRefreshSeconds, then every
--  WeatherRefreshSeconds; after a failure it retries sooner.
--
--  Draws: MeterWxTemp (temperature), MeterWxSub (condition - place),
--  MeterWxIcon (Shape meter, icon built from ellipses and lines in a
--  WxIconS box), the tooltip with the details.
--
--  Bangs: Refresh(), OnDone()
-- =============================================================

local BUSY_LIMIT = 90       -- seconds; RunCommand Timeout is 60
local RETRY = 300           -- seconds after a failed run
local MAX_SHAPES = 24       -- ShapeN options the icon may use

local cfg = {}
local data = {}             -- parsed weather.txt
local running = false
local runSince = 0
local nextRun = 0
local started = false
local shapeCount = 1

-- WMO weather codes (Open-Meteo docs) -> text, icon kind.
local CODES = {
  [0] = { 'Clear', 'clear' },
  [1] = { 'Mostly clear', 'clear' },
  [2] = { 'Partly cloudy', 'partly' },
  [3] = { 'Overcast', 'cloudy' },
  [45] = { 'Fog', 'fog' },
  [48] = { 'Rime fog', 'fog' },
  [51] = { 'Light drizzle', 'rain' },
  [53] = { 'Drizzle', 'rain' },
  [55] = { 'Heavy drizzle', 'rain' },
  [56] = { 'Freezing drizzle', 'rain' },
  [57] = { 'Freezing drizzle', 'rain' },
  [61] = { 'Light rain', 'rain' },
  [63] = { 'Rain', 'rain' },
  [65] = { 'Heavy rain', 'rain' },
  [66] = { 'Freezing rain', 'rain' },
  [67] = { 'Freezing rain', 'rain' },
  [71] = { 'Light snow', 'snow' },
  [73] = { 'Snow', 'snow' },
  [75] = { 'Heavy snow', 'snow' },
  [77] = { 'Snow grains', 'snow' },
  [80] = { 'Light showers', 'rain' },
  [81] = { 'Showers', 'rain' },
  [82] = { 'Heavy showers', 'rain' },
  [85] = { 'Snow showers', 'snow' },
  [86] = { 'Heavy snow showers', 'snow' },
  [95] = { 'Thunderstorm', 'storm' },
  [96] = { 'Thunderstorm, hail', 'storm' },
  [97] = { 'Heavy thunderstorm', 'storm' },
  [99] = { 'Thunderstorm, hail', 'storm' },
}

-- ---- small helpers ------------------------------------------

local function var(name, default)
  return SKIN:GetVariable(name, default or '')
end

local function num(name)
  return SKIN:ParseFormula(SKIN:ReplaceVariables('#' .. name .. '#')) or 0
end

local function trim(s) return (s or ''):match('^%s*(.-)%s*$') end

local function set(meter, option, value)
  SKIN:Bang('!SetOption', meter, option, tostring(value))
end

local function readFile(path)
  local f = io.open(path, 'rb')
  if not f then return nil end
  local s = f:read('*a')
  f:close()
  return s
end

local function split(line)
  local t = {}
  for field in (line .. '\t'):gmatch('([^\t]*)\t') do t[#t + 1] = field end
  return t
end

local function round(x) return math.floor(x + 0.5) end

local function temp(c)
  if not c then return '--' end
  if cfg.fahrenheit then c = c * 9 / 5 + 32 end
  return round(c) .. '°'
end

local function wind(kmh)
  if cfg.fahrenheit then return round(kmh * 0.621371) .. ' mph' end
  return round(kmh) .. ' km/h'
end

-- ---- cache --------------------------------------------------

local function load()
  data = { status = 'loading', detail = '' }
  local s = readFile(var('@') .. 'Cache\\weather.txt')
  if not s then return end
  for line in s:gmatch('[^\n]+') do
    local f = split((line:gsub('\r$', '')))
    if f[1] == 'status' then
      data.status, data.detail = f[2] or 'error', f[3] or ''
    elseif f[1] == 'updated' then
      local y, mo, d, h, mi, sec = (f[2] or ''):match('^(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)$')
      if y then
        data.updated = os.time { year = tonumber(y), month = tonumber(mo), day = tonumber(d),
          hour = tonumber(h), min = tonumber(mi), sec = tonumber(sec) }
      end
    elseif f[1] == 'place' then
      data.place, data.placeFull = f[5] or '', f[6] or ''
    elseif f[1] == 'current' then
      data.temp, data.feels = tonumber(f[2]), tonumber(f[3])
      data.humidity, data.code = tonumber(f[4]), tonumber(f[5])
      data.isDay, data.wind = f[6] ~= '0', tonumber(f[7])
    elseif f[1] == 'today' then
      data.max, data.min = tonumber(f[2]), tonumber(f[3])
    end
  end
end

-- ---- icon ---------------------------------------------------
-- Built in a 1 x 1 box scaled to WxIconS. Shape 1 is the invisible
-- box that keeps the meter size fixed.

local shapes

local function px(v) return string.format('%.2f', v * cfg.iconS) end

local function ref(i) return i == 1 and 'Shape' or ('Shape' .. i) end

local function add(s)
  shapes[#shapes + 1] = s
  return #shapes
end

local function stroke(color)
  return string.format(' | Fill Color 0,0,0,0 | StrokeWidth %.2f | Stroke Color %s'
    .. ' | StrokeStartCap Round | StrokeEndCap Round | StrokeLineJoin Round', cfg.strokeW, color)
end

local function ellipse(cx, cy, r)
  return 'Ellipse ' .. px(cx) .. ',' .. px(cy) .. ',' .. px(r)
end

local function line(x1, y1, x2, y2, color)
  return add('Line ' .. px(x1) .. ',' .. px(y1) .. ',' .. px(x2) .. ',' .. px(y2) .. stroke(color))
end

-- Cloud outline = union of three bumps and a flat bottom, in a box
-- about 0.8 wide, top-left at (ox, oy), scaled by k. Returns the
-- shape strings without attributes.
local function cloudParts(ox, oy, k)
  local function p(x) return x * k end
  return {
    ellipse(ox + p(0.30), oy + p(0.61), p(0.18)),
    ellipse(ox + p(0.52), oy + p(0.48), p(0.24)),
    ellipse(ox + p(0.74), oy + p(0.62), p(0.17)),
    'Rectangle ' .. px(ox + p(0.30)) .. ',' .. px(oy + p(0.55)) .. ',' .. px(p(0.44)) .. ',' .. px(p(0.24)),
  }
end

local function cloud(ox, oy, k, color)
  local parts = cloudParts(ox, oy, k)
  local first = add(parts[1] .. stroke(color))
  local combine = 'Combine ' .. ref(first)
  for i = 2, #parts do combine = combine .. ' | Union ' .. ref(add(parts[i])) end
  add(combine)
end

-- Disk (sun) or crescent (moon); with a cloud, the part behind it
-- is cut away so the cloud does not need an opaque fill.
local function body(kind, cx, cy, r, behind)
  local first = add(ellipse(cx, cy, r) .. stroke(cfg.accent))
  local combine = 'Combine ' .. ref(first)
  if kind == 'moon' then
    combine = combine .. ' | Exclude ' .. ref(add(ellipse(cx + 0.55 * r, cy - 0.45 * r, 0.8 * r)))
  end
  if behind then
    for _, s in ipairs(cloudParts(behind[1], behind[2], behind[3])) do
      combine = combine .. ' | Exclude ' .. ref(add(s))
    end
  end
  if combine ~= 'Combine ' .. ref(first) then add(combine) end
end

local function rays(cx, cy, r1, r2, angles)
  for _, a in ipairs(angles) do
    local rad = math.rad(a)
    line(cx + math.cos(rad) * r1, cy + math.sin(rad) * r1,
      cx + math.cos(rad) * r2, cy + math.sin(rad) * r2, cfg.accent)
  end
end

local function drawIcon(kind, isDay)
  shapes = { 'Rectangle 0,0,' .. px(1) .. ',' .. px(1) .. ' | Fill Color 0,0,0,1 | StrokeWidth 0' }
  -- Cloud high up, room for rain / snow / fog below.
  local high = { 0.04, -0.12, 0.92 }
  if kind == 'clear' then
    if isDay then
      body('sun', 0.5, 0.5, 0.19)
      rays(0.5, 0.5, 0.3, 0.42, { 0, 45, 90, 135, 180, 225, 270, 315 })
    else
      body('moon', 0.5, 0.5, 0.3)
    end
  elseif kind == 'partly' then
    local behind = { 0.08, 0.12, 0.9 }
    if isDay then
      body('sun', 0.34, 0.36, 0.14, behind)
      rays(0.34, 0.36, 0.2, 0.28, { 135, 180, 225, 270, 315 })
    else
      body('moon', 0.34, 0.34, 0.17, behind)
    end
    cloud(behind[1], behind[2], behind[3], cfg.secondary)
  elseif kind == 'cloudy' then
    cloud(-0.015, -0.02, 1, cfg.secondary)
  elseif kind == 'fog' then
    cloud(high[1], high[2], high[3], cfg.secondary)
    line(0.18, 0.74, 0.82, 0.74, cfg.secondary)
    line(0.3, 0.88, 0.7, 0.88, cfg.secondary)
  elseif kind == 'rain' then
    cloud(high[1], high[2], high[3], cfg.secondary)
    for _, x in ipairs { 0.36, 0.54, 0.72 } do line(x, 0.72, x - 0.07, 0.9, cfg.accent) end
  elseif kind == 'snow' then
    cloud(high[1], high[2], high[3], cfg.secondary)
    for _, p in ipairs { { 0.33, 0.78 }, { 0.51, 0.88 }, { 0.69, 0.78 } } do
      add(ellipse(p[1], p[2], 0.045) .. ' | Fill Color ' .. cfg.secondary .. ' | StrokeWidth 0')
    end
  elseif kind == 'storm' then
    cloud(high[1], high[2], high[3], cfg.secondary)
    line(0.56, 0.66, 0.45, 0.8, cfg.accent)
    line(0.45, 0.8, 0.58, 0.8, cfg.accent)
    line(0.58, 0.8, 0.47, 0.95, cfg.accent)
  end
  for i = 1, math.max(#shapes, shapeCount) do
    set('MeterWxIcon', ref(i), shapes[i] or '')
  end
  shapeCount = math.min(#shapes, MAX_SHAPES)
end

-- ---- drawing ------------------------------------------------

local NO_LOCATION = 'Windows location is off.\r\n'
  .. 'Turn on Windows Settings > Privacy & security > Location >\r\n'
  .. '"Let desktop apps access your location", or set\r\n'
  .. 'WeatherLatitude / WeatherLongitude in Variables.inc.'

local function draw()
  local have = data.temp ~= nil
  local place = cfg.place ~= '' and cfg.place or (data.place or '')
  local subColor = cfg.secondary
  local sub, tip

  if have then
    local info = CODES[data.code] or { 'Weather ' .. tostring(data.code), 'cloudy' }
    drawIcon(info[2], data.isDay)
    set('MeterWxTemp', 'Text', temp(data.temp))
    sub = info[1]
    if place ~= '' then sub = sub .. ' · ' .. place end

    local lines = { info[1] }
    if data.feels then lines[#lines + 1] = 'Feels like ' .. temp(data.feels) end
    if data.max and data.min then lines[#lines + 1] = 'High ' .. temp(data.max) .. ' · Low ' .. temp(data.min) end
    if data.humidity then lines[#lines + 1] = 'Humidity ' .. round(data.humidity) .. '%' end
    if data.wind then lines[#lines + 1] = 'Wind ' .. wind(data.wind) end
    local where = cfg.place ~= '' and cfg.place or (data.placeFull or '')
    if where ~= '' then lines[#lines + 1] = where end
    if data.updated then lines[#lines + 1] = 'Updated ' .. os.date('%H:%M', data.updated) end
    if data.status == 'nolocation' then
      lines[#lines + 1] = 'Location is off; showing the last known place.'
    elseif data.status ~= 'ok' and data.status ~= 'loading' then
      lines[#lines + 1] = 'Last update failed: ' .. (data.detail ~= '' and data.detail or data.status)
    end
    lines[#lines + 1] = 'Click to update'
    -- Open-Meteo data are CC BY 4.0: credit next to where they show.
    lines[#lines + 1] = 'Weather by Open-Meteo.com'
    tip = table.concat(lines, '\r\n')
  else
    drawIcon('none')
    set('MeterWxTemp', 'Text', '')
    if running or data.status == 'loading' then
      sub, tip = 'Loading weather…', ''
    elseif data.status == 'nolocation' then
      sub, tip, subColor = 'Location off', NO_LOCATION, cfg.warn
    elseif data.status == 'offline' then
      sub, tip, subColor = 'Weather offline', 'Click to try again', cfg.warn
    else
      sub, subColor = 'Weather unavailable', cfg.warn
      tip = (data.detail or '') .. '\r\nClick to try again'
    end
  end

  set('MeterWxSub', 'Text', sub)
  set('MeterWxSub', 'FontColor', subColor)
  set('MeterWxSub', 'ToolTipText', tip)
  set('MeterWxTemp', 'ToolTipText', tip)
  set('MeterWxIcon', 'ToolTipText', tip)
  SKIN:Bang('!UpdateMeterGroup', 'Weather')
  SKIN:Bang('!Redraw')
end

-- ---- running Weather.ps1 ------------------------------------

local function command()
  local s = 'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'
    .. var('@') .. 'Scripts\\Weather.ps1"'
  -- Only plain numbers / a language code go on the command line.
  local lat, lon = trim(var('WeatherLatitude')), trim(var('WeatherLongitude'))
  if lat:match('^%-?%d+%.?%d*$') and lon:match('^%-?%d+%.?%d*$') then
    s = s .. ' -Lat ' .. lat .. ' -Lon ' .. lon
  end
  local lang = trim(var('WeatherLanguage')):lower()
  if lang:match('^%a%a%a?$') then s = s .. ' -Lang ' .. lang end
  if cfg.place ~= '' then s = s .. ' -NoPlace' end
  return s
end

local function run()
  if running then return end
  running, runSince = true, os.time()
  set('MeasureWeatherRun', 'Parameter', command())
  SKIN:Bang('!UpdateMeasure', 'MeasureWeatherRun')
  SKIN:Bang('!CommandMeasure', 'MeasureWeatherRun', 'Run')
end

-- ---- Rainmeter entry points ----------------------------------

function Initialize()
  cfg.refresh   = math.max(600, tonumber(var('WeatherRefreshSeconds', '1800')) or 1800)
  cfg.fahrenheit = var('TempUnit', 'C'):upper() == 'F'
  cfg.place     = trim(var('WeatherPlace'))
  cfg.iconS     = num('WxIconS')
  cfg.strokeW   = num('IconStrokeW')
  cfg.secondary = var('ColorTextSecondary')
  cfg.accent    = var('ColorAccent')
  cfg.warn      = var('ColorWarn')
  load()
  -- A refresh of the suite (theme change, ...) reuses fresh data.
  if data.status == 'ok' and data.updated then
    nextRun = data.updated + cfg.refresh
  else
    nextRun = 0
  end
end

function Update()
  if not started then
    -- Meters exist now (not yet in Initialize).
    started = true
    draw()
  end
  if running and os.time() - runSince > BUSY_LIMIT then
    -- FinishAction never came (program could not start).
    running = false
    nextRun = os.time() + RETRY
  end
  if not running and os.time() >= nextRun then
    run()
    draw()
  end
  return 0
end

function OnDone()
  running = false
  load()
  local now = os.time()
  if data.status == 'ok' then
    nextRun = now + cfg.refresh
  elseif data.status == 'nolocation' then
    nextRun = now + cfg.refresh
  else
    nextRun = now + RETRY
  end
  draw()
end

function Refresh()
  run()
  draw()
end
