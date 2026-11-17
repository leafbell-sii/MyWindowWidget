-- =============================================================
--  MyWindowWidget - Google Tasks controller (Tasks\Tasks.ini)
--  ENCODING: this file is saved as UTF-16 LE (with BOM) on purpose,
--  like Calendar.lua. Rainmeter then runs it in Unicode mode, so
--  task titles are UTF-8 inside Lua (Korean, emoji, ...).
--
--  Google is reached by @Resources\Scripts\GTasks.ps1, started in a
--  hidden window by the RunCommand measure MeasureRun. The script
--  writes @Resources\Cache\tasks.txt with every list and its open
--  tasks (already sorted by due date); OnDone() reads it. One
--  command runs at a time; the others wait in a queue.
--
--  Layout: the card is split into equal sections, one per list:
--  1, 2 or 3 lists are all shown at once. With 4 or more, three
--  sections are shown and < > in the header pages through them
--  (the last page shows the last three lists).
--
--  Files in @Resources\Cache:
--    tasks.txt   result of the last run (format: GTasks.ps1 header)
--    tasks.page  page shown by < >
--    tasks.new   title of the task being added (UTF-8), written
--                right before the add command starts
--
--  Completing and adding show up at once (optimistic); the run that
--  follows replaces them with what Google returns.
--
--  Bangs (from the skin): Refresh(), PrevPage(), NextPage(),
--  OpenAdd(section), Add(title), Complete(row), OnDone()
-- =============================================================

