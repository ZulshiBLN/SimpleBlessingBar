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
    AURA_DEVOTION = "Devotion Aura",
    AURA_RETRIBUTION = "Retribution Aura",
    AURA_CONCENTRATION = "Concentration Aura",
    AURA_SHADOW = "Shadow Resistance Aura",
    AURA_FROST = "Frost Resistance Aura",
    AURA_FIRE = "Fire Resistance Aura",
    AURA_SANCTITY = "Sanctity Aura",
    MENU_AURA = "Aura",
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
    AURA_DEVOTION = "Aura der Hingabe",
    AURA_RETRIBUTION = "Aura der Vergeltung",
    AURA_CONCENTRATION = "Aura der Konzentration",
    AURA_SHADOW = "Aura des Schattenwiderstands",
    AURA_FROST = "Aura des Frostwiderstands",
    AURA_FIRE = "Aura des Feuerwiderstands",
    AURA_SANCTITY = "Aura der Heiligkeit",
    MENU_AURA = "Aura",
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
    AURA_DEVOTION = "Aura de dévotion",
    AURA_RETRIBUTION = "Aura de vindicte",
    AURA_CONCENTRATION = "Aura de concentration",
    AURA_SHADOW = "Aura de résistance à l'Ombre",
    AURA_FROST = "Aura de résistance au Givre",
    AURA_FIRE = "Aura de résistance au Feu",
    AURA_SANCTITY = "Aura de sainteté",
    MENU_AURA = "Aura",
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
    AURA_DEVOTION = "Aura de devoción",
    AURA_RETRIBUTION = "Aura de castigo",
    AURA_CONCENTRATION = "Aura de concentración",
    AURA_SHADOW = "Aura de resistencia a las Sombras",
    AURA_FROST = "Aura de resistencia a la Escarcha",
    AURA_FIRE = "Aura de Resistencia al Fuego",
    AURA_SANCTITY = "Aura de santidad",
    MENU_AURA = "Aura",
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
    AURA_DEVOTION = "Aura della Devozione",
    AURA_RETRIBUTION = "Aura del Castigo",
    AURA_CONCENTRATION = "Aura di Concentrazione",
    AURA_SHADOW = "Aura di Resistenza all'Ombra",
    AURA_FROST = "Aura di Resistenza al Gelo",
    AURA_FIRE = "Aura di Resistenza al Fuoco",
    AURA_SANCTITY = "Aura di Santità",
    MENU_AURA = "Aura",
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
    AURA_DEVOTION = "Aura de Devoção",
    AURA_RETRIBUTION = "Aura da Retribuição",
    AURA_CONCENTRATION = "Aura de Concentração",
    AURA_SHADOW = "Aura de Resistência à Sombra",
    AURA_FROST = "Aura de Resistência ao Gelo",
    AURA_FIRE = "Aura de Resistência ao Fogo",
    AURA_SANCTITY = "Aura de Santidade",
    MENU_AURA = "Aura",
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
    AURA_DEVOTION = "Аура благочестия",
    AURA_RETRIBUTION = "Аура воздаяния",
    AURA_CONCENTRATION = "Аура сосредоточенности",
    AURA_SHADOW = "Аура сопротивления темной магии",
    AURA_FROST = "Аура сопротивления магии льда",
    AURA_FIRE = "Аура сопротивления огню",
    AURA_SANCTITY = "Аура святости",
    MENU_AURA = "Аура",
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
    AURA_DEVOTION = "기원의 오라",
    AURA_RETRIBUTION = "응보의 오라",
    AURA_CONCENTRATION = "집중의 오라",
    AURA_SHADOW = "암흑 저항의 오라",
    AURA_FROST = "냉기 저항의 오라",
    AURA_FIRE = "화염 저항의 오라",
    AURA_SANCTITY = "고결의 오라",
    MENU_AURA = "오라",
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
    AURA_DEVOTION = "虔诚光环",
    AURA_RETRIBUTION = "惩罚光环",
    AURA_CONCENTRATION = "专注光环",
    AURA_SHADOW = "暗影抗性光环",
    AURA_FROST = "冰霜抗性光环",
    AURA_FIRE = "火焰抗性光环",
    AURA_SANCTITY = "圣洁光环",
    MENU_AURA = "光环",
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
    AURA_DEVOTION = "虔誠光環",
    AURA_RETRIBUTION = "懲戒光環",
    AURA_CONCENTRATION = "專注光環",
    AURA_SHADOW = "暗影抗性光環",
    AURA_FROST = "冰霜抗性光環",
    AURA_FIRE = "火焰抗性光環",
    AURA_SANCTITY = "聖潔光環",
    MENU_AURA = "光環",
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
