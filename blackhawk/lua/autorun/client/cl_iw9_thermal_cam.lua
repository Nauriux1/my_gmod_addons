-- Co-pilot (seat 2) thermal gimbal camera for the Vulture (iw9_veh_blima).
--
-- Left click while seated as co-pilot deploys a belly FLIR gimbal, then
-- enables free look, thermal grade, heat detection, hard-lock track, and LRF.
-- Stowing (LMB while deployed, not zoom-locking) runs the reverse sequence.
--
-- While deployed:
--   * Hold RMB + LMB on a player → hard lock / unlock
--   * Zoom still works while locked
--   * R → LRF pulse
--   * HUD shows target angular rate, estimated speed, and lead offsets
--
-- Deliberately NOT added to iw9_veh_blima_gship.
-- Client-only, purely visual/read-only.

if not CLIENT then return end
if not Glide then return end

hg.vehiclecamblacklist = hg.vehiclecamblacklist or {}
hg.vehiclecamblacklist["iw9_veh_blima"] = true

local SUPPORTED_CLASSES = { iw9_veh_blima = true }
local GIMBAL_SEAT = 2

local GIMBAL_LOCAL_OFFSET = Vector(100, -10, -50)
local FOV_BASE, FOV_MIN = 50, 15
local DETECT_RANGE = 4000
local TOGGLE_COOLDOWN = 0.45
local LOCK_AIM_DOT = 0.96

local LRF_MAX_UNITS   = 12000
local LRF_COOLDOWN    = 1.25
local LRF_HOLD_TIME   = 10
local LRF_FLASH_TIME  = 0.4
local UNITS_TO_METERS = 0.01905
local UNITS_TO_FEET   = 0.0625

-- Stow / deploy timing
local DEPLOY_TIME = 1.7
local STOW_TIME   = 1.3

-- Lead display: how many seconds of pure angular lead to draw on the pip
local LEAD_TIME = 0.4

local CAM_HULL_RADIUS   = 6
local CAM_COLLISION_MIN = Vector(-CAM_HULL_RADIUS, -CAM_HULL_RADIUS, -CAM_HULL_RADIUS)
local CAM_COLLISION_MAX = Vector(CAM_HULL_RADIUS, CAM_HULL_RADIUS, CAM_HULL_RADIUS)

local SLEW_RATE_WIDE   = 120
local SLEW_RATE_NARROW = 22
local SLEW_ACCEL       = 520
local OMEGA            = 16
local ZETA             = 1.15
local LOCK_EPS_ANG     = 0.08
local LOCK_EPS_RATE    = 0.5

local PRECESS_GAIN     = 0.085
local PRECESS_DECAY    = 8

local JOLT_GAIN        = 0.012
local JOLT_DECAY       = 5
local JOLT_THRESH      = 40

local VIB_BASE         = 0.03
local VIB_SPEED_SCALE  = 0.000028
local VIB_ZOOM_POWER   = 1.3
local ROLL_FROM_YAW    = 0.03
local ROLL_RETURN      = 8

