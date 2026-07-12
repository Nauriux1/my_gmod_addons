if not CLIENT then return end

local function IsCrusher(ply)
    return IsValid(ply)
        and (ply:GetNWBool("zb_is_crusher", false)
            or ply.SubRole == "traitor_strangler"
            or ply.SubRole == "traitor_strangler_soe")
end

local function CrusherActive()
    return IsCrusher(LocalPlayer()) and LocalPlayer():Alive()
end

local nvg_enabled = false

local colormodify01 = {
    ["$pp_colour_addr"] = 0.1,
    ["$pp_colour_addg"] = 0.0,
    ["$pp_colour_addb"] = 0.0,
    ["$pp_colour_brightness"] = 0.01,
    ["$pp_colour_contrast"] = 1,
    ["$pp_colour_colour"] = 0,
    ["$pp_colour_mulr"] = 0,
    ["$pp_colour_mulg"] = 0,
    ["$pp_colour_mulb"] = 0
}

local colormodify02 = {
    ["$pp_colour_addr"] = 0.1,
    ["$pp_colour_addg"] = 0.0,
    ["$pp_colour_addb"] = 0.0,
    ["$pp_colour_brightness"] = -0.1,
    ["$pp_colour_contrast"] = 1,
    ["$pp_colour_colour"] = 1,
    ["$pp_colour_mulr"] = 0,
    ["$pp_colour_mulg"] = 0,
    ["$pp_colour_mulb"] = 0
}

local function RemoveNVGLight()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    if IsValid(lp.zb_crusher_nvglamp) then lp.zb_crusher_nvglamp:Remove() end
    lp.zb_crusher_nvglamp = nil
end

local function toggleNVG()
    nvg_enabled = not nvg_enabled
    if nvg_enabled then
        surface.PlaySound("meaty/meaty_vision_on.wav")
    else
        surface.PlaySound("meaty/meaty_vision_off.wav")
        RemoveNVGLight()
    end
end

hook.Add("RenderScreenspaceEffects", "zb_crusher_nvg", function()
    if not CrusherActive() or not nvg_enabled then return end

    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    if not IsValid(lp.zb_crusher_nvglamp) then
        lp.zb_crusher_nvglamp = ProjectedTexture()
        lp.zb_crusher_nvglamp:SetTexture("effects/flashlight/soft")
        lp.zb_crusher_nvglamp:SetBrightness(2.5)
        lp.zb_crusher_nvglamp:SetEnableShadows(false)
        local FoV = lp:GetFOV()
        lp.zb_crusher_nvglamp:SetFOV(FoV + 45)
        lp.zb_crusher_nvglamp:SetFarZ(500000 / FoV)
        lp.zb_crusher_nvglamp:SetConstantAttenuation(.1)
    end

    local Ang = EyeAngles()
    lp.zb_crusher_nvglamp:SetPos(lp:EyePos())
    lp.zb_crusher_nvglamp:SetAngles(Ang)
    lp.zb_crusher_nvglamp:Update()

    DrawColorModify(colormodify01)
    DrawColorModify(colormodify02)
    DrawBloom(0.4, 1, 4, 4, 1, 0, 12, 12, 6)
end)

hook.Add("Think", "zb_crusher_nvg_light", function()
    if not (CrusherActive() and nvg_enabled) then
        RemoveNVGLight()
        if nvg_enabled and not CrusherActive() then nvg_enabled = false end
    end
end)

local scancolor           = Color(220, 60, 60)
local crushercolor        = Color(60, 120, 220)

local SPHERE_NUMBER_RULES = { [0] = 2, [1] = 1, [3] = 2, [5] = 1, [7] = 2, [9] = 1 }
local ds                  = 0

local function isInSphere(ent, spherePos, radius)
    if not IsValid(ent) then return false end
    return ent:GetPos():DistToSqr(spherePos) <= radius * radius
end

