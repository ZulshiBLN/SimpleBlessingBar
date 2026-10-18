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
  keyDown = true,   -- ActionButtonUseKeyDown: secure buttons act on key down
  casts = {},       -- spells cast by secure clicks (RUNCLICK)
}
CHAT = {}

-- Frames. A frame made from a Secure template is protected, and so is every
-- frame above it, as in the client. In combat a protected frame refuses
-- attribute, position and visibility changes with an error, as the client
-- does - so a spec sees a write the addon must not make.
local Methods = {}
local function Guard(self, what)
  if STATE.combat and self.protected then error("protected " .. what .. " in combat", 3) end
end
function Methods:RegisterEvent(e) self.events[e] = true; eventFrames[self] = true end
function Methods:UnregisterEvent(e) self.events[e] = nil end
function Methods:SetScript(s, f) self.scripts[s] = f end
function Methods:GetScript(s) return self.scripts[s] end
function Methods:HookScript(s, f) self.hooks[s] = self.hooks[s] or {}; table.insert(self.hooks[s], f) end
function Methods:SetAttribute(k, v) Guard(self, "SetAttribute"); self.attrs[k] = v end
function Methods:GetAttribute(k) return self.attrs[k] end
function Methods:Show() Guard(self, "Show"); self.shown = true end
function Methods:Hide() Guard(self, "Hide"); self.shown = false end
function Methods:IsShown() return self.shown end
function Methods:SetPoint(...) Guard(self, "SetPoint"); self.points[#self.points + 1] = { ... } end
function Methods:ClearAllPoints() Guard(self, "ClearAllPoints"); self.points = {} end
function Methods:GetPoint(i) local p = self.points[i or 1]; if p then return unpack(p) end end
function Methods:SetSize(w, h) self.w, self.h = w, h end
function Methods:SetWidth(w) self.w = w end
function Methods:GetWidth() return self.w end
function Methods:GetRect() return 100, 200, self.w or 0, self.h or 0 end
function Methods:StartMoving() Guard(self, "StartMoving"); self.moving = true end
function Methods:StopMovingOrSizing() Guard(self, "StopMovingOrSizing"); self.moving = false end
function Methods:RegisterForClicks(...) self.clicks = { ... } end
function Methods:CreateTexture() return NEWOBJ("Texture") end
function Methods:CreateFontString() return NEWOBJ("FontString") end
function Methods:SetTexture(t) self.texture = t end
function Methods:GetTexture() return self.texture end
function Methods:SetDesaturated(v) self.desaturated = v end
function Methods:IsDesaturated() return self.desaturated == true end
function Methods:SetText(t) self.text = t end
function Methods:GetText() return self.text end
function Methods:IsMouseOver() return false end
function Methods:GetName() return rawget(self, "name") end
function Methods:GetParent() return rawget(self, "parent") end

function NEWOBJ(kind, name, parent)
  local o = { kind = kind, name = name, parent = parent, scripts = {}, hooks = {}, events = {},
              attrs = {}, points = {}, shown = true }
  setmetatable(o, { __index = function(_, k) return Methods[k] or noop end })
  return o
end

function CreateFrame(kind, name, parent, template)
  local o = NEWOBJ(kind, name, parent)
  o.template = template
  if template and template:find("Secure") then
    local f = o
    -- rawget: a missing field reads as a method stub through the metatable
    while f do f.protected = true; f = rawget(f, "parent") end
  end
  if name then _G[name] = o end
  return o
end

-- Runs a frame's script and its hooks, recording errors like FIRE does.
function RUNSCRIPT(frame, script, ...)
  local fns = { frame.scripts[script] }
  for _, h in ipairs(frame.hooks[script] or {}) do fns[#fns + 1] = h end
  for _, fn in ipairs(fns) do
    local ok, err = pcall(fn, frame, ...)
    if not ok then table.insert(STATE.errors, script .. ": " .. tostring(err)) end
  end
end

---------------------------------------------------------------------------
-- Secure snippets. A SecureHandler header wraps a frame's OnClick with a pre
-- and a post body, as WrapScript does. The bodies run in an emulated
-- restricted environment and see frames only through handles, which may
-- change protected frames in combat - the one thing addon code may not.
-- Bodies are compiled with their arguments as locals, like the client's.
---------------------------------------------------------------------------
local handles = setmetatable({}, { __mode = "k" })
local function Handle(frame)
  if not frame then return nil end
  if handles[frame] then return handles[frame] end
  local h = {}
  function h:GetAttribute(k) return frame.attrs[k] end
  function h:SetAttribute(k, v) frame.attrs[k] = v end
  function h:Show() frame.shown = true end
  function h:Hide() frame.shown = false end
  function h:IsShown() return frame.shown end
  function h:GetParent() return Handle(rawget(frame, "parent")) end
  function h:GetName() return frame.name end
  function h:GetFrameRef(name)
    local refs = rawget(frame, "refs")
    return Handle(refs and refs[name])
  end
  handles[frame] = h
  return h
end

local restricted = {
  PlayerInCombat = function() return STATE.combat end,
  newtable = function(...) return { ... } end,
  pairs = pairs, ipairs = ipairs, tostring = tostring, type = type,
}
local function Compile(body, args)
  local chunk = assert(loadstring("local " .. args .. " = ...\n" .. body))
  setfenv(chunk, setmetatable({}, { __index = restricted }))
  return chunk
end

-- rawget throughout: a missing field reads as a method stub through the metatable
local function Wraps(frame, script)
  local wraps = rawget(frame, "wraps")
  return wraps and wraps[script] or {}
end
function Methods:SetFrameRef(name, frame)
  self.refs = rawget(self, "refs") or {}
  self.refs[name] = frame
end
function Methods:WrapScript(frame, script, pre, post)
  frame.wraps = rawget(frame, "wraps") or {}
  frame.wraps[script] = frame.wraps[script] or {}
  table.insert(frame.wraps[script], {
    owner = self,
    pre = pre and Compile(pre, "self, button, down, owner"),
    post = post and Compile(post, "self, message, button, down, owner"),
  })
end

-- A click as the client delivers it to a secure button: the wrappers' pre
-- bodies (false cancels the action and every post body), the secure action
-- (on key down while STATE.keyDown, else on key up), the post bodies of the
-- wrappers that returned a message, then the insecure hooks. A spell cast
-- is appended to STATE.casts as { spell = id, unit = token }.
local function Attr(frame, name, button)
  local suffix = button == "LeftButton" and "1" or button == "RightButton" and "2" or ""
  local v = frame.attrs[name .. suffix]
  if v == nil then v = frame.attrs[name] end
  return v
end
function RUNCLICK(frame, button, down)
  local cancelled, messages = false, {}
  for i, w in ipairs(Wraps(frame, "OnClick")) do
    if w.pre then
      local ok, result, message = pcall(w.pre, Handle(frame), button, down, Handle(w.owner))
      if not ok then table.insert(STATE.errors, "snippet: " .. tostring(result)) end
      if result == false then cancelled = true break end
      messages[i] = message
    end
  end
  if not cancelled then
    local template = rawget(frame, "template")
    if template and template:find("SecureActionButtonTemplate")
       and (down == true) == (STATE.keyDown == true) and Attr(frame, "type", button) == "spell" then
      STATE.casts[#STATE.casts + 1] = { spell = Attr(frame, "spell", button), unit = Attr(frame, "unit", button) }
    end
    for i, w in ipairs(Wraps(frame, "OnClick")) do
      if w.post and messages[i] ~= nil then
        local ok, err = pcall(w.post, Handle(frame), messages[i], button, down, Handle(w.owner))
        if not ok then table.insert(STATE.errors, "snippet: " .. tostring(err)) end
      end
    end
  end
  RUNSCRIPT(frame, "OnClick", button, down)
end

GetCVarBool = function(name)
  if name == "ActionButtonUseKeyDown" then return STATE.keyDown == true end
end

GameTooltip = NEWOBJ("GameTooltip")
function GameTooltip:SetOwner(owner) self.owner = owner end
function GameTooltip:SetSpellByID(id) self.spell = id; self.shown = true end

-- Timers: C_Timer.After queues until RUNTIMERS; tickers run on TICK.
local timers, tickers = {}, {}
C_Timer = {
  After = function(_, fn) timers[#timers + 1] = fn end,
  NewTicker = function(_, fn) local t = { fn = fn }; tickers[#tickers + 1] = t; return t end,
}
function RUNTIMERS()
  local list = timers; timers = {}
  for _, fn in ipairs(list) do
    local ok, err = pcall(fn)
    if not ok then table.insert(STATE.errors, "timer: " .. tostring(err)) end
  end
end
function TICK()
  for _, t in ipairs(tickers) do
    local ok, err = pcall(t.fn)
    if not ok then table.insert(STATE.errors, "ticker: " .. tostring(err)) end
  end
end

UIParent = CreateFrame("Frame", "UIParent")
CLASS_ICON_TCOORDS = {}
for _, class in ipairs({ "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }) do
  CLASS_ICON_TCOORDS[class] = { 0, 0.25, 0, 0.25 }
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
  GetPlayerAuraBySpellID = function(id)
    for _, a in ipairs(STATE.units.player.auras or {}) do
      if a.spellId == id then return { spellId = a.spellId, expirationTime = a.expirationTime } end
    end
  end,
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
  GetSpellTexture = function(id) return "icon" .. id end,
}
C_Item = { GetItemCount = function(id) return STATE.bags[id] or 0 end }
IsPlayerSpell = function(id) return STATE.known[id] == true end
