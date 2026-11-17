-- =============================================================
--  MyWindowWidget - iCalendar (.ics) parser
--  Loaded by Calendar.lua with dofile(); returns a module table.
--
--  P.parse(text, rangeStart, rangeEnd, cal) -> list of occurrences
--    { t, finish, allDay, summary, location, cal }
--  Times are local epoch seconds (os.time). Only occurrences that
--  overlap [rangeStart, rangeEnd) are returned.
--
--  Supported (RFC 5545 subset):
--   * line unfolding, text unescaping (\, \; \n \\)
--   * VEVENT: SUMMARY, DTSTART, DTEND / DURATION, LOCATION, UID,
--     RRULE, EXDATE, RECURRENCE-ID, STATUS (CANCELLED skipped)
--   * dates: VALUE=DATE (all day), UTC ("...Z"), TZID=... / floating
--   * RRULE: FREQ=DAILY|WEEKLY|MONTHLY|YEARLY, INTERVAL, COUNT,
--     UNTIL, BYDAY (WEEKLY only)
--  Not supported (event shows only its first occurrence):
--   * TODO: BYDAY on MONTHLY/YEARLY ("2nd Tuesday"), BYMONTHDAY,
--     BYMONTH, BYSETPOS, RDATE.
--   * TODO(verify): TZID other than the local zone (LocalTZID) or
--     UTC is treated as local wall time. Fine when every event is
--     in Asia/Seoul; events created in another zone will be off.
--     (VTIMEZONE blocks are not evaluated.)
-- =============================================================

local P = {}

local DAY = 86400
local MAX_STEPS = 5000

-- Seconds to add to "UTC fields read as local time" to get the
-- true epoch (KST: +32400). No DST in Asia/Seoul; elsewhere this
-- uses the offset in effect now. TODO(verify) for DST zones.
local now = os.time()
P.utcOffset = now - os.time(os.date('!*t', now))

P.localTZID = 'Asia/Seoul'

local UTC_TZIDS = { ['UTC'] = true, ['ETC/UTC'] = true, ['GMT'] = true, ['Z'] = true }

-- ---- helpers -------------------------------------------------

local function unescape(s)
  return (s:gsub('\\(.)', function(c)
    if c == 'n' or c == 'N' then return ' ' end
    return c
  end))
end

local function unfold(text)
  text = text:gsub('\r\n', '\n'):gsub('\r', '\n')
  return (text:gsub('\n[ \t]', ''))
end

-- "NAME;P1=a;P2=\"b:c\":VALUE" -> name, params, value
local function parseLine(line)
  local inQuote = false
  for pos = 1, #line do
    local c = line:sub(pos, pos)
    if c == '"' then
      inQuote = not inQuote
    elseif c == ':' and not inQuote then
      local head, value = line:sub(1, pos - 1), line:sub(pos + 1)
      local name, rest = head:match('^([^;]+)(.*)$')
      local params = {}
      for k, v in rest:gmatch(';([^=;]+)=([^;]*)') do
        params[k:upper()] = (v:gsub('^"(.*)"$', '%1'))
      end
      return (name or ''):upper(), params, value
    end
  end
  return nil
end

local function isoWeekday(t)
  local w = os.date('*t', t).wday -- 1 = Sunday
  return (w + 5) % 7 + 1          -- 1 = Monday .. 7 = Sunday
end

-- Calendar arithmetic that keeps the wall-clock time.
local function addDays(t, n)
  local d = os.date('*t', t)
  d.day = d.day + n
  d.isdst = nil
  return os.time(d)
end

local function addMonths(t, n)
  local d = os.date('*t', t)
  local want = d.day
  d.month = d.month + n
  d.isdst = nil
  local r = os.time(d)
  -- Skip months without that day (e.g. the 31st), per RFC 5545.
  if os.date('*t', r).day ~= want then return nil end
  return r
end

