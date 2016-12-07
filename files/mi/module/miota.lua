module ("mi.module.miota", package.seeall)

local json = require("cjson")
local util = require("mi.miutil")
local client = require("mi.util.mihttp")
local logger = require("mi.milogger")
local crypto = require("mi.util.micrypto")

local SERVER_CONFIG                 = 0
local SERVER_CONFIG_ONLINE_URL      = "http://api.miwifi.com"
local SERVER_CONFIG_STAGING_URL     = "http://api.staging.miwifi.com"
local SERVER_CONFIG_PREVIEW_URL     = "http://api.preview.miwifi.com"

local DEFAULT_TOKEN                 = "8007236f-a2d6-4847-ac83-c49395ad6d65"
local XIAOQIANG_UPGRADE             = "/rs/grayupgrade"
local XIAOQIANG_RECOVERY_UPGRADE    = "/rs/grayupgrade/recovery"

local XIAOQIANG_SERVER = SERVER_CONFIG_ONLINE_URL
if SERVER_CONFIG == 1 then
    XIAOQIANG_SERVER = SERVER_CONFIG_STAGING_URL
elseif SERVER_CONFIG == 2 then
    XIAOQIANG_SERVER = SERVER_CONFIG_PREVIEW_URL
end

function check_upgrade()
    local system = require("mi.util.misystem")
    local sysinfo = system.get_system_info("miscinfo,version,deviceid")
    local isrecovery = sysinfo.miscinfo.recovery == 1 and true or false
    local params = {}
    if isrecovery then
        local configs = system.get_nvram_configs()
        params = {
            {"deviceID", ""},
            {"rom", configs.rom_ver},
            {"hardware", sysinfo.version.HARDWARE},
            {"cfe", configs.uboot},
            {"linux", configs.linux},
            {"ramfs", configs.ramfs},
            {"sqafs", configs.sqafs},
            {"rootfs", configs.rootfs},
            {"channel", configs.rom_channel},
            {"serialNumber", util.nvram_get("SN", "")}
        }
    else
        params = {
            {"deviceID", sysinfo.deviceid},
            {"rom", sysinfo.version.ROM},
            {"hardware", sysinfo.version.HARDWARE},
            {"cfe", sysinfo.version.UBOOT},
            {"linux", sysinfo.version.LINUX},
            {"ramfs", sysinfo.version.RAMFS},
            {"sqafs", sysinfo.version.SQAFS},
            {"rootfs", sysinfo.version.ROOTFS},
            {"channel", sysinfo.version.CHANNEL},
            {"serialNumber", util.nvram_get("SN", "")}
        }
    end
    local query = {}
    table.foreach(params,
        function(k, v)
            query[v[1]] = v[2]
        end
    )
    local function crypt_url(server, sub_url, params, salt)
        if server == nil or params == nil then
            return nil
        end
        local time = os.date("%Y-%m-%d--%X",os.time())
        table.insert(params, {"time", time})
        table.sort(params, function(a, b) return a[1] < b[1] end)
        local str = ""
        table.foreach(params, function(k, v) str = str..v[1].."="..v[2].."&" end)
        if salt ~= nil and salt ~= "" then
            str = str .. salt
        end
        local md5 = crypto.md5_base64_str(str)
        local token = DEFAULT_TOKEN
        local url = ""
        if string.find(server..sub_url,"?") == nil then
            url = server..sub_url.."?s="..md5.."&time="..time.."&token="..client.url_encode(token)
        else
            url = server..sub_url.."&s="..md5.."&time="..time.."&token="..client.url_encode(token)
        end
        return url
    end
    local query_str = client.url_encode_params(query)
    local sub_url = (isrecovery and XIAOQIANG_RECOVERY_UPGRADE or XIAOQIANG_UPGRADE).."?"..query_str
    local url = crypt_url(XIAOQIANG_SERVER, sub_url, params, DEFAULT_TOKEN)
    local response = client.get(url)
    if response.code ~= 200 then
        return false
    end
    local res_tbl
    local function decode(str)
        res_tbl = json.decode(str)
    end
    if not pcall(decode, response.res) then
        return false
    end
    if not res_tbl then
        return false
    end
    if tonumber(res_tbl["code"]) == 0 then
        local result = {}
        if res_tbl.data and res_tbl.data.link then
            local changelog = util.trim(res_tbl.data.description)
            local weight = tonumber(res_tbl.data.weight)
            result["needUpdate"]    = 1
            result["downloadUrl"]   = res_tbl.data.link
            result["fullHash"]      = res_tbl.data.hash
            result["fileSize"]      = res_tbl.data.size
            result["version"]       = res_tbl.data.toVersion
            result["weight"]        = weight or 1
            result["changelogUrl"]  = res_tbl.data.changelogUrl
            result["changeLog"]     = changelog
        else
            local changelog = ""
            if res_tbl.data and res_tbl.data.description then
                changelog = util.trim(res_tbl.data.description)
            end
            result["needUpdate"]    = 0
            result["version"]       = sysinfo.hardware.ROM
            result["changeLog"]     = changelog
        end
        return result
    else
        return false
    end