-- deployState: "stowed" | "deploying" | "deployed" | "stowing"
local cam = {
    active      = false,
    vehicle     = NULL,
    seatIndex   = nil,

    deployState = "stowed",
    deployFrac  = 0,

    cmdYaw      = 0,
    cmdPitch    = 20,

    yaw         = 0,
    pitch       = 20,
    roll        = 0,

    rateYaw     = 0,
    ratePitch   = 0,

    precYaw     = 0,
    precPitch   = 0,

    joltYaw     = 0,
    joltPitch   = 0,

    fov         = FOV_BASE,
    lastZoom    = false,

    prevVehAng  = nil,

    shakeP      = 0,
    shakeY      = 0,
    shakeR      = 0,

    nextToggle  = 0,

    lockTarget  = NULL,

    rmbHeld     = false,

    lrfNext     = 0,
    lrfTime     = 0,
    lrfFlash    = 0,
    lrfValid    = false,
    lrfUnits    = 0,
    lrfMeters   = 0,
    lrfFeet     = 0,

    -- Target kinematics (deg/s, kts, lead deg)
    tgtRateAz   = 0,
    tgtRateEl   = 0,
    tgtSpeedKts = 0,
    leadAz      = 0,
    leadEl      = 0,
    prevTgtAng  = nil,
    prevTgtPos  = nil,
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

local function ClearLock(playSound)
    local had = IsValid(cam.lockTarget)
    cam.lockTarget = NULL
    cam.tgtRateAz, cam.tgtRateEl = 0, 0
    cam.tgtSpeedKts = 0
    cam.leadAz, cam.leadEl = 0, 0
    cam.prevTgtAng = nil
    cam.prevTgtPos = nil
    if playSound and had then
        surface.PlaySound("buttons/button10.wav")
    end
end

local function ClearLRF()
    cam.lrfValid  = false
    cam.lrfUnits  = 0
    cam.lrfMeters = 0
    cam.lrfFeet   = 0
    cam.lrfTime   = 0
    cam.lrfFlash  = 0
end

local function IsDeployed()
    return cam.deployState == "deployed"
end

local function IsSensorLive()
    -- Full FLIR / lock / LRF only when fully out.
    return cam.active and cam.deployState == "deployed"
end

local function FinishStow()
    cam.active = false
    cam.deployState = "stowed"
    cam.deployFrac = 0
    cam.rateYaw, cam.ratePitch = 0, 0
    cam.precYaw, cam.precPitch = 0, 0
    cam.joltYaw, cam.joltPitch = 0, 0
    cam.roll = 0
    cam.shakeP, cam.shakeY, cam.shakeR = 0, 0, 0
    cam.prevVehAng = nil
    ClearLock(false)
    ClearLRF()
    RestoreGlideCameraHooks()
end

local function StopThermalCam()
    -- Immediate hard stop (seat exit / invalid). Skips stow animation.
    if not cam.active and cam.deployState == "stowed" then return end
    FinishStow()
end

local function CanUseThermalCam()
    return IsValid(cam.vehicle)
        and SUPPORTED_CLASSES[cam.vehicle:GetClass()]
        and cam.seatIndex == GIMBAL_SEAT
end

local function BeginDeploy()
    if cam.deployState ~= "stowed" then return end
    if not CanUseThermalCam() then return end

    local vehAng = cam.vehicle:GetAngles()
    cam.active      = true
    cam.deployState = "deploying"
    cam.deployFrac  = 0
    cam.cmdYaw      = vehAng.y
    cam.cmdPitch    = 20
    cam.yaw         = vehAng.y
    cam.pitch       = 20
    cam.roll        = 0
    cam.rateYaw     = 0
    cam.ratePitch   = 0
    cam.precYaw     = 0
    cam.precPitch   = 0
    cam.joltYaw     = 0
    cam.joltPitch   = 0
    cam.fov         = FOV_BASE
    cam.lastZoom    = false
    cam.prevVehAng  = Angle(vehAng.p, vehAng.y, vehAng.r)
    cam.shakeP, cam.shakeY, cam.shakeR = 0, 0, 0
    ClearLock(false)
    ClearLRF()
    cam.lrfNext = 0
    SuppressGlideCameraHooks()
    surface.PlaySound("buttons/lever7.wav")
end

local function BeginStow()
    if cam.deployState ~= "deployed" and cam.deployState ~= "deploying" then return end
    ClearLock(false)
    ClearLRF()
    cam.deployState = "stowing"
    surface.PlaySound("buttons/lever8.wav")
end

local function IsRMBDown(ply)
    if cam.rmbHeld then return true end
    if input.IsMouseDown(MOUSE_RIGHT) then return true end
    if IsValid(ply) and ply:KeyDown(IN_ATTACK2) then return true end
    return false
end

local function WantsLockNotExit(ply)
    if IsRMBDown(ply) then return true end
    if cam.fov < (FOV_BASE - 3) then return true end
    return false
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

local function IsUnarmed(ply)
    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) then return true end

    local cls = wep:GetClass()
    if cls == "weapon_hands_sh"
    or cls == "weapon_hands"
    or cls == "weapon_fists"
    or cls == "none"
    then
        return true
    end

    if string.find(cls, "hands", 1, true) then
        return true
    end

    return false
end

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

local function GetPlayerCharacter(ply)
    if not IsValid(ply) then return nil end
    if IsValid(ply.FakeRagdoll) then return ply.FakeRagdoll end
    return ply
end

local function ResolvePlayerFromEntity(ent)
    if not IsValid(ent) then return nil end
    if ent:IsPlayer() then return ent end

    for _, ply in player.Iterator() do
        if IsValid(ply.FakeRagdoll) and ply.FakeRagdoll == ent then
            return ply
        end
    end

    return nil
end

