-- SimpleBlessingBar - localization
-- The language follows the client (GetLocale()); a saved choice overrides it (ns.SetLocale).
-- Missing texts fall back to English (enUS). enGB clients report enUS.
-- string.format in WoW Lua has no positional arguments (%1$s), so every translation keeps the
-- placeholder order of enUS.

local _, ns = ...

local locales = {}

locales.enUS = {
    NOT_IN_COMBAT = "Not possible in combat.",
    LOADED = "Version %s loaded.",
}

locales.deDE = {
    NOT_IN_COMBAT = "Im Kampf nicht möglich.",
    LOADED = "Version %s geladen.",
}

locales.frFR = {
    NOT_IN_COMBAT = "Impossible en combat.",
    LOADED = "Version %s chargée.",
}

locales.esES = {
    NOT_IN_COMBAT = "No es posible en combate.",
    LOADED = "Versión %s cargada.",
}

-- Spanish (Mexico): like esES; holds only what differs
locales.esMX = setmetatable({
}, { __index = locales.esES })

locales.itIT = {
    NOT_IN_COMBAT = "Non possibile in combattimento.",
    LOADED = "Versione %s caricata.",
}

locales.ptBR = {
    NOT_IN_COMBAT = "Não é possível em combate.",
    LOADED = "Versão %s carregada.",
}

locales.ruRU = {
    NOT_IN_COMBAT = "Невозможно в бою.",
    LOADED = "Версия %s загружена.",
}

locales.koKR = {
    NOT_IN_COMBAT = "전투 중에는 할 수 없습니다.",
    LOADED = "버전 %s 로드됨.",
}

locales.zhCN = {
    NOT_IN_COMBAT = "战斗中无法进行。",
    LOADED = "版本 %s 已加载。",
}

locales.zhTW = {
    NOT_IN_COMBAT = "戰鬥中無法進行。",
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
