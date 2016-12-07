module ("mi.util.mihttp", package.seeall)

local util = require("mi.miutil")
local http = require("socket.http")
local https = require("ssl.https")
local ltn12 = require("luci.ltn12")

function url_encode(str)
    if str then
        str = string.gsub (str, "\r?\n", "\r\n")
        str = string.gsub (str, "([^%w%-%.%_%~ ])",
            function (c)
                return string.format ("%%%02X", string.byte(c))
            end)
        str = string.gsub (str, " ", "+")
    end
    return str
end

function url_encode_params(tbl)
    local enc = ""
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            for i, v2 in ipairs(v) do
                enc = enc .. ( #enc > 0 and "&" or "" ) ..
                    url_encode(k) .. "=" .. url_encode(v2)
            end
        else
            enc = (enc .. ( #enc > 0 and "&" or "" ) ..
                url_encode(k) .. "=" .. url_encode(v))
        end
    end
    return enc
end

function get(url, param_str, cookies)
    local header = {}
    local cookie_str
    local handler
    if cookies and type(cookies) == "table" then
        cookie_str = ""
        for key,value in pairs(cookies) do
            cookie_str = cookie_str..key.."="..value..";path=/;domain=.xiaomi.com;"
        end
        header["Cookie"] = cookie_str
    end
    if url:match("^https://") then
        handler = https
    else
        handler = http
    end

    local result = {
        code = "",
        headers = "",
        status = "",
        res = ""
    }
    local res, code, headers, status
    if util.str_nil(cookie_str) then
        if util.str_nil(param_str) then
            res, code, headers, status = handler.request(url)
        else
            res, code, headers, status = handler.request(url, param_str)
        end
    else
        if not util.str_nil(param_str) then
            local tmp_url = url..param_str
            if tmp_url:match("?") then
                url = tmp_url
            else
                url = url.."?"..param_str
            end
        end
        local t = {}
        res, code, headers, status = handler.request{
            url = url,
            sink = ltn12.sink.table(t),
            headers = header
        }
        res = table.concat(t)
    end
    result.code = code or ""
    result.headers = headers or ""
    result.status = status or ""
    result.res = res or ""
    return result
end

function post(url, param_str, cookies)
    local header = {}
    local cookie_str
    local handler
    if cookies and type(cookies) == "table" then
        cookie_str = ""
        for key,value in pairs(cookies) do
            cookie_str = cookie_str..key.."="..value..";path=/;domain=.xiaomi.com;"
        end
        header["Cookie"] = cookie_str
    end
    header["Content-type"] = "application/x-www-form-urlencoded"
    header["Content-length"] = string.len(param_str)

    if url:match("^https://") then
        handler = https
    else
        handler = http
    end

    local result = {
        code = "",
        headers = "",
        status = "",
        res = ""
    }
    local t = {}
    local res, code, headers, status = handler.request{
        url = url,
        method = "POST",
        source = ltn12.source.string(param_str),
        sink = ltn12.sink.table(t),
        headers = header
    }
    res = table.concat(t)
    result.code = code or ""
    result.headers = headers or ""
    result.status = status or ""
    result.res = res or ""
    return result
end