local function HasLOSToPlayer(ply)
    if not IsValid(ply) or not ply:Alive() then return false end
    if not IsValid(cam.vehicle) then return false end

    local character = GetPlayerCharacter(ply)
    if not IsValid(character) then return false end

    local origin = GetSafeCameraOrigin(cam.vehicle)
    local eyePos = GetCharacterEyePos(character)
    local me = LocalPlayer()

    local tr = util.TraceLine({
        start  = origin,
        endpos = eyePos,
        filter = { cam.vehicle, character, ply, me },
        mask   = MASK_SOLID_BRUSHONLY,
    })

    return tr.Fraction >= 0.98
end

local function FindAimPlayer()
    if not IsValid(cam.vehicle) then return nil end

    local origin = GetSafeCameraOrigin(cam.vehicle)
    local ang = Angle(cam.pitch, cam.yaw, 0)
    local fwd = ang:Forward()
    local me = LocalPlayer()

    local tr = util.TraceLine({
        start  = origin,
        endpos = origin + fwd * DETECT_RANGE,
        filter = { cam.vehicle, me },
        mask   = MASK_SHOT,
    })

    local hitPly = ResolvePlayerFromEntity(tr.Entity)
    if hitPly and hitPly ~= me and hitPly:Alive() and HasLOSToPlayer(hitPly) then
        return hitPly
    end

    local best, bestDot = nil, LOCK_AIM_DOT
    for _, ply in player.Iterator() do
        if ply == me or not ply:Alive() then continue end
        if not HasLOSToPlayer(ply) then continue end

        local character = GetPlayerCharacter(ply)
        local eyePos = GetCharacterEyePos(character)
        local dir = (eyePos - origin)
        local dist = dir:Length()
        if dist < 1 or dist > DETECT_RANGE then continue end

        local dot = fwd:Dot(dir / dist)
        if dot > bestDot then
            bestDot = dot
            best = ply
        end
    end

    return best
end

local function SetLock(ply)
    cam.lockTarget = ply
    cam.rateYaw, cam.ratePitch = 0, 0
    cam.precYaw, cam.precPitch = 0, 0
    cam.joltYaw, cam.joltPitch = 0, 0
    cam.prevTgtAng = nil
    cam.prevTgtPos = nil
    cam.tgtRateAz, cam.tgtRateEl = 0, 0
    cam.leadAz, cam.leadEl = 0, 0
    surface.PlaySound("buttons/button17.wav")
end

local function ToggleLock()
    if not IsSensorLive() then return end

    if IsValid(cam.lockTarget) then
        ClearLock(true)
        return
    end

    local tgt = FindAimPlayer()
    if tgt then
        SetLock(tgt)
    else
        surface.PlaySound("buttons/button8.wav")
    end
end

local function PulseLRF()
    if not IsSensorLive() then return false end

    local now = CurTime()
    if now < cam.lrfNext then
        surface.PlaySound("buttons/button10.wav")
        return true
    end

    local origin = GetSafeCameraOrigin(cam.vehicle)
    local ang = Angle(cam.pitch, cam.yaw, 0)

    if IsValid(cam.lockTarget) then
        local character = GetPlayerCharacter(cam.lockTarget)
        if IsValid(character) then
            ang = (GetCharacterEyePos(character) - origin):Angle()
        end
    end

    local me = LocalPlayer()
    local tr = util.TraceLine({
        start  = origin,
        endpos = origin + ang:Forward() * LRF_MAX_UNITS,
        filter = { cam.vehicle, me },
        mask   = MASK_SHOT,
    })

    cam.lrfTime  = now
    cam.lrfNext  = now + LRF_COOLDOWN
    cam.lrfFlash = now + LRF_FLASH_TIME

    if tr.Hit and not tr.HitSky then
        local units = origin:Distance(tr.HitPos)
        cam.lrfValid  = true
        cam.lrfUnits  = units
        cam.lrfMeters = units * UNITS_TO_METERS
        cam.lrfFeet   = units * UNITS_TO_FEET
        surface.PlaySound("buttons/blip1.wav")
    else
        cam.lrfValid  = false
        cam.lrfUnits  = 0
        cam.lrfMeters = 0
        cam.lrfFeet   = 0
        surface.PlaySound("buttons/button8.wav")
    end

    return true
end

local function LRFHoldActive()
    return cam.lrfTime > 0 and (CurTime() - cam.lrfTime) < LRF_HOLD_TIME
end

local function GetLRFStatus()
    local now = CurTime()
    if now < cam.lrfFlash then
        return cam.lrfValid and "LRF FIRE" or "LRF NO RTN"
    end
    if now < cam.lrfNext then
        return "LRF HOLD"
    end
    return "LRF RDY"