-- Returns { t = epoch, allDay = bool } or nil.
local function parseDT(value, params)
  local y, m, d = value:match('^(%d%d%d%d)(%d%d)(%d%d)')
  if not y then return nil end
  y, m, d = tonumber(y), tonumber(m), tonumber(d)
  local H, M, S, z = value:match('T(%d%d)(%d%d)(%d%d)(Z?)')
  if (params and params.VALUE == 'DATE') or not H then
    return { t = os.time{ year = y, month = m, day = d, hour = 0 }, allDay = true }
  end
  local t = os.time{ year = y, month = m, day = d,
                     hour = tonumber(H), min = tonumber(M), sec = tonumber(S) }
  local tzid = params and params.TZID and params.TZID:upper()
  if z == 'Z' or (tzid and UTC_TZIDS[tzid]) then
    t = t + P.utcOffset
  end
  return { t = t, allDay = false }
end

-- "P1DT2H30M", "PT45M", "P1W" -> seconds
local function parseDuration(v)
  local sign = v:sub(1, 1) == '-' and -1 or 1
  local total = 0
  local w = v:match('(%d+)W'); if w then total = total + tonumber(w) * 7 * DAY end
  local d = v:match('(%d+)D'); if d then total = total + tonumber(d) * DAY end
  local time = v:match('T(.*)$') or ''
  local h = time:match('(%d+)H'); if h then total = total + tonumber(h) * 3600 end
  local mi = time:match('(%d+)M'); if mi then total = total + tonumber(mi) * 60 end
  local s = time:match('(%d+)S'); if s then total = total + tonumber(s) end
  return sign * total
end

local DAYS = { MO = 1, TU = 2, WE = 3, TH = 4, FR = 5, SA = 6, SU = 7 }

