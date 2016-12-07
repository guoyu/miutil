module ("mi.util.micrypto", package.seeall)

local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'

function base64_enc(str)
    return ((str:gsub('.', function(x)
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#str%3+1])
end

function base64_enc_file(filepath)
    local util = require("mi.miutil")
    if util.str_nil(filepath) then
        return nil
    end
    local str = util.exec("/usr/bin/base64 "..filepath)
    if util.str_nil(str) then
        return nil
    else
        return str:gsub("\n", "")
    end
end

function base64_dec(str)
    str = string.gsub(str, '[^'..b..'=]', '')
    return (str:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

function md5_str(str)
    local util = require("mi.miutil")
    return util.trim(util.exec("/bin/echo -n '%s'|/usr/bin/md5sum|/usr/bin/cut -d' ' -f1" % str))
end

function md5_file(filepath)
    local util = require("mi.miutil")
    return util.trim(util.exec("/usr/bin/md5sum '%s'|/usr/bin/cut -d' ' -f1" % filepath))
end

function sha256_str(str)
    local util = require("mi.miutil")
    return util.trim(util.exec("/bin/echo -n '%s'|/usr/bin/sha256sum|/usr/bin/cut -d' ' -f1" % str))
end

function md5_base64_str(str)
    return md5_str(base64_enc(str))
end