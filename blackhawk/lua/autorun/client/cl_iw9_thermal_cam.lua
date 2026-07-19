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

-- Camera bounding settings to avoid Near-Z visual clipping against ground/walls.
local CAM_HULL_RADIUS   = 6
local CAM_COLLISION_MIN = Vector(-CAM_HULL_RADIUS, -CAM_HULL_RADIUS, -CAM_HULL_RADIUS)
local CAM_COLLISION_MAX = Vector(CAM_HULL_RADIUS, CAM_HULL_RADIUS, CAM_HULL_RADIUS)

-- ---------------------------------------------------------------------
-- Gimbal dynamics
--
-- World-stabilized EO turret:
--   * command pose is pure operator intent (mouse)
--   * actual pose critically-damps toward command (no overshoot → no
--     counter-steering fight)
--   * airframe motion does NOT continuously drag the look vector
--     (that was the old STAB_BLEED bug); residual disturbance is a
--     short-lived decaying kick only
--   * spinning rate gyros produce orthogonal precession during slew
--   * rotor wash adds micro-vibration (stronger at zoom / airspeed)
-- ---------------------------------------------------------------------
local SLEW_RATE_WIDE   = 120   -- deg/s max at FOV_BASE
local SLEW_RATE_NARROW = 22    -- deg/s max at FOV_MIN
local SLEW_ACCEL       = 520   -- deg/s^2 motor torque limit
local OMEGA            = 16    -- natural frequency of the pose spring (rad-ish / s)
-- Critical damping ratio ζ = 1 → 2ζω = 2*OMEGA. Slightly overdamped (1.15)
-- so it never rings past the command.
local ZETA             = 1.15
local LOCK_EPS_ANG     = 0.08  -- deg — snap lock when this close
local LOCK_EPS_RATE    = 0.5   -- deg/s

-- Gyro precession: torque about one axis couples into the orthogonal axis.
-- τ = Ω × L  →  small cross-rate while slewing hard.
local PRECESS_GAIN     = 0.085 -- fraction of on-axis rate that appears cross-axis
local PRECESS_DECAY    = 8     -- how fast free precession dies out (1/s)

-- Transient residual from abrupt airframe jolts (not continuous bleed).
local JOLT_GAIN        = 0.012
local JOLT_DECAY       = 5
local JOLT_THRESH      = 40    -- deg/s airframe rate before a jolt registers

local VIB_BASE         = 0.03
local VIB_SPEED_SCALE  = 0.000028
local VIB_ZOOM_POWER   = 1.3
local ROLL_FROM_YAW    = 0.03
local ROLL_RETURN      = 8

local cam = {
    active    = false,
    vehicle   = NULL,
    seatIndex = nil,

    cmdYaw    = 0,
    cmdPitch  = 20,

    yaw       = 0,
    pitch     = 20,
    roll      = 0,

    rateYaw   = 0,
    ratePitch = 0,

    -- Orthogonal precession rates (gyroscopic)
    precYaw   = 0,
    precPitch = 0,

    -- Decaying residual from airframe jolts
    joltYaw   = 0,
    joltPitch = 0,

    fov       = FOV_BASE,
    lastZoom  = false,

    prevVehAng = nil,

    shakeP    = 0,
    shakeY    = 0,
    shakeR    = 0,

    -- Thermal blooming intensity 0..1 (driven by on-screen heat)
    bloom     = 0,
}

local haloTargets = {}

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
    cam.rateYaw, cam.ratePitch = 0, 0
    cam.precYaw, cam.precPitch = 0, 0
    cam.joltYaw, cam.joltPitch = 0, 0
    cam.roll = 0
    cam.shakeP, cam.shakeY, cam.shakeR = 0, 0, 0
    cam.bloom = 0
    cam.prevVehAng = nil
    RestoreGlideCameraHooks()
end

