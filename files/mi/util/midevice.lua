module ("mi.util.midevice", package.seeall)

local util = require("mi.miutil")

-- xqDb + deviceinfo --> devices
function update()
    local uci = require("luci.model.uci").cursor()
    local sqlite = require("lsqlite3")
    local db_file = "/etc/xqDb"
    local db = sqlite.open(db_file)
    local sql_str = string.format("select * from DEVICE_INFO")
    local result = {}
    for row in db:rows(sql_str) do
        if row then
            local mac = util.mac(row[1])
            local dhcpname = row[2]
            local nickname = row[3]
            if dhcpname then
                result[mac] = {
                    ["mac"]         = mac,
                    ["dhcpname"]    = dhcpname,
                    ["nickname"]    = nickname or ""
                }
            end
        end
    end
    db:close()
    uci:foreach("deviceinfo", "device",
        function(s)
            if result[s.mac] then
                result[s.mac]["owner"] = s.owner
                result[s.mac]["device"] = s.device
            else
                result[s.mac] = {
                    ["mac"]         = s.mac,
                    ["dhcpname"]    = "",
                    ["nickname"]    = "",
                    ["owner"]       = s.owner,
                    ["device"]      = s.device
                }
            end
        end
    )
    for mac, value in pairs(result) do
        uci:section("devices", "device", string.lower(mac:gsub(":", "")), value)
    end
    uci:commit("devices")
end

local DHCP_NAME_RULES = {
    {
        ["rule"] = "^mitv",
        ["company"] = "Xiaomi",
        ["icon"] = "device_mitv.png",
        ["type"] = { ["c"] = 3, ["p"] = 4, ["n"] = "小米电视" },
        ["priority"] = 1
    },
    {
        ["rule"] = "^mibox",
        ["company"] = "Xiaomi",
        ["icon"] = "device_mibox.png",
        ["type"] = { ["c"] = 3, ["p"] = 5, ["n"] = "小米盒子" },
        ["priority"] = 1
    },
    {
        ["rule"] = "^miwifi%-r1d",
        ["company"] = "Xiaomi",
        ["icon"] = "device_miwifi_r1d.png",
        ["type"] = { ["c"] = 3, ["p"] = 8, ["n"] = "小米路由器" },
        ["priority"] = 1
    },
    {
        ["rule"] = "^miwifi%-r1cm",
        ["company"] = "Xiaomi",
        ["icon"] = "device_miwifi_r1c.png",
        ["type"] = { ["c"] = 3, ["p"] = 9, ["n"] = "小米路由器mini" },
        ["priority"] = 1
    },
    {
        ["rule"] = "^miwifi%-r1cq",
        ["company"] = "Xiaomi",
        ["icon"] = "device_miwifi_r1c.png",
        ["type"] = { ["c"] = 3, ["p"] = 10, ["n"] = "小米路由器mini2" },
        ["priority"] = 1
    },
    {
        ["rule"] = "^antscam",
        ["company"] = "云蚁",
        ["icon"] = "device_list_intelligent_camera.png",
        ["type"] = { ["c"] = 2, ["p"] = 6, ["n"] = "小蚁智能摄像机" },
        ["priority"] = 1
    },
    {
        ["rule"] = "^xiaomi%.ir",
        ["company"] = "Xiaomi",
        ["icon"] = "device_list_lq.png",
        ["type"] = { ["c"] = 3, ["p"] = 7, ["n"] = "智能红外" },
        ["priority"] = 1
    },
    {
        ["rule"] = "chuangmi%-plug",
        ["company"] = "Chuangmi",
        ["icon"] = "device_list_intelligent_plugin.png",
        ["type"] = { ["c"] = 3, ["p"] = 2, ["n"] = "智能插座" },
        ["priority"] = 1
    },
    {
        ["rule"] = "^zhimi%-airpurifier",
        ["company"] = "zhimi",
        ["icon"] = "device_list_airpurifier.png",
        ["type"] = { ["c"] = 3, ["p"] = 11, ["n"] = "空气净化器" },
        ["priority"] = 1
    }
}

