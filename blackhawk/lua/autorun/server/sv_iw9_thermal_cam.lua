-- Server relay for the co-pilot thermal designator laser.
-- Only the FLIR operator (seat 2) may publish a beam; only seat 1 and seat 2
-- of the same Vulture receive it.

if CLIENT then return end

util.AddNetworkString("iw9_ThermalCam.Laser")

local SUPPORTED = { iw9_veh_blima = true }
local MAX_RANGE_SQR = 15000 * 15000

net.Receive("iw9_ThermalCam.Laser", function(_, ply)
    if not IsValid(ply) then return end

    local veh = ply.GlideGetVehicle and ply:GlideGetVehicle() or NULL
    if not IsValid(veh) then return end
    if not SUPPORTED[veh:GetClass()] then return end

    local seat = ply.GlideGetSeatIndex and ply:GlideGetSeatIndex() or 0
    if seat ~= 2 then return end

    local active = net.ReadBool()
    local origin, hit

    if active then
        origin = net.ReadVector()
        hit    = net.ReadVector()

        if not isvector(origin) or not isvector(hit) then return end
        if origin:DistToSqr(hit) > MAX_RANGE_SQR then return end
        -- Origin must stay near the aircraft.
        if origin:DistToSqr(veh:GetPos()) > (800 * 800) then return end
    end

    local recipients = {}
    for _, p in ipairs(player.GetAll()) do
        if not IsValid(p) then continue end
        local pv = p.GlideGetVehicle and p:GlideGetVehicle() or NULL
        if pv ~= veh then continue end

        local ps = p.GlideGetSeatIndex and p:GlideGetSeatIndex() or 0
        if ps == 1 or ps == 2 then
            recipients[#recipients + 1] = p
        end
    end

    if #recipients == 0 then return end

    net.Start("iw9_ThermalCam.Laser")
        net.WriteEntity(veh)
        net.WriteBool(active)
        if active then
            net.WriteVector(origin)
            net.WriteVector(hit)
        end
    net.Send(recipients)
end)
