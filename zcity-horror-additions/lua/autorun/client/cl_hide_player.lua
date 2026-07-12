if not CLIENT then return end

local function IsZCity()
    return engine.ActiveGamemode() == "zcity"
end

ZB_ScoreboardFilter = ZB_ScoreboardFilter or {}
ZB_ScoreboardFilter.predicates = ZB_ScoreboardFilter.predicates or {}
ZB_ScoreboardFilter.Register = ZB_ScoreboardFilter.Register or function(id, fn)
    ZB_ScoreboardFilter.predicates[id] = fn
end

ZB_ScoreboardFilter.Register("hidden", function(ply)
    return ply:GetNWBool("zb_hidden", false)
end)

local SPEC_HOOK = "FUCKINGSAMENAMEUSEDINHOOKFUCKME"
local zb_specWrapped = false

local function InstallSpecOverride()
    if zb_specWrapped then return end
    local current = hook.GetTable().HUDPaint and hook.GetTable().HUDPaint[SPEC_HOOK]
    if not current then return end
    local original = current

    hook.Add("HUDPaint", SPEC_HOOK, function()
        if not IsZCity() then
            if original then return original() end
            return
        end

        local lp = LocalPlayer()
        if not IsValid(lp) or lp:Alive() then
            if original then return original() end
            return
        end

        local spect = lp:GetNWEntity("spect")
        local hidden = IsValid(spect) and spect:GetNWBool("zb_hidden", false)

        if not hidden then
            if original then return original() end
            return
        end

        if (viewmode or 0) == 3 then return end

        surface.SetFont("HomigradFont")
        surface.SetTextColor(255, 255, 255, 255)

        local txt1 = "Spectating player: Unknown"
        local w1 = surface.GetTextSize(txt1)
        surface.SetTextPos(ScrW() / 2 - w1 / 2, ScrH() / 8 * 7)
        surface.DrawText(txt1)

        local txt2 = "In-game name: Unknown"
        local w2, h2 = surface.GetTextSize(txt2)
        surface.SetTextPos(ScrW() / 2 - w2 / 2, ScrH() / 8 * 7 + h2)
        surface.DrawText(txt2)
    end)

    zb_specWrapped = true
end

hook.Add("InitPostEntity", "zb_hide_player_spec_install", InstallSpecOverride)
timer.Simple(1, InstallSpecOverride)
timer.Simple(5, InstallSpecOverride)
-- designed and realized by alagri & omnissiah respectively
