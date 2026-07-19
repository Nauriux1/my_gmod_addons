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

local GIMBAL_LOCAL_OFFSET = Vector(0, 0, -70) -- belly-mounted; tune in-game, exact hull size unverified
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

local function StopThermalCam()
    if not cam.active then return end
    cam.active = false
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
            surface.PlaySound("buttons/button24.wav")
        else
            surface.PlaySound("buttons/button10.wav")
        end
    end
end)

-- ---------------------------------------------------------------------
-- Mouse look: fully free 360, independent of the vehicle's orientation.
-- Registered at HOOK_MONITOR_HIGH specifically to run (and consume the
-- input, per InputMouseApply's "return true to suppress" contract)
-- before Glide's own camera hook, which sits at HOOK_HIGH -- otherwise
-- Glide's vehicle-look would fight this for the same mouse input.
-- ---------------------------------------------------------------------

hook.Add("InputMouseApply", "iw9_ThermalCam.Mouse", function(cmd, x, y, ang)
    if not cam.active or not CanUseThermalCam() then return end

    local sens = 0.05
    cam.yaw   = (cam.yaw - x * sens) % 360
    cam.pitch = math.Clamp(cam.pitch + y * sens, -85, 85)

    return true
end, HOOK_MONITOR_HIGH)

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
end, HOOK_MONITOR_HIGH)

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
-- HUD: simple camera-feed framing so it reads as a distinct mode, and
-- hide the normal crosshair so it doesn't clash with it.
-- ---------------------------------------------------------------------

hook.Add("HUDShouldDraw", "iw9_ThermalCam.HideDefaultHUD", function(name)
    if cam.active and name == "CHudCrosshair" then return false end
end)

hook.Add("HUDPaint", "iw9_ThermalCam.HUD", function()
    if not cam.active then return end

    local w, h = ScrW(), ScrH()
    local edge = 40
    local col  = Color(80, 255, 140, 200)

    surface.SetDrawColor(col)
    surface.DrawLine(edge, edge, edge + 20, edge)
    surface.DrawLine(edge, edge, edge, edge + 20)
    surface.DrawLine(w - edge, edge, w - edge - 20, edge)
    surface.DrawLine(w - edge, edge, w - edge, edge + 20)
    surface.DrawLine(edge, h - edge, edge + 20, h - edge)
    surface.DrawLine(edge, h - edge, edge, h - edge - 20)
    surface.DrawLine(w - edge, h - edge, w - edge - 20, h - edge)
    surface.DrawLine(w - edge, h - edge, w - edge, h - edge - 20)

    draw.SimpleText("THERMAL CAM", "DermaDefaultBold", edge, edge - 18, col)
    draw.SimpleText(
        #haloTargets .. " HEAT SIGNATURE" .. (#haloTargets == 1 and "" or "S"),
        "DermaDefaultBold", edge, h - edge + 4, col
    )
end)