-- Co-pilot (seat 2) thermal gimbal camera for the Vulture (iw9_veh_blima).
--
-- Left click while seated as co-pilot toggles a fixed camera slung under
-- the helicopter's belly: free 360-degree look independent of the
-- airframe's orientation (like a real stabilized gimbal), a green
-- thermal-style screenspace filter, and a warm halo on any player the
-- camera has a clear line of sight to.
--
-- Deliberately NOT added to iw9_veh_blima_gship (the armed gunship
-- variant): seat 2 there already fires the main turret on left click
-- (see iw9_veh_blima_gship.lua's ENT:Think -> self.turret:UpdateUser).
--
-- This entire feature is client-only, purely visual/read-only (no
-- gameplay state to sync), so there's no server-side file at all.

if not CLIENT then return end
if not Glide then return end

-- The base zcity camera composition (zcity/homigrad/cl_camera.lua) only
-- ever consults the PostPostHGCalcView hook -- which both Glide's own
-- vehicle camera and this feature hook into -- when the vehicle's class
-- is registered in hg.vehiclecamblacklist (see sh_vehicles.lua). That
-- table is normally populated at runtime through an admin menu/console
-- command, not hardcoded per-vehicle in source. Registering it here too
-- means this (and Glide's own camera) works out of the box regardless of
-- whether a server admin has already flipped that flag.
hg.vehiclecamblacklist = hg.vehiclecamblacklist or {}
hg.vehiclecamblacklist["iw9_veh_blima"] = true

local SUPPORTED_CLASSES = { iw9_veh_blima = true }
local GIMBAL_SEAT = 2 -- co-pilot

local GIMBAL_LOCAL_OFFSET = Vector(100, -10, -50) -- belly-mounted; tune in-game, exact hull size unverified
local FOV_BASE, FOV_MIN = 50, 15
local DETECT_RANGE = 4000

-- Named "tcam" (not "cam") so we never shadow the global cam.* render library.
local tcam = {
    active    = false,
    vehicle   = NULL,
    seatIndex = nil,
    yaw       = 0,
    pitch     = 0,
    fov       = FOV_BASE,
}

local haloTargets = {}

-- Stored originals of Glide's hooks so we can restore them exactly when
-- thermal cam turns off. We deliberately do NOT try to out-prioritize
-- Glide's HOOK_HIGH entries (that approach was unreliable against the
-- zcity/Glide composition). Instead we remove Glide's hooks for the
-- duration of thermal mode and put the exact same functions back afterwards.
local originalGlideCalcView = nil
local originalGlideMouse    = nil
local glideHooksSuppressed  = false

local function SuppressGlideCameraHooks()
    if glideHooksSuppressed then return end

    local calcTable = hook.GetTable()["PostPostHGCalcView"]
    if calcTable and calcTable["GlideCamera.CalcView"] then
        originalGlideCalcView = calcTable["GlideCamera.CalcView"]
        hook.Remove("PostPostHGCalcView", "GlideCamera.CalcView")
    end

    local mouseTable = hook.GetTable()["InputMouseApply"]
    if mouseTable and mouseTable["GlideCamera.InputMouseApply"] then
        originalGlideMouse = mouseTable["GlideCamera.InputMouseApply"]
        hook.Remove("InputMouseApply", "GlideCamera.InputMouseApply")
    end

    glideHooksSuppressed = true
end

local function RestoreGlideCameraHooks()
    if not glideHooksSuppressed then return end

    if originalGlideCalcView then
        hook.Add("PostPostHGCalcView", "GlideCamera.CalcView", originalGlideCalcView, HOOK_HIGH)
        originalGlideCalcView = nil
    end

    if originalGlideMouse then
        hook.Add("InputMouseApply", "GlideCamera.InputMouseApply", originalGlideMouse, HOOK_HIGH)
        originalGlideMouse = nil
    end

    glideHooksSuppressed = false
end

local function StopThermalCam()
    if not tcam.active then return end
    tcam.active = false
    RestoreGlideCameraHooks()
end

-- ---------------------------------------------------------------------
-- Track current seat via the same events Glide's own camera uses
-- ---------------------------------------------------------------------

hook.Add("Glide_OnLocalEnterVehicle", "iw9_ThermalCam.Track", function(vehicle, seatIndex)
    tcam.vehicle = vehicle
    tcam.seatIndex = seatIndex
    StopThermalCam()
end)

hook.Add("Glide_OnLocalExitVehicle", "iw9_ThermalCam.Track", function()
    tcam.vehicle = NULL
    tcam.seatIndex = nil
    StopThermalCam()
end)

local function CanUseThermalCam()
    return IsValid(tcam.vehicle)
        and SUPPORTED_CLASSES[tcam.vehicle:GetClass()]
        and tcam.seatIndex == GIMBAL_SEAT
end

-- ---------------------------------------------------------------------
-- Toggle: left click while seated as co-pilot
-- ---------------------------------------------------------------------

hook.Add("Think", "iw9_ThermalCam.Toggle", function()
    if not CanUseThermalCam() then
        if tcam.active then StopThermalCam() end
        return
    end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    if ply:KeyPressed(IN_ATTACK) then
        tcam.active = not tcam.active

        if tcam.active then
            -- Start looking straight down whichever way the vehicle's
            -- currently facing, rather than some arbitrary fixed angle.
            local vehAng = tcam.vehicle:GetAngles()
            tcam.yaw, tcam.pitch, tcam.fov = vehAng.y, 20, FOV_BASE
            SuppressGlideCameraHooks()
            surface.PlaySound("buttons/button24.wav")
        else
            RestoreGlideCameraHooks()
            surface.PlaySound("buttons/button10.wav")
        end
    end
end)

-- ---------------------------------------------------------------------
-- Mouse look: fully free 360, independent of the vehicle's orientation.
-- Glide's own InputMouseApply is removed while we are active, so we no
-- longer need to fight priority; a plain return true is enough to keep
-- other mouse consumers from seeing the deltas.
-- ---------------------------------------------------------------------

hook.Add("InputMouseApply", "iw9_ThermalCam.Mouse", function(cmd, x, y, ang)
    if not tcam.active or not CanUseThermalCam() then return end

    local sens = 0.05
    tcam.yaw   = (tcam.yaw - x * sens) % 360
    tcam.pitch = math.Clamp(tcam.pitch + y * sens, -85, 85)

    return true
end)

-- ---------------------------------------------------------------------
-- Zoom: hold the normal zoom bind to close in
-- ---------------------------------------------------------------------

hook.Add("Think", "iw9_ThermalCam.Zoom", function()
    if not tcam.active then return end
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local target = ply:KeyDown(IN_ZOOM) and FOV_MIN or FOV_BASE
    tcam.fov = Lerp(FrameTime() * 4, tcam.fov, target)
end)

-- ---------------------------------------------------------------------
-- The actual camera override
-- Glide's PostPostHGCalcView is removed while we are active, so this
-- hook can run at normal priority and will be the one that supplies the
-- view table.
-- ---------------------------------------------------------------------

hook.Add("PostPostHGCalcView", "iw9_ThermalCam.CalcView", function()
    if not tcam.active or not CanUseThermalCam() then return end

    local vehicle = tcam.vehicle
    return {
        origin      = vehicle:LocalToWorld(GIMBAL_LOCAL_OFFSET),
        angles      = Angle(tcam.pitch, tcam.yaw, 0),
        fov         = tcam.fov,
        drawviewer  = true,
    }
end)

-- ---------------------------------------------------------------------
-- Thermal FLIR screenspace shader
-- Multi-pass post-process approximating military green-hot FLIR:
--   1) high-contrast desaturate + green phosphor grade
--   2) heat bloom on bright (warm) regions
--   3) green wash + CRT/FLIR scanlines
--   4) sensor noise / grain
--   5) soft radial vignette
-- Pure Lua — no external .vmt / compiled pixel shader required.
-- ---------------------------------------------------------------------

