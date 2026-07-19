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
-- Gimbal dynamics (electro-optical turret simulation)
--
-- Real belly-mounted FLIR/TADS gimbals are NOT free-look mice:
--   * motors have max slew rate (slower when zoomed in)
--   * acceleration is limited (they ramp up / coast to a stop)
--   * gyros stabilize against airframe motion, but not perfectly
--   * rotor wash + airframe flex inject micro-vibration (worse at zoom)
--   * hard slews induce a tiny mechanical roll cant
-- ---------------------------------------------------------------------
local SLEW_RATE_WIDE   = 110   -- deg/s max at FOV_BASE
local SLEW_RATE_NARROW = 18    -- deg/s max at FOV_MIN (telephoto crawl)
local SLEW_ACCEL       = 420   -- deg/s^2 motor acceleration
local SETTLE_STIFFNESS = 14    -- spring gain for final approach to target
local SETTLE_DAMPING   = 9     -- velocity damping on settle
local STAB_BLEED       = 0.035 -- fraction of airframe angular rate that leaks through
local VIB_BASE         = 0.04  -- base vibration amplitude (degrees)
local VIB_SPEED_SCALE  = 0.000035
local VIB_ZOOM_POWER   = 1.35  -- vibration grows with zoom
local ROLL_FROM_YAW    = 0.045 -- dynamic roll per (deg/s) of yaw rate
local ROLL_RETURN      = 6     -- how fast roll settles back to 0

