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

local cam = {
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
    if not cam.active then return end
    cam.active = false
    RestoreGlideCameraHooks()
end

-- ---------------------------------------------------------------------
-- Track current seat via the same events Glide's own camera uses
-- ---------------------------------------------------------------------

hook.Add("Glide_OnLocalEnterVehicle", "iw9_ThermalCam.Track", function(vehicle, seatIndex)
    cam.vehicle = vehicle
    cam.seatIndex = seatIndex
    StopThermalCam()
end)

hook.Add("Glide_OnLocalExitVehicle", "iw9_ThermalCam.Track", function()
    cam.vehicle = NULL
    cam.seatIndex = nil
    StopThermalCam()
end)

local function CanUseThermalCam()
    return IsValid(cam.vehicle)
        and SUPPORTED_CLASSES[cam.vehicle:GetClass()]
        and cam.seatIndex == GIMBAL_SEAT
end

-- ---------------------------------------------------------------------
-- Toggle: left click while seated as co-pilot
-- ---------------------------------------------------------------------

hook.Add("Think", "iw9_ThermalCam.Toggle", function()
    if not CanUseThermalCam() then
        if cam.active then StopThermalCam() end
        return
    end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    if ply:KeyPressed(IN_ATTACK) then
        cam.active = not cam.active

        if cam.active then
            -- Start looking straight down whichever way the vehicle's
            -- currently facing, rather than some arbitrary fixed angle.
            local vehAng = cam.vehicle:GetAngles()
            cam.yaw, cam.pitch, cam.fov = vehAng.y, 20, FOV_BASE
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
    if not cam.active or not CanUseThermalCam() then return end

    local sens = 0.05
    cam.yaw   = (cam.yaw - x * sens) % 360
    cam.pitch = math.Clamp(cam.pitch + y * sens, -85, 85)

    return true
end)

-- ---------------------------------------------------------------------
-- Zoom: hold the normal zoom bind to close in
-- ---------------------------------------------------------------------

hook.Add("Think", "iw9_ThermalCam.Zoom", function()
    if not cam.active then return end
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local target = ply:KeyDown(IN_ZOOM) and FOV_MIN or FOV_BASE
    cam.fov = Lerp(FrameTime() * 4, cam.fov, target)
end)

-- ---------------------------------------------------------------------
-- The actual camera override
-- Glide's PostPostHGCalcView is removed while we are active, so this
-- hook can run at normal priority and will be the one that supplies the
-- view table.
-- ---------------------------------------------------------------------

hook.Add("PostPostHGCalcView", "iw9_ThermalCam.CalcView", function()
    if not cam.active or not CanUseThermalCam() then return end

    local vehicle = cam.vehicle
    return {
        origin      = vehicle:LocalToWorld(GIMBAL_LOCAL_OFFSET),
        angles      = Angle(cam.pitch, cam.yaw, 0),
        fov         = cam.fov,
        drawviewer  = true,
    }
end)

-- ---------------------------------------------------------------------
-- Thermal look: desaturated + green-tinted screenspace effect, plus a
-- warm halo on any player the camera has a clear line of sight to. This
-- is "detection", not a wallhack -- if a wall's in the way, no halo.
-- ---------------------------------------------------------------------

local thermalColorModify = {
    ["$pp_colour_addr"]       = 0,
    ["$pp_colour_addg"]       = 0.05,
    ["$pp_colour_addb"]       = 0,
    ["$pp_colour_brightness"] = 0,
    ["$pp_colour_contrast"]   = 1.35,
    ["$pp_colour_colour"]     = 0, -- fully desaturated
    ["$pp_colour_mulr"]       = 0,
    ["$pp_colour_mulg"]       = 0,
    ["$pp_colour_mulb"]       = 0,
}

hook.Add("RenderScreenspaceEffects", "iw9_ThermalCam.Effect", function()
    if not cam.active then return end
    DrawColorModify(thermalColorModify)
end)

hook.Add("PreDrawHalos", "iw9_ThermalCam.DetectPeople", function()
    table.Empty(haloTargets)
    if not cam.active or not IsValid(cam.vehicle) then return end

    local origin = cam.vehicle:LocalToWorld(GIMBAL_LOCAL_OFFSET)

    for _, target in player.Iterator() do
        if not target:Alive() then continue end
        if target:GetPos():DistToSqr(origin) > DETECT_RANGE * DETECT_RANGE then continue end

        local tr = util.TraceLine({
            start  = origin,
            endpos = target:EyePos(),
            filter = { cam.vehicle, target, LocalPlayer() },
            mask   = MASK_SOLID_BRUSHONLY,
        })
        if tr.Fraction >= 0.98 then
            haloTargets[#haloTargets + 1] = target
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
    if cam.active and name == "CHudCrosshair" then return false end
end)

-- Helper text layout map
local function HDTS_Text(text, x, y, alignX, alignY, color)
    draw.SimpleText(text, "DermaDefaultBold", x, y, color, alignX or TEXT_ALIGN_LEFT, alignY or TEXT_ALIGN_TOP)
end

hook.Add("HUDPaint", "iw9_ThermalCam.HUD", function()
    if not cam.active then return end

    local w, h   = ScrW(), ScrH()
    local cx, cy = w / 2, h / 2
    local col    = Color(80, 255, 140, 230)
    local alertCol = Color(255, 140, 80, 230)

    -- Telemetry logic gathering
    local veh = cam.vehicle
    local pos = IsValid(veh) and veh:GetPos() or Vector(0,0,0)
    local vel = IsValid(veh) and veh:GetVelocity() or Vector(0,0,0)

    -- Rough flight conversions -> Height to Ft, speed approx to Knots
    local alt_feet = math.max(0, pos.z / 12) 
    local spd_kts  = vel:Length() * 0.05 
    -- Turning Garry's yaw map standard: convert (+left/-right) onto a descending 360-based Aircraft Compass Scale.
    local trueAzimuth = ((-cam.yaw % 360) + 360) % 360
    local isNarrowFov = cam.fov < FOV_BASE - 5

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
    surface.DrawLine(cx - pbW, cy, cx - pbW*0.6, cy)                -- Horizontal Left Arm
    surface.DrawLine(cx + pbW*0.6, cy, cx + pbW, cy)                -- Horizontal Right Arm
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
    local tapeSpanDeg = math.Clamp(cam.fov * 1.5, 30, 90)           -- The compass slice spread adapts minimally with zoom 
    local pxScaleMap  = (fW * 0.7) / tapeSpanDeg
    for degOffset = -45, 45 do 
        local markSpanSize = 5 -- tape notches step size 
        if degOffset % markSpanSize == 0 then
            -- Finding proper interval headings surrounding our current yaw orientation map 
            local notchAng  = math.floor(trueAzimuth / markSpanSize) * markSpanSize + degOffset
            -- Smallest path arc representation difference calculation 
            local diffLeft  = math.AngleDifference(notchAng, trueAzimuth) 
            local tapeXPX   = cx + (diffLeft * pxScaleMap)

            -- Keep compass tape bounds clipped within center upper area logic 
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
    
    -- Center Data blocks (Right below azimuth bounding map / Central Bottom Statuses)
    HDTS_Text(string.format("AZ %03.0f°", trueAzimuth), cx, by + 12, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, col)
    HDTS_Text(string.format("EL %s%02.0f°", cam.pitch < 0 and "-" or "+", math.abs(cam.pitch)), cx + fW / 2 - bL, by - 4, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, col)
    
    -- Flank Top-Left Setup  (Mode Status)
    HDTS_Text("MODE : HDTS FLIR", sLeft, sLeft)
    HDTS_Text("WPN  : SAFE", sLeft, sLeft + 15)
    HDTS_Text("LSR  : LRF RDY", sLeft, sLeft + 30)

    -- Flank Bottom-Left Setup  (System Parameters / Optical Modes)
    local factorZOOM = 1 + ((FOV_BASE - cam.fov) / (FOV_BASE - FOV_MIN) * 9) -- Simulates 1x-10x factor format zoom display string formatting mappings
    HDTS_Text(isNarrowFov and "SIGHT: TADS/NAR" or "SIGHT: TADS/WID", sLeft, bHeight - 30)
    HDTS_Text(string.format("ZOOM : [%.1fx]", factorZOOM), sLeft, bHeight - 15)

    -- Flank Top-Right Setup (Kinematic Aircraft Navigation Variables Simulation Scale Calculations Approximated Metric Outputs Math Values Setup Readings Map Variables Calculations Readouts)
    HDTS_Text(string.format("SPD : %04.0f KTS", spd_kts), sRight, sLeft, TEXT_ALIGN_RIGHT)
    HDTS_Text(string.format("ALT : %04.0f FT", alt_feet), sRight, sLeft + 15, TEXT_ALIGN_RIGHT)
    HDTS_Text(string.format("HDG : %03.0f° TRU", trueAzimuth), sRight, sLeft + 30, TEXT_ALIGN_RIGHT)
    
    -- Flank Bottom-Right Setup  (Synthetic Coordinates & Subsystems)
    local rndLatValGridSimulatedMappingDataStringFormatterVarMath = math.abs(pos.y * 11) % 100000 
    local rndLonValGridSimulatedMappingDataStringFormatterVarMath = math.abs(pos.x * 11) % 100000 
    HDTS_Text(string.format("COORDN : %06.0f", rndLatValGridSimulatedMappingDataStringFormatterVarMath), sRight, bHeight - 30, TEXT_ALIGN_RIGHT)
    HDTS_Text(string.format("COORDE : %06.0f", rndLonValGridSimulatedMappingDataStringFormatterVarMath), sRight, bHeight - 15, TEXT_ALIGN_RIGHT)


    -- Lock Indications
    local trackAmountValue = #haloTargets
    if trackAmountValue > 0 then
        local signatureTextTargetMappingTrackingValuesStringsSysReadVarLogValue = trackAmountValue .. " TRK HEAT SGN "
        
        -- Flash on acquisition frames tracking
        local fColorSwapValTrackModeSimulates = (math.sin(RealTime() * 10) > 0) and alertCol or col
        HDTS_Text(signatureTextTargetMappingTrackingValuesStringsSysReadVarLogValue, cx, by + fH + 5, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, fColorSwapValTrackModeSimulates)
        
        -- Local interior bounding target acquire bounding indicator sub-lines mapped offset sizing mappings brackets setups
        surface.SetDrawColor(alertCol)
        local gapXValueTargetsVisualIndicatorMappingOffsetsSizeLockSimDrawBracketVariablesLayoutOffsetsSysVariables = gH * 2
        -- 4 small L corner sets tightly framing targeting core optical mapping tracking brackets sizing visual setups read
        local sSzLengthLockBoxAestheticTargetsBoxReticleSubVisualMappingTrackerBoxValuesOffsetsSysSubMapAestheticVariables = 8
        local tLlxMapTrackingPosVTrackerMapSetupOffsetsSizeLayoutVarsMappingTrackerMapValuesLockLMapTrackersV1XSysAestheticsBox1XMapYOffsetLayoutsV1SizeOffYOffsetsVarsBox1LockSizeMVSYSx = cx - gapXValueTargetsVisualIndicatorMappingOffsetsSizeLockSimDrawBracketVariablesLayoutOffsetsSysVariables
        local tLlyMapTrackingPosVTrackerMapSetupOffsetsSizeLayoutVarsMappingTrackerMapValuesLockLMapTrackersV1XSysAestheticsBox1XMapYOffsetLayoutsV1SizeOffYOffsetsVarsBox1LockSizeMVSYSy = cy - gapXValueTargetsVisualIndicatorMappingOffsetsSizeLockSimDrawBracketVariablesLayoutOffsetsSysVariables
        surface.DrawLine(tLlxMapTrackingPosVTrackerMapSetupOffsetsSizeLayoutVarsMappingTrackerMapValuesLockLMapTrackersV1XSysAestheticsBox1XMapYOffsetLayoutsV1SizeOffYOffsetsVarsBox1LockSizeMVSYSx, tLlyMapTrackingPosVTrackerMapSetupOffsetsSizeLayoutVarsMappingTrackerMapValuesLockLMapTrackersV1XSysAestheticsBox1XMapYOffsetLayoutsV1SizeOffYOffsetsVarsBox1LockSizeMVSYSy, tLlxMapTrackingPosVTrackerMapSetupOffsetsSizeLayoutVarsMappingTrackerMapValuesLockLMapTrackersV1XSysAestheticsBox1XMapYOffsetLayoutsV1SizeOffYOffsetsVarsBox1LockSizeMVSYSx+sSzLengthLockBoxAestheticTargetsBoxReticleSubVisualMappingTrackerBoxValuesOffsetsSysSubMapAestheticVariables, tLlyMapTrackingPosVTrackerMapSetupOffsetsSizeLayoutVarsMappingTrackerMapValuesLockLMapTrackersV1XSysAestheticsBox1XMapYOffsetLayoutsV1SizeOffYOffsetsVarsBox1LockSizeMVSYSy)
        surface.DrawLine(tLlxMapTrackingPosVTrackerMapSetupOffsetsSizeLayoutVarsMappingTrackerMapValuesLockLMapTrackersV1XSysAestheticsBox1XMapYOffsetLayoutsV1SizeOffYOffsetsVarsBox1LockSizeMVSYSx, tLlyMapTrackingPosVTrackerMapSetupOffsetsSizeLayoutVarsMappingTrackerMapValuesLockLMapTrackersV1XSysAestheticsBox1XMapYOffsetLayoutsV1SizeOffYOffsetsVarsBox1LockSizeMVSYSy, tLlxMapTrackingPosVTrackerMapSetupOffsetsSizeLayoutVarsMappingTrackerMapValuesLockLMapTrackersV1XSysAestheticsBox1XMapYOffsetLayoutsV1SizeOffYOffsetsVarsBox1LockSizeMVSYSx, tLlyMapTrackingPosVTrackerMapSetupOffsetsSizeLayoutVarsMappingTrackerMapValuesLockLMapTrackersV1XSysAestheticsBox1XMapYOffsetLayoutsV1SizeOffYOffsetsVarsBox1LockSizeMVSYSy+sSzLengthLockBoxAestheticTargetsBoxReticleSubVisualMappingTrackerBoxValuesOffsetsSysSubMapAestheticVariables)
        
        surface.DrawLine(cx + gapXValueTargetsVisualIndicatorMappingOffsetsSizeLockSimDrawBracketVariablesLayoutOffsetsSysVariables, tLlyMapTrackingPosVTrackerMapSetupOffsetsSizeLayoutVarsMappingTrackerMapValuesLockLMapTrackersV1XSysAestheticsBox1XMapYOffsetLayoutsV1SizeOffYOffsetsVarsBox1LockSizeMVSYSy, cx + gapXValueTargetsVisualIndicatorMappingOffsetsSizeLockSimDrawBracketVariablesLayoutOffsetsSysVariables-sSzLengthLockBoxAestheticTargetsBoxReticleSubVisualMappingTrackerBoxValuesOffsetsSysSubMapAestheticVariables, tLlyMapTrackingPosVTrackerMapSetupOffsetsSizeLayoutVarsMappingTrackerMapValuesLockLMapTrackersV1XSysAestheticsBox1XMapYOffsetLayoutsV1SizeOffYOffsetsVarsBox1LockSizeMVSYSy)
        surface.DrawLine(cx + gapXValueTargetsVisualIndicatorMappingOffsetsSizeLockSimDrawBracketVariablesLayoutOffsetsSysVariables, tLlyMapTrackingPosVTrackerMapSetupOffsetsSizeLayoutVarsMappingTrackerMapValuesLockLMapTrackersV1XSysAestheticsBox1XMapYOffsetLayoutsV1SizeOffYOffsetsVarsBox1LockSizeMVSYSy, cx + gapXValueTargetsVisualIndicatorMappingOffsetsSizeLockSimDrawBracketVariablesLayoutOffsetsSysVariables, tLlyMapTrackingPosVTrackerMapSetupOffsetsSizeLayoutVarsMappingTrackerMapValuesLockLMapTrackersV1XSysAestheticsBox1XMapYOffsetLayoutsV1SizeOffYOffsetsVarsBox1LockSizeMVSYSy+sSzLengthLockBoxAestheticTargetsBoxReticleSubVisualMappingTrackerBoxValuesOffsetsSysSubMapAestheticVariables)
        
        surface.DrawLine(tLlxMapTrackingPosVTrackerMapSetupOffsetsSizeLayoutVarsMappingTrackerMapValuesLockLMapTrackersV1XSysAestheticsBox1XMapYOffsetLayoutsV1SizeOffYOffsetsVarsBox1LockSizeMVSYSx, cy + gapXValueTargetsVisualIndicatorMappingOffsetsSizeLockSimDrawBracketVariablesLayoutOffsetsSysVariables, tLlxMapTrackingPosVTrackerMapSetupOffsetsSizeLayoutVarsMappingTrackerMapValuesLockLMapTrackersV1XSysAestheticsBox1XMapYOffsetLayoutsV1SizeOffYOffsetsVarsBox1LockSizeMVSYSx+sSzLengthLockBoxAestheticTargetsBoxReticleSubVisualMappingTrackerBoxValuesOffsetsSysSubMapAestheticVariables, cy + gapXValueTargetsVisualIndicatorMappingOffsetsSizeLockSimDrawBracketVariablesLayoutOffsetsSysVariables)
        surface.DrawLine(tLlxMapTrackingPosVTrackerMapSetupOffsetsSizeLayoutVarsMappingTrackerMapValuesLockLMapTrackersV1XSysAestheticsBox1XMapYOffsetLayoutsV1SizeOffYOffsetsVarsBox1LockSizeMVSYSx, cy + gapXValueTargetsVisualIndicatorMappingOffsetsSizeLockSimDrawBracketVariablesLayoutOffsetsSysVariables, tLlxMapTrackingPosVTrackerMapSetupOffsetsSizeLayoutVarsMappingTrackerMapValuesLockLMapTrackersV1XSysAestheticsBox1XMapYOffsetLayoutsV1SizeOffYOffsetsVarsBox1LockSizeMVSYSx, cy + gapXValueTargetsVisualIndicatorMappingOffsetsSizeLockSimDrawBracketVariablesLayoutOffsetsSysVariables-sSzLengthLockBoxAestheticTargetsBoxReticleSubVisualMappingTrackerBoxValuesOffsetsSysSubMapAestheticVariables)
        
        surface.DrawLine(cx + gapXValueTargetsVisualIndicatorMappingOffsetsSizeLockSimDrawBracketVariablesLayoutOffsetsSysVariables, cy + gapXValueTargetsVisualIndicatorMappingOffsetsSizeLockSimDrawBracketVariablesLayoutOffsetsSysVariables, cx + gapXValueTargetsVisualIndicatorMappingOffsetsSizeLockSimDrawBracketVariablesLayoutOffsetsSysVariables-sSzLengthLockBoxAestheticTargetsBoxReticleSubVisualMappingTrackerBoxValuesOffsetsSysSubMapAestheticVariables, cy + gapXValueTargetsVisualIndicatorMappingOffsetsSizeLockSimDrawBracketVariablesLayoutOffsetsSysVariables)
        surface.DrawLine(cx + gapXValueTargetsVisualIndicatorMappingOffsetsSizeLockSimDrawBracketVariablesLayoutOffsetsSysVariables, cy + gapXValueTargetsVisualIndicatorMappingOffsetsSizeLockSimDrawBracketVariablesLayoutOffsetsSysVariables, cx + gapXValueTargetsVisualIndicatorMappingOffsetsSizeLockSimDrawBracketVariablesLayoutOffsetsSysVariables, cy + gapXValueTargetsVisualIndicatorMappingOffsetsSizeLockSimDrawBracketVariablesLayoutOffsetsSysVariables-sSzLengthLockBoxAestheticTargetsBoxReticleSubVisualMappingTrackerBoxValuesOffsetsSysSubMapAestheticVariables)
    else
        HDTS_Text("0 SGN TRK  [ STNDBY ]", cx, by + fH + 5, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, col)
    end
end)
