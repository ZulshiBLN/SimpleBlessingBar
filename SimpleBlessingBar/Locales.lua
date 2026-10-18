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
    HELP_HEADER = "Chat commands:",
    CMD_HELP = "Show this list",
    CMD_LOCK = "Lock or unlock the bar",
    CMD_RESET = "Move the bar back to its start position",
    LOCKED = "Bar locked.",
    UNLOCKED = "Bar unlocked.",
    POS_RESET = "Bar position reset.",
    CMD_UNKNOWN = "Unknown command. Type %s for a list.",
    TAB_GENERAL = "General",
    TAB_TRACKING = "Tracking",
    CMD_OPEN = "Open the settings window",
    MENU_COMBAT = "The settings can't be opened in combat.",
}

locales.deDE = {
    NOT_IN_COMBAT = "Im Kampf nicht möglich.",
    LOADED = "Version %s geladen.",
    HELP_HEADER = "Chat-Befehle:",
    CMD_HELP = "Diese Liste anzeigen",
    CMD_LOCK = "Leiste sperren oder entsperren",
    CMD_RESET = "Leiste an die Startposition zurücksetzen",
    LOCKED = "Leiste gesperrt.",
    UNLOCKED = "Leiste entsperrt.",
    POS_RESET = "Position der Leiste zurückgesetzt.",
    CMD_UNKNOWN = "Unbekannter Befehl. %s zeigt alle Befehle.",
    TAB_GENERAL = "Allgemein",
    TAB_TRACKING = "Überwachung",
    CMD_OPEN = "Einstellungsfenster öffnen",
    MENU_COMBAT = "Das Menü kann im Kampf nicht geöffnet werden.",
}

locales.frFR = {
    NOT_IN_COMBAT = "Impossible en combat.",
    LOADED = "Version %s chargée.",
    HELP_HEADER = "Commandes de discussion :",
    CMD_HELP = "Afficher cette liste",
    CMD_LOCK = "Verrouiller ou déverrouiller la barre",
    CMD_RESET = "Remettre la barre à sa position de départ",
    LOCKED = "Barre verrouillée.",
    UNLOCKED = "Barre déverrouillée.",
    POS_RESET = "Position de la barre réinitialisée.",
    CMD_UNKNOWN = "Commande inconnue. Tapez %s pour la liste.",
    TAB_GENERAL = "Général",
    TAB_TRACKING = "Suivi",
    CMD_OPEN = "Ouvrir la fenêtre d'options",
    MENU_COMBAT = "Les options ne peuvent pas être ouvertes en combat.",
}

locales.esES = {
    NOT_IN_COMBAT = "No es posible en combate.",
    LOADED = "Versión %s cargada.",
    HELP_HEADER = "Comandos de chat:",
    CMD_HELP = "Mostrar esta lista",
    CMD_LOCK = "Bloquear o desbloquear la barra",
    CMD_RESET = "Devolver la barra a su posición inicial",
    LOCKED = "Barra bloqueada.",
    UNLOCKED = "Barra desbloqueada.",
    POS_RESET = "Posición de la barra restablecida.",
    CMD_UNKNOWN = "Comando desconocido. Escribe %s para ver la lista.",
    TAB_GENERAL = "General",
    TAB_TRACKING = "Seguimiento",
    CMD_OPEN = "Abrir la ventana de opciones",
    MENU_COMBAT = "Las opciones no se pueden abrir en combate.",
}

-- Spanish (Mexico): like esES; holds only what differs
locales.esMX = setmetatable({
}, { __index = locales.esES })

locales.itIT = {
    NOT_IN_COMBAT = "Non possibile in combattimento.",
    LOADED = "Versione %s caricata.",
    HELP_HEADER = "Comandi chat:",
    CMD_HELP = "Mostra questo elenco",
    CMD_LOCK = "Blocca o sblocca la barra",
    CMD_RESET = "Riporta la barra alla posizione iniziale",
    LOCKED = "Barra bloccata.",
    UNLOCKED = "Barra sbloccata.",
    POS_RESET = "Posizione della barra ripristinata.",
    CMD_UNKNOWN = "Comando sconosciuto. Digita %s per l'elenco.",
    TAB_GENERAL = "Generale",
    TAB_TRACKING = "Monitoraggio",
    CMD_OPEN = "Apri la finestra delle impostazioni",
    MENU_COMBAT = "Le opzioni non possono essere aperte in combattimento.",
}