local function parseRRule(v)
  local r = {}
  for k, val in v:gmatch('([^=;]+)=([^;]*)') do r[k:upper()] = val end
  local rule = {
    freq = (r.FREQ or ''):upper(),
    interval = math.max(1, tonumber(r.INTERVAL or '1') or 1),
    count = tonumber(r.COUNT or ''),
    supported = true,
  }
  if r.UNTIL then
    local u = parseDT(r.UNTIL, {})
    if u then rule['until'] = u.allDay and (u.t + DAY - 1) or u.t end
  end
  if r.BYDAY then
    if rule.freq == 'WEEKLY' then
      rule.byday = {}
      for code in r.BYDAY:gmatch('[^,]+') do
        local wd = DAYS[code:upper():match('(%a%a)$') or '']
        if wd then rule.byday[#rule.byday + 1] = wd end
      end
      table.sort(rule.byday)
    else
      rule.supported = false
    end
  end
  if r.BYMONTHDAY or r.BYMONTH or r.BYSETPOS or r.BYYEARDAY or r.BYWEEKNO then
    rule.supported = false
  end
  if rule.freq ~= 'DAILY' and rule.freq ~= 'WEEKLY' and rule.freq ~= 'MONTHLY'
     and rule.freq ~= 'YEARLY' then
    rule.supported = false
  end
  return rule
end

-- ---- recurrence expansion ----------------------------------

-- Candidates of period k (ascending), or {} when out of range.
local function periodCandidates(ev, rule, k)
  local s = ev.start.t
  local f, n = rule.freq, rule.interval
  if f == 'DAILY' then
    return { addDays(s, k * n) }
  elseif f == 'WEEKLY' then
    if rule.byday and #rule.byday > 0 then
      local base = addDays(s, -(isoWeekday(s) - 1) + 7 * k * n)
      local out = {}
      for _, wd in ipairs(rule.byday) do
        local t = addDays(base, wd - 1)
        if t >= s then out[#out + 1] = t end
      end
      return out
    end
    return { addDays(s, 7 * k * n) }
  elseif f == 'MONTHLY' then
    return { addMonths(s, k * n) }
  elseif f == 'YEARLY' then
    return { addMonths(s, 12 * k * n) }
  end
  return {}
end

-- First period index worth looking at (only safe without COUNT).
local function firstPeriod(ev, rule, rangeStart, dur)
  if rule.count then return 0 end
  local gap = rangeStart - dur - ev.start.t
  if gap <= 0 then return 0 end
  local f, n = rule.freq, rule.interval
  local k
  if f == 'DAILY' then
    k = math.floor(gap / (DAY * n))
  elseif f == 'WEEKLY' then
    k = math.floor(gap / (7 * DAY * n))
  elseif f == 'MONTHLY' then
    k = math.floor(gap / (31 * DAY * n))
  elseif f == 'YEARLY' then
    k = math.floor(gap / (366 * DAY * n))
  else
    k = 0
  end
  return math.max(0, k - 1)
end

local function eventDuration(ev)
  if ev.finish then return math.max(0, ev.finish.t - ev.start.t) end
  if ev.duration then return math.max(0, ev.duration) end
  return ev.start.allDay and DAY or 0
end

local function expand(ev, rangeStart, rangeEnd, overridden, out, cal)
  local dur = eventDuration(ev)
  local function emit(t)
    if ev.exdates[t] then return end
    if overridden[(ev.uid or '') .. '|' .. t] then return end
    if t < rangeEnd and t + math.max(dur, 1) > rangeStart then
      out[#out + 1] = { t = t, finish = t + dur, allDay = ev.start.allDay,
                        summary = ev.summary or '(No title)',
                        location = ev.location or '', cal = cal }
    end
  end

  local rule = ev.rrule
  if not rule or not rule.supported then
    emit(ev.start.t)
    return
  end

  local count, untilT = rule.count, rule['until']
  local n = 0
  local k = firstPeriod(ev, rule, rangeStart, dur)
  for _ = 1, MAX_STEPS do
    local cands = periodCandidates(ev, rule, k)
    for _, t in ipairs(cands) do
      if t then
        if untilT and t > untilT then return end
        if t >= rangeEnd then return end
        n = n + 1
        if count and n > count then return end
        emit(t)
      end
    end
    k = k + 1
  end
end

-- ---- public ----------------------------------------------------

function P.parse(text, rangeStart, rangeEnd, cal)
  text = unfold(text or '')
  local masters, overrides = {}, {}
  local cur, skip = nil, 0

  for line in text:gmatch('[^\n]+') do
    if line == 'BEGIN:VEVENT' then
      cur, skip = { exdates = {} }, 0
    elseif cur then
      if line == 'END:VEVENT' and skip == 0 then
        if cur.start and cur.status ~= 'CANCELLED' or cur.recurId then
          if cur.recurId then
            overrides[#overrides + 1] = cur
          else
            masters[#masters + 1] = cur
          end
        end
        cur = nil
      elseif line:match('^BEGIN:') then
        skip = skip + 1          -- nested VALARM etc.
      elseif line:match('^END:') then
        skip = math.max(0, skip - 1)
      elseif skip == 0 then
        local name, params, value = parseLine(line)
        if name == 'SUMMARY' then
          cur.summary = unescape(value)
        elseif name == 'LOCATION' then
          cur.location = unescape(value)
        elseif name == 'UID' then
          cur.uid = value
        elseif name == 'DTSTART' then
          cur.start = parseDT(value, params)
        elseif name == 'DTEND' then
          cur.finish = parseDT(value, params)
        elseif name == 'DURATION' then
          cur.duration = parseDuration(value)
        elseif name == 'RRULE' then
          cur.rrule = parseRRule(value)
        elseif name == 'EXDATE' then
          for v in value:gmatch('[^,]+') do
            local dt = parseDT(v, params)
            if dt then cur.exdates[dt.t] = true end
          end
        elseif name == 'RECURRENCE-ID' then
          cur.recurId = parseDT(value, params)
        elseif name == 'STATUS' then
          cur.status = value:upper()
        end
      end
    end
  end

  -- Occurrences replaced (or cancelled) by a RECURRENCE-ID event.
  local overridden = {}
  for _, o in ipairs(overrides) do
    if o.recurId then
      overridden[(o.uid or '') .. '|' .. o.recurId.t] = true
    end
  end

  local out = {}
  for _, ev in ipairs(masters) do
    if ev.start and ev.status ~= 'CANCELLED' then
      expand(ev, rangeStart, rangeEnd, overridden, out, cal)
    end
  end
  for _, o in ipairs(overrides) do
    if o.start and o.status ~= 'CANCELLED' then
      o.rrule = nil
      expand(o, rangeStart, rangeEnd, {}, out, cal)
    end
  end
  return out
end

return P
