-- =============================================================
--  MyWindowWidget - Music helper
--  Times() : "1:24 / 3:51" (or "1:02:03 / 1:30:00" for long
--            tracks), from the WebNowPlaying Position / Duration
--            measures' numeric values (seconds).
-- =============================================================

local msPos, msDur

function Initialize()
  msPos = SKIN:GetMeasure('MeasurePosition')
  msDur = SKIN:GetMeasure('MeasureDuration')
end

function Update()
  return 0
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
  return fmt(msPos:GetValue()) .. ' / ' .. fmt(msDur:GetValue())
end
