-- The plugin installer and CyberUI's updater on KOReader's real zip and hash
-- code: choosing the release and channel, refusing unsafe zip entries,
-- installing a zip into a temporary plugins folder only when it matches what
-- GitHub lists, and replacing an installed copy in place.
-- Run: cd <emulator>/koreader && ./luajit <repo>/tests/install.lua <repo>

local REPO = arg[1] or "."
local Kit = dofile(REPO .. "/tests/kit.lua").boot(REPO)
local GitHub = require("cyberui/install/github")
local Unpack = require("cyberui/install/unpack")
local InkAway = require("cyberui/apps/inkaway")

-- release choice
local function asset(tag, extra)
    local a = { name = InkAway.zip(tag), state = "uploaded", size = 1000,
        browser_download_url = "https://github.com/" .. InkAway.repo .. "/releases/download/" .. tag .. "/" .. InkAway.zip(tag),
        digest = "sha256:" .. string.rep("ab", 32) }
    for k, v in pairs(extra or {}) do a[k] = v end
    return a
end
local list = {
    { tag_name = "v5.0.0", draft = false, prerelease = true, assets = { asset("v5.0.0") } },
    { tag_name = "v4.9.0", draft = true, prerelease = false, assets = { asset("v4.9.0") } },
    { tag_name = "v4.8.0", draft = false, prerelease = false, assets = { asset("v4.8.0", { digest = "md5:00" }) } },
    { tag_name = "v4.7.0", draft = false, prerelease = false, assets = { asset("v4.7.0") } },
}
local r = GitHub.pick(list, InkAway)
Kit.ok(r and r.version == "4.7.0", "picks the newest stable release with a verified zip (got " .. tostring(r and r.version) .. ")")
Kit.ok(r and r.digest == string.rep("ab", 32) and r.size == 1000, "keeps its digest and size")
local none, why = GitHub.pick({ message = "API rate limit exceeded" }, InkAway)
Kit.ok(none == nil and why:find("rate limit"), "passes on GitHub's error message")

-- zip entries
local F = "ink-away.koplugin"
Kit.ok(Unpack.entry(F .. "/main.lua", "file", F) == "main.lua", "a file inside the folder is fine")
Kit.ok(Unpack.entry(F .. "/", "directory", F) == "", "the folder itself is fine")
Kit.ok(Unpack.entry(F .. "/../evil.lua", "file", F) == nil, "a path climbing out is refused")
Kit.ok(Unpack.entry("other/main.lua", "file", F) == nil, "a file outside the folder is refused")
Kit.ok(Unpack.entry("/etc/passwd", "file", F) == nil, "an absolute path is refused")
Kit.ok(Unpack.entry(F .. "/link", "link", F) == nil, "a link is refused")

-- a real install from a zip built from a tiny plugin
local tmp = (os.getenv("TMPDIR") or "/tmp") .. "/cyberui-install-test"
os.execute("rm -rf '" .. tmp .. "' && mkdir -p '" .. tmp .. "/src/" .. F .. "/ink' '" .. tmp .. "/plugins'")
local function write(path, text) local f = io.open(path, "w"); f:write(text); f:close() end
write(tmp .. "/src/" .. F .. "/main.lua", "return {}\n")
write(tmp .. "/src/" .. F .. "/_meta.lua", 'return { version = "4.7.0" }\n')
write(tmp .. "/src/" .. F .. "/ink/core.lua", "return 1\n")
os.execute("cd '" .. tmp .. "/src' && zip -qr ../good.zip " .. F)
local sum, size = Unpack.digest(tmp .. "/good.zip")
local rel = { size = size, digest = sum, version = "4.7.0" }
Kit.ok(Unpack.install(tmp .. "/good.zip", { size = size, digest = string.rep("0", 64) }, F, tmp .. "/plugins") == nil,
    "a zip that does not match GitHub's digest is refused")
local ok, err = Unpack.install(tmp .. "/good.zip", rel, F, tmp .. "/plugins")
Kit.ok(ok, "a matching zip installs: " .. tostring(err))
local f = io.open(tmp .. "/plugins/" .. F .. "/ink/core.lua")
Kit.ok(f ~= nil, "its files are in place")
if f then f:close() end
Kit.ok(Unpack.install(tmp .. "/good.zip", rel, F, tmp .. "/plugins") == nil, "installing over an existing copy is refused")
-- a zip with an entry climbing out of the folder
os.execute("cd '" .. tmp .. "' && python3 -c \"import zipfile; z=zipfile.ZipFile('bad.zip','w'); "
    .. "z.writestr('" .. F .. "/main.lua','return {}'); z.writestr('" .. F .. "/_meta.lua','return {}'); "
    .. "z.writestr('" .. F .. "/../evil.lua','x'); z.close()\"")
