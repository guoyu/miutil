module ("mi.util.misystem", package.seeall)

local util = require("mi.miutil")
local cypto = require("mi.util.micrypto")

local function _get_privacy()
    local preference = require("mi.mipreference")
    local privacy = preference.get(preference.PREF_PRIVACY)
    if tonumber(privacy) and tonumber(privacy) == 1 then
        return true
    else
        return false
    end
end

local function _get_initted()
    local preference = require("mi.mipreference")
    local initted = preference.get(preference.PREF_IS_INITED)
    if initted then
        return true
    else
        return false
    end
end

local function _get_misc_info()
    local uci = require("luci.model.uci").cursor()
    local info = {}
    info["bbs"] = tostring(uci:get("misc", "hardware", "bbs"))
    info["cpufreq"] = tostring(uci:get("misc", "hardware", "cpufreq"))
    info["verify"] = tostring(uci:get("misc", "hardware", "verify"))
    info["gpio"] = tonumber(uci:get("misc", "hardware", "gpio")) == 1 and 1 or 0
    info["recovery"] = tonumber(uci:get("misc", "hardware", "recovery")) == 1 and 1 or 0
    info["flashpermission"] = tonumber(uci:get("misc", "hardware", "flash_per")) == 1 and 1 or 0
    return info
end

local function _get_system_uptime()
    local uptime = "cat /proc/uptime"
    local data = util.exec(uptime)
    if data == nil then
        return 0
    else
        local t1,t2 = data:match("^(%S+) (%S+)")
        return util.trim(t1)
    end
end

local function _get_hardware_info()
    local lucisys = require("luci.sys")
    local misc = _get_misc_info()
    local sysinfo = {}
    local processor = util.execl("cat /proc/cpuinfo | grep processor")
    local platform, model, memtotal, memcached, membuffers, memfree, bogomips = lucisys.sysinfo()
    if #processor > 0 then
        sysinfo["core"] = #processor
    else
        sysinfo["core"] = 1
    end
    local chippkg = util.exec("cat /proc/cpuinfo | grep b_chippkg | awk '{print $3}'")
    if chippkg then
        chippkg = tonumber(util.trim(chippkg))
        if chippkg == 0 then
            sysinfo["hz"] = misc.cpufreq
        else
            sysinfo["hz"] = "800MHz"
        end
    else
        sysinfo["hz"] = util.hz_format(tonumber(bogomips)*500000)
    end
    sysinfo["system"] = platform
    sysinfo["memTotal"] = string.format("%0.2f M",memtotal/1024)
    sysinfo["memFree"] = string.format("%0.2f M",memfree/1024)
    return sysinfo
end

local function _get_router_name()
    local preference = require("mi.mipreference")
    local name = preference.get(preference.PREF_ROUTER_NAME, "")
    if util.str_nil(name) then
        -- todo: if nil return wifi ssid
    end
    return name
end

local function _get_router_location()
    local preference = require("mi.mipreference")
    return preference.get(preference.PREF_ROUTER_LOCATION, "")
end

-- 黑色    100
-- 白色    101
-- 橘色    102
-- 绿色    103
-- 蓝色    104
-- 粉色    105
local function _get_router_color()
    local color = util.exec("nvram get color")
    if color then
        color = util.trim(color)
        color = tonumber(color)
        if not color then
            color = 100
        end
    else
        color = 100
    end
    return color
end

local function _get_rom_version_info()
    local uci = require("luci.model.uci").cursor()
    local info = {}
    uci:load("/usr/share/xiaoqiang/xiaoqiang_version")
    local versions = uci:get_all("xiaoqiang_version", "version")
    if versions then
        for key, value in pairs(versions) do
            if not key:match("^%.") then
                info[key] = value
            end
        end
    end
    return info
end

local function _get_eth_link()
    local linkinfo = {}
    local cmd = "/sbin/ethstatus"
    for _, line in ipairs(util.execl(cmd)) do
        local port, link = line:match('port (%d):(%S+)')
        if link then
            if tonumber(port) == 0 then
                linkinfo["lan1"] = link == 'up' and 1 or 0
            end
            if tonumber(port) == 2 then
                linkinfo["lan2"] = link == 'up' and 1 or 0
            end
            if tonumber(port) == 4 then
                linkinfo["wan"] = link == 'up' and 1 or 0
            end
        end
    end
    return linkinfo
end

local function _get_cpu_temperature()
    local temperature = util.exec("/usr/sbin/readtmp")
    if temperature then
        temperature = temperature:match('Temperature: (%S+)')
        if temperature then
            temperature = tonumber(util.trim(temperature))
            return temperature
        end
    end
    return 0
end

local function _get_device_id()
    local uci = require("luci.model.uci").cursor()
    return uci:get("messaging", "deviceInfo", "DEVICE_ID") or ""
end

local function _get_default_mac()
    local macs = {}
    local macstr = util.exec("getmac")
    if macstr then
        local mac = util.split(macstr, ",")
        macs["mac"]  = mac[1]
        macs["mac2"] = mac[2]
        macs["mac5"] = mac[3]
    end
    return macs
end

-- network
local function _get_lan_ip()
    local uci = require("luci.model.uci").cursor()
    local lan = uci:get_all("network", "lan")
    return lan.ipaddr or "192.168.31.1"
end