locales.ptBR = {
    NOT_IN_COMBAT = "Não é possível em combate.",
    LOADED = "Versão %s carregada.",
    HELP_HEADER = "Comandos de chat:",
    CMD_HELP = "Mostrar esta lista",
    CMD_LOCK = "Travar ou destravar a barra",
    CMD_RESET = "Voltar a barra à posição inicial",
    LOCKED = "Barra travada.",
    UNLOCKED = "Barra destravada.",
    POS_RESET = "Posição da barra redefinida.",
    CMD_UNKNOWN = "Comando desconhecido. Digite %s para ver a lista.",
    TAB_GENERAL = "Geral",
    TAB_TRACKING = "Monitoramento",
    CMD_OPEN = "Abrir a janela de configurações",
    MENU_COMBAT = "As opções não podem ser abertas em combate.",
}

locales.ruRU = {
    NOT_IN_COMBAT = "Невозможно в бою.",
    LOADED = "Версия %s загружена.",
    HELP_HEADER = "Команды чата:",
    CMD_HELP = "Показать этот список",
    CMD_LOCK = "Закрепить или открепить панель",
    CMD_RESET = "Вернуть панель в начальное положение",
    LOCKED = "Панель закреплена.",
    UNLOCKED = "Панель откреплена.",
    POS_RESET = "Положение панели сброшено.",
    CMD_UNKNOWN = "Неизвестная команда. Введите %s для списка.",
    TAB_GENERAL = "Общие",
    TAB_TRACKING = "Отслеживание",
    CMD_OPEN = "Открыть окно настроек",
    MENU_COMBAT = "Настройки нельзя открыть в бою.",
}

locales.koKR = {
    NOT_IN_COMBAT = "전투 중에는 할 수 없습니다.",
    LOADED = "버전 %s 로드됨.",
    HELP_HEADER = "채팅 명령어:",
    CMD_HELP = "이 목록 표시",
    CMD_LOCK = "바 잠금 또는 잠금 해제",
    CMD_RESET = "바를 시작 위치로 되돌리기",
    LOCKED = "바가 잠겼습니다.",
    UNLOCKED = "바 잠금이 해제되었습니다.",
    POS_RESET = "바 위치가 초기화되었습니다.",
    CMD_UNKNOWN = "알 수 없는 명령어입니다. 목록은 %s 를 입력하세요.",
    TAB_GENERAL = "일반",
    TAB_TRACKING = "추적",
    CMD_OPEN = "설정 창 열기",
    MENU_COMBAT = "전투 중에는 설정을 열 수 없습니다.",
}

locales.zhCN = {
    NOT_IN_COMBAT = "战斗中无法进行。",
    LOADED = "版本 %s 已加载。",
    HELP_HEADER = "聊天命令：",
    CMD_HELP = "显示此列表",
    CMD_LOCK = "锁定或解锁动作条",
    CMD_RESET = "将动作条移回初始位置",
    LOCKED = "动作条已锁定。",
    UNLOCKED = "动作条已解锁。",
    POS_RESET = "动作条位置已重置。",
    CMD_UNKNOWN = "未知命令。输入 %s 查看列表。",
    TAB_GENERAL = "常规",
    TAB_TRACKING = "追踪",
    CMD_OPEN = "打开设置窗口",
    MENU_COMBAT = "战斗中无法打开设置。",
}

locales.zhTW = {
    NOT_IN_COMBAT = "戰鬥中無法進行。",
    LOADED = "版本 %s 已載入。",
    HELP_HEADER = "聊天指令：",
    CMD_HELP = "顯示此列表",
    CMD_LOCK = "鎖定或解鎖動作條",
    CMD_RESET = "將動作條移回初始位置",
    LOCKED = "動作條已鎖定。",
    UNLOCKED = "動作條已解鎖。",
    POS_RESET = "動作條位置已重置。",
    CMD_UNKNOWN = "未知指令。輸入 %s 查看列表。",
    TAB_GENERAL = "一般",
    TAB_TRACKING = "追蹤",
    CMD_OPEN = "開啟設定視窗",
    MENU_COMBAT = "戰鬥中無法開啟設定。",
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
