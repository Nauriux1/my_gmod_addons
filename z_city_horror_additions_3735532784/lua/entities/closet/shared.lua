ENT.Type            = "anim"
ENT.Base            = "base_gmodentity"
ENT.PrintName       = "Closet"
ENT.Author          = "Ainius"
ENT.Category        = "Horror Additions"
ENT.Spawnable       = true
ENT.AdminSpawnable  = false
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
ENT.PeepholeLocalOffset = Vector(14, 0, 42) -- where the hidden player's "camera" sits, right at the door
ENT.PeepholeAngleOffset = Angle(0, 0, 0)    -- rotate this if the model's front isn't local +X
ENT.ExitLocalOffset     = Vector(34, 0, 0)  -- where a player appears when leaving/being ejected