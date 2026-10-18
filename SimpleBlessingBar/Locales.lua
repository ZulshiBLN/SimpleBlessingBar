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
    MENU_ASSIGN = "Blessing for this class",
    BLESSING_MIGHT = "Blessing of Might",
    BLESSING_WISDOM = "Blessing of Wisdom",
    BLESSING_KINGS = "Blessing of Kings",
    BLESSING_SALVATION = "Blessing of Salvation",
    BLESSING_LIGHT = "Blessing of Light",
}

locales.deDE = {
    NOT_IN_COMBAT = "Im Kampf nicht möglich.",
    LOADED = "Version %s geladen.",
    MENU_ASSIGN = "Segen für diese Klasse",
    BLESSING_MIGHT = "Segen der Macht",
    BLESSING_WISDOM = "Segen der Weisheit",
    BLESSING_KINGS = "Segen der Könige",
    BLESSING_SALVATION = "Segen der Rettung",
    BLESSING_LIGHT = "Segen des Lichts",
}

locales.frFR = {
    NOT_IN_COMBAT = "Impossible en combat.",
    LOADED = "Version %s chargée.",
    MENU_ASSIGN = "Bénédiction pour cette classe",
    BLESSING_MIGHT = "Bénédiction de puissance",
    BLESSING_WISDOM = "Bénédiction de sagesse",
    BLESSING_KINGS = "Bénédiction des rois",
    BLESSING_SALVATION = "Bénédiction de salut",
    BLESSING_LIGHT = "Bénédiction de lumière",
}

locales.esES = {
    NOT_IN_COMBAT = "No es posible en combate.",
    LOADED = "Versión %s cargada.",
    MENU_ASSIGN = "Bendición para esta clase",
    BLESSING_MIGHT = "Bendición del poderío",
    BLESSING_WISDOM = "Bendición de Sabiduría",
    BLESSING_KINGS = "Bendición de los Reyes",
    BLESSING_SALVATION = "Bendición de Salvación",
    BLESSING_LIGHT = "Bendición de la luz",
}

-- Spanish (Mexico): like esES; holds only what differs
locales.esMX = setmetatable({
}, { __index = locales.esES })

locales.itIT = {
    NOT_IN_COMBAT = "Non possibile in combattimento.",
    LOADED = "Versione %s caricata.",
    BLESSING_MIGHT = "Benedizione della Potenza",
    BLESSING_WISDOM = "Benedizione della Saggezza",
    BLESSING_KINGS = "Benedizione dei Re",
    BLESSING_SALVATION = "Benedizione della Salvezza",
    BLESSING_LIGHT = "Benedizione della Luce",
    MENU_ASSIGN = "Benedizione per questa classe",
}

locales.ptBR = {
    NOT_IN_COMBAT = "Não é possível em combate.",
    LOADED = "Versão %s carregada.",
    MENU_ASSIGN = "Bênção para esta classe",
    BLESSING_MIGHT = "Bênção do Poder",
    BLESSING_WISDOM = "Bênção de Sabedoria",
    BLESSING_KINGS = "Bênção dos Reis",
    BLESSING_SALVATION = "Bênção da Salvação",
    BLESSING_LIGHT = "Bênção de Luz",
}

locales.ruRU = {
    NOT_IN_COMBAT = "Невозможно в бою.",
    LOADED = "Версия %s загружена.",
    MENU_ASSIGN = "Благословение для этого класса",
    BLESSING_MIGHT = "Благословение могущества",
    BLESSING_WISDOM = "Благословение мудрости",
    BLESSING_KINGS = "Благословение королей",
    BLESSING_SALVATION = "Благословение спасения",
    BLESSING_LIGHT = "Благословение Света",
}

locales.koKR = {
    NOT_IN_COMBAT = "전투 중에는 할 수 없습니다.",
    LOADED = "버전 %s 로드됨.",
    MENU_ASSIGN = "이 직업의 축복",
    BLESSING_MIGHT = "힘의 축복",
    BLESSING_WISDOM = "지혜의 축복",
    BLESSING_KINGS = "왕의 축복",
    BLESSING_SALVATION = "구원의 축복",
    BLESSING_LIGHT = "빛의 축복",
}

locales.zhCN = {
    NOT_IN_COMBAT = "战斗中无法进行。",
    LOADED = "版本 %s 已加载。",
    MENU_ASSIGN = "该职业的祝福",
    BLESSING_MIGHT = "力量祝福",
    BLESSING_WISDOM = "智慧祝福",
    BLESSING_KINGS = "王者祝福",
    BLESSING_SALVATION = "拯救祝福",
    BLESSING_LIGHT = "光明祝福",
}

locales.zhTW = {
    NOT_IN_COMBAT = "戰鬥中無法進行。",
    LOADED = "版本 %s 已載入。",
    MENU_ASSIGN = "該職業的祝福",
    BLESSING_MIGHT = "力量祝福",
    BLESSING_WISDOM = "智慧祝福",
    BLESSING_KINGS = "王者祝福",
    BLESSING_SALVATION = "拯救祝福",
    BLESSING_LIGHT = "光明祝福",
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