local thermalColorModify = {
    ["$pp_colour_addr"]       = -0.02,
    ["$pp_colour_addg"]       = 0.04,
    ["$pp_colour_addb"]       = -0.04,
    ["$pp_colour_brightness"] = -0.05,
    ["$pp_colour_contrast"]   = 1.55,
    ["$pp_colour_colour"]     = 0.08, -- near-monochrome with a hint of green
    ["$pp_colour_mulr"]       = 0.15,
    ["$pp_colour_mulg"]       = 0.55,
    ["$pp_colour_mulb"]       = 0.12,
}

local matNoise = Material("effects/tvscreen_noise002a") -- engine stock; fails soft if missing
local hasNoise = not matNoise:IsError()

local function DrawThermalScanlines(w, h)
    -- Horizontal FLIR raster lines. Alpha stays low so HUD stays readable.
    surface.SetDrawColor(0, 0, 0, 28)
    for y = 0, h, 3 do
        surface.DrawRect(0, y, w, 1)
    end

    -- Occasional thicker "refresh" bar that drifts slowly down the frame.
    local barY = (RealTime() * 40) % (h + 40) - 20
    surface.SetDrawColor(40, 255, 120, 18)
    surface.DrawRect(0, barY, w, 2)
end

local function DrawThermalGrain(w, h)
    if hasNoise then
        surface.SetMaterial(matNoise)
        surface.SetDrawColor(80, 255, 140, 18)
        -- Scroll UVs slightly each frame for living sensor noise.
        local u = (RealTime() * 0.15) % 1
        local v = (RealTime() * 0.11) % 1
        surface.DrawTexturedRectUV(0, 0, w, h, u, v, u + 1.5, v + 1.5)
    else
        -- Fallback: sparse random pixel static if the stock noise mat is absent.
        surface.SetDrawColor(100, 255, 150, 20)
        for _ = 1, 40 do
            local x = math.random(0, w)
            local y = math.random(0, h)
            surface.DrawRect(x, y, 2, 2)
        end
    end
