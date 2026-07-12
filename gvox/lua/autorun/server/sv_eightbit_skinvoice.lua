include("autorun/sh_eightbit_skinvoice.lua")

-- Проверка загрузки модуля
local ok, mod_or_err = pcall(require, "eightbit")
if not eightbit then
    eightbit = {}
    eightbit.EFF_NONE = 0
    function eightbit.EnableEffect(userid, ...) end
end

-- Проверка наличия модуля eightbit
local eightbit = eightbit
if not eightbit then
    MsgC(Color(255,0,0), "[gVOX] eightbit module not loaded! Voice effects will not work.\n")
else
    MsgC(Color(0,255,0), "[gVOX] eightbit module loaded.\n")
end

if not ok then
    MsgC(Color(255,0,0), "[gVOX] require('eightbit') failed: ", tostring(mod_or_err), "\n")
else
    MsgC(Color(0,255,0), "[gVOX] require('eightbit') succeeded\n")
    if not eightbit then eightbit = mod_or_err end
    -- Отладочный вывод всех экспортированных констант EFF_
    if type(mod_or_err) == "table" then
        for k,v in pairs(mod_or_err) do
            if type(v) == "number" and k:match("^EFF_") then
                MsgC(Color(200,200,0), string.format("[eightbit] %s = %d\n", k, v))
            end
        end
    end
end

local EFF_NONE = eightbit and eightbit.EFF_NONE or 0

-- Храним текущий применённый пресет для каждого игрока
local plyCurrentPreset = {}
local NW_GVOX_EFFECT = "gvox_effect_id"
local NW_GVOX_LOCK = "gvox_effect_lock"

-- Инициализация базы данных
local function InitDatabase()
    local q = sql.Query("SELECT name FROM sqlite_master WHERE type='table' AND name='eightbit_skinvoice'")
    if not q then
        sql.Query([[CREATE TABLE eightbit_skinvoice (
            model TEXT PRIMARY KEY,
            preset_id INTEGER NOT NULL
        );]])
        MsgC(Color(0,255,0), "[gVOX] Table eightbit_skinvoice created.\n")

        -- Дефолтные записи (combine → ID 3, police → ID 14)
        local defaults = {
            "models/player/combine_soldier.mdl", 3,
            "models/player/combine_soldier_prisonguard.mdl", 3,
            "models/player/combine_super_soldier.mdl", 3,
            "models/combine_super_soldier.mdl", 3,
            "models/combine_soldier_prisonguard.mdl", 3,
            "models/combine_soldier.mdl", 3,
            "models/player/police.mdl", 14,
            "models/player/police_fem.mdl", 14,
            "models/police.mdl", 14,
            "models/player/jcms/jcorp_engineer.mdl", 14,
			"models/player/jcms/jcorp_infantry.mdl", 14,
			"models/player/jcms/jcorp_sentinel.mdl", 14,
			"models/player/jcms/jcorp_recon.mdl", 14,
			"models/player/jcms/mafia_engineer.mdl", 14,
			"models/player/jcms/mafia_infantry.mdl", 14,
			"models/player/jcms/mafia_recon.mdl", 14,
			"models/player/jcms/mafia_sentinel.mdl", 14,
        }
        for i = 1, #defaults, 2 do
            sql.Query("INSERT OR IGNORE INTO eightbit_skinvoice (model, preset_id) VALUES (" ..
                sql.SQLStr(defaults[i]) .. ", " .. defaults[i+1] .. ")")
        end
        MsgC(Color(0,255,0), "[gVOX] Default entries added.\n")
    end
end

local function NormalizeModel(model)
    model = tostring(model or "")
    model = string.Trim(model)
    model = string.lower(model)
    model = string.Replace(model, "\\", "/")
    return model
end

-- Получить preset_id для модели из БД
local function GetPresetForModel(model)
    model = NormalizeModel(model)
    local result = sql.Query("SELECT preset_id FROM eightbit_skinvoice WHERE model = " .. sql.SQLStr(model))
    if result and #result > 0 then
        return tonumber(result[1].preset_id)
    end
    return EFF_NONE
end

