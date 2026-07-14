include("shared.lua")

net.Receive("HMCD_Closet_Enter", function()
    local ent = net.ReadEntity()
    LocalPlayer().zh_ClosetEnt = IsValid(ent) and ent or nil
end)

net.Receive("HMCD_Closet_Exit", function()
    LocalPlayer().zh_ClosetEnt = nil
end)

local function InCloset()
    local lp = LocalPlayer()
    return IsValid(lp) and IsValid(lp.zh_ClosetEnt) and lp.zh_ClosetEnt
end

zb = zb or {}
local prevOverrideCalcView = zb.OverrideCalcView

function zb.OverrideCalcView(ply, origin, angles, fov, znear, zfar)
    local closet = InCloset()
    if closet then
        local baseAng = closet:GetPeepholeAngles()
        local eyeAng  = ply:EyeAngles()

        local yaw   = math.Clamp(math.AngleDifference(eyeAng.y, baseAng.y), -closet.PeepholeLookYawLimit, closet.PeepholeLookYawLimit)
        local pitch = math.Clamp(math.AngleDifference(eyeAng.p, baseAng.p), -closet.PeepholeLookPitchLimit, closet.PeepholeLookPitchLimit)

        return {
            origin     = closet:GetPeepholePos(),
            angles     = Angle(baseAng.p + pitch, baseAng.y + yaw, 0),
            fov        = 50,
            znear      = znear,
            zfar       = zfar,
            drawviewer = false,
        }
    end

    if prevOverrideCalcView then
        return prevOverrideCalcView(ply, origin, angles, fov, znear, zfar)
    end
end

hook.Add("PreDrawViewModel", "zh_closet_hide_viewmodel", function()
    if InCloset() then return true end
end)

hook.Add("CreateMove", "zh_closet_block_input", function(cmd)
    if not InCloset() then return end
    cmd:RemoveKey(IN_FORWARD + IN_BACK + IN_MOVELEFT + IN_MOVERIGHT
        + IN_ATTACK + IN_ATTACK2 + IN_JUMP + IN_DUCK + IN_SPEED
        + IN_RELOAD + IN_WALK + IN_ZOOM)
    cmd:SetForwardMove(0)
    cmd:SetSideMove(0)
    cmd:SetUpMove(0)
end)

hook.Add("HUDShouldDraw", "zh_closet_hide_hud", function(name)
    if not InCloset() then return end
    if name == "CHudCrosshair" or name == "CHudWeaponSelection" then
        return false
    end
end)


-- ========================================================
-- PLACEHOLDER PEEPHOLE FRAME (INVISIBLE STENCIL MASK ROUTINE)
-- ========================================================

local cachedPeepholePoly = {}
local zh_lastMaskScale = 0

local function ResolveStencilPolyHoleShape(radius, centerX, centerY)
    if radius == zh_lastMaskScale and #cachedPeepholePoly > 0 then return end 
    
    zh_lastMaskScale = radius
    cachedPeepholePoly = {}
    
    local pointFidelity = math.max(64, math.ceil(radius / 3)) 
    for indexPoint = 0, pointFidelity - 1 do 
        local radDegrees = math.rad( (indexPoint / pointFidelity) * 360 )
        
        table.insert(cachedPeepholePoly, {
            x = centerX + (math.cos(radDegrees) * radius),
            y = centerY + (math.sin(radDegrees) * radius),
            u = (math.cos(radDegrees) + 1) * 0.5,
            v = (math.sin(radDegrees) + 1) * 0.5 
        })
    end
end

hook.Add("HUDPaint", "zh_closet_peephole_frame", function()
    if not InCloset() then return end
    
    local viewportW, viewportH = ScrW(), ScrH()
    local scaleRadius = math.min(viewportW, viewportH) * 0.28 
    
    -- Remaps perfectly across resolution adjustments silently
    ResolveStencilPolyHoleShape(scaleRadius, viewportW / 2, viewportH / 2)

    -- ===================
    --   THE STENCIL PASS
    -- ===================
    render.ClearStencil()
    render.SetStencilEnable(true)
    
    render.SetStencilWriteMask(255)
    render.SetStencilTestMask(255)
    render.SetStencilReferenceValue(1)

    -- Phase A: Mark Out The Cookie Cutter Center INVISIBLY.
    -- (STENCIL_NEVER means 'do not render any pixel colors visually'.
    -- STENCIL_REPLACE fail op assigns that dropped area its masking marker.)
    render.SetStencilCompareFunction(STENCIL_NEVER) 
    render.SetStencilFailOperation(STENCIL_REPLACE)
    render.SetStencilZFailOperation(STENCIL_KEEP)
    render.SetStencilPassOperation(STENCIL_KEEP) 

    draw.NoTexture()
    surface.SetDrawColor(255, 255, 255, 255) 
    surface.DrawPoly(cachedPeepholePoly) -- Gmod engine draws absolutely NO visuals, marks out Mask region 1. 

    -- Phase B: Fill Total Darkness bounds EVERYWHERE that DOES NOT carry the Cookie Cutter Mask Marker! 
    render.SetStencilCompareFunction(STENCIL_NOTEQUAL) 
    render.SetStencilFailOperation(STENCIL_KEEP) 
    render.SetStencilPassOperation(STENCIL_KEEP) 

    surface.SetDrawColor(0, 0, 0, 255) 
    surface.DrawRect(0, 0, viewportW, viewportH)

    -- Cleanup Rule Blocks safely
    render.SetStencilEnable(false)
    

    -- Optional Fading Tunnel Rims Effect around outline edge adding simulated shadows:
    if surface.DrawCircle then 
        local centerHoleX = viewportW / 2
        local centerHoleY = viewportH / 2 
        
        for rimLayerCount = 1, 32 do
            local shrinkRimSizeMapping = scaleRadius * (1 - (rimLayerCount * 0.003)) 
            local currentRingAlphaStateFade = math.max(0, 255 - (rimLayerCount * 7)) 
            surface.DrawCircle(centerHoleX, centerHoleY, math.floor(shrinkRimSizeMapping), 0, 0, 0, currentRingAlphaStateFade) 
        end 
    end 
end)