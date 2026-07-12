-- eightbit_skinvoice language definitions
if EIGHTBIT_SKINVOICE_LANG then return end
EIGHTBIT_SKINVOICE_LANG = true

EIGHTBIT_SKINVOICE = EIGHTBIT_SKINVOICE or {}

-- Доступные языки и их отображаемые названия
EIGHTBIT_SKINVOICE.AvailableLangs = {
    ["en"] = "English",
    ["ru"] = "Русский",
    ["es"] = "Español",
    ["fr"] = "Français",
}

-- Таблица переводов
EIGHTBIT_SKINVOICE.LANG = {
    ["en"] = {
        -- Menu titles
        menu_title          = "gVOX - Voice settings by model",
        menu_util_label     = "Voice by model settings",
        -- Labels
        model_label         = "Model (path):",
        preset_label        = "Preset:",
        -- Buttons
        add_button          = "Add/Update",
        remove_button       = "Delete selected",
        refresh_button      = "Refresh list",
        -- Messages
        msg_admin_only      = "[gVOX] Only superadmin can open this menu.",
        msg_enter_model     = "[gVOX] Enter model.",
        msg_select_preset   = "[gVOX] Select preset.",
        msg_select_rule     = "[gVOX] Select rule to delete.",
        msg_language_changed= "[gVOX] Language changed. Please reopen the menu if needed.",
        -- Preset names (by id)
        presets = {
            [0]  = "No effect",
            [1]  = "Cleaner",
            [2]  = "Walkie-talkie",
            [3]  = "Combine",
            [4]  = "Darth Vader",
            [5]  = "Robot",
            [6]  = "Demon",
            [7]  = "Alien",
            [8]  = "Overdrive",
            [9]  = "Distortion",
            [10] = "Telephone",
            [11] = "Megaphone",
            [12] = "Chipmunk",
            [13] = "Slowdown",
            [14] = "Metrocop",
        },
        -- Language selector
        language_label      = "Language:",
    },
    ["ru"] = {
        menu_title          = "gVOX - Настройка голоса по моделям",
        menu_util_label     = "Настройка голоса по моделям",
        model_label         = "Модель (путь):",
        preset_label        = "Пресет:",
        add_button          = "Добавить/Обновить",
        remove_button       = "Удалить выбранное",
        refresh_button      = "Обновить список",
        msg_admin_only      = "[gVOX] Только суперадмин может открыть это меню.",
        msg_enter_model     = "[gVOX] Введите модель.",
        msg_select_preset   = "[gVOX] Выберите пресет.",
        msg_select_rule     = "[gVOX] Выберите правило для удаления.",
        msg_language_changed= "[gVOX] Язык изменён. При необходимости переоткройте меню.",
        presets = {
            [0]  = "Нет эффекта",
            [1]  = "Чистильщик",
            [2]  = "Рация",
            [3]  = "Комбайн",
            [4]  = "Дарт Вейдер",
            [5]  = "Робот",
            [6]  = "Демон",
            [7]  = "Пришелец",
            [8]  = "Овердрайв",
            [9]  = "Дисторшн",
            [10] = "Телефон",
            [11] = "Мегафон",
            [12] = "Бурундук",
            [13] = "Замедление",
            [14] = "Метрокоп",
        },
        language_label      = "Язык:",
    },
    ["es"] = {
        menu_title          = "gVOX - Ajustes de voz por modelo",
        menu_util_label     = "Ajustes de voz por modelo",
        model_label         = "Modelo (ruta):",
        preset_label        = "Preajuste:",
        add_button          = "Añadir/Actualizar",
        remove_button       = "Eliminar seleccionado",
        refresh_button      = "Actualizar lista",
        msg_admin_only      = "[gVOX] Solo superadmin puede abrir este menú.",
        msg_enter_model     = "[gVOX] Introduzca modelo.",
        msg_select_preset   = "[gVOX] Seleccione preajuste.",
        msg_select_rule     = "[gVOX] Seleccione regla para eliminar.",
        msg_language_changed= "[gVOX] Idioma cambiado. Vuelva a abrir el menú si es necesario.",
        presets = {
            [0]  = "Sin efecto",
            [1]  = "Limpiador",
            [2]  = "Walkie-talkie",
            [3]  = "Combine",
            [4]  = "Darth Vader",
            [5]  = "Robot",
            [6]  = "Demon",
            [7]  = "Alien",
            [8]  = "Overdrive",
            [9]  = "Distorsión",
            [10] = "Teléfono",
            [11] = "Megáfono",
            [12] = "Chipmunk",
            [13] = "Cámara lenta",
            [14] = "Metrocop",
        },
        language_label      = "Idioma:",
    },
    ["fr"] = {
        menu_title          = "gVOX - Paramètres vocaux par modèle",
        menu_util_label     = "Paramètres vocaux par modèle",
        model_label         = "Modèle (chemin):",
        preset_label        = "Préréglage:",
        add_button          = "Ajouter/Mettre à jour",
        remove_button       = "Supprimer la sélection",
        refresh_button      = "Actualiser la liste",
        msg_admin_only      = "[gVOX] Seul superadmin peut ouvrir ce menu.",
        msg_enter_model     = "[gVOX] Entrez le modèle.",
        msg_select_preset   = "[gVOX] Sélectionnez préréglage.",
        msg_select_rule     = "[gVOX] Sélectionnez règle à supprimer.",
        msg_language_changed= "[gVOX] Langue modifiée. Rouvrez le menu si nécessaire.",
        presets = {
            [0]  = "Aucun effet",
            [1]  = "Nettoyeur",
            [2]  = "Talkie-walkie",
            [3]  = "Combine",
            [4]  = "Dark Vador",
            [5]  = "Robot",
            [6]  = "Demon",
            [7]  = "Alien",
            [8]  = "Overdrive",
            [9]  = "Distorsion",
            [10] = "Téléphone",
            [11] = "Mégaphone",
            [12] = "Chipmunk",
            [13] = "Ralentissement",
            [14] = "Metrocop",
        },
        language_label      = "Langue:",
    },
}

-- Вспомогательная функция для получения перевода по ключу
function EIGHTBIT_SKINVOICE.GetText(key, lang)
    lang = lang or (CLIENT and GetConVarString("gvox_language") or "en")
    local tbl = EIGHTBIT_SKINVOICE.LANG[lang]
    if tbl and tbl[key] then
        return tbl[key]
    end
    -- fallback to English
    tbl = EIGHTBIT_SKINVOICE.LANG["en"]
    if tbl and tbl[key] then
        return tbl[key]
    end
    return key
end

-- Получение локализованного названия пресета по ID
function EIGHTBIT_SKINVOICE.GetPresetName(id, lang)
    lang = lang or (CLIENT and GetConVarString("gvox_language") or "en")
    local tbl = EIGHTBIT_SKINVOICE.LANG[lang]
    if tbl and tbl.presets and tbl.presets[id] then
        return tbl.presets[id]
    end
    -- fallback to English
    tbl = EIGHTBIT_SKINVOICE.LANG["en"]
    if tbl and tbl.presets and tbl.presets[id] then
        return tbl.presets[id]
    end
    return "Unknown ("..id..")"
end
