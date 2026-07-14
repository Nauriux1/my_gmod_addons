-- Crusher "Sounds" radial submenu.
--
-- Adds a "Sounds" entry to the crusher's radial menu (the same one used
-- by Predator Vision / Toggle Player ESP). Selecting it instantly opens
-- a second radial wheel listing the sounds below, using hg's own
-- CreateRadialMenu(options_table) API (see the "Do Gesture" RMB menu in
-- zcity/homigrad/cl_hud.lua for the same pattern) — this is a real
-- nested wheel, not a fake/rebuilt one.
--
-- Edit SOUND_LIST below to add/remove sounds. Each entry is
-- { "sound/path.wav", "Display Name" }.

local SOUND_LIST = {
    { "crusher/ambient4.mp3", "Scare" },
	{ "crusher/behind.mp3", "BEHIND YOU" },

}

local function IsCrusher(ply)
    return IsValid(ply)
        and (ply:GetNWBool("zb_is_crusher", false)
            or ply.SubRole == "traitor_strangler"
            or ply.SubRole == "traitor_strangler_soe")
end

if SERVER then
    util.AddNetworkString("HMCD_Crusher_PlaySound")

    local lastPlayed = {}
    local COOLDOWN = 1.0

    net.Receive("HMCD_Crusher_PlaySound", function(len, ply)
        if not IsValid(ply) or not ply:Alive() then return end
        if not IsCrusher(ply) then return end

        local idx = net.ReadUInt(8)
        local entry = SOUND_LIST[idx]
        if not entry then return end

        local uid = ply:UserID()
        local now = CurTime()
        if lastPlayed[uid] and now - lastPlayed[uid] < COOLDOWN then return end
        lastPlayed[uid] = now

        ply:EmitSound(entry[1], 75, 100, 1)
    end)

    hook.Add("PlayerDisconnected", "ZB_CrusherSounds_Cleanup", function(ply)
        lastPlayed[ply:UserID()] = nil
    end)
end

if CLIENT then
    local function CrusherActive()
        return IsCrusher(LocalPlayer()) and LocalPlayer():Alive()
    end

    local function playSound(idx)
        net.Start("HMCD_Crusher_PlaySound")
        net.WriteUInt(idx, 8)
        net.SendToServer()
    end

    local function openSoundMenu()
        local commands = {}
        for i, entry in ipairs(SOUND_LIST) do
            commands[i] = {
                [1] = function() playSound(i) end,
                [2] = entry[2],
            }
        end
        -- Back option returns to the normal top-level radial.
        commands[#commands + 1] = {
            [1] = function() hg.CreateRadialMenu() end,
            [2] = "< Back",
        }
        hg.CreateRadialMenu(commands)
    end

    hook.Add("radialOptions", "zb_crusher_sounds_menu", function()
        if not CrusherActive() then return end
        hg.radialOptions[#hg.radialOptions + 1] = { function() openSoundMenu() end, "Sounds, RMB - Menu" }
    end)
end