-- SimpleBlessingBar - localization
-- The language follows the client (GetLocale()); a saved choice overrides it (ns.SetLocale).
-- Missing texts fall back to English (enUS). enGB clients report enUS.
-- string.format in WoW Lua has no positional arguments (%1$s), so every translation keeps the
-- placeholder order of enUS.

local _, ns = ...

local locales = {}

locales.enUS = {
    LOADED = "Version %s loaded.",
}

locales.deDE = {
    LOADED = "Version %s geladen.",
}

locales.frFR = {
    LOADED = "Version %s chargée.",
}

locales.esES = {
    LOADED = "Versión %s cargada.",
}

-- Spanish (Mexico): like esES; holds only what differs
locales.esMX = setmetatable({
}, { __index = locales.esES })

locales.itIT = {
    LOADED = "Versione %s caricata.",
}

locales.ptBR = {
    LOADED = "Versão %s carregada.",
}

locales.ruRU = {
    LOADED = "Версия %s загружена.",
}

locales.koKR = {
    LOADED = "버전 %s 로드됨.",
}

locales.zhCN = {
    LOADED = "版本 %s 已加载。",
}

locales.zhTW = {
    LOADED = "版本 %s 已載入。",
}

local client = GetLocale()
if not locales[client] then client = "enUS" end -- e.g. enGB/enCN -> English
local active, activeCode = locales[client], client

ns.locales = locales
ns.clientLocale = client
ns.LOCALE_ORDER = { "enUS", "deDE", "frFR", "esES", "esMX", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }
-- Language names in their own language; non-Latin scripts carry an English suffix in case the
-- client font cannot display them
ns.LOCALE_NAMES = {
    enUS = "English", deDE = "Deutsch", frFR = "Français",
    esES = "Español (España)", esMX = "Español (México)", itIT = "Italiano",
    ptBR = "Português (Brasil)", ruRU = "Русский (Russian)", koKR = "한국어 (Korean)",
    zhCN = "简体中文 (Chinese S.)", zhTW = "繁體中文 (Chinese T.)",
}

function ns.SetLocale(code)
    if not locales[code] then code = client end
    active, activeCode = locales[code], code
end
function ns.GetLocaleCode() return activeCode end
ns.L = setmetatable({}, {
    __index = function(_, key)
        return active[key] or locales.enUS[key] or key
    end,
})