end

local function DrawThermalVignette(w, h)
    -- Four edge fades approximating a circular optical vignette without a custom texture.
    local edge = math.floor(math.min(w, h) * 0.12)
    local steps = 12
    for i = 0, steps - 1 do
        local a = math.floor((i / steps) ^ 1.6 * 140)
        local t = math.floor(edge * (i / steps))
        surface.SetDrawColor(0, 8, 0, a)
        -- top / bottom
        surface.DrawRect(0, t, w, 2)
        surface.DrawRect(0, h - t - 2, w, 2)
        -- left / right
        surface.DrawRect(t, 0, 2, h)
        surface.DrawRect(w - t - 2, 0, 2, h)
    end
end

hook.Add("RenderScreenspaceEffects", "iw9_ThermalCam.Effect", function()
    if not tcam.active then return end

    -- Pass 1: FLIR color grade (high contrast, near-mono, green phosphor).
    DrawColorModify(thermalColorModify)

    -- Pass 2: heat bloom — lifts bright/warm regions so bodies and engines glow.
    DrawBloom(0.55, 1.8, 8, 8, 1, 0.9, 0.35, 1.0, 0.35)

    -- Pass 3–5: overlays that need 2D surface drawing.
    local w, h = ScrW(), ScrH()
    cam.Start2D()
        -- Soft green additive wash
        surface.SetDrawColor(30, 180, 70, 22)
        surface.DrawRect(0, 0, w, h)

        DrawThermalScanlines(w, h)
        DrawThermalGrain(w, h)
        DrawThermalVignette(w, h)
    cam.End2D()
end)

local function GetCharacterEyePos(character)
    if character:IsPlayer() then
        return character:EyePos()
    end

    -- prop_ragdoll (FakeRagdoll): prefer eyes attachment, then head bone, else a raised center.
    local attId = character:LookupAttachment("eyes")
    if attId and attId > 0 then
        local att = character:GetAttachment(attId)
        if att and att.Pos then return att.Pos end
    end

    local headBone = character:LookupBone("ValveBiped.Bip01_Head1")
    if headBone then
        local pos = character:GetBonePosition(headBone)
        if pos then return pos end
    end

    return character:GetPos() + Vector(0, 0, 20)
end