function identify_device(mac, dhcp_name)
    local iden
    if dhcp_name then
        for _, rule in pairs(DHCP_NAME_RULES) do
            if dhcp_name:match(rule.rule) then
                iden = {
                    ["name"] = rule["company"],
                    ["icon"] = rule["icon"],
                    ["type"] = rule["type"]
                }
            end
        end
    end
    if not iden then
        local nixiofs = require("nixio.fs")
        local oui_filepath = "/tmp/oui"
        if not nixiofs.access(oui_filepath) then
            os.execute("unzip -d /tmp /usr/share/xiaoqiang/oui.zip")
        end
        if nixiofs.access(oui_filepath) then
            local key = string.upper(string.sub(string.gsub(mac,":","-"),1,8))
            local line = util.trim(util.exec("sed -n '/"..key.."/p' "..oui_filepath))
            if line then
                local company = util.trim(util.split(line, key)[2])
                local icon = company:match("ICON:(%S+)")
                if icon and company then
                    iden["name"] = company:match("(.+)ICON:%S+") or ""
                    iden["icon"] = icon
                else
                    iden["name"] = company
                    iden["icon"] = ""
                end
                iden["type"] = {["c"] = 0, ["p"] = 0, ["n"] = ""}
            end
        end
    end
    if not iden then
        iden = {["name"] = "", ["icon"] = "", ["type"] = {["c"] = 0, ["p"] = 0, ["n"] = ""}}
    end
    return iden
end

-- config devices
function get_device_info(mac)
    if util.str_nil(mac) then
        return nil
    end
    local deviceinfo
    local info = uci:get_all("devices", "device", string.lower(mac:gsub(":", "")))
    if info then
        deviceinfo = {
            ["mac"]         = util.mac(mac),
            ["owner"]       = info.owner or "",
            ["device"]      = info.device or "",
            ["nickname"]    = info.nickname or "",
            ["dhcpname"]    = info.dhcpname or ""
        }
    end
    return deviceinfo
end

-- dict
function get_devices_info()
    local uci = require("luci.model.uci").cursor()
    local devices = {}
    uci:foreach("devices", "device",
        function(s)
            devices[s.mac] = {
                ["mac"]         = s.mac,
                ["owner"]       = s.owner,
                ["device"]      = s.device,
                ["nickname"]    = s.nickname,
                ["dhcpname"]    = s.dhcpname
            }
        end
    )
    return devices
end

function save_device_info(mac, info)
    if util.str_nil(mac) or not info or type(info) ~= "table" then
        return
    end
    local uci = require("luci.model.uci").cursor()
    local key = string.lower(mac:gsub(":", ""))
    uci:section("devices", device, key, info)
    uci:commit("devices")
end

function save_devices_info(infos)
    if not infos or type(infos) ~= "table" then
        return
    end
    local uci = require("luci.model.uci").cursor()
    for _, info in ipairs(infos) do
        if info.mac then
            local key = string.lower(info.mac:gsub(":", ""))
            uci:section("devices", device, key, info)
        end
    end
    uci:commit("devices")
end

-- list
function get_dhcp_leases()
    local nixiofs = require("nixio.fs")
    local uci = require("luci.model.uci").cursor()
    local result = {}
    local leasefile = "/var/dhcp.lease"
    uci:foreach("dhcp", "dnsmasq",
    function(s)
        if s.leasefile and nixiofs.access(s.leasefile) then
            leasefile = s.leasefile
            return false
        end
    end)
    local dhcp = io.open(leasefile, "r")
    if dhcp then
        for line in dhcp:lines() do
            if line then
                local ts, mac, ip, name = line:match("^(%d+) (%S+) (%S+) (%S+)")
                if name == "*" then
                    name = ""
                end
                if ts and mac and ip and name then
                    result[#result+1] = {
                        mac  = util.mac(mac),
                        ip   = ip,
                        name = name
                    }
                end
            end
        end
        dhcp:close()
        return result
    else
        return {}
    end
end

-- key:ip/mac
function get_dhcp_dict(key)
    local dict = {}
    local dhcpleases = get_dhcp_leases()
    for _, value in ipairs(dhcpleases) do
        if key == "ip" then
            dict[value.ip] = value
        else
            dict[value.mac] = value
        end
    end
    return dict
end

-- dict
function get_devices_permissions(macs)
    local json = require("cjson")
    local permissions = {}
    local data = util.execl("/usr/sbin/sysapi macfilter get")
    local macarry = {}
    local disk_access_permission = {}
    for _, permission in ipairs(data) do
        local mac = permission:match('mac=(%S-);') or ""
        if mac and mac ~= "" then
            table.insert(macarry, util.mac(mac))
        end
    end
    local payload = {
        ["api"] = 70,
        ["macs"] = macarry
    }
    local result = util.thrift_tunnel_to_datacenter(json.encode(payload))
    if result and result.code == 0 then
        for index, v in ipairs(result.canAccessAllDisk) do
            disk_access_permission[macarry[index]] = v
        end
    end
    for _, permission in ipairs(data) do
        permission = permission..";"
        local mac       = permission:match('mac=(%S-);') or ""
        local wan       = permission:match('wan=(%S-);') or ""
        local lan       = permission:match('lan=(%S-);') or ""
        local admin     = permission:match('admin=(%S-);') or ""
        local pridisk   = permission:match('pridisk=(%S-);') or ""

        local item = {}
        if mac then
            item["mac"]     = util.mac(mac)
            item["wan"]     = string.upper(wan) == "YES" and true or false
            item["lan"]     = string.upper(lan) == "YES" and true or false
            item["admin"]   = string.upper(admin) == "YES" and true or false
            item["pridisk"] = string.upper(pridisk) == "YES" and true or false
            local disk_access = disk_access_permission[util.mac(mac)]
            if disk_access ~= nil then
                item.lan = disk_access
            end
            permissions[item.mac] = item
        end
    end
    return permissions
