-- =============================================================
--  MyWindowWidget - keep an expanded card above the other cards
--  Loaded with dofile(); returns a module table. ASCII only.
--
--  Z.Raise(name)    puts the current skin "Topmost" (!ZPos 1)
--  Z.Restore(name)  puts it back where the user had it
--
--  !ZPos is saved to Rainmeter.ini (AlwaysOnTop, checked
--  2026-11-17), so the user's own setting is kept in
--  @Resources\Cache\<name>.zpos while raised. The file also
--  survives a refresh or crash: Restore() still finds it.
--  A skin that is already Topmost / Stay topmost is left alone.
-- =============================================================

local Z = {}

local function cacheFile(name)
  return SKIN:GetVariable('@') .. 'Cache\\' .. name .. '.zpos'
end

local function readFile(path)
  local f = io.open(path, 'rb')
  if not f then return nil end
  local s = f:read('*a')
  f:close()
  return s
end

-- AlwaysOnTop of the current config in Rainmeter.ini (UTF-16 LE;
-- the section and key are ASCII, so dropping the zero bytes is
-- enough). 0 when not found.
local function currentZPos()
  local s = readFile(SKIN:GetVariable('SETTINGSPATH') .. 'Rainmeter.ini')
  if not s then return 0 end
  s = s:gsub('%z', '')
  local config = SKIN:GetVariable('CURRENTCONFIG'):gsub('%p', '%%%0')
  local section = s:match('%[' .. config .. '%]([^%[]*)')
  local v = section and section:match('[\r\n]AlwaysOnTop=(%-?%d)')
  return tonumber(v) or 0
end

function Z.Raise(name)
  local file = cacheFile(name)
  if not readFile(file) then
    local z = currentZPos()
    if z >= 1 then return end
    local f = io.open(file, 'w')
    if f then
      f:write(tostring(z))
      f:close()
    end
  end
  SKIN:Bang('!ZPos', '1')
end

function Z.Restore(name)
  local file = cacheFile(name)
  local s = readFile(file)
  if not s then return end
  os.remove(file)
  local z = tonumber(s:match('%-?%d')) or 0
  SKIN:Bang('!ZPos', tostring(z))
end

return Z