hook.Add("PreDrawHalos", "iw9_ThermalCam.DetectPeople", function()
    table.Empty(haloTargets)
    if not tcam.active or not IsValid(tcam.vehicle) then return end

    local origin = tcam.vehicle:LocalToWorld(GIMBAL_LOCAL_OFFSET)
    local me = LocalPlayer()

    for _, target in player.Iterator() do
        -- Never mark the thermal operator or fully dead players.
        if target == me then continue end
        if not target:Alive() then continue end

        -- Living but ragdolled players are represented by their FakeRagdoll;
        -- standing players are the player entity itself.
        local character = IsValid(target.FakeRagdoll) and target.FakeRagdoll or target

        if character:GetPos():DistToSqr(origin) > DETECT_RANGE * DETECT_RANGE then continue end

        local eyePos = GetCharacterEyePos(character)

        local tr = util.TraceLine({
            start  = origin,
            endpos = eyePos,
            filter = { tcam.vehicle, character, target, me },
            mask   = MASK_SOLID_BRUSHONLY,
        })
        if tr.Fraction >= 0.98 then
            haloTargets[#haloTargets + 1] = character
        end
    end

    if #haloTargets > 0 then
        halo.Add(haloTargets, Color(255, 200, 80), 2, 2, 1, true, false)
    end
end)

-- ---------------------------------------------------------------------
-- HDTS HUD Layout
-- Full Head-Down Targeting System readout for military-style telemetry.
-- ---------------------------------------------------------------------

hook.Add("HUDShouldDraw", "iw9_ThermalCam.HideDefaultHUD", function(name)
    if tcam.active and name == "CHudCrosshair" then return false end
end)

-- Helper text layout map
local function HDTS_Text(text, x, y, alignX, alignY, color)
    draw.SimpleText(text, "DermaDefaultBold", x, y, color, alignX or TEXT_ALIGN_LEFT, alignY or TEXT_ALIGN_TOP)
end

hook.Add("HUDPaint", "iw9_ThermalCam.HUD", function()
    if not tcam.active then return end

    local w, h   = ScrW(), ScrH()
    local cx, cy = w / 2, h / 2
    local col    = Color(80, 255, 140, 230)
    local alertCol = Color(255, 140, 80, 230)

    -- Telemetry logic gathering
    local veh = tcam.vehicle
    local pos = IsValid(veh) and veh:GetPos() or Vector(0,0,0)
    local vel = IsValid(veh) and veh:GetVelocity() or Vector(0,0,0)

    -- Rough flight conversions -> Height to Ft, speed approx to Knots
    local alt_feet = math.max(0, pos.z / 12)
    local spd_kts  = vel:Length() * 0.05
    -- Turning Garry's yaw map standard: convert (+left/-right) onto a descending 360-based Aircraft Compass Scale.
    local trueAzimuth = ((-tcam.yaw % 360) + 360) % 360
    local isNarrowFov = tcam.fov < FOV_BASE - 5

    -- Screen boundary offsets for side panel telemetry
    local sLeft   = h * 0.1
    local sRight  = w - (h * 0.1)
    local bHeight = h - (h * 0.1)

    -- Safe/Target framing central brackets
    local fW, fH = w * 0.65, h * 0.65
    local bx, by = cx - fW / 2, cy - fH / 2
    local bL     = h * 0.05

    surface.SetDrawColor(col)

    -- Outer bounding field frames
    surface.DrawLine(bx, by, bx + bL, by)                           -- Top Left L-Bracket
    surface.DrawLine(bx, by, bx, by + bL)
    surface.DrawLine(bx + fW, by, bx + fW - bL, by)                 -- Top Right L-Bracket
    surface.DrawLine(bx + fW, by, bx + fW, by + bL)
    surface.DrawLine(bx, by + fH, bx + bL, by + fH)                 -- Bottom Left L-Bracket
    surface.DrawLine(bx, by + fH, bx, by + fH - bL)
    surface.DrawLine(bx + fW, by + fH, bx + fW - bL, by + fH)       -- Bottom Right L-Bracket
    surface.DrawLine(bx + fW, by + fH, bx + fW, by + fH - bL)

    -- Sight Inner Pitch Horizon Brackets (Static framing structure simulating M-TADS lock borders)
    local pbW = w * 0.15
    local pbH = h * 0.06
    surface.DrawLine(cx - pbW, cy, cx - pbW * 0.6, cy)              -- Horizontal Left Arm
    surface.DrawLine(cx + pbW * 0.6, cy, cx + pbW, cy)              -- Horizontal Right Arm
    surface.DrawLine(cx - pbW, cy, cx - pbW, cy + pbH)              -- Lower drops left
    surface.DrawLine(cx + pbW, cy, cx + pbW, cy + pbH)              -- Lower drops right

    -- Reticle Setup (Gap center cross)
    local gH, lH = h * 0.02, h * 0.04
    surface.DrawLine(cx - gH - lH, cy, cx - gH, cy)
    surface.DrawLine(cx + gH, cy, cx + gH + lH, cy)
    surface.DrawLine(cx, cy - gH - lH, cx, cy - gH)
    surface.DrawLine(cx, cy + gH, cx, cy + gH + lH)
    -- Micro cross dot exactly dead-center
    surface.DrawLine(cx - 3, cy, cx + 3, cy)
    surface.DrawLine(cx, cy - 3, cx, cy + 3)

    -- HEADING TAPE LOGIC
    local tapeSpanDeg = math.Clamp(tcam.fov * 1.5, 30, 90)
    local pxScaleMap  = (fW * 0.7) / tapeSpanDeg
    for degOffset = -45, 45 do
        local markSpanSize = 5
        if degOffset % markSpanSize == 0 then
            local notchAng  = math.floor(trueAzimuth / markSpanSize) * markSpanSize + degOffset
            local diffLeft  = math.AngleDifference(notchAng, trueAzimuth)
            local tapeXPX   = cx + (diffLeft * pxScaleMap)

            if tapeXPX > bx and tapeXPX < bx + fW then
                local isMajor = notchAng % 15 == 0
                surface.DrawLine(tapeXPX, by, tapeXPX, by + (isMajor and 8 or 4))

                if isMajor then
                    local labelAngle = (notchAng + 360) % 360
                    local bearingStr = string.format("%02d", labelAngle / 10)
                    if labelAngle == 0   then bearingStr = "N"
                    elseif labelAngle == 90  then bearingStr = "E"
                    elseif labelAngle == 180 then bearingStr = "S"
                    elseif labelAngle == 270 then bearingStr = "W"
                    end
                    HDTS_Text(bearingStr, tapeXPX, by - 2, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, col)
                end
            end
        end
    end

    -- TELEMETRY READOUT PANELS

    HDTS_Text(string.format("AZ %03.0f°", trueAzimuth), cx, by + 12, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, col)
    HDTS_Text(string.format("EL %s%02.0f°", tcam.pitch < 0 and "-" or "+", math.abs(tcam.pitch)), cx + fW / 2 - bL, by - 4, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, col)

    -- Flank Top-Left Setup  (Mode Status)
    HDTS_Text("MODE : HDTS FLIR", sLeft, sLeft)
    HDTS_Text("WPN  : SAFE", sLeft, sLeft + 15)
    HDTS_Text("LSR  : LRF RDY", sLeft, sLeft + 30)

    -- Flank Bottom-Left Setup  (System Parameters / Optical Modes)
    local factorZOOM = 1 + ((FOV_BASE - tcam.fov) / (FOV_BASE - FOV_MIN) * 9)
    HDTS_Text(isNarrowFov and "SIGHT: TADS/NAR" or "SIGHT: TADS/WID", sLeft, bHeight - 30)
    HDTS_Text(string.format("ZOOM : [%.1fx]", factorZOOM), sLeft, bHeight - 15)

    -- Flank Top-Right Setup
    HDTS_Text(string.format("SPD : %04.0f KTS", spd_kts), sRight, sLeft, TEXT_ALIGN_RIGHT)
    HDTS_Text(string.format("ALT : %04.0f FT", alt_feet), sRight, sLeft + 15, TEXT_ALIGN_RIGHT)
    HDTS_Text(string.format("HDG : %03.0f° TRU", trueAzimuth), sRight, sLeft + 30, TEXT_ALIGN_RIGHT)

    -- Flank Bottom-Right Setup
    local rndLat = math.abs(pos.y * 11) % 100000
    local rndLon = math.abs(pos.x * 11) % 100000
    HDTS_Text(string.format("COORDN : %06.0f", rndLat), sRight, bHeight - 30, TEXT_ALIGN_RIGHT)
    HDTS_Text(string.format("COORDE : %06.0f", rndLon), sRight, bHeight - 15, TEXT_ALIGN_RIGHT)

    -- Lock Indications
    local trackAmountValue = #haloTargets
    if trackAmountValue > 0 then
        local signatureText = trackAmountValue .. " TRK HEAT SGN "
        local fColor = (math.sin(RealTime() * 10) > 0) and alertCol or col
        HDTS_Text(signatureText, cx, by + fH + 5, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, fColor)

        surface.SetDrawColor(alertCol)
        local gap = gH * 2
        local sSz = 8
        local lx, ly = cx - gap, cy - gap
        local rx, ry = cx + gap, cy + gap

        surface.DrawLine(lx, ly, lx + sSz, ly)
        surface.DrawLine(lx, ly, lx, ly + sSz)
        surface.DrawLine(rx, ly, rx - sSz, ly)
        surface.DrawLine(rx, ly, rx, ly + sSz)
        surface.DrawLine(lx, ry, lx + sSz, ry)
        surface.DrawLine(lx, ry, lx, ry - sSz)
        surface.DrawLine(rx, ry, rx - sSz, ry)
        surface.DrawLine(rx, ry, rx, ry - sSz)
    else
        HDTS_Text("0 SGN TRK  [ STNDBY ]", cx, by + fH + 5, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, col)
    end
end)
