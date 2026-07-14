--ENT.ClosetModel = "models/props_c17/FurnitureDresser001a.mdl"


ENT.Type            = "anim"
ENT.Base            = "base_gmodentity"
ENT.PrintName       = "Closet"
ENT.Author          = "Ainius"
ENT.Category        = "Horror Additions"
ENT.Spawnable       = true
ENT.AdminSpawnable  = true
ENT.Purpose         = "A hiding spot with a peephole. Anyone but the crusher can hide inside; the crusher can check it and throw whoever's inside back out."

-- Change this to whatever closet/wardrobe prop you want to use.
ENT.ClosetModel = "models/props_c17/FurnitureDresser001a.mdl"

-- All offsets below are LOCAL to the entity (i.e. relative to its own
-- position/angles), and are re-resolved to world space every time
-- they're used — so if the closet gets pushed or rotated (it's a
-- physics prop), the peephole view and exit point move/rotate with it
-- instead of staying fixed in the old spot.
--
-- These are tuned very roughly for FurnitureWardrobe001a and will
-- likely need adjusting for your model: X = local forward (out the
-- front doors), Z = up.
ENT.PeepholeLocalOffset = Vector(14, 0, 32) -- where the hidden player's "camera" sits, right at the door
ENT.PeepholeAngleOffset = Angle(0, 0, 0)    -- rotate this if the model's front isn't local +X
ENT.ExitLocalOffset     = Vector(34, 0, 0)  -- where a player appears when leaving/being ejected

-- How far the occupant can turn their head away from dead-ahead while
-- looking through the peephole, in degrees. Keeps it feeling like a
-- small hole rather than a free-floating camera.
ENT.PeepholeLookYawLimit   = 45
ENT.PeepholeLookPitchLimit = 30

-- Shared so both the server (ejecting/exiting) and client (peephole
-- camera) can compute these consistently. These MUST live here, not in
-- init.lua/cl_init.lua only, or one realm ends up without them.
function ENT:GetPeepholePos()
    return self:LocalToWorld(self.PeepholeLocalOffset)
end

function ENT:GetPeepholeAngles()
    return self:LocalToWorldAngles(self.PeepholeAngleOffset)
end

function ENT:GetExitPos()
    return self:LocalToWorld(self.ExitLocalOffset), self:GetAngles()
end