end

hook.Add("Glide_OnLocalEnterVehicle", "iw9_ThermalCam.Track", function(vehicle, seatIndex)
    cam.vehicle = vehicle
    cam.seatIndex = seatIndex
    cam.nextToggle = 0
    cam.rmbHeld = false
    StopThermalCam()
end)

hook.Add("Glide_OnLocalExitVehicle", "iw9_ThermalCam.Track", function()
    cam.vehicle = NULL
    cam.seatIndex = nil
    cam.nextToggle = 0
    cam.rmbHeld = false
    StopThermalCam()
end)

hook.Add("PlayerBindPress", "iw9_ThermalCam.RMB", function(ply, bind, pressed)
    if ply ~= LocalPlayer() then return end
    if bind == "+attack2" then
        cam.rmbHeld = pressed and true or false
    end
end)

hook.Add("PlayerBindPress", "iw9_ThermalCam.Toggle", function(ply, bind, pressed)
    if not pressed then return end
    if ply ~= LocalPlayer() then return end
    if bind ~= "+attack" then return end
    if not CanUseThermalCam() then return end

    local now = CurTime()

    if now < cam.nextToggle then
        if cam.active then return true end
        return
    end

    -- Busy deploying/stowing: swallow click, don't reverse mid-cycle.
    if cam.deployState == "deploying" or cam.deployState == "stowing" then
        return true
    end

    if cam.deployState == "deployed" then
        if WantsLockNotExit(ply) then
            ToggleLock()
            cam.nextToggle = now + TOGGLE_COOLDOWN
            return true
        end

        BeginStow()
        cam.nextToggle = now + TOGGLE_COOLDOWN
        return true
    end

    -- Stowed → deploy
    if not IsUnarmed(ply) then return end

    BeginDeploy()
    cam.nextToggle = now + TOGGLE_COOLDOWN
    return true
end)

hook.Add("PlayerBindPress", "iw9_ThermalCam.LRF", function(ply, bind, pressed)
    if not pressed then return end
    if ply ~= LocalPlayer() then return end
    if bind ~= "+reload" then return end
    if not IsSensorLive() then return end

    PulseLRF()
    return true
end)

-- ---------------------------------------------------------------------
-- Deploy / stow animation driver
-- ---------------------------------------------------------------------

hook.Add("Think", "iw9_ThermalCam.Deploy", function()
    if not cam.active then return end

    local dt = FrameTime()
    if dt <= 0 then return end

    if cam.deployState == "deploying" then
        cam.deployFrac = math.min(1, cam.deployFrac + dt / DEPLOY_TIME)
        if cam.deployFrac >= 1 then
            cam.deployState = "deployed"
            cam.deployFrac = 1
            surface.PlaySound("buttons/button24.wav")
        end
    elseif cam.deployState == "stowing" then
        cam.deployFrac = math.max(0, cam.deployFrac - dt / STOW_TIME)
        if cam.deployFrac <= 0 then
            FinishStow()
            surface.PlaySound("buttons/button10.wav")
        end
    end
end)

hook.Add("Think", "iw9_ThermalCam.Safety", function()
    if cam.active and not CanUseThermalCam() then
        StopThermalCam()
    end

    if cam.active and cam.rmbHeld and not input.IsMouseDown(MOUSE_RIGHT) then
        local ply = LocalPlayer()
        if not (IsValid(ply) and ply:KeyDown(IN_ATTACK2)) then
            cam.rmbHeld = false
        end
    end

    if IsSensorLive() and cam.lrfTime > 0 and not LRFHoldActive() then
        ClearLRF()
    end
end)

-- ---------------------------------------------------------------------
-- Lock track + target rate / lead computation
-- ---------------------------------------------------------------------

