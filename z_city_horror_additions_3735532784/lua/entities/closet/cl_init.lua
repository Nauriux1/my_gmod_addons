include("shared.lua")

-- NOTE ON VOICE: this doesn't touch voice chat at all — VC keeps working
-- normally while hiding, as requested. If/when you add a muffle effect,
-- the natural hook point is right after HMCD_Closet_Enter below (e.g.
-- driving a gVOX preset while ply.zh_ClosetEnt is set, see
-- zcity-horror-additions/lua/autorun/server/sv_crusher_demon_voice.lua
-- for the same pattern applied to the crusher).

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

local CAMERA_OFFSET_POS = Vector(20, 0, 15) -- Move (Forward, Left/Right, Up/Down) from the middle of the closet
local CAMERA_OFFSET_ANG = Angle(0, 0, 0)    -- Change Pitch, Yaw, Roll. E.g. Angle(0, 90, 0) if it stares sideways

local MAX_LOOK_YAW   = 90  -- How far left/right they can look (degrees)
local MAX_LOOK_PITCH = 360  -- How far up/down they can look (degrees)

-- Peephole camera: always recalculated from the closet's CURRENT
-- position/angles, so it follows the closet if it gets pushed or
-- rotated instead of staying fixed in the old spot.
hook.Add("CalcView", "zh_closet_peephole", function(ply, pos, angles, fov)
    local closet = InCloset()
    if not closet then return end

    local view = {}
    local basePos, baseAng

    -- Try calling custom methods, otherwise use our calculated center and offsets
    if closet.GetPeepholePos and closet.GetPeepholeAngles then
        basePos = closet:GetPeepholePos()
        baseAng = closet:GetPeepholeAngles()
    else
        local centerOffset = closet:OBBCenter() + CAMERA_OFFSET_POS
        basePos = closet:LocalToWorld(centerOffset)
        baseAng = closet:LocalToWorldAngles(CAMERA_OFFSET_ANG)
    end

    -- Allow the player to actually look around with their mouse (clamped within boundaries)
    -- This stops the camera from feeling horribly locked and "stiff".
    local relativePitch = math.NormalizeAngle(angles.p - baseAng.p)
    local relativeYaw   = math.NormalizeAngle(angles.y - baseAng.y)

    relativePitch = math.Clamp(relativePitch, -MAX_LOOK_PITCH, MAX_LOOK_PITCH)
    relativeYaw   = math.Clamp(relativeYaw, -MAX_LOOK_YAW, MAX_LOOK_YAW)

    view.origin     = basePos
    view.angles     = baseAng + Angle(relativePitch, relativeYaw, 0)
    view.fov        = 60 -- Raised slightly from 50. Too narrow causes clipping into the model's inside polygons
    view.drawviewer = false

    return view
end)


-- Don't draw the gun while peeking through the peephole.
hook.Add("PreDrawViewModel", "zh_closet_hide_viewmodel", function()
    if InCloset() then return true end
end)

-- No free-look/movement/firing while hidden — the server already
-- enforces MOVETYPE_NONE, this just keeps input from being sent at all.
hook.Add("CreateMove", "zh_closet_block_input", function(cmd)
    local closet = InCloset()
    if not closet then return end
    
    cmd:ClearButtons()
    cmd:ClearMovement()
    
    -- Sync their true server angle with our calculated base so their head doesn't snap on exit
    local baseAng
    if closet.GetPeepholeAngles then
        baseAng = closet:GetPeepholeAngles()
    else
        baseAng = closet:LocalToWorldAngles(CAMERA_OFFSET_ANG)
    end

    local angles = cmd:GetViewAngles()
    local relativePitch = math.NormalizeAngle(angles.p - baseAng.p)
    local relativeYaw   = math.NormalizeAngle(angles.y - baseAng.y)

    local newPitch = math.Clamp(relativePitch, -MAX_LOOK_PITCH, MAX_LOOK_PITCH)
    local newYaw   = math.Clamp(relativeYaw, -MAX_LOOK_YAW, MAX_LOOK_YAW)

    cmd:SetViewAngles(baseAng + Angle(newPitch, newYaw, 0))
end)

hook.Add("HUDShouldDraw", "zh_closet_hide_hud", function(name)
    if not InCloset() then return end
    if name == "CHudCrosshair" or name == "CHudWeaponSelection" then
        return false
    end
end)

-- Placeholder peephole framing so this is testable before your real
-- peephole art goes in. Deliberately simple: HUDPaint draws ON TOP of
-- the already-rendered 3D view, it can't punch a see-through hole into
-- it — actually masking the view down to a circular peephole needs a
-- render-target/stencil pass (or just an overlay PNG with a transparent
-- center), which is exactly the piece you're adding yourself. This just
-- draws a thin ring so there's *something* on screen in the meantime;
-- swap out or delete once your real overlay is in.
hook.Add("HUDPaint", "zh_closet_peephole_frame", function()
    if not InCloset() then return end

    local w, h = ScrW(), ScrH()
    local r = math.min(w, h) * 0.28

    surface.SetDrawColor(0, 0, 0, 255)
    surface.DrawOutlinedRect(w / 2 - r, h / 2 - r, r * 2, r * 2, 6)
end)