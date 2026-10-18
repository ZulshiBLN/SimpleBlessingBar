-- Minimal WoW API mock: what the addon calls, nothing more. STATE is the
-- world a spec builds; CHAT collects print.
--
-- STATE.units maps a unit token to a record. Two tokens for the same
-- player share one record, so UnitIsUnit compares records:
--   { class = "MAGE", connected = true, dead = false, visible = true,
--     range = true, subgroup = 1,
--     auras = { { spellId = 19740, expirationTime = 100, mine = true } } }
-- connected, visible and range default to true, dead to false.
local noop = function() end
local eventFrames = {}
STATE = {
  class = "PALADIN", locale = "deDE", errors = {},
  units = {},       -- unit token -> record; "player" is added by the loader
  group = nil,      -- nil, "party" or "raid"
  known = {},       -- spell ID -> true for IsPlayerSpell
  bags = {},        -- item ID -> count
  combat = false,
}
CHAT = {}

local Methods = {}
function Methods:RegisterEvent(e) self.events[e] = true; eventFrames[self] = true end
function Methods:UnregisterEvent(e) self.events[e] = nil end
function Methods:SetScript(s, f) self.scripts[s] = f end

function CreateFrame(kind, name)
  local o = { kind = kind, name = name, scripts = {}, events = {} }
  setmetatable(o, { __index = function(_, k) return Methods[k] or noop end })
  if name then _G[name] = o end
  return o
end

-- Runs every OnEvent script registered for the event; an error is recorded
-- in STATE.errors, as BugGrabber would, instead of stopping the spec.
function FIRE(event, ...)
  for f in pairs(eventFrames) do
    if f.events[event] and f.scripts.OnEvent then
      local ok, err = pcall(f.scripts.OnEvent, f, event, ...)
      if not ok then table.insert(STATE.errors, event .. ": " .. tostring(err)) end
    end
  end
end

-- The field read from the TOC on disk, as the client reads it.
local function TocField(addon, field)
  local f = assert(io.open(addon .. "/" .. addon .. ".toc", "rb"))
  local text = f:read("*a")
  f:close()
  return text:match("\n## " .. field .. ":%s*([^\r\n]-)%s*[\r\n]")
end

print = function(...)
  local t = {}
  for i = 1, select("#", ...) do t[#t + 1] = tostring((select(i, ...))) end
  CHAT[#CHAT + 1] = table.concat(t, " ")
end
GetLocale = function() return STATE.locale end
C_AddOns = { GetAddOnMetadata = TocField }
SlashCmdList = {}
InCombatLockdown = function() return STATE.combat end

local function U(unit) return unit and STATE.units[unit] end
UnitExists = function(u) return U(u) ~= nil end
UnitClass = function(u) local r = U(u) if r then return "Class", r.class end end
UnitIsConnected = function(u) local r = U(u) return r ~= nil and r.connected ~= false end
UnitIsDeadOrGhost = function(u) local r = U(u) return r ~= nil and r.dead == true end
UnitIsVisible = function(u) local r = U(u) return r ~= nil and r.visible ~= false end
UnitIsUnit = function(a, b) return U(a) ~= nil and U(a) == U(b) end

local function countUnits(prefix)
  local n = 0
  for unit in pairs(STATE.units) do
    if unit:match("^" .. prefix .. "%d+$") then n = n + 1 end
  end
  return n
end
IsInRaid = function() return STATE.group == "raid" end
IsInGroup = function() return STATE.group ~= nil end
GetNumGroupMembers = function()
  if STATE.group == "raid" then return countUnits("raid") end
  if STATE.group == "party" then return countUnits("party") + 1 end
  return 0
end
GetNumSubgroupMembers = function() return countUnits("party") end
GetRaidRosterInfo = function(i)
  local r = U("raid" .. i)
  if r then return "Raider" .. i, 0, r.subgroup end
end

-- "HELPFUL|PLAYER" returns only the auras the player cast (mine = true).
C_UnitAuras = {
  GetAuraDataByIndex = function(u, i, filter)
    local r = U(u)
    if not r then return end
    local n = 0
    for _, a in ipairs(r.auras or {}) do
      if a.mine or not (filter or ""):find("PLAYER") then
        n = n + 1
        if n == i then return { spellId = a.spellId, expirationTime = a.expirationTime } end
      end
    end
  end,
}
C_Spell = {
  IsSpellInRange = function(_, u) local r = U(u) return r ~= nil and r.range ~= false end,
}
C_Item = { GetItemCount = function(id) return STATE.bags[id] or 0 end }
IsPlayerSpell = function(id) return STATE.known[id] == true end