hook.Add("Think", "iw9_ThermalCam.LockTrack", function()
    if not IsSensorLive() then return end
    if not IsValid(cam.lockTarget) then
        cam.lockTarget = NULL
        cam.tgtRateAz, cam.tgtRateEl = 0, 0
        cam.tgtSpeedKts = 0
        cam.leadAz, cam.leadEl = 0, 0
        cam.prevTgtAng = nil
        cam.prevTgtPos = nil
        return
    end

    local ply = cam.lockTarget

    if not ply:Alive() or not HasLOSToPlayer(ply) then
        ClearLock(true)
        return
    end

    local dt = FrameTime()
    if dt <= 0 then return end
    dt = math.min(dt, 0.05)

    local character = GetPlayerCharacter(ply)
    local origin = GetSafeCameraOrigin(cam.vehicle)
    local aimPos = GetCharacterEyePos(character)
    local ang = (aimPos - origin):Angle()

    cam.cmdYaw   = ang.y
    cam.cmdPitch = math.Clamp(ang.p, -85, 85)

    -- Angular rate of the line-of-sight vector (deg/s).
    if cam.prevTgtAng then
        local rawAz = AngleDiffDeg(ang.y, cam.prevTgtAng.y) / dt
        local rawEl = (ang.p - cam.prevTgtAng.p) / dt
        -- Light smoothing so the HUD doesn't chatter.
        cam.tgtRateAz = Lerp(math.min(1, 10 * dt), cam.tgtRateAz, rawAz)
        cam.tgtRateEl = Lerp(math.min(1, 10 * dt), cam.tgtRateEl, rawEl)
    end
    cam.prevTgtAng = Angle(ang.p, ang.y, 0)

    -- Estimated target ground speed (same kts scale as aircraft HUD).
    local vel = ply:GetVelocity()
    if IsValid(character) and not character:IsPlayer() then
        -- Ragdoll: approximate from position delta if velocity is dead.
        if cam.prevTgtPos then
            local d = (aimPos - cam.prevTgtPos):Length() / dt
            cam.tgtSpeedKts = Lerp(math.min(1, 6 * dt), cam.tgtSpeedKts, d * 0.05)
        end
    else
        cam.tgtSpeedKts = Lerp(math.min(1, 6 * dt), cam.tgtSpeedKts, vel:Length() * 0.05)
    end
    cam.prevTgtPos = aimPos

    -- Pure angular lead pip (seconds of motion ahead of current LOS).
    cam.leadAz = cam.tgtRateAz * LEAD_TIME
    cam.leadEl = cam.tgtRateEl * LEAD_TIME
end)

hook.Add("InputMouseApply", "iw9_ThermalCam.Mouse", function(cmd, x, y, ang)
    if not cam.active or not CanUseThermalCam() then return end
    -- No free-look until fully deployed; swallow so vehicle cam stays suppressed.
    if not IsDeployed() then return true end

    if IsValid(cam.lockTarget) then
        return true
    end

    local sens = 0.048 * (cam.fov / FOV_BASE)

    cam.cmdYaw   = (cam.cmdYaw - x * sens) % 360
    cam.cmdPitch = math.Clamp(cam.cmdPitch + y * sens, -85, 85)

    return true
end)

