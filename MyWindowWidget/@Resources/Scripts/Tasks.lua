-- =============================================================
--  MyWindowWidget - Google Tasks controller
--  ENCODING: this file is saved as UTF-16 LE (with BOM) on purpose,
--  like Calendar.lua. Rainmeter then runs it in Unicode mode, so
--  task titles are UTF-8 inside Lua (Korean, emoji, ...).
--
--  Google is reached by @Resources\Scripts\GTasks.ps1, started in a
--  hidden window by the RunCommand measure MeasureRun. The script
--  writes @Resources\Cache\tasks<Slot>.txt, OnDone() reads it. One
--  command runs at a time; the others wait in a queue.
--
--  Files in @Resources\Cache (N = TasksSlot):
--    tasksN.txt  result of the last run (format: GTasks.ps1 header)
--    tasksN.sel  id of the list picked with < > (none = list N)
--    tasksN.new  title of the task being added (UTF-8), written
--                right before the add command starts
--
--  Completing and adding show up at once (optimistic); the run that
--  follows replaces them with what Google returns.
--
--  Bangs (from the skin): Refresh(), PrevList(), NextList(),
--  Complete(row), Add(title), OnDone()
-- =============================================================

local MAX_ROWS = 10
local BUSY_LIMIT = 90   -- seconds; RunCommand Timeout is 60
local MONTHS = { 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' }

local cfg = {}
local slot, rows, refreshEvery
local lists, tasks = {}, {}
local shownList             -- entry of `lists` shown by this slot
local status, detail = 'loading', ''
local picked = ''           -- contents of tasksN.sel
local queue = {}
local running               -- queue item being run, nil = idle
local runSince = 0
local lastFetch = 0
local started = false
local doneIds = {}          -- completed here, not yet confirmed
local addTitles = {}        -- added here, not yet confirmed

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

local function show(meter, on)
  SKIN:Bang(on and '!ShowMeter' or '!HideMeter', meter)
end

local function cachePath(ext)
  return var('@') .. 'Cache\\tasks' .. slot .. '.' .. ext
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

-- Google ids are URL-safe base64; nothing else goes on a command line.
local function safeId(id)
  return id ~= nil and id:match('^[%w_%-]+$') ~= nil
end

local function split(line)
  local t = {}
  for field in (line .. '\t'):gmatch('([^\t]*)\t') do t[#t + 1] = field end
  return t
end

-- ---- cache --------------------------------------------------

local function loadCache()
  lists, tasks, shownList = {}, {}, nil
  local s = readFile(cachePath('txt'))
  if not s then
    status, detail = 'loading', ''
    return
  end
  for line in s:gmatch('[^\n]+') do
    local f = split((line:gsub('\r$', '')))
    if f[1] == 'status' then
      status, detail = f[2] or 'error', f[3] or ''
    elseif f[1] == 'list' then
      local l = { id = f[2], title = f[4] or '' }
      lists[#lists + 1] = l
      if f[3] == '1' then shownList = l end
    elseif f[1] == 'task' and not doneIds[f[2]] then
      tasks[#tasks + 1] = { id = f[2], depth = tonumber(f[3]) or 0, due = f[4] or '', title = f[5] or '' }
    end
  end
  -- Added here but not on Google yet: keep them at the top.
  for i = #addTitles, 1, -1 do
    table.insert(tasks, 1, { id = '', depth = 0, due = '', title = addTitles[i], pending = true })
  end
end

-- ---- drawing ------------------------------------------------

local function dueLabel(due)
  local y, m, d = due:match('^(%d+)-(%d+)-(%d+)$')
  if not y then return '', cfg.secondary end
  y, m, d = tonumber(y), tonumber(m), tonumber(d)
  local now = os.date('*t')
  local today = os.time { year = now.year, month = now.month, day = now.day, hour = 12 }
  local days = math.floor((os.time { year = y, month = m, day = d, hour = 12 } - today) / 86400 + 0.5)
  if days == 0 then return 'Today', cfg.accent end
  if days == 1 then return 'Tomorrow', cfg.secondary end
  if days == -1 then return 'Yesterday', cfg.warn end
  local label = MONTHS[m] .. ' ' .. d
  if y ~= now.year then label = label .. " '" .. string.format('%02d', y % 100) end
  return label, days < 0 and cfg.warn or cfg.secondary
end

local function blocked()
  return status == 'setup' or status == 'auth'
end

local function emptyText()
  if status == 'setup' then
    return 'Not connected. See README: Google Tasks.'
  end
  if status == 'auth' then
    return 'Sign-in expired. Run the setup again (README: Google Tasks).'
  end
  if #tasks > 0 then return '' end
  if not shownList then
    if status == 'offline' then return 'Offline' end
    if status == 'error' then return 'Could not load the tasks.' end
    return 'Loading…'
  end
  return 'No open tasks'
end

local function footText()
  if running then return 'Syncing…', cfg.secondary end
  if status == 'offline' then return 'Offline', cfg.warn end
  if status == 'error' then
    local d = detail ~= '' and detail or 'Error'
    if #d > 32 then d = d:sub(1, 30) .. '…' end
    return d, cfg.warn
  end
  if not blocked() and #tasks > rows then return '+' .. (#tasks - rows) .. ' more', cfg.secondary end
  return '', cfg.secondary
end

local function draw()
  local off = blocked()

  set('MeterListName', 'Text', shownList and shownList.title or 'Google Tasks')
  show('MeterPrev', not off and #lists > 1)
  show('MeterNext', not off and #lists > 1)

  for i = 1, MAX_ROWS do
    local t = (not off and i <= rows) and tasks[i] or nil
    local chk, txt, due = 'MeterCheck' .. i, 'MeterTask' .. i, 'MeterDue' .. i
    if t then
      local indent = (t.depth > 0) and cfg.indent or 0
      local label, color = dueLabel(t.due)
      local dueW = (label ~= '') and cfg.dueW or 0
      set(chk, 'X', cfg.pad + indent)
      set(txt, 'X', cfg.pad + indent + cfg.ic + cfg.gap)
      set(txt, 'W', cfg.cardW - 2 * cfg.pad - indent - cfg.ic - cfg.gap - dueW)
      set(txt, 'Text', t.title ~= '' and t.title or '(untitled)')
      set(txt, 'ToolTipText', t.title)
      set(txt, 'FontColor', t.pending and cfg.muted or cfg.primary)
      set(due, 'Text', label)
      set(due, 'FontColor', color)
    end
    show(chk, t ~= nil)
    show(txt, t ~= nil)
    show(due, t ~= nil)
  end

  set('MeterEmpty', 'Text', emptyText())
  local foot, footColor = footText()
  set('MeterStatus', 'Text', foot)
  set('MeterStatus', 'FontColor', footColor)
  show('MeterAdd', not off and shownList ~= nil)

  SKIN:Bang('!UpdateMeterGroup', 'Tasks')
  SKIN:Bang('!Redraw')
end

-- ---- running GTasks.ps1 --------------------------------------

local function command(action, listId, extra)
  local s = 'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'
    .. var('@') .. 'Scripts\\GTasks.ps1" -Action ' .. action .. ' -Slot ' .. slot
  if safeId(listId) then s = s .. ' -ListId ' .. listId end
  return s .. (extra or '')
end

local function start(item)
  running, runSince = item, os.time()
  if item.title then
    -- The script reads (and deletes) this file. Written now, not at
    -- Add() time, so two quick adds do not overwrite each other.
    writeFile(cachePath('new'), item.title)
  end
  set('MeasureRun', 'Parameter', item.cmd)
  SKIN:Bang('!UpdateMeasure', 'MeasureRun')
  SKIN:Bang('!CommandMeasure', 'MeasureRun', 'Run')
end

local function enqueue(item)
  if item.fetch then
    lastFetch = os.time()
    if running and running.fetch then return end
    for _, q in ipairs(queue) do
      if q.fetch then return end
    end
  end
  if running then
    queue[#queue + 1] = item
  else
    start(item)
  end
end

local function fetch()
  enqueue { cmd = command('fetch', picked), fetch = true }
end

-- The list the shown tasks belong to (complete / add go there).
local function shownId()
  return shownList and shownList.id or picked
end

-- ---- Rainmeter entry points ----------------------------------

function Initialize()
  slot = math.floor(tonumber(var('TasksSlot', '1')) or 1)
  rows = math.max(1, math.min(MAX_ROWS, math.floor(num('TasksRows'))))
  refreshEvery = math.max(60, tonumber(var('TasksRefreshSeconds', '300')) or 300)
  cfg.pad    = num('Pad')
  cfg.gap    = num('Gap')
  cfg.ic     = num('Ic')
  cfg.indent = num('TaskIndent')
  cfg.dueW   = num('DueW')
  cfg.cardW  = num('CardW')
  cfg.primary   = var('ColorTextPrimary')
  cfg.secondary = var('ColorTextSecondary')
  cfg.muted     = var('ColorTextMuted')
  cfg.accent    = var('ColorAccent')
  cfg.warn      = var('ColorWarn')

  picked = trim(readFile(cachePath('sel')))
  if not safeId(picked) then picked = '' end
  loadCache()
end

function Update()
  if not started then
    -- Meters exist now (not yet in Initialize).
    started = true
    draw()
    fetch()
    draw()
    return 0
  end
  if running and os.time() - runSince > BUSY_LIMIT then
    -- FinishAction never came (program could not start).
    running = nil
  end
  if not running and os.time() - lastFetch >= refreshEvery then
    fetch()
    draw()
  end
  return 0
end

function OnDone()
  local item = running
  running = nil
  if item and item.doneId then doneIds[item.doneId] = nil end
  if item and item.title then table.remove(addTitles, 1) end
  loadCache()
  if #queue > 0 then start(table.remove(queue, 1)) end
  draw()
end

function Refresh()
  fetch()
  draw()
end

local function pickList(step)
  if #lists < 2 then return end
  local idx = 1
  for i, l in ipairs(lists) do
    if shownList and l.id == shownList.id then idx = i end
  end
  idx = (idx - 1 + step) % #lists + 1
  shownList = lists[idx]
  picked = shownList.id
  writeFile(cachePath('sel'), picked)
  tasks = {}
  status = 'loading'
  fetch()
  draw()
end

function PrevList() pickList(-1) end
function NextList() pickList(1) end

function Complete(row)
  local t = tasks[row]
  if blocked() or not t or t.pending or not safeId(t.id) then return end
  doneIds[t.id] = true
  table.remove(tasks, row)
  enqueue { cmd = command('complete', shownId(), ' -TaskId ' .. t.id), doneId = t.id }
  draw()
end

function Add(title)
  title = trim((title or ''):gsub('[\r\n\t]+', ' '))
  if title == '' or blocked() or not shownList then return end
  addTitles[#addTitles + 1] = title
  table.insert(tasks, 1, { id = '', depth = 0, due = '', title = title, pending = true })
  enqueue { cmd = command('add', shownId()), title = title }
  draw()
end
