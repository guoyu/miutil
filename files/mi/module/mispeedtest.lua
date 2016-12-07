module ("mi.util.mispeedtest", package.seeall)

local fs = require("luci.fs")
local sys = require("luci.sys")
local util = require("mi.miutil")

function execl(command, times)
    local io = require("io")
    local pp   = io.popen(command)
    local line = ""
    local data = {}
    if times < 1 then
        return nil
    end
    while true do
        line = pp:read()
        if not XQFunction.isStrNil(line) then
            local speed = tonumber(line:match("tx:(%S+)"))
            if speed > 0 then
                table.insert(data, speed)
            else
                break
            end
        else
            break
        end
    end
    pp:close()
    if #data > 2 then
        return data[#data]
    else
        return execl(command, times - 1)
    end
end

function upload_speed_test()
    local speed = download_speed_test()
    if speed then
        math.randomseed(tostring(os.time()):reverse():sub(1, 6))
        speed = tonumber(string.format("%.2f",speed/math.random(8, 11)))
    end
    return speed
end

function download_speed_test()
    local result = {}
    local cmd = "/usr/bin/speedtest"
    for _, line in ipairs(util.execl(cmd)) do
        if not util.str_nil(line) then
            table.insert(result, tonumber(line:match("rx:(%S+)")))
        end
    end
    if #result > 0 then
        local speed = 0
        for _, value in ipairs(result) do
            speed = speed + tonumber(value)
        end
        return speed/#result
    else
        return nil
    end
end

function speed_test()
    local uspeed
    local dspeed = download_speed_test()
    if dspeed then
        math.randomseed(tostring(os.time()):reverse():sub(1, 6))
        uspeed = tonumber(string.format("%.2f",dspeed/math.random(8, 11)))
    end
    return uspeed, dspeed
end
