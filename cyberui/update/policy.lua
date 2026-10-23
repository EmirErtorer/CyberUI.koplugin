-- Updates, the rules: which of CyberUI's GitHub releases may be offered, and
-- as what. Plain Lua (no network, files or widgets), so the tests drive it.
--
--   * A release is a published GitHub release tagged with a version
--     ("v1.1.0", "v1.2.0-beta.1") that carries "CyberUI.koplugin-<tag>.zip"
--     with a SHA-256 digest (see GitHub.release). GitHub's prerelease flag
--     says which channel it is in.
--   * The newest stable release is offered when it is newer than what is
--     installed; never an older one, except to go back to it from a
--     prerelease or a test build.
--   * With prereleases on, the newest prerelease is offered too, but only
--     while it is newer than the newest stable release.

local GitHub = require("cyberui/install/github")

local Policy = {}

-- CyberUI as GitHub knows it.
Policy.SELF = {
    repo = "EmirErtorer/CyberUI.koplugin",
    folder = "CyberUI.koplugin",
    zip = function(tag) return "CyberUI.koplugin-" .. tag .. ".zip" end,
}
Policy.DAY = 24 * 3600     -- between automatic checks
Policy.RETRY = 3600        -- after an automatic check that failed

-- "v1.1.0" or "1.2.0-beta.1" as { major, minor, patch, pre = { parts } },
-- or nil when it is not a version.
function Policy.parse(s)
    if type(s) ~= "string" then return nil end
    local a, b, c, rest = s:match("^v?(%d+)%.(%d+)%.(%d+)(.*)$")
    if not a then return nil end
    local v = { tonumber(a), tonumber(b), tonumber(c) }
    if rest ~= "" then
        local pre = rest:match("^%-([%w%.%-]+)$")
        if not pre then return nil end
        v.pre = {}
        for part in pre:gmatch("[^%.]+") do v.pre[#v.pre + 1] = tonumber(part) or part end
    end
    return v
end

-- -1, 0 or 1 as version a comes before, equals or comes after b (1.1.0-beta.2
-- comes before 1.1.0); nil when either is not a version.
function Policy.compare(a, b)
    a = type(a) == "table" and a or Policy.parse(a)
    b = type(b) == "table" and b or Policy.parse(b)
    if not (a and b) then return nil end
    for i = 1, 3 do
        if a[i] ~= b[i] then return a[i] < b[i] and -1 or 1 end
    end
    if not a.pre and not b.pre then return 0 end
    if not a.pre then return 1 end
    if not b.pre then return -1 end
    for i = 1, math.max(#a.pre, #b.pre) do
        local x, y = a.pre[i], b.pre[i]
        if x == nil then return -1 end
        if y == nil then return 1 end
        if x ~= y then
            local nx, ny = type(x) == "number", type(y) == "number"
            if nx and ny then return x < y and -1 or 1 end
            if nx ~= ny then return nx and -1 or 1 end   -- numbers before words
            return x < y and -1 or 1
        end
    end
    return 0
end

-- What GitHub's release list offers the installed version `current`:
--   stable, stable_action   the newest stable release; "update", "back" (from
--                           a prerelease or test build) or "current"
--   pre, pre_action         the newest prerelease while it is newer than
--                           stable; "try" or "current"
--   on_pre                  the installed version is a prerelease or test build
function Policy.offers(list, current, addon)
    addon = addon or Policy.SELF
    local cur = Policy.parse(current)
    local stable, pre, listed_pre
    for _i, r in ipairs(type(list) == "table" and list or {}) do
        local rel = GitHub.release(r, addon)
        local v = rel and Policy.parse(rel.tag)
        if v then
            rel.v = v
            if rel.pre then
                if cur and Policy.compare(v, cur) == 0 then listed_pre = true end
                if not pre or Policy.compare(v, pre.v) > 0 then pre = rel end
            elseif not stable or Policy.compare(v, stable.v) > 0 then
                stable = rel
            end
        end
    end
    if pre and stable and Policy.compare(pre.v, stable.v) <= 0 then pre = nil end
    local out = { stable = stable, pre = pre }
    out.on_pre = cur ~= nil and (listed_pre or cur.pre ~= nil or (stable ~= nil and Policy.compare(cur, stable.v) > 0))
    if stable then
        local c = cur and Policy.compare(stable.v, cur)
        out.stable_action = (not c or c > 0) and "update" or ((c < 0 or out.on_pre) and "back" or "current")
    end
    if pre then
        local c = cur and Policy.compare(pre.v, cur)
        out.pre_action = (not c or c > 0) and "try" or (c == 0 and "current" or nil)
    end
    return out
end

-- Is an automatic check due? `last` when the last one worked, `tried` when
-- one was last tried (os.time values, or nil).
function Policy.due(now, last, tried)
    local function bad(t) return type(t) ~= "number" or t > now end
    if not bad(tried) and now - tried < Policy.RETRY then return false end
    return bad(last) or now - last >= Policy.DAY
end

-- Release notes (GitHub's Markdown) as plain lines to read: headings in
-- capitals, bullets with a dash, links and marks taken out.
function Policy.notes(md)
    local out = {}
    for line in ((md or ""):gsub("\r", "") .. "\n"):gmatch("([^\n]*)\n") do
        line = line:gsub("!%b[]%b()", ""):gsub("%[([^%]]*)%]%b()", "%1"):gsub("<[^>]+>", "")
            :gsub("%*%*(.-)%*%*", "%1"):gsub("`([^`]*)`", "%1")
        local heading = line:match("^%s*#+%s+(.+)$")
        local bullet = line:match("^%s*[%-%*%+]%s+(.+)$")
        if heading then out[#out + 1] = "// " .. heading:upper()
        elseif bullet then out[#out + 1] = "- " .. bullet
        elseif line:match("%S") then out[#out + 1] = (line:gsub("^%s+", ""))
        elseif #out > 0 and out[#out] ~= "" then out[#out + 1] = "" end
    end
    return table.concat(out, "\n")
end

return Policy
