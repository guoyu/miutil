module ("mi.mipreference", package.seeall)

PREF_PRIVACY                = "PRIVACY"
PREF_IS_INITED              = "INITTED"
PREF_IS_PASSPORT_BOUND      = "PASSPORT_BOUND"
PREF_ROUTER_NAME            = "ROUTER_NAME"
PREF_WAN_SPEED_HISTORY      = "WAN_SPEED_HISTORY"
PREF_UPGRADE_INFO           = "UPGRADE_INFO"
PREF_WPS_TIMESTAMP          = "WPS_TIMESTAMP"
PREF_ROUTER_NAME_PENDING    = "ROUTER_NAME_PENDING"
PREF_BOUND_USERINFO         = "BOUND_USER_INFO"
PREF_ROM_FULLSIZE           = "ROM_FULLSIZE"
PREF_PPPOE_NAME             = "PPPOE_NAME"
PREF_PPPOE_PASSWORD         = "PPPOE_PASSWORD"
PREF_ROM_DOWNLOAD_URL       = "ROM_DOWNLOAD_URL"
PREF_ROM_UPLOAD_URL         = "ROM_UPLOAD_URL"
PREF_PAUSED_IDS             = "PAUSED_IDS"
PREF_TIMESTAMP              = "TIMESTAMP"
PREF_ROM_DOWNLOAD_ID        = "ROM_DOWNLOAD_ID"
PREF_ROUTER_LOCATION        = "ROUTER_LOCALE"

function get(key, defaultValue, config) 
    if not config then
        config = "xiaoqiang"
    end
    local cursor = require("luci.model.uci").cursor()
    local value = cursor:get(config, "common", key)
    return value or defaultValue;
end

function set(key, value, config)
    if not config then
        config = "xiaoqiang"
    end
    local cursor = require("luci.model.uci").cursor()
    if value == nil then
        value = ""
    end
    cursor:set(config, "common", key, value)
    cursor:save(config)
    return cursor:commit(config)
end