local cam = {
    active    = false,
    vehicle   = NULL,
    seatIndex = nil,

    -- Operator command (where the stick wants to look)
    cmdYaw    = 0,
    cmdPitch  = 20,

    -- Actual gimbal pose (what the sensor is pointing at)
    yaw       = 0,
    pitch     = 20,
    roll      = 0,

    -- Angular rates of the gimbal itself (deg/s)
    rateYaw   = 0,
    ratePitch = 0,

    fov       = FOV_BASE,
    lastZoom  = false,

    -- Airframe tracking for stabilization bleed
    prevVehAng = nil,

    -- Composite shake applied on top of the pose each frame
    shakeP    = 0,
    shakeY    = 0,
    shakeR    = 0,
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
    cam.rateYaw, cam.ratePitch = 0, 0
    cam.roll = 0
    cam.shakeP, cam.shakeY, cam.shakeR = 0, 0, 0
    cam.prevVehAng = nil
    RestoreGlideCameraHooks()
end

-- ---------------------------------------------------------------------
-- Physical Camera Collision Resolution Helper Functions.
-- Ensures the view stays entirely clear without peeking beyond map bounds.
-- ---------------------------------------------------------------------
local function GetSafeCameraOrigin(vehicle)
    if not IsValid(vehicle) then return Vector() end

    -- Avoid shooting bounding-traces diagonally out from origin through body chunks;
    -- instead we spawn safely *inside* above the pod vertically then strictly trace
    -- straight downwards to rest it firmly above surfaces/hillsides if clipping.
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

-- Max slew rate interpolates between wide and narrow FOV limits.
local function GetMaxSlewRate()
    local t = math.Clamp((cam.fov - FOV_MIN) / (FOV_BASE - FOV_MIN), 0, 1)
    -- Smoothstep so the crawl-in feels natural as optics tighten.
    t = t * t * (3 - 2 * t)
    return Lerp(t, SLEW_RATE_NARROW, SLEW_RATE_WIDE)
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
-- Toggle: left click while seated as co-pilot AND unarmed
-- ---------------------------------------------------------------------

hook.Add("Think", "iw9_ThermalCam.Toggle", function()
    if not CanUseThermalCam() then
        if cam.active then StopThermalCam() end
        return
    end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    if ply:KeyPressed(IN_ATTACK) then
        -- WEAPON FILTER: Disallow thermal control panel toggle if holding a functional weapon.
        local activeWep = ply:GetActiveWeapon()
        local isUnarmed = not IsValid(activeWep) or activeWep:GetClass() == "weapon_hands_sh"

        if not isUnarmed then return end

        cam.active = not cam.active

        if cam.active then
            -- Boot the gimbal looking roughly along the airframe heading,
            -- slightly nose-down — typical search posture.
            local vehAng = cam.vehicle:GetAngles()
            cam.cmdYaw   = vehAng.y
            cam.cmdPitch = 20
            cam.yaw      = vehAng.y
            cam.pitch    = 20
            cam.roll     = 0
            cam.rateYaw  = 0
            cam.ratePitch = 0
            cam.fov      = FOV_BASE
            cam.lastZoom = false
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
-- Mouse look: operator command only.
-- Deltas update the *commanded* look direction. The physical gimbal
-- chases that command in Think with real motor limits — so flinging the
-- mouse does not teleport the sensor, it just asks the motors to catch up.
-- Sensitivity scales with FOV so telephoto tracking stays precise.
-- ---------------------------------------------------------------------

hook.Add("InputMouseApply", "iw9_ThermalCam.Mouse", function(cmd, x, y, ang)
    if not cam.active or not CanUseThermalCam() then return end

    local fovMul = cam.fov / FOV_BASE
    -- Slightly non-linear: very small motions stay fine, big flicks still register.
    local sens = 0.048 * fovMul

    cam.cmdYaw   = (cam.cmdYaw - x * sens) % 360
    cam.cmdPitch = math.Clamp(cam.cmdPitch + y * sens, -85, 85)

    return true
end)

-- ---------------------------------------------------------------------
-- Gimbal servo integration + FOV zoom
-- Runs every frame while active: motors, stabilization bleed, vibration.
-- ---------------------------------------------------------------------

local function AngleDiffDeg(a, b)
    local d = (a - b) % 360
    if d > 180 then d = d - 360 end
    return d
end

hook.Add("Think", "iw9_ThermalCam.GimbalDynamics", function()
    if not cam.active or not CanUseThermalCam() then return end

    local dt = FrameTime()
    if dt <= 0 then return end
    -- Hard cap so a hitch doesn't yeet the gimbal across the sky.
    dt = math.min(dt, 0.05)

    local vehicle = cam.vehicle
    local maxRate = GetMaxSlewRate()

    -- --- Error from actual pose to commanded pose ---
    local errYaw   = AngleDiffDeg(cam.cmdYaw, cam.yaw)
    local errPitch = cam.cmdPitch - cam.pitch

    -- Desired rates: proportional (spring) toward the command, clamped to max slew.
    -- When far away this is rate-limited; when close the spring settles smoothly.
    local desireYaw   = math.Clamp(errYaw   * SETTLE_STIFFNESS, -maxRate, maxRate)
    local desirePitch = math.Clamp(errPitch * SETTLE_STIFFNESS, -maxRate, maxRate)

    -- Motor acceleration toward desired rates (inertia).
    local function ApproachRate(current, desire, accel)
        local delta = desire - current
        local step  = accel * dt
        if math.abs(delta) <= step then return desire end
        return current + math.Clamp(delta, -step, step)
    end

    cam.rateYaw   = ApproachRate(cam.rateYaw,   desireYaw,   SLEW_ACCEL)
    cam.ratePitch = ApproachRate(cam.ratePitch, desirePitch, SLEW_ACCEL)

    -- Extra damping so it doesn't oscillate around the target.
    cam.rateYaw   = cam.rateYaw   * math.max(0, 1 - SETTLE_DAMPING * dt * 0.15)
    cam.ratePitch = cam.ratePitch * math.max(0, 1 - SETTLE_DAMPING * dt * 0.15)

    -- Integrate pose.
    cam.yaw   = (cam.yaw + cam.rateYaw * dt) % 360
    cam.pitch = math.Clamp(cam.pitch + cam.ratePitch * dt, -85, 85)

    -- --- Imperfect gyro stabilization ---
    -- A real gimbal rejects most airframe motion. A few percent still leaks
    -- through as residual drift the operator has to correct.
    local vehAng = vehicle:GetAngles()
    if cam.prevVehAng then
        local dPitch = AngleDiffDeg(vehAng.p, cam.prevVehAng.p) / dt
        local dYaw   = AngleDiffDeg(vehAng.y, cam.prevVehAng.y) / dt
        local dRoll  = AngleDiffDeg(vehAng.r, cam.prevVehAng.r) / dt

        cam.yaw   = (cam.yaw   + dYaw   * STAB_BLEED * dt) % 360
        cam.pitch = math.Clamp(cam.pitch + dPitch * STAB_BLEED * dt, -85, 85)

        -- Command drifts with the leak too, so the operator doesn't fight a
        -- constantly re-opening error when the ship banks steadily.
        cam.cmdYaw   = (cam.cmdYaw   + dYaw   * STAB_BLEED * dt) % 360
        cam.cmdPitch = math.Clamp(cam.cmdPitch + dPitch * STAB_BLEED * dt, -85, 85)

        -- Roll disturbance from airframe roll rate (tiny).
        cam.roll = cam.roll + dRoll * STAB_BLEED * 0.25 * dt
    end
    cam.prevVehAng = Angle(vehAng.p, vehAng.y, vehAng.r)

    -- Dynamic roll cant from hard yaw slews (mechanical gimbal coupling),
    -- then spring back to level.
    local targetRoll = -cam.rateYaw * ROLL_FROM_YAW
    cam.roll = Lerp(math.min(1, ROLL_RETURN * dt), cam.roll, targetRoll)
    cam.roll = math.Clamp(cam.roll, -6, 6)

    -- --- Rotor / airframe vibration ---
    -- Amplitude grows with airspeed and zoom. Frequencies sit in the
    -- "helicopter rattle" band so it reads as mechanical, not noise.
    local speed = vehicle:GetVelocity():Length()
    local zoomMul = (FOV_BASE / math.max(cam.fov, FOV_MIN)) ^ VIB_ZOOM_POWER
    local amp = (VIB_BASE + speed * VIB_SPEED_SCALE) * zoomMul

    local t = RealTime()
    -- Two incommensurate frequencies per axis → organic, non-repeating shake.
    cam.shakeP = math.sin(t * 17.3) * amp * 0.55
               + math.sin(t * 29.1) * amp * 0.25
    cam.shakeY = math.sin(t * 19.7) * amp * 0.45
               + math.cos(t * 23.4) * amp * 0.30
    cam.shakeR = math.sin(t * 13.2) * amp * 0.20
end)

-- ---------------------------------------------------------------------
-- Realistic Camera Lens Optical Swapping on Right Click hold
-- ---------------------------------------------------------------------

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
    -- Servo-style optic train: fast at first, eases into the stop.
    cam.fov = Lerp(math.min(FrameTime() * 8, 1), cam.fov, targetFov)
end)

-- ---------------------------------------------------------------------
-- The actual camera override
-- ---------------------------------------------------------------------

hook.Add("PostPostHGCalcView", "iw9_ThermalCam.CalcView", function()
    if not cam.active or not CanUseThermalCam() then return end

    local vehicle = cam.vehicle
    local origin  = GetSafeCameraOrigin(vehicle)

    -- Composite final look: gimbal pose + residual shake.
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
-- Thermal look: desaturated + green-tinted screenspace effect, plus a
-- warm halo on any living player (standing or ragdolled) the camera has
-- a clear line of sight to. Dead players and the local thermal operator
-- are never marked. This is "detection", not a wallhack -- if a wall's
-- in the way, no halo.
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

        -- Outer soft thermal bloom
        halo.Add(haloTargets, Color(200, 255, 200, pulse * 0.4), 4, 4, 1, true, false)
        -- Inner white-hot core
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
    local pos = IsValid(veh) and veh:GetPos() or Vector(0,0,0)
    local vel = IsValid(veh) and veh:GetVelocity() or Vector(0,0,0)

    local alt_feet = math.max(0, pos.z / 12)
    local spd_kts  = vel:Length() * 0.05
    -- Display the *actual* gimbal heading (not the raw command) so the
    -- tape matches what the sensor is seeing during a slew lag.
    local trueAzimuth = ((-cam.yaw % 360) + 360) % 360
    local isNarrowFov = cam.fov < FOV_BASE - 5

    local sLeft   = h * 0.1
    local sRight  = w - (h * 0.1)
    local bHeight = h - (h * 0.1)

    local fW, fH = w * 0.65, h * 0.65
    local bx, by = cx - fW / 2, cy - fH / 2
    local bL     = h * 0.05

    surface.SetDrawColor(col)

    -- Outer bounding field frames
    surface.DrawLine(bx, by, bx + bL, by)
    surface.DrawLine(bx, by, bx, by + bL)
    surface.DrawLine(bx + fW, by, bx + fW - bL, by)
    surface.DrawLine(bx + fW, by, bx + fW, by + bL)
    surface.DrawLine(bx, by + fH, bx + bL, by + fH)
    surface.DrawLine(bx, by + fH, bx, by + fH - bL)
    surface.DrawLine(bx + fW, by + fH, bx + fW - bL, by + fH)
    surface.DrawLine(bx + fW, by + fH, bx + fW, by + fH - bL)

    -- Sight inner pitch horizon brackets
    local pbW = w * 0.15
    local pbH = h * 0.06
    surface.DrawLine(cx - pbW, cy, cx - pbW * 0.6, cy)
    surface.DrawLine(cx + pbW * 0.6, cy, cx + pbW, cy)
    surface.DrawLine(cx - pbW, cy, cx - pbW, cy + pbH)
    surface.DrawLine(cx + pbW, cy, cx + pbW, cy + pbH)

    -- Reticle
    local gH, lH = h * 0.02, h * 0.04
    surface.DrawLine(cx - gH - lH, cy, cx - gH, cy)
    surface.DrawLine(cx + gH, cy, cx + gH + lH, cy)
    surface.DrawLine(cx, cy - gH - lH, cx, cy - gH)
    surface.DrawLine(cx, cy + gH, cx, cy + gH + lH)
    surface.DrawLine(cx - 3, cy, cx + 3, cy)
    surface.DrawLine(cx, cy - 3, cx, cy + 3)

    -- Heading tape
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

    -- On-screen signature count + per-target brackets
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
