-- The plugin installer on KOReader's real zip and hash code: choosing the
-- release, refusing unsafe zip entries, and installing a zip into a
-- temporary plugins folder only when it matches what GitHub lists.
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
os.execute("rm -rf '" .. tmp .. "'")

Kit.finish("install")
