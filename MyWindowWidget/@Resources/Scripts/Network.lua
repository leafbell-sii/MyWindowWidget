-- =============================================================
--  MyWindowWidget - Network helper
--  * InNum()/InUnit(), OutNum()/OutUnit() : current rate split
--      into number and unit ("12.4" + "MB/s", "320" + "KB/s").
--      Bits mode (UseBits=1) gives "96.0" + "Mb/s", 1000-based.
--  * TodayIn()/TodayOut() : today's total ("1.2 GB").
--  * Update() : refreshes the above and accumulates today's
--      traffic. Must sit after MeasureNetIn/Out in the skin.
--
--  "Today" is counted here rather than with Cumulative=1:
--  Rainmeter's cumulative stats are per-interface and global,
--  so switching Wi-Fi <-> wired would make them jump. Summing
--  rate * interval keeps working across adapter changes.
--  The running total is saved to @Resources\Cache\NetToday.txt
--  every SaveEvery seconds and restarts at local midnight.
-- =============================================================

local SaveEvery = 30

local useBits, interval, cacheFile
local msIn, msOut
local today, totalIn, totalOut, sinceSave
local inNum, inUnit, outNum, outUnit = '0', 'B/s', '0', 'B/s'

local function readCache()
  local f = io.open(cacheFile, 'r')
  if not f then return end
  local d, i, o = f:read('*l'), f:read('*n'), f:read('*n')
  f:close()
  if d == today and i and o then
    totalIn, totalOut = i, o
  end
end

local function writeCache()
  local f = io.open(cacheFile, 'w')
  if not f then return end
  f:write(today, '\n', string.format('%.0f', totalIn), '\n', string.format('%.0f', totalOut), '\n')
  f:close()
end

function Initialize()
  useBits   = tonumber(SKIN:GetVariable('UseBits', '0')) == 1
  interval  = (tonumber(SKIN:GetVariable('NetUpdate', '1000')) or 1000) / 1000
  cacheFile = SKIN:GetVariable('@') .. 'Cache\\NetToday.txt'
  msIn      = SKIN:GetMeasure('MeasureNetIn')
  msOut     = SKIN:GetMeasure('MeasureNetOut')
  today     = os.date('%Y-%m-%d')
  totalIn, totalOut, sinceSave = 0, 0, 0
  readCache()
end

function Update()
  local now = os.date('%Y-%m-%d')
  if now ~= today then
    today, totalIn, totalOut = now, 0, 0
    writeCache()
  end

  -- Rate measures return bytes/s (bits/s when UseBits=1).
  local div = useBits and 8 or 1
  totalIn  = totalIn  + (msIn:GetValue()  / div) * interval
  totalOut = totalOut + (msOut:GetValue() / div) * interval

  inNum, inUnit   = FormatRate(msIn:GetValue())
  outNum, outUnit = FormatRate(msOut:GetValue())

  sinceSave = sinceSave + interval
  if sinceSave >= SaveEvery then
    sinceSave = 0
    writeCache()
  end
  return 0
end

local function scale(v, base, units)
  v = tonumber(v) or 0
  if v < 0 then v = 0 end
  local i = 1
  while v >= base and i < #units do
    v = v / base
    i = i + 1
  end
  local s
  if i == 1 then
    s = string.format('%d', math.floor(v + 0.5))
  elseif v < 100 then
    s = string.format('%.1f', v)
  else
    s = string.format('%d', math.floor(v + 0.5))
  end
  return s, units[i]
end

function FormatRate(v)
  if useBits then
    return scale(v, 1000, { 'b/s', 'Kb/s', 'Mb/s', 'Gb/s' })
  end
  return scale(v, 1024, { 'B/s', 'KB/s', 'MB/s', 'GB/s' })
end

function FormatBytes(v)
  local n, u = scale(v, 1024, { 'B', 'KB', 'MB', 'GB', 'TB' })
  return n .. ' ' .. u
end

function InNum()   return inNum   end
function InUnit()  return inUnit  end
function OutNum()  return outNum  end
function OutUnit() return outUnit end

function TodayIn()  return FormatBytes(totalIn)  end
function TodayOut() return FormatBytes(totalOut) end
