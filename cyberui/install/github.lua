-- GitHub releases: reading the API's list of a repository's releases, each
-- usable only when it is published (not a draft), tagged with a version and
-- carries its plugin zip with a SHA-256 digest. Plain Lua over the API's
-- answer, so the tests feed it saved answers. Used to install companions
-- (Ink Away) and by CyberUI's own updater.

local Net = require("cyberui/install/net")

local GitHub = {}

GitHub.MAX_FEED = 1024 * 1024        -- the release list, in bytes
GitHub.MAX_ZIP = 32 * 1024 * 1024    -- a plugin zip

-- One of the API's releases as a plugin may use it, or nil. `addon` gives
-- repo and the zip's name for a tag.
function GitHub.release(r, addon)
    if type(r) ~= "table" or r.draft ~= false or type(r.tag_name) ~= "string" then return nil end
    local name = addon.zip(r.tag_name)
    local url = "https://github.com/" .. addon.repo .. "/releases/download/" .. r.tag_name .. "/" .. name
    for _j, a in ipairs(type(r.assets) == "table" and r.assets or {}) do
        if type(a) == "table" and a.name == name and a.state == "uploaded" and a.browser_download_url == url
                and type(a.size) == "number" and a.size > 0 and a.size <= GitHub.MAX_ZIP
                and type(a.digest) == "string" and a.digest:match("^sha256:%x+$") and #a.digest == 71 then
            return {
                tag = r.tag_name, version = (r.tag_name:gsub("^v", "")), url = url, size = a.size,
                digest = a.digest:sub(8):lower(), pre = r.prerelease == true,
                notes = type(r.body) == "string" and r.body or "",
                date = type(r.published_at) == "string" and r.published_at:sub(1, 10) or nil,
            }
        end
    end
    return nil
end

-- The newest stable release a plugin may install from the API's list, or
-- nil and why.
function GitHub.pick(list, addon)
    if type(list) ~= "table" then return nil, "GitHub's answer could not be read" end
    if list.message then return nil, tostring(list.message) end
    for _i, r in ipairs(list) do
        local rel = GitHub.release(r, addon)
        if rel and not rel.pre then return rel end
    end
    return nil, "no release with a verified zip"
end

-- Ask GitHub for a repository's releases: done(list) or done(nil, why).
function GitHub.releases(addon, done)
    local api = "https://api.github.com/repos/" .. addon.repo .. "/releases?per_page=30"
    Net.get(api, GitHub.MAX_FEED, 40, function(path, why)
        if not path then return done(nil, why) end
        local f = io.open(path, "rb")
        local body = f and f:read("*a")
        if f then f:close() end
        os.remove(path)
        local ok, list = pcall(function() return require("json").decode(body or "") end)
        if not ok or type(list) ~= "table" then return done(nil, "GitHub's answer could not be read") end
        if list.message then return done(nil, tostring(list.message)) end
        done(list)
    end)
end

-- Ask GitHub for the release to install, then done(release) or done(nil, why).
function GitHub.latest(addon, done)
    GitHub.releases(addon, function(list, why)
        if not list then return done(nil, why) end
        done(GitHub.pick(list, addon))
    end)
end

return GitHub