local bsum, bsize = Unpack.digest(tmp .. "/bad.zip")
os.execute("rm -rf '" .. tmp .. "/plugins2' && mkdir -p '" .. tmp .. "/plugins2'")
Kit.ok(Unpack.install(tmp .. "/bad.zip", { size = bsize, digest = bsum }, F, tmp .. "/plugins2") == nil,
    "a zip with an unsafe entry is refused")
local left = io.popen("ls -A '" .. tmp .. "/plugins2'"):read("*a")
Kit.ok(left == "", "and nothing of it is left behind")
-- replacing an installed copy (an update): a mismatched zip leaves it alone
write(tmp .. "/plugins/" .. F .. "/old.txt", "old\n")
Kit.ok(Unpack.replace(tmp .. "/good.zip", { size = size, digest = string.rep("0", 64) }, F, tmp .. "/plugins") == nil,
    "an update that does not match GitHub's digest is refused")
Kit.ok(io.open(tmp .. "/plugins/" .. F .. "/old.txt") ~= nil, "and the installed copy is untouched")
local rok, rerr = Unpack.replace(tmp .. "/good.zip", rel, F, tmp .. "/plugins")
Kit.ok(rok, "a matching update replaces the installed copy: " .. tostring(rerr))
Kit.ok(io.open(tmp .. "/plugins/" .. F .. "/old.txt") == nil and io.open(tmp .. "/plugins/" .. F .. "/ink/core.lua") ~= nil,
    "the new copy is in place")
Kit.ok(io.open(Unpack.previous(tmp .. "/plugins", F) .. "/old.txt") ~= nil, "the old copy waits aside until the next start")
os.execute("rm -rf '" .. tmp .. "'")

-- the update rules
local Policy = require("cyberui/update/policy")
Kit.ok(Policy.compare("1.1.0-beta.2", "1.1.0") == -1 and Policy.compare("v1.2.0", "1.1.9") == 1
    and Policy.compare("1.1.0-beta.10", "1.1.0-beta.2") == 1, "versions compare the semantic way")
local function self_rel(tag, pre, extra)
    local a = { name = Policy.SELF.zip(tag), state = "uploaded", size = 1000,
        browser_download_url = "https://github.com/" .. Policy.SELF.repo .. "/releases/download/" .. tag .. "/" .. Policy.SELF.zip(tag),
        digest = "sha256:" .. string.rep("cd", 32) }
    local r = { tag_name = tag, draft = false, prerelease = pre, assets = { a }, body = "## New\n- a thing" }
    for k, v in pairs(extra or {}) do r[k] = v end
    return r
end
local feed = { self_rel("v1.2.0-beta.1", true), self_rel("v1.1.0", false), self_rel("v1.0.0", false),
    self_rel("v9.0.0", false, { draft = true }) }
local o = Policy.offers(feed, "1.0.0")
Kit.ok(o.stable.version == "1.1.0" and o.stable_action == "update", "the newest stable release is offered as an update")
Kit.ok(o.pre and o.pre.version == "1.2.0-beta.1" and o.pre_action == "try", "a newer prerelease is offered to try")
o = Policy.offers(feed, "1.2.0-beta.1")
Kit.ok(o.on_pre and o.stable_action == "back" and o.pre_action == "current", "from a prerelease, stable is offered to go back to")
o = Policy.offers({ self_rel("v1.3.0-beta.1", true), self_rel("v1.3.0", false) }, "1.3.0")
Kit.ok(o.pre == nil and o.stable_action == "current", "a prerelease older than stable is not offered")
Kit.ok(Policy.due(100000, nil, nil) and not Policy.due(100000, 99000, nil) and not Policy.due(200000, nil, 199000),
    "the daily check is due once a day, not right after a failed try")
Kit.ok(Policy.notes("## Added\n- **Bold** [link](http://x)"):find("// ADDED\n%- Bold link") ~= nil, "release notes read as plain lines")

Kit.finish("install")
