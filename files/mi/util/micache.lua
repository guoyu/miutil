module ("mi.util.micache", package.seeall)

local util      = require("mi.miutil")
local lucisys   = require("luci.sys")
local nixio     = require("nixio")
local nixiofs   = require("nixio.fs")

function save_cache(key, data, expire)
    if not key or not data then
        return false
    end
    local path = "/tmp/"..key
    local info = {}
    info.data = data
    info.atime = lucisys.uptime()
    info.expire = tostring(expire or "none")
    local cache = nixio.open(path, "w", 600)
    cache:writeall(util.get_bytecode(info))
    cache:close()
    return true
end

function get_cache(key)
    if not key then
        return nil
    end
    local path = "/tmp/"..key
    if not nixiofs.access(path) then
        return nil
    end
    local blob = nixiofs.readfile(path)
    local func = loadstring(blob)
    setfenv(func, {})

    local data = func()
    if data.atime and tonumber(data.expire) and tonumber(data.expire) > 0 and data.atime + data.expire < lucisys.uptime() then
        nixiofs.unlink(path)
        return nil
    end
    return data.data
end

function delete_cache(key)
    if not key then
        return false
    end
    local path = "/tmp/"..key
    if nixiofs.access(path) then
        nixiofs.unlink(path)
    end
    return true
end