-- =============================================================
--  MyWindowWidget - Calendar controller
--  ENCODING: this file is saved as UTF-16 LE (with BOM) on purpose.
--  That makes Rainmeter run it in Unicode mode, so event titles are
--  UTF-8 inside Lua instead of the ANSI code page (emoji, CJK, ...).
--  Rainmeter 4.5 does not accept a UTF-8 BOM. Keep this encoding.
--
--  * Fills the 6x7 grid (MeterDay1..42), weekday header, month
--    title, today highlight, selected-day ring and event dots
--    (MeterCellShapes) for the month being viewed.
--  * Fills the Upcoming list (MeterUpWhen1..N / MeterUpText1..N,
--    dots in MeterUpDots): next events from now, or the events of
--    the day the user clicked.
--  * Loads iCal data: WebParser measures MeasureICal1..4 capture
--    the whole feed as their string value and call
--    OnDownloaded(N) / OnError(N) / OnInvalid(N). Good feeds are
--    copied to @Resources\Cache\calN.ics, which is also read at
--    start-up and used while offline.
--
--  Bangs (from the skin): Prev(), Next(), Today(), Select(i),
--  OnDownloaded(n), OnError(n), Refresh()
-- =============================================================

local MAX_CALS = 4
local CELLS = 42
local MONTHS = { 'January', 'February', 'March', 'April', 'May', 'June', 'July',
                 'August', 'September', 'October', 'November', 'December' }
local MONTHS_SHORT = { 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug',
                       'Sep', 'Oct', 'Nov', 'Dec' }
