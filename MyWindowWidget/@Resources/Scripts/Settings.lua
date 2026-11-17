-- =============================================================
--  MyWindowWidget - Settings controller
--
--  Draws the current choices (theme swatches, opacity / week
--  start pills, 24h / seconds toggles) and writes a change to
--  @Resources\Variables.inc, then refreshes every MyWindowWidget skin.
--
--  Theme swatches read ColorBgRGB / ColorAccent straight from
--  each @Resources\Themes\<Name>.inc listed in ThemeList, so a
--  new theme only needs its file and a ThemeList entry.
--
--  Folding (SettingsCollapsed) hides meter group Body and its
--  container MeterBody and shrinks CardH to the title row. It is
--  saved too, but needs no refresh.
--
--  Bangs: SetTheme(i), SetAlpha(a), Toggle('Use24h'|'ShowSeconds'),
--         SetWeekStart('Mon'|'Sun'), ToggleFold()
-- =============================================================

local MAX_THEMES = 8   -- two rows of four swatches in Settings.ini
local ALPHAS = { 178, 217, 255 }   -- 70% / 85% / 100%

local themes = {}
local c = {}       -- colours
local g = {}       -- geometry
local folded = false

local function var(name, default) return SKIN:GetVariable(name, default or '') end
local function num(name)
  return SKIN:ParseFormula(SKIN:ReplaceVariables('#' .. name .. '#')) or 0
end
local function set(meter, option, value)
  SKIN:Bang('!SetOption', meter, option, tostring(value))
end

local function readThemeColors(name)
  local f = io.open(var('@') .. 'Themes\\' .. name .. '.inc', 'r')
  if not f then return nil end
  local s = f:read('*a')
  f:close()
  local bg = s:match('\nColorBgRGB%s*=%s*([%d,%s]+)')
  local accent = s:match('\nColorAccent%s*=%s*([%d,%s]+)')
  if not bg or not accent then return nil end
  bg = bg:gsub('%s', '')
  accent = accent:gsub('%s', '')
  return { bg = bg .. ',255', accent = accent }
end

-- Rounded pill; selected = accent tint + primary text.
local function pill(shapeMeter, textMeter, selected)
  local fill = selected and c.accentDim or c.bgAlt
  local stroke = selected and c.accent or c.border
  set(shapeMeter, 'Shape', string.format(
    'Rectangle 0.5,0.5,%.2f,%.2f,%.2f | Fill Color %s | StrokeWidth 1 | Stroke Color %s',
    g.pillW - 1, g.pillH - 1, (g.pillH - 1) / 2, fill, stroke))
  set(textMeter, 'FontColor', selected and c.text or c.secondary)
end

local function toggle(meter, on)
  local r = g.trackH / 2
  local knobR = r - 3 * g.scale
  local cx = on and (g.trackW - r) or r
  set(meter, 'Shape', string.format(
    'Rectangle 0.5,0.5,%.2f,%.2f,%.2f | Fill Color %s | StrokeWidth 1 | Stroke Color %s',
    g.trackW - 1, g.trackH - 1, r - 0.5, on and c.accent or c.bgAlt, on and c.accent or c.border))
  set(meter, 'Shape2', string.format('Ellipse %.2f,%.2f,%.2f | Fill Color %s | StrokeWidth 0',
    cx, r, knobR, on and c.onAccent or c.secondary))
end