-- Применить эффект, если текущий пресет отличается от требуемого
local function ApplyPresetIfNeeded(ply)
    if not IsValid(ply) then return end
    if not eightbit or not eightbit.EnableEffect then return end

    local userid = ply:UserID()
    local model = ply:GetModel()
    local targetPreset = GetPresetForModel(model)
    local currentPreset = plyCurrentPreset[userid] or EFF_NONE

    -- Запоминаем, какой эффект должен быть у игрока
    ply:SetNWInt(NW_GVOX_EFFECT, targetPreset)

    -- Если эффекта нет — сбрасываем как раньше
    if targetPreset == EFF_NONE then
        if currentPreset ~= EFF_NONE then
            eightbit.EnableEffect(userid, EFF_NONE)
            plyCurrentPreset[userid] = EFF_NONE
        end
        return
    end

    -- Если радио временно удерживает эффект — gVOX не вмешивается
    plyCurrentPreset[userid] = targetPreset
    if ply:GetNWBool(NW_GVOX_LOCK, false) then return end

    -- Обычное применение gVOX
    eightbit.EnableEffect(userid, targetPreset)
end

-- Таймер проверки всех игроков (раз в секунду)
timer.Create("eightbit_skinvoice_check", 0.25, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        ApplyPresetIfNeeded(ply)
    end
end)

-- При первом появлении игрока
hook.Add("PlayerInitialSpawn", "eightbit_skinvoice_init", function(ply)
    timer.Simple(0.5, function() ApplyPresetIfNeeded(ply) end)
end)

-- Очистка при выходе
hook.Add("PlayerDisconnected", "eightbit_skinvoice_cleanup", function(ply)
    local userid = ply:UserID()
    plyCurrentPreset[userid] = nil
    ply:SetNWInt(NW_GVOX_EFFECT, EFF_NONE)
    ply:SetNWBool(NW_GVOX_LOCK, false)

    if eightbit and eightbit.EnableEffect then
        eightbit.EnableEffect(userid, EFF_NONE)
    end
end)

-- Сетевые сообщения (без изменений)
util.AddNetworkString("eightbit_skinvoice_request_rules")
util.AddNetworkString("eightbit_skinvoice_send_rules")
util.AddNetworkString("eightbit_skinvoice_add_rule")
util.AddNetworkString("eightbit_skinvoice_remove_rule")

