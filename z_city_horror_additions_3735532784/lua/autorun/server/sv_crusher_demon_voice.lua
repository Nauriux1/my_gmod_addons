if not SERVER then return end

-- Applies the gVOX "Demon" voice preset (preset id 6, per gvox's own
-- sh_eightbit_skinvoice_lang.lua presets table, consistent across all
-- locales) to whoever is currently the crusher.
--
-- Uses the same NW lock convar (gvox_effect_lock) that gvox's own
-- radio/walkie-talkie integration uses (see the bottom of
-- gvox/lua/autorun/server/sv_eightbit_skinvoice.lua) so this doesn't
-- fight with per-model voice rules: while the lock is set, gVOX's own
-- timer will not overwrite the effect we apply here.

local okRequire = pcall(require, "eightbit")
local eightbit  = rawget(_G, "eightbit")
if not eightbit or not eightbit.EnableEffect then
    MsgC(Color(255, 0, 0), "[ZHorror] eightbit module not available — crusher demon voice disabled.\n")
    return
end

local EFF_NONE = eightbit.EFF_NONE or 0
local NW_GVOX_EFFECT = "gvox_effect_id"
local NW_GVOX_LOCK   = "gvox_effect_lock"

if not ConVarExists("zb_zh_crusher_voice_effect") then
    CreateConVar("zb_zh_crusher_voice_effect", "6", FCVAR_ARCHIVE + FCVAR_REPLICATED,
        "ZHorror: gVOX preset id applied to the crusher's voice (6 = Demon)", 0, 14)
end
if not ConVarExists("zb_zh_crusher_voice_enabled") then
    CreateConVar("zb_zh_crusher_voice_enabled", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED,
        "ZHorror: enable the crusher demon voice filter", 0, 1)
end

local function VoiceEnabled()
    local cv = GetConVar("zb_zh_crusher_voice_enabled")
    return not cv or cv:GetBool()
end

local function CrusherEffectId()
    local cv = GetConVar("zb_zh_crusher_voice_effect")
    return (cv and cv:GetInt()) or 6
end

local function IsCrusher(ply)
    return IsValid(ply)
        and (ply:GetNWBool("zb_is_crusher", false)
            or ply.SubRole == "traitor_strangler"
            or ply.SubRole == "traitor_strangler_soe")
end

local appliedTo = {}

-- NOTE: gVOX's own radio/walkie-talkie effect timer (bottom half of
-- gvox/lua/autorun/server/sv_eightbit_skinvoice.lua) shares this exact
-- same lock convar and eightbit.EnableEffect call. It decides whether
-- it's free to grab the lock by checking the player's gvox_effect_id NW
-- int -- which we never set -- so as far as it's concerned the crusher
-- has no effect, and it happily steals the lock the moment he talks over
-- a headset/walkie. It releases the lock again once he stops talking.
--
-- A one-shot "apply once, remember we did" approach has no way to notice
-- that theft, so the demon voice would just stay gone until this timer
-- got reset (e.g. by toggling zb_zh_crusher_voice_enabled off/on). Fix:
-- reassert every tick instead of gating on a boolean. Cheap (usually 0-1
-- crushers alive at once) and self-heals regardless of what stole it.
timer.Create("ZB_CrusherDemonVoice", 0.2, 0, function()
    if not VoiceEnabled() then
        for uid in pairs(appliedTo) do
            appliedTo[uid] = nil
        end
        return
    end

    for _, ply in player.Iterator() do
        local uid   = ply:UserID()
        local isCr  = IsCrusher(ply) and ply:Alive()

        if isCr then
            appliedTo[uid] = true
            ply:SetNWBool(NW_GVOX_LOCK, true)
            eightbit.EnableEffect(uid, CrusherEffectId())
        elseif appliedTo[uid] then
            appliedTo[uid] = nil
            ply:SetNWBool(NW_GVOX_LOCK, false)

            -- If the player's model doesn't have its own gVOX rule,
            -- clear the effect immediately. Otherwise let gVOX's own
            -- timer reapply the model-based preset on its next tick.
            if ply:GetNWInt(NW_GVOX_EFFECT, EFF_NONE) == EFF_NONE then
                eightbit.EnableEffect(uid, EFF_NONE)
            end
        end
    end
end)

hook.Add("PlayerDisconnected", "ZB_CrusherDemonVoice_Cleanup", function(ply)
    appliedTo[ply:UserID()] = nil
end)