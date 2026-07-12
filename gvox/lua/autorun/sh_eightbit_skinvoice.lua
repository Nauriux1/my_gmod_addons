-- eightbit_skinvoice shared definitions

if EIGHTBIT_SKINVOICE_SHARED then return end
EIGHTBIT_SKINVOICE_SHARED = true

include("autorun/sh_eightbit_skinvoice_lang.lua")   -- <-- добавить эту строку

EIGHTBIT_SKINVOICE = EIGHTBIT_SKINVOICE or {}

EIGHTBIT_SKINVOICE.PresetList = {
    { id = 0,  name = "Нет эффекта" },
    { id = 1,  name = "Чистильщик" },
    { id = 2,  name = "Десемплинг" },
    { id = 3,  name = "Комбайн" },
    { id = 4,  name = "Дарт Вейдер" },
    { id = 5,  name = "Радио" },
    { id = 6,  name = "Робот" },
    { id = 7,  name = "Пришелец" },
    { id = 8,  name = "Овердрайв" },
    { id = 9,  name = "Дисторшн" },
    { id = 10, name = "Телефон" },
    { id = 11, name = "Мегафон" },
    { id = 12, name = "Бурундук" },
    { id = 13, name = "Замедление" },
    { id = 14, name = "Метрокоп" },
}

-- Маппинг для быстрого доступа (оставляем как есть, используется только на сервере)
EIGHTBIT_SKINVOICE.PresetByName = {}
EIGHTBIT_SKINVOICE.PresetById = {}
for _, p in ipairs(EIGHTBIT_SKINVOICE.PresetList) do
    EIGHTBIT_SKINVOICE.PresetByName[p.name] = p.id
    EIGHTBIT_SKINVOICE.PresetById[p.id] = p.name
end