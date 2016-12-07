module ("mi.milogger", package.seeall)

local posix = require("posix")

--[[
    0    mergency: system is unusable
    1    Alert: action must be taken immediately
    2    Critical: critical conditions
    3    Error: error conditions
    4    Warning: warning conditions
    5    Notice: normal but significant condition
    6    Informational: informational messages
    7    Debug: debug-level messages
]]--
function log(...)
    local priority = arg[1]
    if priority and tonumber(priority) and tonumber(priority) >= 0 and tonumber(priority) <= 7 then
        local util = require("luci.util")
        posix.openlog("miutil","np",LOG_USER)
        for i = 2, arg.n do
            posix.syslog(priority, util.serialize_data(arg[i]))
        end
        posix.closelog()
    end
end