local MAX_ROWS = 22         -- MeterCheck/Task/DueN in Tasks.ini
local MAX_SECTIONS = 3      -- MeterSecName/More/AddN in Tasks.ini
local BUSY_LIMIT = 90       -- seconds; RunCommand Timeout is 60
local MONTHS = { 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' }

local cfg = {}
local refreshEvery
local lists = {}            -- { id, title, tasks = { {id, depth, due, title, pending} } }
local status, detail = 'loading', ''
local page = 1
local shown = {}            -- lists in the visible sections
local secTop = {}           -- y of each visible section
local rowMap = {}           -- row meter -> { list, index }
local addList               -- id of the list the input box adds to
local queue = {}
local running               -- queue item being run, nil = idle
local runSince = 0
local lastFetch = 0
local syncedAt              -- os.time() of the last successful fetch
local statusShown           -- header status text now on screen
local started = false
local doneIds = {}          -- completed here, not yet confirmed
local adds = {}             -- { listId, title } added here, not yet confirmed

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
  return var('@') .. 'Cache\\tasks.' .. ext
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

local function findList(id)
  for _, l in ipairs(lists) do
    if l.id == id then return l end
  end
  return nil
end

-- Where Google puts a new task once the list is sorted by due date:
-- first among the top-level tasks without a due date.
local function insertPending(l, title)
  local at = #l.tasks + 1
  for i, t in ipairs(l.tasks) do
    if t.depth == 0 and t.due == '' then at = i; break end
  end
  table.insert(l.tasks, at, { id = '', depth = 0, due = '', title = title, pending = true })
end

-- ---- cache --------------------------------------------------

local function loadCache()
  lists = {}
  local s = readFile(cachePath('txt'))
  if not s then
    status, detail = 'loading', ''
    return
  end
  for line in s:gmatch('[^\n]+') do
    local f = split((line:gsub('\r$', '')))
    if f[1] == 'status' then
      status, detail = f[2] or 'error', f[3] or ''
    elseif f[1] == 'updated' then
      -- Local time; older caches have no seconds.
      local y, mo, d, h, mi, sec = (f[2] or ''):match('^(%d+)-(%d+)-(%d+) (%d+):(%d+):?(%d*)$')
      if y then
        syncedAt = os.time { year = tonumber(y), month = tonumber(mo), day = tonumber(d),
          hour = tonumber(h), min = tonumber(mi), sec = tonumber(sec) or 0 }
      end
    elseif f[1] == 'list' then
      lists[#lists + 1] = { id = f[2], title = f[3] or '', tasks = {} }
    elseif f[1] == 'task' and not doneIds[f[3]] then
      local l = findList(f[2])
      if l then
        l.tasks[#l.tasks + 1] = { id = f[3], depth = tonumber(f[4]) or 0, due = f[5] or '', title = f[6] or '' }
      end
    end
  end
  -- Added here but not on Google yet.
  for _, a in ipairs(adds) do
    local l = findList(a.listId)
    if l then insertPending(l, a.title) end
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

local function pageCount()
  if #lists <= MAX_SECTIONS then return 1 end
  return math.ceil(#lists / MAX_SECTIONS)
end

-- Text in the middle of the card when no list can be shown.
local function emptyText()
  if status == 'setup' then
    return 'Not connected. See README: Google Tasks.'
  end
  if status == 'auth' then
    return 'Sign-in expired. Run the setup again (README: Google Tasks).'
  end
  if #lists > 0 then return '' end
  if status == 'offline' then return 'Offline' end
  if status == 'error' then return 'Could not load the tasks.' end
  return 'Loading…'
end

-- "just now", "5m ago", "3h ago", "2d ago".
local function ago(t)
  local s = math.max(0, os.time() - t)
  if s < 60 then return 'just now' end
  if s < 3600 then return math.floor(s / 60) .. 'm ago' end
  if s < 86400 then return math.floor(s / 3600) .. 'h ago' end
  return math.floor(s / 86400) .. 'd ago'
end

local function statusText()
  if running then return 'Syncing…', cfg.secondary end
  if status == 'offline' then return 'Offline', cfg.warn end
  if status == 'error' then
    local d = detail ~= '' and detail or 'Error'
    if #d > 24 then d = d:sub(1, 22) .. '…' end
    return d, cfg.warn
  end
  if blocked() or not syncedAt then return '', cfg.secondary end
  return 'Updated ' .. ago(syncedAt), cfg.secondary
end

-- Header status (left of the sync button). Also called every
-- second from Update(); redraws only when the text changes.
local function drawStatus()
  local st, color = statusText()
  if st == statusShown then return false end
  statusShown = st
  set('MeterStatus', 'Text', st)
  set('MeterStatus', 'FontColor', color)
  set('MeterStatus', 'ToolTipText', syncedAt and ('Last synced ' .. os.date('%b %d %H:%M', syncedAt)) or '')
  set('MeterSync', 'IconColor', 'Stroke Color ' .. (running and cfg.muted or cfg.secondary))
  return true
end

local function hideRow(i)
  show('MeterCheck' .. i, false)
  show('MeterTask' .. i, false)
  show('MeterDue' .. i, false)
end

-- One task (or the "No open tasks" line when t is nil) in row
-- meter i, centred on y.
local function drawRow(i, t, y)
  local chk, txt, due = 'MeterCheck' .. i, 'MeterTask' .. i, 'MeterDue' .. i
  if not t then
    set(txt, 'X', cfg.pad)
    set(txt, 'Y', y)
    set(txt, 'W', cfg.cardW - 2 * cfg.pad)
    set(txt, 'Text', 'No open tasks')
    set(txt, 'ToolTipText', '')
    set(txt, 'FontColor', cfg.muted)
    show(chk, false)
    show(txt, true)
    show(due, false)
    return
  end
  local indent = (t.depth > 0) and cfg.indent or 0
  local label, color = dueLabel(t.due)
  local dueW = (label ~= '') and cfg.dueW or 0
  set(chk, 'X', cfg.pad + indent)
  set(chk, 'Y', y - cfg.ic / 2)
  set(txt, 'X', cfg.pad + indent + cfg.ic + cfg.gap)
  set(txt, 'Y', y)
  set(txt, 'W', cfg.cardW - 2 * cfg.pad - indent - cfg.ic - cfg.gap - dueW)
  set(txt, 'Text', t.title ~= '' and t.title or '(untitled)')
  set(txt, 'ToolTipText', t.title)
  set(txt, 'FontColor', t.pending and cfg.muted or cfg.primary)
  set(due, 'Y', y)
  set(due, 'Text', label)
  set(due, 'FontColor', color)
  show(chk, not t.pending)
  show(txt, true)
  show(due, label ~= '')
end

local function draw()
  local off = blocked()
  local pages = pageCount()
  page = math.max(1, math.min(page, pages))

  -- Header, right to left: paging, sync button, status.
  local paging = not off and pages > 1
  show('MeterPrev', paging)
  show('MeterNext', paging)
  show('MeterPage', paging)
  set('MeterPage', 'Text', page .. '/' .. pages)
  local syncX = cfg.cardW - cfg.pad - cfg.ic
  if paging then syncX = syncX - 2 * cfg.ic - cfg.pageW - cfg.gap end
  set('MeterSync', 'X', syncX)
  show('MeterSync', not off)
  set('MeterStatus', 'X', syncX - cfg.gap / 2)
  statusShown = nil
  drawStatus()

  -- Which lists are visible.
  shown = {}
  if not off then
    local k = math.min(#lists, MAX_SECTIONS)
    local first = math.max(1, math.min((page - 1) * MAX_SECTIONS + 1, #lists - k + 1))
    for s = 1, k do shown[s] = lists[first + s - 1] end
  end

  -- Equal sections over the body.
  local k = #shown
  local secH = k > 0 and (cfg.bodyH - (k - 1) * cfg.gap) / k or 0
  local row = 0
  rowMap = {}
  for s = 1, MAX_SECTIONS do
    local l = shown[s]
    local name, more, add, sep = 'MeterSecName' .. s, 'MeterSecMore' .. s, 'MeterSecAdd' .. s, 'MeterSecSep' .. s
    if l then
      local top = math.floor(cfg.bodyY + (s - 1) * (secH + cfg.gap) + 0.5)
      secTop[s] = top
      local headMid = top + cfg.secHeadH / 2
      set(name, 'Y', headMid)
      set(name, 'Text', l.title ~= '' and l.title or '(untitled list)')
      set(add, 'Y', headMid - cfg.ic / 2)
      set(more, 'Y', headMid)
      if s > 1 then set(sep, 'Y', math.floor(top - cfg.gap / 2)) end

      local fit = math.max(1, math.floor((secH - cfg.secHeadH) / cfg.rowH))
      local n = #l.tasks
      if n == 0 then
        if row < MAX_ROWS then
          row = row + 1
          drawRow(row, nil, top + cfg.secHeadH + cfg.rowH / 2)
        end
      else
        for i = 1, math.min(n, fit) do
          if row >= MAX_ROWS then break end
          row = row + 1
          rowMap[row] = { list = l, index = i }
          drawRow(row, l.tasks[i], top + cfg.secHeadH + (i - 0.5) * cfg.rowH)
        end
      end
      set(more, 'Text', n > fit and ('+' .. (n - fit) .. ' more') or '')
    end
    show(name, l ~= nil)
    show(more, l ~= nil)
    show(add, l ~= nil)
    if s > 1 then show(sep, l ~= nil) end
  end
  for i = row + 1, MAX_ROWS do hideRow(i) end

  set('MeterEmpty', 'Text', k == 0 and emptyText() or '')

  SKIN:Bang('!UpdateMeterGroup', 'Tasks')
  SKIN:Bang('!Redraw')
end

-- ---- running GTasks.ps1 --------------------------------------

local function command(action, listId, extra)
  local s = 'powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'
    .. var('@') .. 'Scripts\\GTasks.ps1" -Action ' .. action
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
  enqueue { cmd = command('fetch'), fetch = true }
end

-- ---- Rainmeter entry points ----------------------------------

function Initialize()
  refreshEvery = math.max(60, tonumber(var('TasksRefreshSeconds', '300')) or 300)
  cfg.scale    = num('Scale')
  cfg.pad      = num('Pad')
  cfg.gap      = num('Gap')
  cfg.ic       = num('Ic')
  cfg.indent   = num('TaskIndent')
  cfg.dueW     = num('DueW')
  cfg.pageW    = num('PageW')
  cfg.rowH     = num('RowH')
  cfg.secHeadH = num('SecHeadH')
  cfg.cardW    = num('CardW')
  cfg.bodyY    = num('BodyY')
  cfg.bodyH    = num('CardH') - cfg.pad - cfg.bodyY
  cfg.primary   = var('ColorTextPrimary')
  cfg.secondary = var('ColorTextSecondary')
  cfg.muted     = var('ColorTextMuted')
  cfg.accent    = var('ColorAccent')
  cfg.warn      = var('ColorWarn')

  page = math.floor(tonumber(trim(readFile(cachePath('page')))) or 1)
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
  elseif drawStatus() then
    SKIN:Bang('!UpdateMeter', 'MeterStatus')
    SKIN:Bang('!UpdateMeter', 'MeterSync')
    SKIN:Bang('!Redraw')
  end
  return 0
end

function OnDone()
  local item = running
  running = nil
  if item and item.doneId then doneIds[item.doneId] = nil end
  if item and item.title then table.remove(adds, 1) end
  loadCache()
  if #queue > 0 then start(table.remove(queue, 1)) end
  draw()
end

function Refresh()
  fetch()
  draw()
end

local function turnPage(step)
  local pages = pageCount()
  if pages < 2 then return end
  page = (page - 1 + step) % pages + 1
  writeFile(cachePath('page'), tostring(page))
  draw()
end

function PrevPage() turnPage(-1) end
function NextPage() turnPage(1) end

-- "+" in a section header: the input box covers that header row.
function OpenAdd(s)
  local l = shown[s]
  if blocked() or not l then return end
  addList = l.id
  set('MeasureTaskInput', 'Y', secTop[s] + 2 * cfg.scale)
  SKIN:Bang('!UpdateMeasure', 'MeasureTaskInput')
  SKIN:Bang('!CommandMeasure', 'MeasureTaskInput', 'ExecuteBatch 1')
end

function Add(title)
  title = trim((title or ''):gsub('[\r\n\t]+', ' '))
  local l = addList and findList(addList)
  if title == '' or blocked() or not l then return end
  adds[#adds + 1] = { listId = l.id, title = title }
  insertPending(l, title)
  enqueue { cmd = command('add', l.id), title = title }
  draw()
end

function Complete(row)
  local m = rowMap[row]
  local t = m and m.list.tasks[m.index]
  if blocked() or not t or t.pending or not safeId(t.id) then return end
  doneIds[t.id] = true
  table.remove(m.list.tasks, m.index)
  enqueue { cmd = command('complete', m.list.id, ' -TaskId ' .. t.id), doneId = t.id }
  draw()
end
