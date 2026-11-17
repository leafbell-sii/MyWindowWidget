-- =============================================================
--  MyWindowWidget - System skin helper (System\System.ini)
--  This is the script measure MeasureGPU: Update() returns the GPU
--  usage in percent, so the GPU graph and value read it directly.
--
--  GPU: @Resources\Scripts\GpuLoad.ps1 runs in a hidden window
--  (RunCommand measure MeasureGpuRun) and writes
--  @Resources\Cache\gpu.txt ("<unix time> <percent>" or
--  "<unix time> na") every GPU_INTERVAL seconds; see its header for
--  why it is not the UsageMonitor plugin. This script writes
--  Cache\gpu.alive every ALIVE_EVERY seconds; GpuLoad.ps1 stops when
--  that file gets old (skin unloaded, Rainmeter gone). When gpu.txt
--  is stale the script is started again (one copy at a time: it
--  holds a named mutex, a second copy exits at once).
--
--  Drives: SystemDrives (Variables.inc) lists up to four drives,
--  e.g. "C:|D:". Each listed drive gets a slot (measures
--  MeasureDriveFree/Total/PctN, meter group DriveN): its Drive=
--  option and label are set here. Unused slots are disabled; the
--  rows of drives that exist are packed (layoutDrives), the others
--  hidden and moved to Y=0 (a hidden meter still stretches the
--  window), and CardH is set to fit the shown rows.
-- =============================================================

local MAX_DRIVES = 4    -- slots in System.ini
local GPU_INTERVAL = 2  -- seconds between GpuLoad.ps1 samples
local STALE = 4 * GPU_INTERVAL + 2
local RELAUNCH_WAIT = 30
local ALIVE_EVERY = 10

local drives = {}
local started = false
local gpu = 0
local gpuNA = false
local lastLaunch = -RELAUNCH_WAIT
local lastAlive = 0

local function var(name, default) return SKIN:GetVariable(name, default or '') end
local function num(name)
  return SKIN:ParseFormula(SKIN:ReplaceVariables('#' .. name .. '#')) or 0
end
local function cache(name) return var('@') .. 'Cache\\' .. name end

function Initialize()
  drives = {}
  for d in var('SystemDrives', 'C:'):gmatch('[^|]+') do
    d = d:match('^%s*(.-)%s*$'):upper()
    -- "C" is taken as "C:".
    if d:match('^%a$') then d = d .. ':' end
    if d:match('^%a:$') and #drives < MAX_DRIVES then drives[#drives + 1] = d end
  end
end

-- Meters exist now (not yet in Initialize).
local function setupDrives()
  for i = 1, MAX_DRIVES do
    local d = drives[i]
    local free, total, pct = 'MeasureDriveFree' .. i, 'MeasureDriveTotal' .. i, 'MeasureDrivePct' .. i
    if d then
      SKIN:Bang('!SetOption', free, 'Drive', d)
      SKIN:Bang('!SetOption', total, 'Drive', d)
      SKIN:Bang('!SetOption', 'MeterDriveLabel' .. i, 'Text', d)
      SKIN:Bang('!UpdateMeasure', free)
      SKIN:Bang('!UpdateMeasure', total)
      SKIN:Bang('!UpdateMeasure', pct)
    else
      SKIN:Bang('!DisableMeasure', free)
      SKIN:Bang('!DisableMeasure', total)
      SKIN:Bang('!DisableMeasure', pct)
    end
  end
end

-- Rows for the listed drives that exist (total size > 0), packed
-- from the top. Re-checked every DRIVE_CHECK seconds so a drive
-- that appears or goes away (USB, network) moves the rows.
local DRIVE_CHECK = 30
local lastCheck = -DRIVE_CHECK
local layoutKey

local function layoutDrives(now)
  if now - lastCheck < DRIVE_CHECK then return end
  lastCheck = now
  local present, key = {}, ''
  for i = 1, MAX_DRIVES do
    local m = drives[i] and SKIN:GetMeasure('MeasureDriveTotal' .. i)
    present[i] = m ~= nil and m:GetValue() > 0
    key = key .. (present[i] and '1' or '0')
  end
  if key == layoutKey then return end
  layoutKey = key

  local rowH, y0 = num('DriveRowH'), num('DriveY')
  local labelDY, valueH, barH = num('DriveLabelDY'), num('DriveValueH'), num('BarH')
  local k = 0
  for i = 1, MAX_DRIVES do
    local group = 'Drive' .. i
    if present[i] then
      local y = y0 + k * rowH
      k = k + 1
      SKIN:Bang('!SetOption', 'MeterDriveLabel' .. i, 'Y', tostring(y + labelDY))
      SKIN:Bang('!SetOption', 'MeterDriveValue' .. i, 'Y', tostring(y))
      SKIN:Bang('!SetOption', 'MeterDriveBar' .. i, 'Y', tostring(y + valueH / 2 - barH / 2))
      SKIN:Bang('!SetOption', 'MeterDriveDetail' .. i, 'Y', tostring(y + labelDY))
      SKIN:Bang('!ShowMeterGroup', group)
    else
      SKIN:Bang('!SetOptionGroup', group, 'Y', '0')
      SKIN:Bang('!HideMeterGroup', group)
    end
  end
  local h = num('CardHBase') + k * rowH
  if k == 0 then
    -- No drive rows: end the card under RAM, without the separator.
    SKIN:Bang('!HideMeter', 'MeterSep2')
    h = num('RamY') + num('ValueH') + num('Pad')
  else
    SKIN:Bang('!ShowMeter', 'MeterSep2')
  end
  SKIN:Bang('!SetVariable', 'CardH', tostring(h))
  SKIN:Bang('!UpdateMeter', '*')
  SKIN:Bang('!Redraw')
end

-- ---- GPU ----------------------------------------------------

local function touchAlive(now)
  if now - lastAlive < ALIVE_EVERY then return end
  lastAlive = now
  local f = io.open(cache('gpu.alive'), 'w')
  if f then
    f:write(tostring(now))
    f:close()
  end
end

local function launch(now)
  lastLaunch = now
  SKIN:Bang('!SetOption', 'MeasureGpuRun', 'Parameter',
    'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'
    .. var('@') .. 'Scripts\\GpuLoad.ps1" -Interval ' .. GPU_INTERVAL)
  SKIN:Bang('!UpdateMeasure', 'MeasureGpuRun')
  SKIN:Bang('!CommandMeasure', 'MeasureGpuRun', 'Run')
end

local function readGpu(now)
  local f = io.open(cache('gpu.txt'), 'r')
  local s = f and f:read('*a') or ''
  if f then f:close() end
  local t, v = s:match('^(%d+)%s+(%S+)')
  t = tonumber(t)
  if t and now - t <= STALE then
    gpuNA = v == 'na'
    gpu = tonumber(v) or 0
    return
  end
  -- Missing or stale: (re)start the sampler, keep the last value.
  if now - lastLaunch >= RELAUNCH_WAIT then launch(now) end
end

local naShown
local function showNA()
  if naShown == gpuNA then return end
  naShown = gpuNA
  SKIN:Bang('!SetOption', 'MeterGpuValue', 'Text', gpuNA and 'n/a' or '%1%')
  SKIN:Bang('!SetOption', 'MeterGpuValue', 'ToolTipText', gpuNA and 'No GPU performance counters' or '')
end

function Update()
  local now = os.time()
  if not started then
    started = true
    setupDrives()
  end
  layoutDrives(now)
  touchAlive(now)
  readGpu(now)
  showNA()
  return gpuNA and 0 or gpu
end