-- Отправка всех правил клиенту
local function SendRules(ply)
    local rules = sql.Query("SELECT model, preset_id FROM eightbit_skinvoice ORDER BY model") or {}
    net.Start("eightbit_skinvoice_send_rules")
    net.WriteUInt(#rules, 16)
    for _, row in ipairs(rules) do
        net.WriteString(row.model)
        net.WriteUInt(tonumber(row.preset_id), 8)
    end
    net.Send(ply)
end

net.Receive("eightbit_skinvoice_request_rules", function(len, ply)
    if not ply:IsSuperAdmin() then return end
    SendRules(ply)
end)

net.Receive("eightbit_skinvoice_add_rule", function(len, ply)
    if not ply:IsSuperAdmin() then return end
    local model = NormalizeModel(net.ReadString())
    local preset_id = net.ReadUInt(8)
    if model == "" then return end

    sql.Query("INSERT OR REPLACE INTO eightbit_skinvoice (model, preset_id) VALUES (" ..
        sql.SQLStr(model) .. ", " .. preset_id .. ")")

    -- Обновить эффект у игроков с этой моделью
    for _, p in ipairs(player.GetAll()) do
        if p:GetModel() == model then
            ApplyPresetIfNeeded(p)
        end
    end

    SendRules(ply)
end)

net.Receive("eightbit_skinvoice_remove_rule", function(len, ply)
    if not ply:IsSuperAdmin() then return end
    local model = NormalizeModel(net.ReadString())
    if model == "" then return end

    sql.Query("DELETE FROM eightbit_skinvoice WHERE model = " .. sql.SQLStr(model))

    -- Сбросить эффект у игроков с этой моделью
    for _, p in ipairs(player.GetAll()) do
		if p:GetModel() == model then
			p:SetNWBool(NW_GVOX_LOCK, false)
			eightbit.EnableEffect(p:UserID(), EFF_NONE)
			plyCurrentPreset[p:UserID()] = EFF_NONE
			p:SetNWInt(NW_GVOX_EFFECT, EFF_NONE)
		end
    end

    SendRules(ply)
end)

-- Инициализация БД при старте сервера
hook.Add("Initialize", "eightbit_skinvoice_initdb", InitDatabase)

MsgC(Color(0,255,0), "[gVOX] Server part loaded.\n")






----------------- jmod + Zcity module

if not SERVER then return end

local okRequire = pcall(require, "eightbit")
local eightbit = rawget(_G, "eightbit")
if not eightbit then return end
if not eightbit.EnableEffect then return end

local EFF_NONE = eightbit.EFF_NONE or 0
local RADIO_EFF = 5

local NW_GVOX_EFFECT = "gvox_effect_id"
local NW_GVOX_LOCK = "gvox_effect_lock"

local ZCITY_WALKIE_CLASS = "weapon_walkie_talkie"

local forcedByRadio = {}

local function JModReady()
    return istable(JMod)
        and isfunction(JMod.PlyHasArmorEff)
        and isfunction(JMod.PlayersCanComm)
end

local function CanHearViaHeadset(listener, speaker)
    if listener == speaker then return false end
    if not IsValid(listener) or not listener:IsPlayer() or not listener:Alive() then return false end
    if not IsValid(speaker) or not speaker:IsPlayer() or not speaker:Alive() then return false end
    if not JModReady() then return false end

    if not JMod.PlyHasArmorEff(listener, "teamComms") then return false end
    if not JMod.PlyHasArmorEff(speaker, "teamComms") then return false end

    return JMod.PlayersCanComm(listener, speaker) == true
end

local function IsWalkieSpeakerActive(speaker)
    if not IsValid(speaker) or not speaker:IsPlayer() or not speaker:Alive() then return false end
    if not speaker:HasWeapon(ZCITY_WALKIE_CLASS) then return false end

    local swep = speaker:GetWeapon(ZCITY_WALKIE_CLASS)
    if not IsValid(swep) then return false end

    local isOn = (swep.GetIsOn and swep:GetIsOn()) or swep.isOn
    if not isOn then return false end

    if swep.GetInUsing and swep:GetInUsing() then return true end

    return speaker:IsSpeaking()
end

local function CanHearViaWalkie(listener, speaker)
    if listener == speaker then return false end
    if not IsValid(listener) or not listener:IsPlayer() or not listener:Alive() then return false end
    if not IsValid(speaker) or not speaker:IsPlayer() or not speaker:Alive() then return false end
    if not listener:HasWeapon(ZCITY_WALKIE_CLASS) then return false end
    if not speaker:HasWeapon(ZCITY_WALKIE_CLASS) then return false end
    if not IsWalkieSpeakerActive(speaker) then return false end

    local listenerWep = listener:GetWeapon(ZCITY_WALKIE_CLASS)
    if not IsValid(listenerWep) then return false end
    if not isfunction(listenerWep.CanListen) then return false end

    local okCall, canHear = pcall(listenerWep.CanListen, listenerWep, listener, speaker, false)
    if not okCall then return false end

    return canHear == true
end

timer.Create("gVOX_RadioEffectTimer", 0.25, 0, function()
    if not okRequire then return end

    local shouldRadio = {}
    local players = player.GetAll()

    for _, speaker in ipairs(players) do
        for _, listener in ipairs(players) do
            if CanHearViaHeadset(listener, speaker) or CanHearViaWalkie(listener, speaker) then
                shouldRadio[speaker:UserID()] = true
                break
            end
        end
    end

    for _, ply in ipairs(players) do
        local uid = ply:UserID()
        local hasGvoxEffect = ply:GetNWInt(NW_GVOX_EFFECT, EFF_NONE) ~= EFF_NONE

        if shouldRadio[uid] and not hasGvoxEffect then
            if not forcedByRadio[uid] then
                ply:SetNWBool(NW_GVOX_LOCK, true)
                eightbit.EnableEffect(uid, RADIO_EFF)
                forcedByRadio[uid] = true
            end
        elseif forcedByRadio[uid] then
            forcedByRadio[uid] = nil
            ply:SetNWBool(NW_GVOX_LOCK, false)

            if ply:GetNWInt(NW_GVOX_EFFECT, EFF_NONE) == EFF_NONE then
                eightbit.EnableEffect(uid, EFF_NONE)
            end
        end
    end
end)

hook.Add("PlayerDisconnected", "gVOX_RadioEffectCleanup", function(ply)
    forcedByRadio[ply:UserID()] = nil
end)
