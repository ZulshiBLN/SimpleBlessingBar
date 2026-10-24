-- The workflows' rights (ruleset plan 2026-10-24-workflow-rights): no checkout keeps the job's
-- token in .git/config - nothing in them pushes - and the upload jobs only read; the github job
-- keeps the write right release.yml gives it, to create the release. Read as text: a few line
-- checks need no YAML parser.

local WORKFLOWS = { "build.yml", "ci.yml", "publish.yml", "release.yml" }

local function read(name)
    local f = assert(io.open(".github/workflows/" .. name, "rb"))
    local text = f:read("*a"):gsub("\r", "")
    f:close()
    return text
end

local function lines(text)
    local out = {}
    for l in (text .. "\n"):gmatch("([^\n]*)\n") do out[#out + 1] = l end
    return out
end

-- Every checkout's step - the lines indented deeper than its "- uses" - says
-- `persist-credentials: false`, inline (`with: { ... }`) or in a `with:` block
local function checkoutProblems(name, text)
    local out, ls = {}, lines(text)
    for i, l in ipairs(ls) do
        local indent = l:match("^(%s*)%- uses: actions/checkout@")
        if indent then
            local step = {}
            for j = i + 1, #ls do
                local own = ls[j]:match("^(%s*)%S")
                if own and #own <= #indent then break end
                step[#step + 1] = ls[j]
            end
            if not table.concat(step, "\n"):find("persist%-credentials:%s*false") then
                out[#out + 1] = ("%s:%d keeps the token"):format(name, i)
            end
        end
    end
    return out
end

-- The lines of one job of publish.yml, up to the next job
local function job(text, key)
    local out, inside = {}, false
    for _, l in ipairs(lines(text)) do
        if l:find("^  [%w_-]+:%s*$") then inside = l:find("^  " .. key .. ":") ~= nil
        elseif inside then out[#out + 1] = l end
    end
    return table.concat(out, "\n")
end

local function publishProblems(text)
    local out = {}
    for _, key in ipairs({ "curseforge", "wago" }) do
        if not job(text, key):find("\n?%s*permissions:%s*{%s*contents:%s*read%s*}") then
            out[#out + 1] = key .. " has no read-only permissions"
        end
    end
    if job(text, "github"):find("permissions:", 1, true) then
        out[#out + 1] = "github sets its own permissions"
    end
    return out
end

describe("the workflows' rights", function()
    it("store no token in any checkout, and let the upload jobs only read", function()
        local problems = {}
        for _, name in ipairs(WORKFLOWS) do
            for _, p in ipairs(checkoutProblems(name, read(name))) do problems[#problems + 1] = p end
        end
        for _, p in ipairs(publishProblems(read("publish.yml"))) do problems[#problems + 1] = p end
        assert.are.same({}, problems)
    end)

    it("notice one checkout that keeps the token, and an upload job with write rights", function()
        local text = read("publish.yml")
        local oneLost = text:gsub("\n%s*with:%s*{%s*persist%-credentials:%s*false%s*}[^\n]*", "", 1)
        assert.are.equal(1, #checkoutProblems("publish.yml", oneLost))
        local writable = text:gsub("permissions:%s*{%s*contents:%s*read%s*}", "permissions: { contents: write }", 1)
        assert.are.equal(1, #publishProblems(writable))
    end)
end)
