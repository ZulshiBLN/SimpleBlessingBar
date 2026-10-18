-- Minimal WoW API mock: what the addon calls while it loads and at login,
-- nothing more. STATE is what a spec sets before loading; CHAT collects print.
local noop = function() end
local eventFrames = {}
STATE = { class = "PALADIN", locale = "deDE", errors = {} }
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
UnitClass = function() return "Class", STATE.class end
C_AddOns = { GetAddOnMetadata = TocField }
SlashCmdList = {}
