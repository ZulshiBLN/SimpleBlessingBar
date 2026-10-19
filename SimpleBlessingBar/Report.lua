-- SimpleBlessingBar - bug report window
-- As in SimpleConjureBar (ruleset plan 2026-10-18-settings-more). Addons cannot send data, open
-- a browser or write to the clipboard, so the window builds a ready report - addon version,
-- client, language, settings and this addon's Lua errors from BugGrabber - in a selected text
-- box, to copy with Ctrl+C and paste as a new issue. No character name or realm goes into it.

local _, ns = ...
if not ns.enabled then return end

local D = ns.D
local SetL = ns.SetL

local db
ns.OnDBReady(function(d) db = d end)

local MAX_ERRORS = 5       -- newest errors of this addon included in the report
local MAX_STACK_LINES = 12 -- stack lines per error

---------------------------------------------------------------------------
-- Report content
---------------------------------------------------------------------------
-- What could name the reporter: on Forever a character has a first and a second name, and
-- UnitFullName returns the second where a realm used to be (ruleset research
-- 2026-10-18-paladin-facts). A secret value is never compared (code.md).
local function Identity()
    local list = {}
    local first, second = UnitFullName("player")
    for _, part in ipairs({ { first, "<player>" }, { second, "<player>" }, { GetRealmName(), "<realm>" } }) do
        local value = part[1]
        if type(value) == "string" and value ~= "" and not issecretvalue(value) then
            list[#list + 1] = part
        end
    end
    return list
end

-- The text with every name of the reporter replaced
local function Anonymize(text, identity)
    text = tostring(text or "")
    for _, part in ipairs(identity) do
        local pattern = part[1]:gsub("%W", "%%%0")
        text = text:gsub(pattern, part[2])
    end
    return text
end

-- This addon's errors from BugGrabber (the collector BugSack builds on), newest first.
-- BugGrabber is optional (project.md), and its data comes from outside: checked here.
local function CollectErrors()
    local list = {}
    local grabber = BugGrabber
    if not (grabber and grabber.GetDB) then return list, false end
    local ok, errors = pcall(grabber.GetDB, grabber)
    if not ok or type(errors) ~= "table" then return list, true end
    for i = #errors, 1, -1 do
        local e = errors[i]
        if type(e) == "table" then
            local text = tostring(e.message or "") .. "\n" .. tostring(e.stack or "")
            if text:find(ns.ADDON_NAME, 1, true) then
                list[#list + 1] = e
                if #list >= MAX_ERRORS then break end
            end
        end
    end
    return list, true
end

local function FirstLines(text, max)
    local out, n = {}, 0
    for line in tostring(text or ""):gmatch("[^\n]+") do
        n = n + 1
        if n > max then out[#out + 1] = "..." break end
        out[#out + 1] = line
    end
    return table.concat(out, "\n")
end

-- Plain settings (numbers, booleans, strings) sorted by name, and the bar's order
local function SettingsText()
    local keys = {}
    for k, v in pairs(db) do
        local t = type(v)
        if t == "number" or t == "boolean" or t == "string" then keys[#keys + 1] = k end
    end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. tostring(db[k]) end
    parts[#parts + 1] = "order=" .. table.concat(db.order, ",")
    return table.concat(parts, ", ")
end

function ns.BuildReport(description)
    local version, build, _, interface = GetBuildInfo()
    local _, classFile = UnitClass("player")
    local identity = Identity()
    local lines = {
        "## SimpleBlessingBar bug report",
        "",
        "**Description:** " .. ((description and description ~= "") and Anonymize(description, identity) or "-"),
        "",
        "- Addon version: " .. ns.VERSION,
        "- Client: " .. tostring(version) .. " (build " .. tostring(build) .. ", interface " .. tostring(interface) .. ")",
        "- Client locale: " .. tostring(GetLocale()) .. ", addon language: "
            .. tostring(SimpleBlessingBarGlobalDB.language or "auto"),
        "- Character: " .. tostring(classFile) .. ", level " .. tostring(UnitLevel("player"))
            .. (IsInRaid() and ", raid" or IsInGroup() and ", party" or ", solo"),
        "- Date: " .. date("%Y-%m-%d %H:%M"),
        "- Settings: " .. SettingsText(),
        "",
    }
    local errors, hasGrabber = CollectErrors()
    if not hasGrabber then
        lines[#lines + 1] = "**Lua errors:** BugGrabber/BugSack not installed"
    elseif #errors == 0 then
        lines[#lines + 1] = "**Lua errors:** none from SimpleBlessingBar"
    else
        lines[#lines + 1] = "**Lua errors (newest first):**"
        for i, e in ipairs(errors) do
            lines[#lines + 1] = ""
            lines[#lines + 1] = ("Error %d (x%s, %s):"):format(i, tostring(e.counter or 1), tostring(e.time or "?"))
            lines[#lines + 1] = "```"
            lines[#lines + 1] = Anonymize(FirstLines(e.message, 6), identity)
            lines[#lines + 1] = Anonymize(FirstLines(e.stack, MAX_STACK_LINES), identity)
            lines[#lines + 1] = "```"
        end
    end
    return table.concat(lines, "\n")
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local frame

local function SelectReport()
    frame.report:SetFocus()
    frame.report:HighlightText()
end

local function Refresh()
    frame.reportText = ns.BuildReport(frame.desc:GetText())
    frame.report:SetText(frame.reportText)
    frame.report:SetCursorPosition(0)
end

local function CreateWindow()
    local W, H, PAD = 520, 420, 22
    frame = CreateFrame("Frame", "SimpleBlessingBarReport", UIParent, "BackdropTemplate")
    ns.reportWindow = frame
    frame:SetSize(W, H)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    tinsert(UISpecialFrames, "SimpleBlessingBarReport") -- closes with Escape

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18)
    SetL(title, "REPORT_TITLE")
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    -- Step 1: optional description
    local step1 = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    step1:SetPoint("TOPLEFT", PAD, -50)
    SetL(step1, "REPORT_STEP1")
    local desc = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    desc:SetPoint("TOPLEFT", step1, "BOTTOMLEFT", 6, -4)
    desc:SetSize(W - 2 * PAD - 6, 22)
    desc:SetAutoFocus(false)
    desc:SetMaxLetters(300)
    desc:SetScript("OnTextChanged", function(_, userInput) if userInput then Refresh() end end)
    desc:SetScript("OnEnterPressed", SelectReport)
    desc:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    frame.desc = desc

    -- Step 2: the report, selected for Ctrl+C (read-only)
    local step2 = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    step2:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", -6, -12)
    SetL(step2, "REPORT_STEP2")

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", step2, "BOTTOMLEFT", 0, -6)
    scroll:SetPoint("BOTTOMRIGHT", -PAD - 22, 92)
    local bg = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    bg:SetPoint("TOPLEFT", scroll, -4, 4)
    bg:SetPoint("BOTTOMRIGHT", scroll, 24, -4)
    bg:SetColorTexture(0, 0, 0, 0.5)

    local report = CreateFrame("EditBox", nil, scroll)
    report:SetMultiLine(true)
    report:SetAutoFocus(false)
    report:SetFontObject("ChatFontNormal")
    report:SetWidth(W - 2 * PAD - 30)
    report:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    report:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    -- Read-only: user edits are undone right away
    report:SetScript("OnTextChanged", function(self, userInput)
        if userInput then
            self:SetText(frame.reportText or "")
            self:HighlightText()
        end
    end)
    scroll:SetScrollChild(report)
    frame.report = report

    -- Step 3: where to paste it
    local step3 = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    step3:SetPoint("BOTTOMLEFT", PAD, 66)
    step3:SetPoint("RIGHT", -PAD, 0)
    step3:SetJustifyH("LEFT")
    SetL(step3, "REPORT_STEP3")
    local url = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
    url:SetPoint("BOTTOMLEFT", PAD + 6, 40)
    url:SetSize(W - 2 * PAD - 6, 22)
    url:SetAutoFocus(false)
    url:SetText(D.BUG_REPORT_URL)
    url:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    url:SetScript("OnTextChanged", function(self, userInput)
        if userInput then self:SetText(D.BUG_REPORT_URL) self:HighlightText() end
    end)
    url:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    local done = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    done:SetSize(120, 22)
    done:SetPoint("BOTTOMRIGHT", -PAD, 16)
    SetL(done, "CLOSE")
    done:SetScript("OnClick", function() frame:Hide() end)

    frame:SetScript("OnShow", function()
        Refresh()
        SelectReport()
    end)
    frame:Hide()
end

-- The report window replaces the settings window
function ns.OpenBugReport()
    if not frame then CreateWindow() end
    ns.CloseSettings()
    frame.desc:SetText("")
    if frame:IsShown() then Refresh() SelectReport() else frame:Show() end
end