local WEEKDAYS_MON = { 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun' }
local WEEKDAYS_SUN = { 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat' }

local Parser
local cfg = {}           -- sizes / colours read from the skin
local enabled = {}       -- [n] = true when ICalUrlN is set
local status = {}        -- [n] = 'ok' | 'offline' | 'invalid' | 'none'
local occ = {}           -- [n] = occurrences of calendar n
local dayCals = {}       -- ['YYYY-MM-DD'] = { [n] = true }
local viewY, viewM
local todayKey
local selectedKey        -- nil = Upcoming mode
local cellKeys = {}      -- [i] = day key of grid cell i
local upRows

-- ---- small helpers -------------------------------------------

local function num(name)
  return SKIN:ParseFormula(SKIN:ReplaceVariables('#' .. name .. '#')) or 0
end

local function var(name, default)
  return SKIN:GetVariable(name, default or '')
end

local function trim(s) return (s or ''):match('^%s*(.-)%s*$') end

local function dayKey(t) return os.date('%Y-%m-%d', t) end

local function noon(y, m, d)
  return os.time{ year = y, month = m, day = d, hour = 12 }
end

local function addDays(t, n)
  local d = os.date('*t', t)
  d.day = d.day + n
  d.isdst = nil
  return os.time(d)
end

local function isoWeekday(t)
  return (os.date('*t', t).wday + 5) % 7 + 1
end

local function readFile(path)
  local f = io.open(path, 'rb')
  if not f then return nil end
  local s = f:read('*a')
  f:close()
  return s
end

local function writeFile(path, s)
  local f = io.open(path, 'wb')
  if not f then return false end
  f:write(s)
  f:close()
  return true
end

local function looksLikeICal(s)
  return s and s:find('BEGIN:VCALENDAR', 1, true) ~= nil
end

local function set(meter, option, value)
  SKIN:Bang('!SetOption', meter, option, tostring(value))
end

local function cachePath(n) return var('@') .. 'Cache\\cal' .. n .. '.ics' end

-- ---- data ----------------------------------------------------

-- Expand window: 1 month back .. 2 months ahead (spec), from today.
local function range()
  local d = os.date('*t')
  local s = os.time{ year = d.year, month = d.month - 1, day = 1, hour = 0 }
  local e = os.time{ year = d.year, month = d.month + 3, day = 1, hour = 0 }
  return s, e
end

local function rebuildDays()
  dayCals = {}
  for n = 1, MAX_CALS do
    for _, o in ipairs(occ[n] or {}) do
      -- Mark every day the event touches (DTEND is exclusive).
      local last = math.max(o.t, o.finish - 1)
      local t = o.t
      local guard = 0
      while dayKey(t) <= dayKey(last) and guard < 400 do
        local k = dayKey(t)
        dayCals[k] = dayCals[k] or {}
        dayCals[k][n] = true
        t = addDays(t, 1)
        guard = guard + 1
      end
    end
  end
end

local function loadText(n, text)
  local s, e = range()
  local ok, res = pcall(Parser.parse, text, s, e, n)
  if ok then
    occ[n] = res
    return true
  end
  print('MyWindowWidget Calendar: parse error in calendar ' .. n .. ': ' .. tostring(res))
  return false
end

-- ---- drawing -------------------------------------------------

local function drawGrid()
  set('MeterMonth', 'Text', MONTHS[viewM] .. ' ' .. viewY)

  local wds = cfg.weekStartMon and WEEKDAYS_MON or WEEKDAYS_SUN
  for c = 1, 7 do set('MeterWd' .. c, 'Text', wds[c]) end

  local first = noon(viewY, viewM, 1)
  local wd = isoWeekday(first)
  local lead = cfg.weekStartMon and (wd - 1) or (wd % 7)
  local start = addDays(first, -lead)

  local shapes = { 'Rectangle 0,0,' .. cfg.gridW .. ',' .. cfg.gridH ..
                   ' | Fill Color 0,0,0,1 | StrokeWidth 0' }
  for i = 1, CELLS do
    local t = addDays(start, i - 1)
    local d = os.date('*t', t)
    local key = dayKey(t)
    cellKeys[i] = key
    local col, row = (i - 1) % 7, math.floor((i - 1) / 7)
    local cx = (col + 0.5) * cfg.cellW
    local cy = row * cfg.cellH + cfg.cellH * 0.42

    local color = (d.month == viewM) and cfg.cText or cfg.cMuted
    local weight = 400
    if key == todayKey then
      shapes[#shapes + 1] = string.format('Ellipse %.2f,%.2f,%.2f | Fill Color %s | StrokeWidth 0',
        cx, cy, cfg.cellH * 0.38, cfg.cAccent)
      color, weight = cfg.cOnAccent, 700
    end
    if key == selectedKey then
      shapes[#shapes + 1] = string.format('Ellipse %.2f,%.2f,%.2f | Fill Color 0,0,0,0 | StrokeWidth %.2f | Stroke Color %s',
        cx, cy, cfg.cellH * 0.38, cfg.ringW, cfg.cAccent)
    end

    -- Event dots (one per calendar, max 3) under the number.
    local cals = dayCals[key]
    if cals then
      local list = {}
      for n = 1, MAX_CALS do if cals[n] then list[#list + 1] = n end end
      while #list > 3 do table.remove(list) end
      local gap = cfg.dotR * 2.6
      local x0 = cx - (#list - 1) * gap / 2
      local dy = row * cfg.cellH + cfg.cellH * 0.86
      local alpha = (d.month == viewM) and '' or 'dim'
      for j, n in ipairs(list) do
        local c = (alpha == 'dim') and cfg.calDim[n] or cfg.calColor[n]
        shapes[#shapes + 1] = string.format('Ellipse %.2f,%.2f,%.2f | Fill Color %s | StrokeWidth 0',
          x0 + (j - 1) * gap, dy, cfg.dotR, c)
      end
    end

    local m = 'MeterDay' .. i
    set(m, 'Text', d.day)
    set(m, 'FontColor', color)
    set(m, 'FontWeight', weight)
  end

  for j, s in ipairs(shapes) do
    set('MeterCellShapes', j == 1 and 'Shape' or ('Shape' .. j), s)
  end
  -- An empty ShapeN ends the list (clears dots from a previous draw).
  set('MeterCellShapes', 'Shape' .. (#shapes + 1), '')
end

local function whenLabel(o, withDay)
  local time = o.allDay and 'All day' or os.date('%H:%M', o.t)
  if not withDay then return time end
  local k = dayKey(math.max(o.t, os.time()))
  local day
  if k == todayKey then
    day = 'Today'
  elseif k == dayKey(addDays(os.time(), 1)) then
    day = 'Tomorrow'
  else
    local d = os.date('*t', o.t)
    day = MONTHS_SHORT[d.month] .. ' ' .. d.day
  end
  return day .. '  ' .. time
end

local function drawList()
  local items, header, withDay = {}, 'Upcoming', true
  local nowT = os.time()

  if selectedKey then
    local y, m, d = selectedKey:match('(%d+)-(%d+)-(%d+)')
    header = MONTHS_SHORT[tonumber(m)] .. ' ' .. tonumber(d)
    withDay = false
    for n = 1, MAX_CALS do
      for _, o in ipairs(occ[n] or {}) do
        if dayKey(o.t) <= selectedKey and dayKey(math.max(o.t, o.finish - 1)) >= selectedKey then
          items[#items + 1] = o
        end
      end
    end
  else
    for n = 1, MAX_CALS do
      for _, o in ipairs(occ[n] or {}) do
        if o.finish > nowT or (o.allDay and dayKey(o.t) == todayKey) then
          items[#items + 1] = o
        end
      end
    end
  end
  table.sort(items, function(a, b)
    if a.t ~= b.t then return a.t < b.t end
    if a.allDay ~= b.allDay then return a.allDay end
    return a.summary < b.summary
  end)

  set('MeterUpTitle', 'Text', header)

  -- Status: hint when nothing is configured, "offline" when a
  -- calendar could not be fetched (cached data still shown).
  local anyEnabled, offline = false, false
  for n = 1, MAX_CALS do
    if enabled[n] then anyEnabled = true end
    if status[n] == 'offline' or status[n] == 'invalid' then offline = true end
  end
  set('MeterUpStatus', 'Text', offline and 'offline' or '')

  local message
  if not anyEnabled then
    message = 'Add your iCal URL in Secrets.inc'
  elseif #items == 0 then
    message = selectedKey and 'No events' or 'No upcoming events'
  end

  local dots = { 'Rectangle 0,0,1,1 | Fill Color 0,0,0,0 | StrokeWidth 0' }
  for r = 1, upRows do
    local o = items[r]
    if o then
      set('MeterUpWhen' .. r, 'Text', whenLabel(o, withDay))
      set('MeterUpText' .. r, 'Text', o.summary)
      local y = (r - 0.5) * cfg.rowH
      dots[#dots + 1] = string.format('Ellipse %.2f,%.2f,%.2f | Fill Color %s | StrokeWidth 0',
        cfg.dotR * 1.2, y, cfg.dotR * 1.2, cfg.calColor[o.cal])
    elseif r == 1 and message then
      set('MeterUpWhen1', 'Text', message)
      set('MeterUpText1', 'Text', '')
    else
      set('MeterUpWhen' .. r, 'Text', '')
      set('MeterUpText' .. r, 'Text', '')
    end
  end
  for j, s in ipairs(dots) do
    set('MeterUpDots', j == 1 and 'Shape' or ('Shape' .. j), s)
  end
  set('MeterUpDots', 'Shape' .. (#dots + 1), '')
end

local function redraw()
  drawGrid()
  drawList()
  SKIN:Bang('!UpdateMeterGroup', 'Cal')
  SKIN:Bang('!Redraw')
end

-- ---- Rainmeter entry points ------------------------------------

function Initialize()
  Parser = dofile(var('@') .. 'Scripts\\ICalParser.lua')
  Parser.localTZID = var('LocalTZID', 'Asia/Seoul')

  cfg.weekStartMon = trim(var('WeekStart', 'Mon')):lower() ~= 'sun'
  cfg.cellW = num('CellW')
  cfg.cellH = num('CellH')
  cfg.gridW = cfg.cellW * 7
  cfg.gridH = cfg.cellH * 6
  cfg.rowH = num('UpRowH')
  cfg.dotR = num('DotR')
  cfg.ringW = num('Scale') * 1.2
  cfg.cText = var('ColorTextPrimary')
  cfg.cMuted = var('ColorTextMuted')
  cfg.cAccent = var('ColorAccent')
  cfg.cOnAccent = var('ColorOnAccent')
  cfg.calColor, cfg.calDim = {}, {}
  for n = 1, MAX_CALS do
    local c = var('ColorCal' .. n, var('ColorAccent'))
    cfg.calColor[n] = c
    cfg.calDim[n] = (c:gsub(',%s*%d+%s*$', ',90'))
  end
  upRows = math.floor(num('UpRows'))

  local today = os.time()
  todayKey = dayKey(today)
  local d = os.date('*t', today)
  viewY, viewM = d.year, d.month

  for n = 1, MAX_CALS do
    occ[n] = {}
    local url = trim(var('ICalUrl' .. n, ''))
    if url ~= '' then
      enabled[n] = true
      status[n] = 'none'
      local cached = readFile(cachePath(n))
      if looksLikeICal(cached) then loadText(n, cached) end
    end
  end
  rebuildDays()
end

local started = false

-- Called every skin update (1 s). The first call draws and starts
-- the downloads (meters and measures all exist by then); later
-- calls only act when the date changes.
function Update()
  if not started then
    started = true
    for n = 1, MAX_CALS do
      if enabled[n] then SKIN:Bang('!EnableMeasure', 'MeasureICal' .. n) end
    end
    redraw()
    return 0
  end

  local k = dayKey(os.time())
  if k ~= todayKey then
    todayKey = k
    -- Re-expand recurrences around the new date.
    for n = 1, MAX_CALS do
      local cached = enabled[n] and readFile(cachePath(n))
      if looksLikeICal(cached) then loadText(n, cached) end
    end
    rebuildDays()
    redraw()
  end
  return 0
end

function OnDownloaded(n)
  local m = SKIN:GetMeasure('MeasureICal' .. n)
  local text = m and m:GetStringValue()
  if looksLikeICal(text) and loadText(n, text) then
    writeFile(cachePath(n), text)
    status[n] = 'ok'
  else
    status[n] = 'invalid'
  end
  rebuildDays()
  redraw()
end

-- Host unreachable: keep showing the cached data.
function OnError(n)
  status[n] = 'offline'
  redraw()
end

-- Reached, but the response is not a calendar (wrong or revoked
-- URL, Google sign-in page, ...).
function OnInvalid(n)
  status[n] = 'invalid'
  redraw()
end

function Prev()
  viewM = viewM - 1
  if viewM < 1 then viewM, viewY = 12, viewY - 1 end
  redraw()
end

function Next()
  viewM = viewM + 1
  if viewM > 12 then viewM, viewY = 1, viewY + 1 end
  redraw()
end

function Today()
  local d = os.date('*t')
  viewY, viewM, selectedKey = d.year, d.month, nil
  redraw()
end

-- Click on a day: list that day's events; click again to go back
-- to Upcoming. Clicking a day of another month also switches to it.
function Select(i)
  local key = cellKeys[i]
  if not key then return end
  if key == selectedKey then
    selectedKey = nil
  else
    selectedKey = key
    local y, m = key:match('(%d+)-(%d+)')
    viewY, viewM = tonumber(y), tonumber(m)
  end
  redraw()
end

-- Back to Upcoming without changing the month.
function ClearSelection()
  selectedKey = nil
  redraw()
end