local function GetSafeCameraOrigin(vehicle)
    if not IsValid(vehicle) then return Vector() end

    local startWorld = vehicle:LocalToWorld(Vector(GIMBAL_LOCAL_OFFSET.x, GIMBAL_LOCAL_OFFSET.y, 30))
    local idealPos   = vehicle:LocalToWorld(GIMBAL_LOCAL_OFFSET)

    local tr = util.TraceHull({
        start  = startWorld,
        endpos = idealPos,
        mins   = CAM_COLLISION_MIN,
        maxs   = CAM_COLLISION_MAX,
        mask   = MASK_SOLID,
        filter = function(ent)
            if not IsValid(ent) then return true end
            if ent:IsPlayer() or ent:IsNPC() then return false end

            local current = ent
            while IsValid(current) do
                if current == vehicle then return false end
                current = current:GetParent()
            end

            return true
        end
    })

    return tr.HitPos
end

local function GetMaxSlewRate()
    local t = math.Clamp((cam.fov - FOV_MIN) / (FOV_BASE - FOV_MIN), 0, 1)
    t = t * t * (3 - 2 * t)
    return Lerp(t, SLEW_RATE_NARROW, SLEW_RATE_WIDE)
end

local function AngleDiffDeg(a, b)
    local d = (a - b) % 360
    if d > 180 then d = d - 360 end
    return d
end

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

hook.Add("Think", "iw9_ThermalCam.Toggle", function()
    if not CanUseThermalCam() then
        if cam.active then StopThermalCam() end
        return
    end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    if ply:KeyPressed(IN_ATTACK) then
        local activeWep = ply:GetActiveWeapon()
        local isUnarmed = not IsValid(activeWep) or activeWep:GetClass() == "weapon_hands_sh"
        if not isUnarmed then return end

        cam.active = not cam.active

        if cam.active then
            local vehAng = cam.vehicle:GetAngles()
            cam.cmdYaw    = vehAng.y
            cam.cmdPitch  = 20
            cam.yaw       = vehAng.y
            cam.pitch     = 20
            cam.roll      = 0
            cam.rateYaw   = 0
            cam.ratePitch = 0
            cam.precYaw   = 0
            cam.precPitch = 0
            cam.joltYaw   = 0
            cam.joltPitch = 0
            cam.fov       = FOV_BASE
            cam.lastZoom  = false
            cam.bloom     = 0
            cam.prevVehAng = Angle(vehAng.p, vehAng.y, vehAng.r)
            cam.shakeP, cam.shakeY, cam.shakeR = 0, 0, 0
            SuppressGlideCameraHooks()
            surface.PlaySound("buttons/button24.wav")
        else
            RestoreGlideCameraHooks()
            surface.PlaySound("buttons/button10.wav")
        end
    end
end)

-- ---------------------------------------------------------------------
-- Mouse → command pose only. FOV-scaled sensitivity.
-- ---------------------------------------------------------------------

hook.Add("InputMouseApply", "iw9_ThermalCam.Mouse", function(cmd, x, y, ang)
    if not cam.active or not CanUseThermalCam() then return end

    local sens = 0.048 * (cam.fov / FOV_BASE)

    cam.cmdYaw   = (cam.cmdYaw - x * sens) % 360
    cam.cmdPitch = math.Clamp(cam.cmdPitch + y * sens, -85, 85)

    return true
end)

-- ---------------------------------------------------------------------
-- Critically-damped gimbal + gyro precession + residual jolts
-- ---------------------------------------------------------------------

