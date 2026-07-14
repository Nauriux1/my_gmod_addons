if not CLIENT then return end

-- Persistent, independently-toggleable ESP for the crusher.
-- This is separate from "Predator Vision" (nightvision) and from the
-- timed "Look for Prey" scan ping — it's an on/off through-wall reveal
-- of every alive player's position, toggled via its own radial option.

local function IsCrusher(ply)
    return IsValid(ply)
        and (ply:GetNWBool("zb_is_crusher", false)
            or ply.SubRole == "traitor_strangler"
            or ply.SubRole == "traitor_strangler_soe")
end

local function CrusherActive()
    return IsCrusher(LocalPlayer()) and LocalPlayer():Alive()
end

local esp_enabled = false

local function toggleESP()
    esp_enabled = not esp_enabled
    surface.PlaySound(esp_enabled and "meaty/meaty_vision_on.wav" or "meaty/meaty_vision_off.wav")
end

concommand.Add("crusher_esp_toggle", function()
    if not CrusherActive() then return end
    toggleESP()
end)

if not pcall(surface.CreateFont, "Crusher_ESP_Font", {
    font      = "Bahnschrift",
    size      = 16,
    weight    = 600,
    antialias = true,
    shadow    = true,
}) then
    surface.CreateFont("Crusher_ESP_Font", {
        font      = "Tahoma",
        size      = 16,
        weight    = 600,
        antialias = true,
        shadow    = true,
    })
end

local col_dot_near  = Color(210, 40, 40, 255)
local col_dot_far   = Color(210, 40, 40, 190)
local col_text      = Color(255, 255, 255, 235)
local col_text_bg   = Color(0, 0, 0, 140)

hook.Add("HUDPaint", "zb_crusher_esp", function()
    if not CrusherActive() or not esp_enabled then return end

    local lp = LocalPlayer()
    local scrW, scrH = ScrW(), ScrH()
    local marginX, marginY = scrW * .04, scrH * .06

    for _, ply in player.Iterator() do
        if ply == lp or not IsValid(ply) or not ply:Alive() then continue end

        local worldPos = ply:GetPos() + Vector(0, 0, 64)
        local sp        = worldPos:ToScreen()
        local onscreen  = sp.visible

        local x = math.Clamp(sp.x, marginX, scrW - marginX)
        local y = math.Clamp(sp.y, marginY, scrH - marginY)

        local dist  = lp:GetPos():Distance(ply:GetPos())
        local meters = math.floor(dist / 52.49) -- ~ hammer units to meters

        local dotCol  = onscreen and col_dot_near or col_dot_far
        local dotSize = onscreen and 7 or 11

        surface.SetDrawColor(dotCol)
        surface.DrawRect(x - dotSize / 2, y - dotSize / 2, dotSize, dotSize)
        surface.SetDrawColor(Color(0, 0, 0, 200))
        surface.DrawOutlinedRect(x - dotSize / 2, y - dotSize / 2, dotSize, dotSize, 1)

        local label = string.format("%s [%dm]", ply:Nick(), meters)
        surface.SetFont("Crusher_ESP_Font")
        local tw, th = surface.GetTextSize(label)

        surface.SetDrawColor(col_text_bg)
        surface.DrawRect(x - tw / 2 - 3, y + dotSize, tw + 6, th + 2)
        surface.SetTextColor(col_text)
        surface.SetTextPos(x - tw / 2, y + dotSize + 1)
        surface.DrawText(label)
    end
end)

hook.Add("radialOptions", "zb_crusher_esp_option", function()
    if not CrusherActive() then return end
    hg.radialOptions[#hg.radialOptions + 1] = { toggleESP, "Toggle Player ESP" }
end)

hook.Add("PreCleanupMap", "zb_crusher_esp_cleanup", function()
    esp_enabled = false
end)