hook.Add("Think", "iw9_ThermalCam.GimbalDynamics", function()
    if not cam.active or not CanUseThermalCam() then return end
    if cam.deployState == "stowed" then return end

    local dt = FrameTime()
    if dt <= 0 then return end
    dt = math.min(dt, 0.05)

    local vehicle = cam.vehicle
    local maxRate = GetMaxSlewRate()
    local isLocked = IsValid(cam.lockTarget) and IsDeployed()

    if isLocked then
        maxRate = math.max(maxRate, 45)
    end

    -- During deploy/stow, hold a fixed nose-down search pose.
    if not IsDeployed() then
        local vehAng = vehicle:GetAngles()
        cam.cmdYaw   = vehAng.y
        cam.cmdPitch = 25
    end

    local errYaw   = AngleDiffDeg(cam.cmdYaw, cam.yaw)
    local errPitch = cam.cmdPitch - cam.pitch

    local twoZetaOmega = 2 * ZETA * OMEGA
    local omegaSq      = OMEGA * OMEGA

    local accYaw   = errYaw   * omegaSq - cam.rateYaw   * twoZetaOmega
    local accPitch = errPitch * omegaSq - cam.ratePitch * twoZetaOmega

    accYaw   = math.Clamp(accYaw,   -SLEW_ACCEL, SLEW_ACCEL)
    accPitch = math.Clamp(accPitch, -SLEW_ACCEL, SLEW_ACCEL)

    cam.rateYaw   = math.Clamp(cam.rateYaw   + accYaw   * dt, -maxRate, maxRate)
    cam.ratePitch = math.Clamp(cam.ratePitch + accPitch * dt, -maxRate, maxRate)

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

    local slewMag = math.abs(cam.rateYaw) + math.abs(cam.ratePitch)

    if IsDeployed() and not isLocked then
        local drivePrecPitch =  cam.rateYaw   * PRECESS_GAIN
        local drivePrecYaw   = -cam.ratePitch * PRECESS_GAIN

        if slewMag > 1 then
            cam.precPitch = Lerp(math.min(1, 10 * dt), cam.precPitch, drivePrecPitch)
            cam.precYaw   = Lerp(math.min(1, 10 * dt), cam.precYaw,   drivePrecYaw)
        else
            local decay = math.max(0, 1 - PRECESS_DECAY * dt)
            cam.precPitch = cam.precPitch * decay
            cam.precYaw   = cam.precYaw   * decay
        end

        local precYawStep   = cam.precYaw   * dt
        local precPitchStep = cam.precPitch * dt
        cam.yaw      = (cam.yaw      + precYawStep) % 360
        cam.cmdYaw   = (cam.cmdYaw   + precYawStep) % 360
        cam.pitch    = math.Clamp(cam.pitch    + precPitchStep, -85, 85)
        cam.cmdPitch = math.Clamp(cam.cmdPitch + precPitchStep, -85, 85)

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
            if math.abs(dRoll) > JOLT_THRESH then
                cam.roll = cam.roll + dRoll * JOLT_GAIN * 0.15
            end
        end
        cam.prevVehAng = Angle(vehAng.p, vehAng.y, vehAng.r)

        local joltDecay = math.max(0, 1 - JOLT_DECAY * dt)
        cam.joltYaw   = cam.joltYaw   * joltDecay
        cam.joltPitch = cam.joltPitch * joltDecay

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
    else
        local vehAng = vehicle:GetAngles()
        cam.prevVehAng = Angle(vehAng.p, vehAng.y, vehAng.r)
        if isLocked or not IsDeployed() then
            cam.precYaw, cam.precPitch = 0, 0
            cam.joltYaw, cam.joltPitch = 0, 0
        end
    end

    local targetRoll = -cam.rateYaw * ROLL_FROM_YAW
    cam.roll = Lerp(math.min(1, ROLL_RETURN * dt), cam.roll, targetRoll)
    cam.roll = math.Clamp(cam.roll, -5, 5)

    local speed = vehicle:GetVelocity():Length()
    local zoomMul = (FOV_BASE / math.max(cam.fov, FOV_MIN)) ^ VIB_ZOOM_POWER
    local amp = (VIB_BASE + speed * VIB_SPEED_SCALE) * zoomMul
    -- Mute vibration until fully deployed.
    if not IsDeployed() then amp = amp * cam.deployFrac * 0.3 end
    local t = RealTime()
    cam.shakeP = math.sin(t * 17.3) * amp * 0.55 + math.sin(t * 29.1) * amp * 0.25
    cam.shakeY = math.sin(t * 19.7) * amp * 0.45 + math.cos(t * 23.4) * amp * 0.30
    cam.shakeR = math.sin(t * 13.2) * amp * 0.20
end)

hook.Add("Think", "iw9_ThermalCam.Zoom", function()
    if not IsSensorLive() then return end
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local wantZoom = IsRMBDown(ply)

    if wantZoom ~= cam.lastZoom then
        surface.PlaySound("thermal/zoomin.ogg")
        cam.lastZoom = wantZoom
    end

    local targetFov = wantZoom and FOV_MIN or FOV_BASE
    cam.fov = Lerp(math.min(FrameTime() * 8, 1), cam.fov, targetFov)
end)

hook.Add("PostPostHGCalcView", "iw9_ThermalCam.CalcView", function()
    if not cam.active or not CanUseThermalCam() then return end
    if cam.deployFrac <= 0.02 then return end

    local origin = GetSafeCameraOrigin(cam.vehicle)

    -- During deploy the pod eases out of a raised/stowed pose.
    local stowLift = (1 - cam.deployFrac) * 18
    origin = origin + Vector(0, 0, stowLift)

    local ang = Angle(
        cam.pitch + cam.shakeP,
        cam.yaw   + cam.shakeY,
        cam.roll  + cam.shakeR
    )

    -- FOV slightly wider while the doors are still opening.
    local fov = Lerp(cam.deployFrac, FOV_BASE + 20, cam.fov)

    return {
        origin     = origin,
        angles     = ang,
        fov        = fov,
        drawviewer = true,
    }
end)

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
    if not IsSensorLive() then return end
    DrawColorModify(thermalColorModify)
end)

