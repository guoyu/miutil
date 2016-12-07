module ("mi.util.minetwork", package.seeall)

local util = require("mi.miutil")

function get_auto_wan_type()
    local util = require("luci.util")
    local result = util.execi("/usr/sbin/wanlinkprobe 1 WAN pppoe dhcp")
    local link,pppoe,dhcp
    if result then
        for line in result do
            if line:match("^LINK=(%S+)") ~= nil then
                link = line:match("^LINK=(%S+)")
            elseif line:match("^PPPOE=(%S+)") ~= nil then
                pppoe = line:match("^PPPOE=(%S+)")
            elseif line:match("^DHCP=(%S+)") ~= nil then
                dhcp = line:match("^DHCP=(%S+)")
            end
        end
    end
    if pppoe == "YES" then
        return 1
    elseif dhcp == "YES" then
        return 2
    elseif link ~= "YES" then
        return 99
    else
        return 0
    end
end

function get_lan_info()
    local network = require("luci.model.network").init()
    local info = {}
    local lan = network:get_network("lan")
    if lan then
        local device = lan:get_interface()
        local ipaddrs = device:ipaddrs()
        local ip6addrs = device:ip6addrs()
        if device and #ipaddrs > 0 then
            local ips = {}
            for _,ip in ipairs(ipaddrs) do
                ips[#ips+1]         = {}
                ips[#ips]["ip"]     = ip:host():string()
                ips[#ips]["mask"]   = ip:mask():string()
            end
            info["ipv4"] = ips
        end
        if device and #ip6addrs > 0 then
            local ips = {}
            for _,ip in ipairs(ip6addrs) do
                ips[#ips+1]         = {}
                ips[#ips]["ip"]     = ip:host():string()
                ips[#ips]["mask"]   = ip:mask():string()
            end
            info["ipv6"] = ips
        end
        info["gateway"] = lan:gwaddr()
        info["dnsaddrs"] = lan:dnsaddrs()
        info["mac"] = device:mac()
        if lan:uptime() > 0 then
            info["uptime"] = lan:uptime()
        else
            info["uptime"] = 0
        end
        local status = lan:status()
        if status == "down" then
            info["status"] = 0
        elseif status == "up" then
            info["status"] = 1
        end
    end
    return info
end

function _ubus_call_wan_status()
    local ubus = require("ubus").connect()
    local status = ubus:call("network.interface.wan", "status", {})
    return status
end

function get_wan_info()
    local network = require("luci.model.network").init()
    local info = {}
    local wan = network:get_network("wan")
    if wan then
        local device = wan:get_interface()
        local ipaddrs = device:ipaddrs()
        local ip6addrs = device:ip6addrs()
        if device and #ipaddrs > 0 then
            local ips = {}
            for _,ip in ipairs(ipaddrs) do
                ips[#ips+1]         = {}
                ips[#ips]["ip"]     = ip:host():string()
                ips[#ips]["mask"]   = ip:mask():string()
            end
            info["ipv4"] = ips
        end
        if device and #ip6addrs > 0 then
            local ips = {}
            for _,ip in ipairs(ip6addrs) do
                ips[#ips+1]         = {}
                ips[#ips]["ip"]     = ip:host():string()
                ips[#ips]["mask"]   = ip:mask():string()
            end
            info["ipv6"] = ips
        end
        info["gateway"] = wan:gwaddr()
        info["dnsaddrs"] = wan:dnsaddrs()
        info["mac"] = device:mac()
        if wan:uptime() > 0 then
            info["uptime"] = wan:uptime()
        else
            info["uptime"] = 0
        end
        local status = _ubus_call_wan_status()
        if not status.up and not status.pending then
            info["status"] = 0
        elseif status.up and not status.pending then
            info["status"] = 1
        elseif not status.up and status.pending then
            info["status"] = 2
        end
        local details = {}
        local proto = wan:proto()
        if proto == "mobile" or proto == "3g" then
            details["wanType"] = "mobile"
        elseif proto == "static" then
            details["wanType"]  = "static"
            details["ipaddr"]   = wan:get_option_value("ipaddr")
            details["netmask"]  = wan:get_option_value("netmask")
            details["gateway"]  = wan:get_option_value("gateway")
        elseif proto == "pppoe" then
            details["wanType"]  = "pppoe"
            details["username"] = wan:get_option_value("username")
            details["password"] = wan:get_option_value("password")
            details["peerdns"]  = wan:get_option_value("peerdns")
            details["service"]  = wan:get_option_value("service")
        elseif proto == "dhcp" then
            details["wanType"]  = "dhcp"
            details["peerdns"]  = wan:get_option_value("peerdns")
        end
        if not util.str_nil(wan:get_option_value("dns")) then
            details["dns"] = util.split(wan:get_option_value("dns")," ")
        end
        details["ifname"] = wan:get_option_value("ifname")
        info["details"] = details
    end
    return info
end

function get_lan_dhcp_info()
    local uci = require("luci.model.uci").cursor()
    local dhcp = {}
    local ignore = uci:get("dhcp", "lan", "ignore")
    local leasetime = uci:get("dhcp", "lan", "leasetime")
    if ignore ~= "1" then
        ignore = "0"
    end
    local leasetimeNum,leasetimeUnit = leasetime:match("^(%d+)([^%d]+)")
    dhcp["lanIp"] = uci:get("dhcp", "lan", "ipaddr")
    dhcp["start"] = uci:get("dhcp", "lan", "start")
    dhcp["limit"] = uci:get("dhcp", "lan", "limit")
    dhcp["leasetime"] = leasetime
    dhcp["leasetimeNum"] = leasetimeNum
    dhcp["leasetimeUnit"] = leasetimeUnit
    dhcp["ignore"] = ignore
    return dhcp
end

function set_wan_light(proto, username, password, service)
    local uci = require("luci.model.uci").cursor()
    local owan = uci:get_all("network", "wan")
    if proto == "pppoe" then
        local wan = {
            ["ifname"] = owan.ifname,
            ["proto"] = proto,
            ["username"] = username,
            ["password"] = password,
            ["service"] = service
        }
        uci:delete("network", "wan")
        uci:section("network", "interface", "wan", wan)
        uci:commit("network")
        -- todo:
    elseif proto == "dhcp" then
        if owan.proto == "pppoe" then
            local wan = {
                ["ifname"] = owan.ifname,
                ["proto"] = "dhcp"
            }
            os.execute("lua /usr/sbin/pppoe.lua down")
            uci:delete("network", "wan")
            uci:section("network", "interface", "wan", wan)
            uci:commit("network")
            -- todo:
        end
    end
    return true
end

function mac_clone(mac)
    local network = require("luci.model.network").init()
    local wan = network:get_network("wan")
    if mac then
        if util.macaddr(mac) then
            local oldmac = wan:get_option_value("macaddr")
            if oldmac ~= mac then
                wan:set("macaddr",mac)
                network:commit("network")
            end
        else
            return false
        end
    else
        local misys = require("mi.util.misystem")
        local default_macs = misys.get_system_info("default_mac")
        local default = default_macs.default_mac.mac
        wan:set("macaddr",default)
        network:commit("network")
    end
    return true
end

function generate_dns(dns1, dns2)
    local dns
    if not util.str_nil(dns1) and not util.str_nil(dns2) then
        dns = {dns1, dns2}
    elseif not util.str_nil(dns1) then
        dns = dns1
    elseif not util.str_nil(dns2) then
        dns = dns2
    end
    return dns
end

function dnsmsq_restart()
    util.fork("/sbin/ifup wan; /etc/init.d/filetunnel restart")
end

function wan_restart()
    util.fork("ubus call network reload; sleep 1; /etc/init.d/dnsmasq restart > /dev/null")
end

function set_wan_pppoe(name, password, dns1, dns2, peerdns, mtu, special, service)
    local uci = require("luci.model.uci").cursor()
    local iface = "wan"
    local ifname = uci:get("network", "wan", "ifname")
    local macaddr = uci:get("network", "wan", "macaddr")
    local oldconf = uci:get_all("network", "wan") or {}

    local wanrestart = false
    local dnsrestart = true
    if name and oldconf.username ~= name
        or password and oldconf.password ~= password
        or mtu and tonumber(oldconf.mtu) ~= tonumber(mtu)
        or special and tonumber(oldconf.special) ~= tonumber(special)
        or service and oldconf.service ~= service then
        wanrestart = true
    end

    if not wanrestart then
        local dnss = {}
        local odnss = {}
        if oldconf.dns and type(oldconf.dns) == "string" then
            odnss = {oldconf.dns}
        elseif oldconf.dns and type(oldconf.dns) == "table" then
            odnss = oldconf.dns
        end
        if not XQFunction.isStrNil(dns1) then
            table.insert(dnss, dns1)
        end
        if not XQFunction.isStrNil(dns2) then
            table.insert(dnss, dns2)
        end
        if #dnss == #odnss then
            if #dnss == 0 then
                dnsrestart = false
            else
                local odnsd = {}
                local match = 0
                for _, dns in ipairs(odnss) do
                    odnsd[dns] = 1
                end
                for _, dns in ipairs(dnss) do
                    if odnsd[dns] == 1 then
                        match = match + 1
                    end
                end
                if match == #dnss then
                    dnsrestart = false
                end
            end
        end
    end

    local mtuvalue
    if mtu then
        mtuvalue = tonumber(mtu)
    else
        mtuvalue = 1480
    end
    if wanrestart or dnsrestart then
        local network = require("luci.model.network").init()
        network:del_network(iface)
        network:add_network(
            iface, {
                proto    ="pppoe",
                ifname   = ifname,
                username = name,
                password = password,
                dns      = generate_dns(dns1,dns2),
                peerdns  = peerdns,
                macaddr  = macaddr,
                service  = service,
                mtu      = mtuvalue,
                special  = special
            }
        )
        network:commit("network")
        os.execute("/usr/sbin/vpn.lua down")
    end
    if dnsrestart then
        dnsmsq_restart()
    end
    if wanrestart then
        wan_restart()
    end
    if not util.str_nil(name) then
        util.nvram_set("nv_pppoe_name", name)
    end
    if not util.str_nil(password) then
        util.nvram_set("nv_pppoe_pwd", password)
    end
    util.nvram_set("nv_wan_type", "pppoe")
    util.nvram_commit()
end

function set_wan_static_ip(ip, mask, gw, dns1, dns2, peerdns)
    local uci = require("luci.model.uci").cursor()
    local iface = "wan"
    local ifname = uci:get("network", "wan", "ifname")
    local macaddr = uci:get("network", "wan", "macaddr")
    local oldconf = uci:get_all("network", "wan") or {}

    local wanrestart = true
    local dnsrestart = true
    if oldconf.ip == ip
        and oldconf.mask == mask
        and oldconf.gw == gw then
        wanrestart = false
    end
    if not wanrestart then
        local dnss = {}
        local odnss = {}
        if oldconf.dns and type(oldconf.dns) == "string" then
            odnss = {oldconf.dns}
        elseif oldconf.dns and type(oldconf.dns) == "table" then
            odnss = oldconf.dns
        end
        if not XQFunction.isStrNil(dns1) then
            table.insert(dnss, dns1)
        end
        if not XQFunction.isStrNil(dns2) then
            table.insert(dnss, dns2)
        end
        if #dnss == #odnss then
            if #dnss == 0 then
                dnsrestart = false
            else
                local odnsd = {}
                local match = 0
                for _, dns in ipairs(odnss) do
                    odnsd[dns] = 1
                end
                for _, dns in ipairs(dnss) do
                    if odnsd[dns] == 1 then
                        match = match + 1
                    end
                end
                if match == #dnss then
                    dnsrestart = false
                end
            end
        end
    else
        dnsrestart = false
    end
    if wanrestart or dnsrestart then
        local network = require("luci.model.network").init()
        network:del_network(iface)
        network:add_network(
            iface, {
                proto    ="static",
                ifname   = ifname,
                ipaddr   = ip,
                netmask  = mask,
                gateway  = gw,
                dns      = generate_dns(dns1,dns2),
                macaddr  = macaddr
            }
        )
        network:commit("network")
    end
    if dnsrestart then
        dnsmsq_restart()
    end
    if wanrestart then
        wan_restart()
    end
    util.nvram_set("nv_wan_type", "static")
    util.nvram_commit()
end

function set_wan_dhcp(dns1, dns2)
    local uci = require("luci.model.uci").cursor()
    local iface = "wan"
    local ifname = uci:get("network", "wan", "ifname")
    local macaddr = uci:get("network", "wan", "macaddr")
    local oldconf = uci:get_all("network", "wan") or {}

    local wanrestart = true
    local dnsrestart = false
    if oldconf.proto == "dhcp" then
        wanrestart = false
    end
    if not wanrestart then
        if dns1 and dns2 then
            dnsrestart = true
        end
    end
    if wanrestart or dnsrestart then
        local network = require("luci.model.network").init()
        network:del_network(iface)
        network:add_network(
            iface, {
                proto    ="dhcp",
                ifname   = ifname,
                dns      = generate_dns(dns1,dns2),
                macaddr  = macaddr
            }
        )
        network:commit("network")
    end
    if dnsrestart then
        dnsmsq_restart()
    end
    if wanrestart then
        wan_restart()
    end
    util.nvram_set("nv_wan_type", "dhcp")
    util.nvram_commit()
end