local FUNCTIONS = {
    ["privacy"]         = _get_privacy,
    ["initted"]         = _get_initted,
    ["miscinfo"]        = _get_misc_info,
    ["uptime"]          = _get_system_uptime,
    ["hardware"]        = _get_hardware_info,
    ["router_name"]     = _get_router_name,
    ["router_location"] = _get_router_location,
    ["router_color"]    = _get_router_color,
    ["version"]         = _get_rom_version_info,
    ["ethlink"]         = _get_eth_link,
    ["cpu_temperature"] = _get_cpu_temperature,
    ["deviceid"]        = _get_device_id,
    ["default_mac"]     = _get_default_mac,
    ["lan_ip"]          = _get_lan_ip
}

function get_system_info(keystr)
    local status = {}
    if keystr then
        for key, fun in pairs(FUNCTIONS) do
            status[key] = fun()
        end
    else
        local keys = util.split(keystr, ",")
        if keys then
            for _, key in ipairs(keys) do
                local info
                local fun = FUNCTIONS[key]
                if fun then
                    info = fun()
                end
                if info then
                    status[key] = info
                end
            end
        end
    end
    return status
end

function get_nvram_configs()
    local configs = {}
    configs["wifi_ssid"]    = util.nvram_get("nv_wifi_ssid", "")
    configs["wifi_enc"]     = util.nvram_get("nv_wifi_enc", "")
    configs["wifi_pwd"]     = util.nvram_get("nv_wifi_pwd", "")
    configs["rom_ver"]      = util.nvram_get("nv_rom_ver", "")
    configs["rom_channel"]  = util.nvram_get("nv_rom_channel", "")
    configs["hardware"]     = util.nvram_get("nv_hardware", "")
    configs["uboot"]        = util.nvram_get("nv_uboot", "")
    configs["linux"]        = util.nvram_get("nv_linux", "")
    configs["ramfs"]        = util.nvram_get("nv_ramfs", "")
    configs["sqafs"]        = util.nvram_get("nv_sqafs", "")
    configs["rootfs"]       = util.nvram_get("nv_rootfs", "")
    configs["sys_pwd"]      = util.nvram_get("nv_sys_pwd", "")
    configs["wan_type"]     = util.nvram_get("nv_wan_type", "")
    configs["pppoe_name"]   = util.nvram_get("nv_pppoe_name", "")
    configs["pppoe_pwd"]    = util.nvram_get("nv_pppoe_pwd", "")
    return configs
end

function init_root_passwd()
    local genpwd = util.exec("mkxqimage -I")
    if genpwd then
        local lucisys = require("luci.sys")
        genpwd = util.trim(genpwd)
        lucisys.user.setpasswd("root", genpwd)
    end
end

function set_privacy(agree, f_hook)
    local preference = require("mi.mipreference")
    local privacy = agree and "1" or "0"
    preference.set(preference.PREF_PRIVACY, privacy)
    if f_hook and type(f_hook) == "function" then
        f_hook(privacy)
    end
end

function set_inited()
    local preference = require("mi.mipreference")
    preference.set(preference.PREF_PRIVACY, "YES")
    os.execute("/usr/sbin/sysapi webinitrdr set off")
    util.fork("/etc/init.d/xunlei restart")
end

function set_router_name(name, f_hook)
    if name then
        local preference = require("mi.mipreference")
        preference.set(preference.PREF_ROUTER_NAME, name)
        if f_hook and type(f_hook) == "function" then
            f_hook(name)
        end
    end
end

--
-- 家/单位/其它
--
function set_router_location(location, f_hook)
    if location then
        local preference = require("mi.mipreference")
        preference.set(preference.PREF_ROUTER_LOCATION, location)
        if f_hook and type(f_hook) == "function" then
            f_hook(location)
        end
    end
end

function generate_log_key()
    local mac = _get_default_mac().mac
    local timestamp = string.format("%012d", os.time())
    local key = cypto.base64_enc(mac.."-"..timestamp)
    return key
end

--[[
    M:Network detection log
    B:System log
    X:Not use
    Y:Not use
    Z:Not use
]]--
function upload_log_file(logfile, logtype, logkey)
    local LOG_TYPE = {
        ["M"] = "TTo=",
        ["B"] = "Qjo=",
        ["X"] = "WDo=",
        ["Y"] = "WTo=",
        ["Z"] = "Wjo="
    }

    local HBASE_LOG_UPLOAD_URL  = "https://log.miwifi.com/xiaoqiang_log/"
    local SUB_KEY               = "false-row-key"
    local CURL_CMD              = "curl -k -i -f -X PUT %s%s -H \"Content-Type: application/json\" --data @%s 2>/dev/null"
    local JSON_FILE             = "/tmp/log.json"

    local json = require("cjson")
    local column = LOG_TYPE[logtype]
    if not column then
        return false
    end
    local key = logkey or generate_log_key()
    local base64_str = cypto.base64_enc_file(logfile)
    local data = {["Row"] = {["key"] = key, ["Cell"] = {{["column"] = column, ["$"] = base64_str}}}}
    local data_str = json.encode(data)
    local log_json_file = io.open(JSON_FILE, "w")
    if log_json_file then
        log_json_file:write(data_str)
        log_json_file:close()
    end
    local command = string.format(CURL_CMD, HBASE_LOG_UPLOAD_URL, SUB_KEY, JSON_FILE)
    local result = util.exec(command)
    if util.str_nil(result) then
        return false
    else
        if string.find(result, "OK") ~= nil then
            return true
        else
            return false
        end
    end
end
