-- =============================================================
--  MyWindowWidget - Music card views (Music\Music.ini)
--
--  Two views:
--    mini  collapsed, as tall as the Clock card (group MiniView,
--          container MeterMiniView, cover mask MeterArtMask)
--    full  expanded (group FullView, container MeterFullView,
--          cover mask MeterArtMaskL); the card is Topmost while
--          expanded (ZOrder.lua) because it covers other cards.
--  Toggle() switches and saves the view in
--  @Resources\Cache\music.view, so it survives refreshes.
--
--  Meters that depend on the player state (cover image, play /
--  pause icon, seek bar, times, repeat-one mark) are not in the
--  view groups: this script shows the ones for the current view
--  on every update, so showing a view never shows e.g. both icons.
--
--  Times() : "1:24 / 3:51" (or "1:02:03 / 1:30:00" for long
--            tracks), from the WebNowPlaying Position / Duration
--            measures' numeric values (seconds).
-- =============================================================

local ms = {}
local g = {}
local view = 'mini'
local shown = {}
local started = false
local ZOrder

local GROUP = { mini = 'MiniView', full = 'FullView' }
local MASKS = {
  mini = { 'MeterMiniView', 'MeterArtMask' },
  full = { 'MeterFullView', 'MeterArtMaskL' },
}

local function num(name)
  return SKIN:ParseFormula(SKIN:ReplaceVariables('#' .. name .. '#')) or 0
end

local function viewFile() return SKIN:GetVariable('@') .. 'Cache\\music.view' end

-- Show / hide only when it changes.
local function vis(meter, on)
  if shown[meter] == on then return end
  shown[meter] = on
  SKIN:Bang(on and '!ShowMeter' or '!HideMeter', meter)
end

local function applyState()
  local state = ms.state:GetValue()
  local idle = ms.status:GetValue() == 0 or state == 0
  local playing = state == 1
  local cover = ms.cover:GetStringValue() ~= ''
  local full = view == 'full'
  local mini = not full

  vis('MeterArt', mini and cover)
  vis('MeterPlayIcon', mini and not playing)
  vis('MeterPauseIcon', mini and playing)
  vis('MeterSeek', mini and not idle)

  vis('MeterArtL', full and cover)
  vis('MeterPlayIconL', full and not playing)
  vis('MeterPauseIconL', full and playing)
  vis('MeterSeekL', full and not idle)
  vis('MeterTimesL', full and not idle)
  vis('MeterRepeatOne', full and ms.rep:GetValue() == 1)
end

local function applyView()
  local on = view
  local off = view == 'full' and 'mini' or 'full'
  SKIN:Bang('!SetVariable', 'CardH', tostring(view == 'full' and g.hFull or g.hMini))
  SKIN:Bang('!HideMeterGroup', GROUP[off])
  for _, m in ipairs(MASKS[off]) do SKIN:Bang('!HideMeter', m) end
  for _, m in ipairs(MASKS[on]) do SKIN:Bang('!ShowMeter', m) end
  SKIN:Bang('!ShowMeterGroup', GROUP[on])
  shown = {}
  applyState()
  if view == 'full' then ZOrder.Raise('music') else ZOrder.Restore('music') end
  SKIN:Bang('!UpdateMeter', '*')
  SKIN:Bang('!Redraw')
end

function Initialize()
  ms.status = SKIN:GetMeasure('MeasureStatus')
  ms.state = SKIN:GetMeasure('MeasureState')
  ms.rep = SKIN:GetMeasure('MeasureRepeat')
  ms.cover = SKIN:GetMeasure('MeasureCoverPath')
  ms.pos = SKIN:GetMeasure('MeasurePosition')
  ms.dur = SKIN:GetMeasure('MeasureDuration')
  g.hMini = num('CardHMini')
  g.hFull = num('CardHFull')
  ZOrder = dofile(SKIN:GetVariable('@') .. 'Scripts\\ZOrder.lua')

  local f = io.open(viewFile(), 'r')
  if f then
    if (f:read('*l') or '') == 'full' then view = 'full' end
    f:close()
  end
end

function Update()
  if not started then
    -- Meters exist now (not yet in Initialize).
    started = true
    applyView()
  else
    applyState()
  end
  return 0
end

function Toggle()
  view = view == 'full' and 'mini' or 'full'
  local f = io.open(viewFile(), 'w')
  if f then
    f:write(view)
    f:close()
  end
  applyView()
end

local function fmt(s)
  s = math.floor((tonumber(s) or 0) + 0.5)
  if s < 0 then s = 0 end
  local h = math.floor(s / 3600)
  local m = math.floor((s % 3600) / 60)
  local sec = s % 60
  if h > 0 then
    return string.format('%d:%02d:%02d', h, m, sec)
  end
  return string.format('%d:%02d', m, sec)
end

function Times()
  return fmt(ms.pos:GetValue()) .. ' / ' .. fmt(ms.dur:GetValue())
end