end

function get_device_permissions(mac)
    local json = require("cjson")
    local permissions = {
        ["mac"]     = util.mac(mac),
        ["wan"]     = true,
        ["lan"]     = false,
        ["admin"]   = true,
        ["pridisk"] = false
    }
    local mac = util.mac(mac)
    local data = util.execl("/usr/sbin/sysapi macfilter get")
    local disk_access = false
    local payload = {
        ["api"] = 70,
        ["macs"] = {mac}
    }
    local result = util.thrift_tunnel_to_datacenter(json.encode(payload))
    if result and result.code == 0 then
        disk_access = result.canAccessAllDisk[1]
        for _, permission in ipairs(data) do
            permission = permission..";"
            local smac = permission:match('mac=(%S-);') or ""
            if smac and util.mac(smac) == mac then
                local wan       = permission:match('wan=(%S-);') or ""
                local lan       = permission:match('lan=(%S-);') or ""
                local admin     = permission:match('admin=(%S-);') or ""
                local pridisk   = permission:match('pridisk=(%S-);') or ""
                permissions["mac"]     = util.mac(mac)
                permissions["wan"]     = string.upper(wan) == "YES" and true or false
                permissions["lan"]     = disk_access
                permissions["admin"]   = string.upper(admin) == "YES" and true or false
                permissions["pridisk"] = string.upper(pridisk) == "YES" and true or false
                break
            end
        end
    end
    return permissions
end

function get_device_details(mac, withpermission)
    local details = {
        ["mac"]         = "",
        ["flag"]        = 0,
        ["name"]        = "",
        ["dhcpname"]    = "",
        ["type"]        = {["c"] = 0, ["p"] = 0, ["n"] = ""}
    }
    if util.str_nil(mac) then
        return details
    else
        mac = util.mac(mac)
    end
    local dhcpinfo = get_dhcp_dict("mac")[mac]
    local deviceinfo = get_device_info(mac)
    local name, dhcpname, nickname, company
    if dhcpinfo and dhcpinfo.name then
        dhcpname = dhcpinfo.name
    end
    if deviceinfo then
        details.flag = 1
        if not util.str_nil(deviceinfo.nickname) then
            nickname = deviceinfo.nickname
            name = nickname
        end
        if not util.str_nil(deviceinfo.dhcpname) and util.str_nil(dhcpname) then
            dhcpname = deviceinfo.dhcpname
        end
    end
    local iden = identify_device(mac, dhcpname)
    local device_type = company["type"]
    if not name and device_type.n then
        name = device_type.n
    end
    if not name and dhcpname then
        name = dhcpname
    end
    if not name and company.name then
        name = company.name
    end
    if not name then
        name = mac
    end
    if device_type.c == 3 and not nickname then
        name = device_type.n
    end

    details["mac"]      = mac
    details["name"]     = name
    details["owner"]    = deviceinfo.owner
    details["device"]   = deviceinfo.device
    details["dhcpname"] = dhcpname or ""
    details["type"]     = device_type

    if withpermission then
        local pushutil = require("mi.util.mipush")
        local permissions = get_device_permissions(mac)
        local authority = {}
        authority["wan"]        = permissions["wan"] and 1 or 0
        authority["lan"]        = permissions["lan"] and 1 or 0
        authority["admin"]      = permissions["admin"] and 1 or 0
        authority["pridisk"]    = permissions["pridisk"] and 1 or 0
        local notifydict = pushutil.notify_dict()
        local push = 0
        local mackey = mac:gsub(":", "")
        if notifydict[mackey] then
            push = 1
        end
        local times = pushutil.get_authen_failed_times(mac) or 0
        details["push"] = push
        details["times"] = times
        details["authority"] = authority
    end
    return details
end

-- mode: 0/1/2 有线/无线/有线+无线
-- online: 0/1/2 离线/在线/离线+在线
function get_devices(mode, online)
end