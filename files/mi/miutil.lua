module ("mi.miutil", package.seeall)

function str_nil(str)
    if str == nil or str == "" then
        return true
    else
        return false
    end
end

-- Serialize the contents of a table value.
function _serialize_table(t)
    local data  = ""
    local idata = ""
    local ilen  = 0
    for k, v in pairs(t) do
        if type(k) ~= "number" or k < 1 or math.floor(k) ~= k or ( k - #t ) > 3 then
            k = _serialize_data(k)
            v = _serialize_data(v)
            data = data .. ( #data > 0 and ", " or "" ) ..
                '[' .. k .. '] = ' .. v
        elseif k > ilen then
            ilen = k
        end
    end
    for i = 1, ilen do
        local v = _serialize_data(t[i])
        idata = idata .. ( #idata > 0 and ", " or "" ) .. v
    end
    return idata .. ( #data > 0 and #idata > 0 and ", " or "" ) .. data
end

function _serialize_data(val)
    if val == nil then
        return "nil"
    elseif type(val) == "number" then
        return val
    elseif type(val) == "string" then
        return "%q" % val
    elseif type(val) == "boolean" then
        return val and "true" or "false"
    elseif type(val) == "function" then
        return "loadstring(%q)" % get_bytecode(val)
    elseif type(val) == "table" then
        return "{ " .. _serialize_table(val) .. " }"
    else
        return '"[unhandled data type:' .. type(val) .. ']"'
    end
end

-- Check weather a table has Recursion, if true, it cant be serialized
function _has_recursion(t)
    if t == nil or type(t) ~= "table" then
        return false
    end
    local seen = {}
    -- add root to seen
    seen[t] = true
    return _has_r(t, seen)
end

function _has_r(t, seen)
    for k, v in pairs(t) do
        if type(k) == "table" then
            if seen[k] then
                -- check is recursion
                local tmp = t
                while true do
                    if tmp == k then
                        return true
                    else 
                        tmp = seen[tmp]
                        if not tmp then
                            break
                        end
                    end
                end
                -- check end
            end
            seen[k] = t
            if _has_r(k, seen) then
                return true
            end
        end
        if type(v) == "table" then
            if seen[v] then
                -- check is recursion
                local tmp = t
                while true do
                    if tmp == v then
                        return true
                    else 
                        tmp = seen[tmp]
                        if not tmp then
                            break
                        end
                    end
                end
                -- check end
            end
            seen[v] = t
            if _has_r(v, seen) then
                return true
            end
        end
    end
    return false
end

function get_bytecode(val)
    local code
    if type(val) == "function" then
        code = string.dump(val)
    else
        code = string.dump(loadstring("return " .. serialize_data(val)))
    end
    return code
end

function serialize_data(val) 
    assert(not _has_recursion(val), "Recursion detected.")
    return _serialize_data(val)
end

function exec(command)
    local pp = io.popen(command)
    local data = pp:read("*a")
    pp:close()
    return data
end

function execi(command)
    local pp = io.popen(command)
    return pp and function()
        local line = pp:read()
        if not line then
            pp:close()
        end
        return line
    end
end

function execl(command)
    local pp   = io.popen(command)
    local line = ""
    local data = {}
    while true do
        line = pp:read()
        if (line == nil) then break end
        data[#data+1] = line
    end
    pp:close()
    return data
end

function split(str, pat, max, regex)
    pat = pat or "\n"
    max = max or #str
    local t = {}
    local c = 1
    if #str == 0 then
        return {""}
    end
    if #pat == 0 then
        return nil
    end
    if max == 0 then
        return str
    end
    repeat
        local s, e = str:find(pat, c, not regex)
        max = max - 1
        if s and max < 0 then
            t[#t+1] = str:sub(c)
        else
            t[#t+1] = str:sub(c, s and s - 1)
        end
        c = e and e + 1 or #str + 1
    until not s or max < 0
    return t
end

function trim(str)
    return (str:gsub("^%s*(.-)%s*$", "%1"))
end

function fork(cmdstr)
    local nixio = require("nixio")
    local pid = nixio.fork()
    if pid > 0 then
        return
    elseif pid == 0 then
        nixio.chdir("/")
        local null = nixio.open("/dev/null", "w+")
        if null then
            nixio.dup(null, nixio.stderr)
            nixio.dup(null, nixio.stdout)
            nixio.dup(null, nixio.stdin)
            if null:fileno() > 2 then
                null:close()
            end
        end
        nixio.exec("/bin/sh", "-c", cmdstr)
    end
end

function mac(mac)
    if mac then
        return string.upper(string.gsub(mac,"-",":"))
    else
        return ""
    end
end

function thrift_tunnel_to_datacenter(payload)
    if not payload then
        return nil
    end
    local json = require("cjson")
    local crypto = require("mi.util.micrypto")
    payload = crypto.base64_enc(payload)
    local result = trim(exec("thrifttunnel 0 '%s'" % payload))
    if not result or result == "" then
        return nil
    else
        return json.decode(result)
    end
end

function _cmd_format(str)
    if str_nil(str) then
        return ""
    else
        return str:gsub("\\", "\\\\"):gsub("`", "\\`"):gsub("\"", "\\\"")
    end
end

function nvram_get(key, default)
    if str_nil(key) then
        return default
    end
    local cmd = string.format("nvram get \"%s\"", _cmd_format(key))
    local value = exec(cmd)
    if value then
        value = trim(value)
    end
    if str_nil(value) then
        return default
    else
        return value
    end
end

function nvram_set(key, value, commit)
    if str_nil(key) then
        return
    end
    local cmd
    if str_nil(value) then
        cmd = string.format("nvram unset \"%s\"", _cmd_format(key))
    else
        cmd = string.format("nvram set \"%s\"=\"%s\"", _cmd_format(key), _cmd_format(value))
    end
    os.execute(cmd)
    if commit then
        os.execute("nvram commit")
    end
end

function nvram_commit()
    os.execute("nvram commit")
end

function hz_format(hertz)
    local suff = {"Hz", "KHz", "MHz", "GHz", "THz"}
    for i=1, 5 do
        if hertz > 1024 and i < 5 then
            hertz = hertz / 1024
        else
            return string.format("%.2f %s", hertz, suff[i])
        end
    end
end

function macaddr(val)
    if val and val:match(
        "^[a-fA-F0-9]+:[a-fA-F0-9]+:[a-fA-F0-9]+:" ..
         "[a-fA-F0-9]+:[a-fA-F0-9]+:[a-fA-F0-9]+$"
    ) then
        local parts = split( val, ":" )
        for i = 1,6 do
            parts[i] = tonumber( parts[i], 16 )
            if parts[i] < 0 or parts[i] > 255 then
                return false
            end
        end
        return true
    end
    return false
end

function wpakey(val)
    if #val == 64 then
        return (val:match("^[a-fA-F0-9]+$") ~= nil)
    else
        return (#val >= 8) and (#val <= 63)
    end
end

function wepkey(val)
    if val:sub(1, 2) == "s:" then
        val = val:sub(3)
    end
    if (#val == 10) or (#val == 26) then
        return (val:match("^[a-fA-F0-9]+$") ~= nil)
    else
        return (#val == 5) or (#val == 13)
    end
end

function lanip(val)
    if str_nil(val) then
        return false
    end
    local ip = require("luci.ip")
    local iptonl = ip.iptonl(val)
    if (iptonl >= ip.iptonl("10.0.0.0") and iptonl <= ip.iptonl("10.255.255.255"))
        or (iptonl >= ip.iptonl("172.16.0.0") and iptonl <= ip.iptonl("172.31.255.255"))
        or (iptonl >= ip.iptonl("192.168.0.0") and iptonl <= ip.iptonl("192.168.255.255")) then
        return true
    else
        return false
    end
end

function wanip(val)
    if str_nil(val) then
        return false
    end
    local ip = require("luci.ip")
    local iptonl = ip.iptonl(val)
    if (iptonl >= ip.iptonl("1.0.0.0") and iptonl <= ip.iptonl("126.0.0.0"))
        or (iptonl >= ip.iptonl("128.0.0.0") and iptonl <= ip.iptonl("223.255.255.255")) then
        return true
    else
        return false
    end
end