hook.Add("Think", "iw9_ThermalCam.GimbalDynamics", function()
    if not cam.active or not CanUseThermalCam() then return end

    local dt = FrameTime()
    if dt <= 0 then return end
    dt = math.min(dt, 0.05)

    local vehicle = cam.vehicle
    local maxRate = GetMaxSlewRate()

    -- Error to operator command (shortest arc on yaw).
    local errYaw   = AngleDiffDeg(cam.cmdYaw, cam.yaw)
    local errPitch = cam.cmdPitch - cam.pitch

    -- Second-order critically/over-damped spring:
    --   a = ω²·err − 2ζω·rate
    -- Integrated with an acceleration clamp so motors still feel physical.
    local twoZetaOmega = 2 * ZETA * OMEGA
    local omegaSq      = OMEGA * OMEGA

    local accYaw   = errYaw   * omegaSq - cam.rateYaw   * twoZetaOmega
    local accPitch = errPitch * omegaSq - cam.ratePitch * twoZetaOmega

    accYaw   = math.Clamp(accYaw,   -SLEW_ACCEL, SLEW_ACCEL)
    accPitch = math.Clamp(accPitch, -SLEW_ACCEL, SLEW_ACCEL)

    cam.rateYaw   = math.Clamp(cam.rateYaw   + accYaw   * dt, -maxRate, maxRate)
    cam.ratePitch = math.Clamp(cam.ratePitch + accPitch * dt, -maxRate, maxRate)

    -- Snap-lock when we're basically there — kills residual micro-drift
    -- that used to force tiny counter-corrections.
    if math.abs(errYaw) < LOCK_EPS_ANG and math.abs(cam.rateYaw) < LOCK_EPS_RATE then
        cam.yaw     = cam.cmdYaw
        cam.rateYaw = 0
    else
        cam.yaw = (cam.yaw + cam.rateYaw * dt) % 360
    end

    if math.abs(errPitch) < LOCK_EPS_ANG and math.abs(cam.ratePitch) < LOCK_EPS_RATE then
        cam.pitch     = cam.cmdPitch
        cam.ratePitch = 0
    else
        cam.pitch = math.Clamp(cam.pitch + cam.ratePitch * dt, -85, 85)
    end

    -- -----------------------------------------------------------------
    -- Gyroscopic precession
    -- A spinning rate-gyro (spin axis ≈ sensor bore-sight) responds to a
    -- commanded torque about yaw by precessing about pitch, and vice
    -- versa. Direction follows the right-hand rule relative to spin.
    -- We drive a small cross-rate from the *motor* rates, then let free
    -- precession decay once the slew stops — visible as a soft orthogonal
    -- drift during hard pans, not a constant fight.
    -- -----------------------------------------------------------------
    local drivePrecPitch =  cam.rateYaw   * PRECESS_GAIN
    local drivePrecYaw   = -cam.ratePitch * PRECESS_GAIN

    -- Blend toward the driven cross-rate while slewing; otherwise decay.
    local slewMag = math.abs(cam.rateYaw) + math.abs(cam.ratePitch)
    if slewMag > 1 then
        cam.precPitch = Lerp(math.min(1, 10 * dt), cam.precPitch, drivePrecPitch)
        cam.precYaw   = Lerp(math.min(1, 10 * dt), cam.precYaw,   drivePrecYaw)
    else
        local decay = math.max(0, 1 - PRECESS_DECAY * dt)
        cam.precPitch = cam.precPitch * decay
        cam.precYaw   = cam.precYaw   * decay
    end

    -- Apply precession as a soft offset to the *displayed* pose via the
    -- command-tracking path: nudge actual angles, and nudge command the
    -- same amount so the operator is not forced to counter-steer it away.
    -- (It reads as the whole reticle drifting slightly cross-axis mid-slew.)
    local precYawStep   = cam.precYaw   * dt
    local precPitchStep = cam.precPitch * dt
    cam.yaw      = (cam.yaw      + precYawStep) % 360
    cam.cmdYaw   = (cam.cmdYaw   + precYawStep) % 360
    cam.pitch    = math.Clamp(cam.pitch    + precPitchStep, -85, 85)
    cam.cmdPitch = math.Clamp(cam.cmdPitch + precPitchStep, -85, 85)

    -- -----------------------------------------------------------------
    -- Airframe jolt residual (NOT continuous bleed)
    -- Only large, sudden vehicle angular rates inject a kick that then
    -- decays. Steady turns no longer drag the look vector.
    -- -----------------------------------------------------------------
    local vehAng = vehicle:GetAngles()
    if cam.prevVehAng then
        local dPitch = AngleDiffDeg(vehAng.p, cam.prevVehAng.p) / dt
        local dYaw   = AngleDiffDeg(vehAng.y, cam.prevVehAng.y) / dt
        local dRoll  = AngleDiffDeg(vehAng.r, cam.prevVehAng.r) / dt

        if math.abs(dYaw) > JOLT_THRESH then
            cam.joltYaw = cam.joltYaw + dYaw * JOLT_GAIN
        end
        if math.abs(dPitch) > JOLT_THRESH then
            cam.joltPitch = cam.joltPitch + dPitch * JOLT_GAIN
        end

        -- Tiny roll disturbance from sharp roll inputs.
        if math.abs(dRoll) > JOLT_THRESH then
            cam.roll = cam.roll + dRoll * JOLT_GAIN * 0.15
        end
    end
    cam.prevVehAng = Angle(vehAng.p, vehAng.y, vehAng.r)

    local joltDecay = math.max(0, 1 - JOLT_DECAY * dt)
    cam.joltYaw   = cam.joltYaw   * joltDecay
    cam.joltPitch = cam.joltPitch * joltDecay

    -- Jolt affects actual pose + command equally (stabilized hold of a
    -- ground point still drifts together; no counter-steer required).
    if math.abs(cam.joltYaw) > 0.0001 then
        local step = cam.joltYaw * dt * 10
        cam.yaw    = (cam.yaw    + step) % 360
        cam.cmdYaw = (cam.cmdYaw + step) % 360
    end
    if math.abs(cam.joltPitch) > 0.0001 then
        local step = cam.joltPitch * dt * 10
        cam.pitch    = math.Clamp(cam.pitch    + step, -85, 85)
        cam.cmdPitch = math.Clamp(cam.cmdPitch + step, -85, 85)
    end

    -- Dynamic roll cant from yaw rate, spring home.
    local targetRoll = -cam.rateYaw * ROLL_FROM_YAW
    cam.roll = Lerp(math.min(1, ROLL_RETURN * dt), cam.roll, targetRoll)
    cam.roll = math.Clamp(cam.roll, -5, 5)

    -- Rotor / airframe vibration
    local speed = vehicle:GetVelocity():Length()
    local zoomMul = (FOV_BASE / math.max(cam.fov, FOV_MIN)) ^ VIB_ZOOM_POWER
    local amp = (VIB_BASE + speed * VIB_SPEED_SCALE) * zoomMul
    local t = RealTime()
    cam.shakeP = math.sin(t * 17.3) * amp * 0.55 + math.sin(t * 29.1) * amp * 0.25
    cam.shakeY = math.sin(t * 19.7) * amp * 0.45 + math.cos(t * 23.4) * amp * 0.30
    cam.shakeR = math.sin(t * 13.2) * amp * 0.20

    -- Thermal bloom intensity eases toward scene heat load.
    local heatLoad = math.Clamp(#haloTargets / 6, 0, 1)
    -- Fast slews also smear the sensor (integration bloom).
    local smear = math.Clamp(slewMag / maxRate, 0, 1) * 0.35
    local targetBloom = math.Clamp(heatLoad * 0.75 + smear, 0, 1)
    cam.bloom = Lerp(math.min(1, 4 * dt), cam.bloom, targetBloom)
end)

hook.Add("Think", "iw9_ThermalCam.Zoom", function()
    if not cam.active then return end
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local wantZoom = ply:KeyDown(IN_ATTACK2)

    if wantZoom ~= cam.lastZoom then
        surface.PlaySound("thermal/zoomin.ogg")
        cam.lastZoom = wantZoom
    end

    local targetFov = wantZoom and FOV_MIN or FOV_BASE
    cam.fov = Lerp(math.min(FrameTime() * 8, 1), cam.fov, targetFov)
end)

hook.Add("PostPostHGCalcView", "iw9_ThermalCam.CalcView", function()
    if not cam.active or not CanUseThermalCam() then return end

    local origin = GetSafeCameraOrigin(cam.vehicle)

    local ang = Angle(
        cam.pitch + cam.shakeP,
        cam.yaw   + cam.shakeY,
        cam.roll  + cam.shakeR
    )

    return {
        origin     = origin,
        angles     = ang,
        fov        = cam.fov,
        drawviewer = true,
    }
end)

-- ---------------------------------------------------------------------
-- Thermal grade + blooming
-- Bright heat sources wash the focal plane: contrast collapses, a warm
-- green haze lifts, and engine-style bloom flares. Intensity tracks
-- cam.bloom (on-screen signatures + slew smear).
-- ---------------------------------------------------------------------

local thermalColorModify = {
    ["$pp_colour_addr"]       = 0,
    ["$pp_colour_addg"]       = 0.05,
    ["$pp_colour_addb"]       = 0,
    ["$pp_colour_brightness"] = 0,
    ["$pp_colour_contrast"]   = 1.35,
    ["$pp_colour_colour"]     = 0,
    ["$pp_colour_mulr"]       = 0,
    ["$pp_colour_mulg"]       = 0,
    ["$pp_colour_mulb"]       = 0,
}

hook.Add("RenderScreenspaceEffects", "iw9_ThermalCam.Effect", function()
    if not cam.active then return end

    local b = cam.bloom

    -- Base FLIR grade, softened as bloom rises (hot scene washes detail).
    thermalColorModify["$pp_colour_contrast"]   = Lerp(b, 1.35, 0.95)
    thermalColorModify["$pp_colour_brightness"] = Lerp(b, 0.00, 0.08)
    thermalColorModify["$pp_colour_addg"]       = Lerp(b, 0.05, 0.12)
    thermalColorModify["$pp_colour_addr"]       = Lerp(b, 0.00, 0.03)
    DrawColorModify(thermalColorModify)

    -- Heat bloom: darken threshold drops and blur widens with load so
    -- white-hot bodies flare into neighbouring pixels.
    local darken = Lerp(b, 0.75, 0.35)
    local mul    = Lerp(b, 1.2,  2.8)
    local blurx  = Lerp(b, 4,    14)
    local blury  = Lerp(b, 4,    14)
    local passes = math.floor(Lerp(b, 1, 3) + 0.5)
    DrawBloom(darken, mul, blurx, blury, passes, 1, 0.55, 1.0, 0.45)

    -- Fast slew smear — the FPA integrates while the gimbal is moving.
    if b > 0.15 then
        DrawMotionBlur(0.08 + b * 0.12, 0.6 + b * 0.25, 0.01)
    end
end)

local function GetCharacterEyePos(character)
    if character:IsPlayer() then
        return character:EyePos()
    end

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
    if not cam.active or not IsValid(cam.vehicle) then return end

    local origin = GetSafeCameraOrigin(cam.vehicle)
    local me = LocalPlayer()

    for _, target in player.Iterator() do
        if target == me then continue end
        if not target:Alive() then continue end

        local character = IsValid(target.FakeRagdoll) and target.FakeRagdoll or target

        if character:GetPos():DistToSqr(origin) > DETECT_RANGE * DETECT_RANGE then continue end

        local eyePos = GetCharacterEyePos(character)

        local tr = util.TraceLine({
            start  = origin,
            endpos = eyePos,
            filter = { cam.vehicle, character, target, me },
            mask   = MASK_SOLID_BRUSHONLY,
        })
        if tr.Fraction >= 0.98 then
            haloTargets[#haloTargets + 1] = character
        end
    end

    if #haloTargets > 0 then
        local pulse = 220 + math.sin(RealTime() * 15) * 35
        local b = cam.bloom

        -- Bloom-scaled halo: outer bloom corona grows with scene heat.
        local outer = 4 + b * 6
        halo.Add(haloTargets, Color(200, 255, 200, (pulse * 0.35) * (0.7 + b * 0.6)), outer, outer, 1, true, false)
        -- Mid thermal wash
        halo.Add(haloTargets, Color(230, 255, 230, 180 + b * 60), 2 + b * 2, 2 + b * 2, 2, true, false)
        -- White-hot core
        halo.Add(haloTargets, Color(pulse, pulse, pulse, 255), 1, 1, 3, true, false)
    end
end)

-- ---------------------------------------------------------------------
-- HDTS HUD Layout
-- ---------------------------------------------------------------------

hook.Add("HUDShouldDraw", "iw9_ThermalCam.HideDefaultHUD", function(name)
    if cam.active and name == "CHudCrosshair" then return false end
end)

local function HDTS_Text(text, x, y, alignX, alignY, color)
    draw.SimpleText(text, "DermaDefaultBold", x, y, color, alignX or TEXT_ALIGN_LEFT, alignY or TEXT_ALIGN_TOP)
end

hook.Add("HUDPaint", "iw9_ThermalCam.HUD", function()
    if not cam.active then return end

    local w, h   = ScrW(), ScrH()
    local cx, cy = w / 2, h / 2
    local col    = Color(80, 255, 140, 230)
    local alertCol = Color(255, 140, 80, 230)

    local veh = cam.vehicle
    local pos = IsValid(veh) and veh:GetPos() or Vector(0, 0, 0)
    local vel = IsValid(veh) and veh:GetVelocity() or Vector(0, 0, 0)

    local alt_feet = math.max(0, pos.z / 12)
    local spd_kts  = vel:Length() * 0.05
    local trueAzimuth = ((-cam.yaw % 360) + 360) % 360
    local isNarrowFov = cam.fov < FOV_BASE - 5

    local sLeft   = h * 0.1
    local sRight  = w - (h * 0.1)
    local bHeight = h - (h * 0.1)

    local fW, fH = w * 0.65, h * 0.65
    local bx, by = cx - fW / 2, cy - fH / 2
    local bL     = h * 0.05

    surface.SetDrawColor(col)

    surface.DrawLine(bx, by, bx + bL, by)
    surface.DrawLine(bx, by, bx, by + bL)
    surface.DrawLine(bx + fW, by, bx + fW - bL, by)
    surface.DrawLine(bx + fW, by, bx + fW, by + bL)
    surface.DrawLine(bx, by + fH, bx + bL, by + fH)
    surface.DrawLine(bx, by + fH, bx, by + fH - bL)
    surface.DrawLine(bx + fW, by + fH, bx + fW - bL, by + fH)
    surface.DrawLine(bx + fW, by + fH, bx + fW, by + fH - bL)

    local pbW = w * 0.15
    local pbH = h * 0.06
    surface.DrawLine(cx - pbW, cy, cx - pbW * 0.6, cy)
    surface.DrawLine(cx + pbW * 0.6, cy, cx + pbW, cy)
    surface.DrawLine(cx - pbW, cy, cx - pbW, cy + pbH)
    surface.DrawLine(cx + pbW, cy, cx + pbW, cy + pbH)

    local gH, lH = h * 0.02, h * 0.04
    surface.DrawLine(cx - gH - lH, cy, cx - gH, cy)
    surface.DrawLine(cx + gH, cy, cx + gH + lH, cy)
    surface.DrawLine(cx, cy - gH - lH, cx, cy - gH)
    surface.DrawLine(cx, cy + gH, cx, cy + gH + lH)
    surface.DrawLine(cx - 3, cy, cx + 3, cy)
    surface.DrawLine(cx, cy - 3, cx, cy + 3)

    local tapeSpanDeg = math.Clamp(cam.fov * 1.5, 30, 90)
    local pxScaleMap  = (fW * 0.7) / tapeSpanDeg
    for degOffset = -45, 45 do
        local markSpanSize = 5
        if degOffset % markSpanSize == 0 then
            local notchAng = math.floor(trueAzimuth / markSpanSize) * markSpanSize + degOffset
            local diffLeft = math.AngleDifference(notchAng, trueAzimuth)
            local tapeXPX  = cx + (diffLeft * pxScaleMap)

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

    HDTS_Text(string.format("AZ %03.0f°", trueAzimuth), cx, by + 12, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, col)
    HDTS_Text(string.format("EL %s%02.0f°", cam.pitch < 0 and "-" or "+", math.abs(cam.pitch)), cx + fW / 2 - bL, by - 4, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, col)

    HDTS_Text("MODE : HDTS FLIR", sLeft, sLeft)
    HDTS_Text("WPN  : SAFE", sLeft, sLeft + 15)
    HDTS_Text("LSR  : LRF RDY", sLeft, sLeft + 30)

    local factorZOOM = 1 + ((FOV_BASE - cam.fov) / (FOV_BASE - FOV_MIN) * 9)
    HDTS_Text(isNarrowFov and "SIGHT: TADS/NAR" or "SIGHT: TADS/WID", sLeft, bHeight - 30)
    HDTS_Text(string.format("ZOOM : [%.1fx]", factorZOOM), sLeft, bHeight - 15)

    HDTS_Text(string.format("SPD : %04.0f KTS", spd_kts), sRight, sLeft, TEXT_ALIGN_RIGHT)
    HDTS_Text(string.format("ALT : %04.0f FT", alt_feet), sRight, sLeft + 15, TEXT_ALIGN_RIGHT)
    HDTS_Text(string.format("HDG : %03.0f° TRU", trueAzimuth), sRight, sLeft + 30, TEXT_ALIGN_RIGHT)

    local rndLat = math.abs(pos.y * 11) % 100000
    local rndLon = math.abs(pos.x * 11) % 100000
    HDTS_Text(string.format("COORDN : %06.0f", rndLat), sRight, bHeight - 30, TEXT_ALIGN_RIGHT)
    HDTS_Text(string.format("COORDE : %06.0f", rndLon), sRight, bHeight - 15, TEXT_ALIGN_RIGHT)

    local onScreenSignatures = {}
    for i = 1, #haloTargets do
        local tgt = haloTargets[i]
        if IsValid(tgt) then
            local tgtPos = tgt.WorldSpaceCenter and tgt:WorldSpaceCenter() or (tgt:GetPos() + Vector(0, 0, 35))
            local sc = tgtPos:ToScreen()
            if sc.visible and sc.x >= 0 and sc.x <= w and sc.y >= 0 and sc.y <= h then
                onScreenSignatures[#onScreenSignatures + 1] = { x = sc.x, y = sc.y }
            end
        end
    end

    local trackAmountValue = #onScreenSignatures
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

        for i = 1, trackAmountValue do
            local scPos = onScreenSignatures[i]
            local sx, sy = scPos.x, scPos.y
            local sz, sl = 12, 4

            surface.DrawLine(sx - sz, sy - sz, sx - sz + sl, sy - sz)
            surface.DrawLine(sx - sz, sy - sz, sx - sz, sy - sz + sl)
            surface.DrawLine(sx + sz, sy - sz, sx + sz - sl, sy - sz)
            surface.DrawLine(sx + sz, sy - sz, sx + sz, sy - sz + sl)
            surface.DrawLine(sx - sz, sy + sz, sx - sz + sl, sy + sz)
            surface.DrawLine(sx - sz, sy + sz, sx - sz, sy + sz - sl)
            surface.DrawLine(sx + sz, sy + sz, sx + sz - sl, sy + sz)
            surface.DrawLine(sx + sz, sy + sz, sx + sz, sy + sz - sl)
            surface.DrawRect(sx - 1, sy - 1, 2, 2)
        end
    else
        HDTS_Text("0 SGN TRK  [ STNDBY ]", cx, by + fH + 5, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, col)
    end
end)