local function draw()
  local current = var('Theme', 'Brown')
  for i = 1, MAX_THEMES do
    local t = themes[i]
    local sw, name = 'MeterSw' .. i, 'MeterSwName' .. i
    if t then
      local r = g.swD / 2
      set(sw, 'Shape', string.format('Ellipse %.2f,%.2f,%.2f | Fill Color %s | StrokeWidth 1 | Stroke Color %s',
        r + 3, r + 3, r, t.colors.bg, c.border))
      set(sw, 'Shape2', string.format('Ellipse %.2f,%.2f,%.2f | Fill Color %s | StrokeWidth 0',
        r + 3, r + 3, r * 0.42, t.colors.accent))
      if t.name == current then
        set(sw, 'Shape3', string.format('Ellipse %.2f,%.2f,%.2f | Fill Color 0,0,0,0 | StrokeWidth %.2f | Stroke Color %s',
          r + 3, r + 3, r + 2, 1.6 * g.scale, c.accent))
        set(name, 'FontColor', c.text)
      else
        set(sw, 'Shape3', '')
        set(name, 'FontColor', c.secondary)
      end
      set(name, 'Text', t.name)
      SKIN:Bang('!ShowMeter', sw)
      SKIN:Bang('!ShowMeter', name)
    else
      SKIN:Bang('!HideMeter', sw)
      SKIN:Bang('!HideMeter', name)
    end
  end

  local alpha = tonumber(var('BgAlpha', '217')) or 217
  for i, a in ipairs(ALPHAS) do
    pill('MeterOp' .. i, 'MeterOpText' .. i, alpha == a)
  end

  toggle('MeterT24', var('Use24h', '1') == '1')
  toggle('MeterTSec', var('ShowSeconds', '1') == '1')

  local mon = var('WeekStart', 'Mon'):lower() ~= 'sun'
  pill('MeterWs1', 'MeterWsText1', mon)
  pill('MeterWs2', 'MeterWsText2', not mon)

  SKIN:Bang('!UpdateMeterGroup', 'Set')
  SKIN:Bang('!Redraw')
end

-- Open: show Body (the swatches of missing themes stay hidden).
local function applyFold()
  SKIN:Bang('!SetVariable', 'CardH', tostring(folded and g.cardHFolded or g.cardHOpen))
  set('MeterFold', 'Shape2', folded and 'Path FoldDown | Extend FoldStroke' or 'Path FoldUp | Extend FoldStroke')
  set('MeterFold', 'ToolTipText', folded and 'Unfold' or 'Fold')
  -- Hiding the container is what shrinks the window (Settings.ini).
  if folded then
    SKIN:Bang('!HideMeterGroup', 'Body')
    SKIN:Bang('!HideMeter', 'MeterBody')
  else
    SKIN:Bang('!ShowMeter', 'MeterBody')
    SKIN:Bang('!ShowMeterGroup', 'Body')
    draw()
  end
  SKIN:Bang('!UpdateMeter', '*')
  SKIN:Bang('!Redraw')
end

local function write(key, value)
  SKIN:Bang('!WriteKeyValue', 'Variables', key, tostring(value), var('@') .. 'Variables.inc')
end

local function applyAll()
  SKIN:Bang('!RefreshGroup', 'MyWindowWidget')
end

function Initialize()
  c.text = var('ColorTextPrimary')
  c.secondary = var('ColorTextSecondary')
  c.accent = var('ColorAccent')
  c.accentDim = var('ColorAccentDim')
  c.onAccent = var('ColorOnAccent')
  c.bgAlt = var('ColorBgAlt')
  c.border = var('ColorBorder')

  g.scale = num('Scale')
  g.swD = num('SwD')
  g.pillW = num('PillW')
  g.pillH = num('PillH')
  g.trackW = num('TrackW')
  g.trackH = num('TrackH')
  g.cardHOpen = num('CardHOpen')
  g.cardHFolded = num('CardHFolded')
  folded = var('SettingsCollapsed', '0') == '1'

  themes = {}
  for name in var('ThemeList', 'Brown'):gmatch('[^|]+') do
    name = name:match('^%s*(.-)%s*$')
    local colors = name ~= '' and readThemeColors(name)
    if colors and #themes < MAX_THEMES then
      themes[#themes + 1] = { name = name, colors = colors }
    end
  end
end

local started = false
function Update()
  if not started then
    started = true
    draw()
    applyFold()
  end
  return 0
end

function ToggleFold()
  folded = not folded
  write('SettingsCollapsed', folded and 1 or 0)
  applyFold()
end

function SetTheme(i)
  local t = themes[i]
  if not t or t.name == var('Theme') then return end
  write('Theme', t.name)
  applyAll()
end

function SetAlpha(a)
  a = math.max(0, math.min(255, math.floor(tonumber(a) or 217)))
  write('BgAlpha', a)
  write('BgAlphaHover', math.min(255, a + 18))
  applyAll()
end

function Toggle(key)
  if key ~= 'Use24h' and key ~= 'ShowSeconds' then return end
  write(key, var(key, '1') == '1' and 0 or 1)
  applyAll()
end

function SetWeekStart(v)
  if v ~= 'Mon' and v ~= 'Sun' then return end
  write('WeekStart', v)
  applyAll()
end