hook.Add("PreDrawHalos", "iw9_ThermalCam.DetectPeople", function()
    table.Empty(haloTargets)
    if not IsSensorLive() or not IsValid(cam.vehicle) then return end

    local origin = GetSafeCameraOrigin(cam.vehicle)
    local me = LocalPlayer()

    for _, target in player.Iterator() do
        if target == me then continue end
        if not target:Alive() then continue end

        local character = GetPlayerCharacter(target)

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

        halo.Add(haloTargets, Color(200, 255, 200, pulse * 0.35), 4, 4, 1, true, false)
        halo.Add(haloTargets, Color(230, 255, 230, 180), 2, 2, 2, true, false)
        halo.Add(haloTargets, Color(pulse, pulse, pulse, 255), 1, 1, 3, true, false)

        if IsValid(cam.lockTarget) then
            local lockChar = GetPlayerCharacter(cam.lockTarget)
            if IsValid(lockChar) then
                halo.Add({ lockChar }, Color(255, 160, 60, 255), 3, 3, 2, true, false)
            end
        end
    end
end)

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
    local lockCol  = Color(255, 200, 60, 240)
    local lrfCol   = Color(120, 220, 255, 240)

    local sLeft   = h * 0.1
    local sRight  = w - (h * 0.1)
    local bHeight = h - (h * 0.1)

    -- Deploy / stow progress screen
    if cam.deployState == "deploying" or cam.deployState == "stowing" then
        local pct = math.floor(cam.deployFrac * 100)
        local label = cam.deployState == "deploying" and "GIMBAL DEPLOYING" or "GIMBAL STOWING"
        local barW, barH = w * 0.28, 8
        local bx = cx - barW / 2
        local by = cy + h * 0.06

        surface.SetDrawColor(0, 0, 0, 160)
        surface.DrawRect(0, 0, w, h)

        HDTS_Text(label, cx, cy - 20, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, col)
        HDTS_Text(string.format("%d%%", pct), cx, cy + 4, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, col)

        surface.SetDrawColor(40, 80, 50, 220)
        surface.DrawOutlinedRect(bx, by, barW, barH)
        surface.SetDrawColor(80, 255, 140, 230)
        surface.DrawRect(bx + 1, by + 1, (barW - 2) * cam.deployFrac, barH - 2)
        return
    end

    if not IsDeployed() then return end

    local veh = cam.vehicle
    local pos = IsValid(veh) and veh:GetPos() or Vector(0, 0, 0)
    local vel = IsValid(veh) and veh:GetVelocity() or Vector(0, 0, 0)

    local alt_feet = math.max(0, pos.z / 12)
    local spd_kts  = vel:Length() * 0.05
    local trueAzimuth = ((-cam.yaw % 360) + 360) % 360
    local isNarrowFov = cam.fov < FOV_BASE - 5
    local isLocked = IsValid(cam.lockTarget)

    local fW, fH = w * 0.65, h * 0.65
    local bx, by = cx - fW / 2, cy - fH / 2
    local bL     = h * 0.05

    surface.SetDrawColor(isLocked and lockCol or col)

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

    -- Lead pip while locked (offset from center by angular lead → screen px).
    if isLocked then
        local pxPerDeg = (w * 0.5) / math.max(cam.fov * 0.5, 1)
        local lx = cx + cam.leadAz * pxPerDeg
        local ly = cy - cam.leadEl * pxPerDeg
        surface.SetDrawColor(lockCol)
        local s = 6
        surface.DrawLine(lx - s, ly, lx + s, ly)
        surface.DrawLine(lx, ly - s, lx, ly + s)
        surface.DrawOutlinedRect(lx - 3, ly - 3, 6, 6)
    end

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
                    HDTS_Text(bearingStr, tapeXPX, by - 2, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, isLocked and lockCol or col)
                end
            end
        end
    end

    local hudCol = isLocked and lockCol or col
    local lrfStatus = GetLRFStatus()
    local lrfStatusCol = hudCol
    if lrfStatus == "LRF FIRE" then
        lrfStatusCol = lrfCol
    elseif lrfStatus == "LRF NO RTN" then
        lrfStatusCol = alertCol
    elseif lrfStatus == "LRF HOLD" then
        lrfStatusCol = Color(180, 180, 100, 230)
    end

    HDTS_Text(string.format("AZ %03.0f°", trueAzimuth), cx, by + 12, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, hudCol)
    HDTS_Text(string.format("EL %s%02.0f°", cam.pitch < 0 and "-" or "+", math.abs(cam.pitch)), cx + fW / 2 - bL, by - 4, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM, hudCol)

    HDTS_Text("MODE : HDTS FLIR", sLeft, sLeft, nil, nil, hudCol)
    HDTS_Text(isLocked and "WPN  : TRACK" or "WPN  : SAFE", sLeft, sLeft + 15, nil, nil, isLocked and lockCol or col)
    HDTS_Text("LSR  : " .. lrfStatus, sLeft, sLeft + 30, nil, nil, lrfStatusCol)

    local yOff = 45
    if LRFHoldActive() then
        if cam.lrfValid then
            HDTS_Text(string.format("RNG  : %05.0f M", cam.lrfMeters), sLeft, sLeft + yOff, nil, nil, lrfCol)
            HDTS_Text(string.format("     : %05.0f FT", cam.lrfFeet), sLeft, sLeft + yOff + 15, nil, nil, lrfCol)
            yOff = yOff + 30
        else
            HDTS_Text("RNG  : ----- M", sLeft, sLeft + yOff, nil, nil, alertCol)
            yOff = yOff + 15
        end
    end

    -- Lead / rate block (always shows gimbal slew; target rates when locked)
    local slewMag = math.sqrt(cam.rateYaw * cam.rateYaw + cam.ratePitch * cam.ratePitch)
    HDTS_Text(string.format("SLEW : %05.1f °/s", slewMag), sLeft, sLeft + yOff, nil, nil, hudCol)
    yOff = yOff + 15

    if isLocked then
        HDTS_Text(string.format("RATE : AZ %+05.1f", cam.tgtRateAz), sLeft, sLeft + yOff, nil, nil, lockCol)
        HDTS_Text(string.format("       EL %+05.1f", cam.tgtRateEl), sLeft, sLeft + yOff + 15, nil, nil, lockCol)
        HDTS_Text(string.format("TSPD : %04.0f KTS", cam.tgtSpeedKts), sLeft, sLeft + yOff + 30, nil, nil, lockCol)
        HDTS_Text(string.format("LEAD : AZ %+04.1f°", cam.leadAz), sLeft, sLeft + yOff + 45, nil, nil, lockCol)
        HDTS_Text(string.format("       EL %+04.1f°", cam.leadEl), sLeft, sLeft + yOff + 60, nil, nil, lockCol)
    end

    local factorZOOM = 1 + ((FOV_BASE - cam.fov) / (FOV_BASE - FOV_MIN) * 9)
    HDTS_Text(isNarrowFov and "SIGHT: TADS/NAR" or "SIGHT: TADS/WID", sLeft, bHeight - 30, nil, nil, hudCol)
    HDTS_Text(string.format("ZOOM : [%.1fx]", factorZOOM), sLeft, bHeight - 15, nil, nil, hudCol)

    HDTS_Text(string.format("SPD : %04.0f KTS", spd_kts), sRight, sLeft, TEXT_ALIGN_RIGHT, nil, hudCol)
    HDTS_Text(string.format("ALT : %04.0f FT", alt_feet), sRight, sLeft + 15, TEXT_ALIGN_RIGHT, nil, hudCol)
    HDTS_Text(string.format("HDG : %03.0f° TRU", trueAzimuth), sRight, sLeft + 30, TEXT_ALIGN_RIGHT, nil, hudCol)

    local rndLat = math.abs(pos.y * 11) % 100000
    local rndLon = math.abs(pos.x * 11) % 100000
    HDTS_Text(string.format("COORDN : %06.0f", rndLat), sRight, bHeight - 30, TEXT_ALIGN_RIGHT, nil, hudCol)
    HDTS_Text(string.format("COORDE : %06.0f", rndLon), sRight, bHeight - 15, TEXT_ALIGN_RIGHT, nil, hudCol)

    if LRFHoldActive() and cam.lrfValid then
        local age = CurTime() - cam.lrfTime
        local alpha = age < 1 and 255 or math.Clamp(255 * (1 - (age - 1) / (LRF_HOLD_TIME - 1)), 80, 255)
        local bigCol = Color(lrfCol.r, lrfCol.g, lrfCol.b, alpha)
        HDTS_Text(string.format("R %05.0f M", cam.lrfMeters), cx, cy + h * 0.12, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, bigCol)
    elseif LRFHoldActive() and not cam.lrfValid and CurTime() < cam.lrfFlash then
        HDTS_Text("NO RTN", cx, cy + h * 0.12, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, alertCol)
    end

    if isLocked then
        local flash = (math.sin(RealTime() * 8) > 0) and lockCol or alertCol
        HDTS_Text("★ HARD LOCK", cx, by + fH + 5, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, flash)

        surface.SetDrawColor(lockCol)
        local gap, sSz = gH * 2.4, 12
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
    end
end)
