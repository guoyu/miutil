module ("mi.util.mipush", package.seeall)

local util = require("mi.miutil")

function push_settings()
    local uci = require("luci.model.uci").cursor()
    local result = {
        ["auth"] = false,
        ["quiet"] = false
    }
    local settings = uci:get_all("devicelist", "settings")
    if settings then
        result.auth = tonumber(settings.auth) == 1 and true or false
        result.quiet = tonumber(settings.quiet) == 1 and true or false
    end
    return result
end

-- key:auth/quiet value:0/1
function set_push_config(key, value)
    local uci = require("luci.model.uci").cursor()
    local settings = uci:get_all("devicelist", "settings")
    if settings then
        settings[key] = value
    else
        settings = {}
        settings[key] = value
    end
    uci:section("devicelist", "core", "settings", settings)
    uci:commit("devicelist")
end

function get_authen_failed_times_dict()
    local uci = require("luci.model.uci").cursor()
    local authfail = uci:get_all("devicelist", "authfail")
    return authfail or {}
end

function get_authen_failed_times(mac)
    if util.str_nil(mac) then
        return
    else
        mac = util.mac(mac)
    end
    local uci = require("luci.model.uci").cursor()
    local mackey = mac:gsub(":", "")
    if not uci:get_all("devicelist", "authfail") then
        uci:section("devicelist", "record", "authfail", {})
        uci:commit("devicelist")
        return 0
    else
        local failed = uci:get("devicelist", "authfail", mackey)
        if failed and tonumber(failed) then
            return tonumber(failed)
        else
            return 0
        end
    end
end

function set_authen_failed_times(mac, times)
    if util.str_nil(mac) or not tonumber(times) then
        return
    else
        mac = util.mac(mac)
    end
    local uci = require("luci.model.uci").cursor()
    local mackey = mac:gsub(":", "")
    local authfail = uci:get_all("devicelist", "authfail")
    if not authfail then
        authfail = {}
    end
    authfail[mackey] = times
    uci:section("devicelist", "record", "authfail", authfail)
    uci:commit("devicelist")
end 

function special_notify(mac)
    if util.str_nil(mac) then
        return false, 0
    else
        mac = util.mac(mac)
    end
    local uci = require("luci.model.uci").cursor()
    local mackey = mac:gsub(":", "")
    local record = uci:get("devicelist", "notify", mackey)
    if record and tonumber(record) then
        return true, tonumber(record)
    end
    return false, 0
end

function set_special_notify(mac, enable, timestamp)
    if util.str_nil(mac) and tonumber(timestamp) then
        return false
    else
        mac = util.mac(mac)
    end
    local uci = require("luci.model.uci").cursor()
    local mackey = mac:gsub(":", "")
    if not uci:get_all("devicelist", "notify") then
        uci:section("devicelist", "record", "notify", {})
        uci:commit("devicelist")
    end
    if enable then
        local record = uci:get("devicelist", "notify", mackey)
        if not record then
            uci:set("devicelist", "notify", mackey, 1)
            uci:commit("devicelist")
        else
            uci:set("devicelist", "notify", mackey, timestamp)
            uci:commit("devicelist")
        end
    else
        uci:delete("devicelist", "notify", mackey)
        uci:commit("devicelist")
    end
    return true
end

function notify_dict()
    local dict = {}
    local uci = require("luci.model.uci").cursor()
    local notify = uci:get_all("devicelist", "notify")
    if notify then
        for key, value in pairs(notify) do
            if tonumber(value) then
                dict[key] = 1
            end
        end
    end
    return dict
end