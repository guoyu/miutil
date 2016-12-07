module ("mi.util.misynchrodata", package.seeall)

local json = require("cjson")
local client = require("messageclient")

function sync_router_name(name)
    if name then
        client.send("router_name", name)
    end
end

function sync_router_location(location)
    if location then
        client.send("router_locale", location)
    end
end

function sync_wifi_ssid(wifi24, wifi5)
    if wifi24 then
        client.send("ssid_24G", wifi24)
    end
    if wifi5 then
        client.send("ssid_5G", wifi5)
    end
end

-- 0/1/2 普通/无线中继/有线中继
function sync_work_mode(mode)
    if mode then
        client.send("work_mode", tostring(mode))
    end
end

function sync_ap_lan_ip(ip)
    if ip then
        MessageClient.send("ap_lan_ip", tostring(ip))
    end
end