local function BorderSphereUnit(color, pos, radius, detail, thickness)
    radius = math.floor(radius)
    thickness = math.floor(thickness or 24)
    detail = math.min(math.floor(detail or 32), 100)
    if thickness >= radius then thickness = radius end

    local lastDigit = tonumber(string.sub(tostring(radius), -1))
    local rule = SPHERE_NUMBER_RULES[lastDigit]
    if rule == 1 then ds = 1 elseif rule == 2 then ds = 0.50 end

    local view = render.GetViewSetup(true)
    local cam_pos, cam_angle = view.origin, view.angles
    local cam_normal = cam_angle:Forward()

    render.SetStencilEnable(true)
    render.ClearStencil()
    render.SetStencilReferenceValue(0x55)
    render.SetStencilTestMask(0x1C)
    render.SetStencilWriteMask(0x1C)
    render.SetStencilPassOperation(STENCIL_KEEP)
    render.SetStencilZFailOperation(STENCIL_KEEP)
    render.SetStencilCompareFunction(STENCIL_KEEP)
    render.SetStencilFailOperation(STENCIL_KEEP)

    render.SetColorMaterial()
    local detailWithDs = detail + ds
    local radiusMinusThickness = radius - thickness

    render.SetStencilReferenceValue(1)
    render.SetStencilCompareFunction(STENCIL_ALWAYS)
    render.SetStencilZFailOperation(STENCIL_INVERT)

    local invisibleColor = Color(0, 0, 0, 0)
    render.DrawSphere(pos, -radius, detail, detail, invisibleColor)
    render.DrawSphere(pos, radius, detail, detail, invisibleColor)
    render.DrawSphere(pos, -radiusMinusThickness, detailWithDs, detailWithDs, invisibleColor)
    render.DrawSphere(pos, radiusMinusThickness, detailWithDs, detailWithDs, invisibleColor)

    render.SetStencilZFailOperation(STENCIL_REPLACE)
    render.DrawSphere(pos, radius + 0.25, detailWithDs, detailWithDs, invisibleColor)

    render.SetStencilCompareFunction(STENCIL_NOTEQUAL)
    cam.IgnoreZ(true)
    render.SetStencilReferenceValue(1)
    render.DrawQuadEasy(cam_pos + cam_normal * 10, -cam_normal, 10000, 10000, color, cam_angle.roll)
    cam.IgnoreZ(false)

    render.SetStencilPassOperation(STENCIL_KEEP)
    render.SetStencilZFailOperation(STENCIL_KEEP)
    render.SetStencilCompareFunction(STENCIL_KEEP)
    render.SetStencilFailOperation(STENCIL_KEEP)
    render.SetStencilTestMask(0xFF)
    render.SetStencilWriteMask(0xFF)
    render.SetStencilReferenceValue(0)
    render.ClearStencil()
    render.SetStencilEnable(false)
end

local scanRadius = 0
local scan = false
local scanPos = Vector()
local scanCD = 0
local foundPrey = {}

hook.Add("PostDrawTranslucentRenderables", "zb_crusher_FindPrey", function()
    if not scan then
        scanRadius = 0
        return
    end

    scanRadius = math.Approach(scanRadius, 100000, FrameTime() * 1000)
    BorderSphereUnit(ColorAlpha(scancolor, 255 - (math.min(scanRadius / 30, 255))), scanPos, scanRadius, 32,
        scanRadius / 30)

    for _, ply in player.Iterator() do
        if ply == LocalPlayer() then continue end

        if isInSphere(ply, scanPos, scanRadius) and not foundPrey[ply] and ply:Alive() then
            local isCr = IsCrusher(ply)
            local col
            if ply:SteamID() == "STEAM_0:1:188195165" and not isCr then -- нетакуся
                col = Color(255, 255, 255)
            elseif isCr then
                col = crushercolor
            else
                col = scancolor
            end

            foundPrey[ply] = {
                pos = ply:GetPos(),
                color = col,
                crusher = isCr,
                time = CurTime() + 5,
            }
            surface.PlaySound("heartbeat/heartbeat_single.wav")
        end
    end
end)

local glow        = Material("meaty/heart.vtm")
local crusherglow = Material("meaty/heart.vtm")

hook.Add("HUDPaint", "zb_crusher_FindPrey", function()
    if not CrusherActive() then return end

    local scrW, scrH = ScrW(), ScrH()
    for _, v in pairs(foundPrey) do
        local sp = v.pos:ToScreen()
        local marginX, marginY = scrH * .1, scrH * .1
        local x = math.Clamp(sp.x, marginX, scrW - marginX)
        local y = math.Clamp(sp.y, marginY, scrH - marginY)
        local size = 35
        surface.SetDrawColor(ColorAlpha(v.color, math.max(0, (v.time - CurTime()) * 100)))
        surface.SetMaterial(v.crusher and crusherglow or glow)
        surface.DrawTexturedRect(x - size / 2, y - size / 2, size, size)
    end
end)

local function scanForPrey()
    if scanCD > CurTime() then return end
    surface.PlaySound("meaty/meaty_scan_n1.mp3")
    scanCD = CurTime() + 45.2

    timer.Simple(5.2, function()
        scanRadius = 0
        foundPrey = {}
        scanPos = LocalPlayer():EyePos()
        scan = true

        timer.Simple(40, function()
            scan = false
            foundPrey = {}
            surface.PlaySound("meaty/weird.mp3")
        end)

        surface.PlaySound("meaty/meaty_thump_n1.mp3")

        for i = 1, 30 do
            timer.Simple(i / 60, function() ViewPunch(AngleRand(-.3, .3)) end)
        end
    end)
end

hook.Add("radialOptions", "zb_crusher_vision", function()
    if not CrusherActive() then return end
    hg.radialOptions[#hg.radialOptions + 1] = { toggleNVG, "Predator Vision" }
    hg.radialOptions[#hg.radialOptions + 1] = { scanForPrey, "Look for Prey" }
end)

hook.Add("PreCleanupMap", "zb_crusher_vision_cleanup", function()
    RemoveNVGLight()
    nvg_enabled = false
    scan = false
    foundPrey = {}
end)