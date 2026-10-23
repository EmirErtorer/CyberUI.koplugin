-- Downloads for installing plugins: each request runs in a short-lived
-- background process (KOReader's runInSubProcess) that writes what it
-- fetched to a file, so KOReader never waits on the network. Only GitHub's
-- hosts are spoken to, over HTTPS, with at most five redirects and a size
-- limit; a request that hangs is stopped at its deadline.

local DataStorage = require("datastorage")
local UIManager = require("ui/uimanager")
local lfs = require("libs/libkoreader-lfs")

local Net = {}

-- Hosts a request may go to: the API and where GitHub sends a download.
Net.HOSTS = { ["api.github.com"] = true, ["github.com"] = true,
    ["objects.githubusercontent.com"] = true, ["release-assets.githubusercontent.com"] = true }

local POLL = 0.5
local serial = 0

-- May a request go to this URL?
function Net.allowed(url)
    local host = type(url) == "string" and url:match("^https://([^/:%?#]+)[/%?#]")
    return host ~= nil and Net.HOSTS[host] == true
end

-- The folder downloads are written to (in KOReader's cache).
function Net.dir()
    local base = DataStorage:getDataDir() .. "/cache"
    local dir = base .. "/cyberui-install"
    if lfs.attributes(base, "mode") ~= "directory" then lfs.mkdir(base) end
    if lfs.attributes(dir, "mode") ~= "directory" then lfs.mkdir(dir) end
    return dir
end

-- In the background process: fetch `url` into `path`, at most `limit` bytes.
-- Returns true, or nil and why not.
function Net.fetch(url, path, limit)
    local http = require("socket.http")
    local socket = require("socket")
    local socketutil = require("socketutil")
    for _hop = 1, 6 do
        if not Net.allowed(url) then return nil, "not a GitHub address" end
        local f, ferr = io.open(path, "wb")
        if not f then return nil, ferr end
        local got, over = 0, false
        local sink = function(chunk, err)
            if chunk then
                got = got + #chunk
                if got > limit then over = true; return nil, "too large" end
                return f:write(chunk) and 1 or nil
            end
            return err == nil and 1 or nil, err
        end
        socketutil:set_timeout(15, 90)
        local code, headers = socket.skip(1, http.request({
            url = url, method = "GET", redirect = false, sink = sink,
            headers = { ["User-Agent"] = "CyberUI-KOReader-plugin", ["Accept"] = "application/vnd.github+json" },
        }))
        socketutil:reset_timeout()
        f:close()
        if over then os.remove(path); return nil, "larger than expected" end
        if (code == 301 or code == 302 or code == 303 or code == 307 or code == 308)
                and type(headers) == "table" and headers.location then
            os.remove(path)
            url = headers.location
        elseif code == 200 then
            return true
        else
            os.remove(path)
            return nil, type(code) == "number" and ("HTTP " .. code) or tostring(code or "no connection")
        end
    end
    os.remove(path)
    return nil, "too many redirects"
end

-- Fetch `url` into a new file in the background, then done(path) or
-- done(nil, why). Without background processes it runs here instead.
function Net.get(url, limit, timeout, done)
    local util = require("ffi/util")
    serial = serial + 1
    local path = string.format("%s/%d-%d", Net.dir(), os.time(), serial)
    local status = path .. ".status"
    os.remove(path); os.remove(status)
    local pid = util.runInSubProcess(function()
        local ok, res, why = pcall(Net.fetch, url, path, limit)
        local f = io.open(status .. ".part", "wb")
        if f then
            f:write((ok and res) and "ok" or tostring(ok and why or res))
            f:close()
            os.rename(status .. ".part", status)
        end
    end, false, false)
    if not pid then
        UIManager:scheduleIn(0.2, function()
            local ok, res, why = pcall(Net.fetch, url, path, limit)
            if ok and res then return done(path) end
            done(nil, tostring(ok and why or res))
        end)
        return
    end
    local waited = 0
    local function poll()
        if not util.isSubProcessDone(pid) then
            waited = waited + POLL
            if waited >= timeout then
                util.terminateSubProcess(pid)
                UIManager:scheduleIn(1, function() util.isSubProcessDone(pid) end)
                os.remove(path)
                os.remove(status)
                return done(nil, "timed out")
            end
            return UIManager:scheduleIn(POLL, poll)
        end
        local f = io.open(status, "rb")
        local s = f and f:read("*a")
        if f then f:close() end
        os.remove(status)
        if s == "ok" then return done(path) end
        os.remove(path)
        done(nil, s or "the request stopped")
    end
    UIManager:scheduleIn(POLL, poll)
end

return Net