end

function _pause_download(ids)
    if util.str_nil(ids) then
        return
    end
    local payload = {
        ["api"] = 505,
        ["idList"] = ids
    }
    util.thrift_tunnel_to_datacenter(json.encode(payload))
end

function _resume_download(ids)
    if util.str_nil(ids) then
        return
    end
    local payload = {
        ["api"] = 506,
        ["idList"] = ids
    }
    util.thrift_tunnel_to_datacenter(json.encode(payload))
end

function _delete_download(ids)
    if util.str_nil(ids) then
        return
    end
    local payload = {
        ["api"] = 507,
        ["idList"] = ids,
        ["deletefile"] = true
    }
    util.thrift_tunnel_to_datacenter(json.encode(payload))
end

function _check_resource(url)
    if util.str_nil(url) then
        return false
    end
    local check = os.execute("wget -t3 -T10 --spider '"..url.."'")
    if check ~= 0 then
        return false
    end
    return true
end

function _wget_download(url)
    if util.str_nil(url) then
        return false
    end
    if not _check_resource(url) then
        logger.log(6, "Wget --spider : Bad url "..url)
        return false
    end
    -- XQPreference.set(PREF_DOWNLOAD_TYPE, 2)
    local fs = require("luci.fs")
    local filepath = "/tmp/rom.bin"
    -- local filesize = XQPreference.get(XQConfigs.PREF_ROM_FULLSIZE, nil)
    -- if filesize then
    --     filesize = tonumber(filesize)
    --     if XQSysUtil.checkDiskSpace(filesize) then
    --         filepath = UDISKFILEPATH
    --     elseif XQSysUtil.checkTmpSpace(filesize) then
    --         filepath = TMPFILEPATH
    --     else
    --         return false
    --     end
    -- else
    --     return false
    -- end
    -- XQPreference.set(PREF_DOWNLOAD_FILE_PATH, filepath)
    if fs.access(filepath) then
        fs.unlink(filepath)
    end
    local download = "wget -t3 -T30 '"..url.."' -O "..filepath
    os.execute(download)
    return crypto.md5_file(filepath), filepath
end

-- priority:1 will pause other downloads
function _xunlei_download(url, priority)
    logger.log(4, "Xunlei download: start "..url)
    local priority = priority or 1
    local payload = {
        ["api"]         = 504,
        ["url"]         = url,
        ["type"]        = 1,
        ["redownload"]  = 0,
        ["hidden"]      = true,
        ["path"]        = "/userdisk/download/",
        ["dupId"]       = ""
    }
    local ids = {}
    local clist = {}
    if priority == 1 then
        local dolist = util.thrift_tunnel_to_datacenter([[{"api":503,"hidden":true}]])
        if dolist and dolist.code == 0 then
            table.foreach(dolist.uncompletedList,
                function(i,v)
                    if v.downloadStatus == 1 or v.downloadStatus == 32 then
                        table.insert(ids, v.id)
                    end
                end
            )
            clist = dolist.completedList
        else
            logger.log(4, "Xunlei download: check downloading ... api 503 failed")
            return false
        end
    end
    ids = table.concat(ids, ";")
    logger.log(4, "Xunlei download: pause download "..ids)
    _pause_download(ids)

    local download = util.thrift_tunnel_to_datacenter(json.encode(payload))
    if not download then
        logger.log(4, "Xunlei download: create download failed")
        return false
    end
    if download and download.code ~= 2010 and download.code ~= 0 then
        logger.log(4, "Xunlei download: internal error", download)
        return false
    end
    if download.code == 2010 then
        local fs = require("luci.fs")
        local local_filename
        for _, item in ipairs(clist) do
            if item.id == download.info.id then
                local_filename = item.localFileName
            end
        end
        if not util.str_nil(local_filename) and fs.access(local_filename) then
            download.code = 0
            logger.log(4, "Xunlei download: file exist (predownload hit)")
        else
            logger.log(4, "Xunlei download: retry !!!")
            payload.dupId = download.info.id
            payload.redownload = 1
            download = util.thrift_tunnel_to_datacenter(json.encode(payload))
        end
    end
    local download_id
    if not download then
        return false
    end
    if download and download.code ~= 0 then
        return false
    else
        download_id = download.info.id
    end
    local nodata = 0
    local nomatch = 0
    local lastsize = 0
    while true do
        local match = 0
        os.execute("sleep 3")
        local dlist = util.thrift_tunnel_to_datacenter([[{"api":503,"hidden":true}]])
        if dlist and dlist.code == 0 then
            local completedList = dlist.completedList
            local uncompletedList = dlist.uncompletedList
            table.foreach(uncompletedList, function(i,v) table.insert(completedList, v) end)
            for _,item in ipairs(completedList) do
                if (download_id and item.id == download_id) or (not download_id and item.address == downloadUrl) then
                    match = 1
                    if not download_id then
                        download_id = item.id
                    end
                    if lastsize == item.fileDownloadedSize then
                        nodata = nodata + 1
                    else
                        lastsize = item.fileDownloadedSize
                        nodata = 0
                    end
                    if item.datacenterErrorCode ~= 0 then
                        _resume_download(ids)
                        _delete_download(download_id)
                        logger.log(4, "Xunlei download: datacenter error !!!"..item.datacenterErrorCode)
                        return false
                    elseif item.downloadStatus == 4 then
                        _resume_download(ids)
                        logger.log(4, "Xunlei download: succeed !!!")
                        return crypto.md5_file(item.localFileName), item.localFileName
                    elseif item.downloadStatus == 16 then
                        _resume_download(ids)
                        _delete_download(download_id)
                        logger.log(4, "Xunlei download: download failed !!!"..item.downloadStatus)
                        return false
                    elseif nodata > 60 then
                        _resume_download(ids)
                        _delete_download(download_id)
                        logger.log(4, "Xunlei download: timeout !!!")
                        return false
                    end
                end
            end
        end
        if match == 0 then
            nomatch = nomatch + 1
        end
        if nomatch > 60 then
            _resume_download(ids)
            _delete_download(download_id)
            logger.log(4, "Xunlei download: error !!!")
            return false
        end
    end
end

-- smart:0/1/2  both/xunlei/wget
function download(url, smart, priority)
    if util.str_nil(url) then
        return false
    end
    local hash, filepath
    if not smart or smart == 0 or smart == 1 then
        logger.log(6, "Download start..."..url)
        local hash, filepath = _xunlei_download(url, priority)
        if hash and filepath then
            return hash, filepath
        end
    end
    if not smart or smart == 0 or smart == 2 then
        logger.log(4, "Wget download: start !!!")
        hash, filepath = _wget_download(url)
        if hash and filepath then
            logger.log(4, "Wget download: succeed !!!")
            return hash, filepath
        else
            logger.log(4, "Wget download: failed !!!")
        end
    end
    return false
end
