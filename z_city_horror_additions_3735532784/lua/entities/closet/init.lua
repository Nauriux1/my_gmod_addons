AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

util.AddNetworkString("HMCD_Closet_Enter")
util.AddNetworkString("HMCD_Closet_Exit")

local function IsCrusher(ply)
    return IsValid(ply)
        and (ply:GetNWBool("zb_is_crusher", false)
            or ply.SubRole == "traitor_strangler"
            or ply.SubRole == "traitor_strangler_soe")
end

function ENT:Initialize()
    self:SetModel(self.ClosetModel)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
    end

    self.Occupant = nil
end

function ENT:GetPeepholePos()
    return self:LocalToWorld(self.PeepholeLocalOffset)
end

function ENT:GetPeepholeAngles()
    return self:LocalToWorldAngles(self.PeepholeAngleOffset)
end

function ENT:GetExitPos()
    return self:LocalToWorld(self.ExitLocalOffset), self:GetAngles()
end

-- Purely cosmetic — does not touch the real player's health/state.
-- Just a ragdoll prop matching their model, launched away from the
-- closet, that cleans itself up after a few seconds.
local function SpawnFakeRagdoll(ply, pos, ang, vel)
    local ragdoll = ents.Create("prop_ragdoll")
    if not IsValid(ragdoll) then return end

    ragdoll:SetModel(ply:GetModel())
    ragdoll:SetSkin(ply:GetSkin())
    for i = 0, ply:GetNumBodyGroups() - 1 do
        ragdoll:SetBodygroup(i, ply:GetBodygroup(i))
    end
    ragdoll:SetPos(pos)
    ragdoll:SetAngles(ang)
    ragdoll:Spawn()
    ragdoll:Activate()

    for i = 0, ragdoll:GetPhysicsObjectCount() - 1 do
        local rphys = ragdoll:GetPhysicsObjectNum(i)
        if IsValid(rphys) then
            rphys:SetVelocity(vel + VectorRand() * 30)
            rphys:AddAngleVelocity(VectorRand() * 200)
        end
    end

    SafeRemoveEntityDelayed(ragdoll, 4)
end

function ENT:EnterCloset(ply)
    if not IsValid(ply) or IsCrusher(ply) then return end
    if not ply:Alive() then return end

    if IsValid(self.Occupant) then
        ply:Notify("Someone is already in there..", 0, "closet_occupied_" .. self:EntIndex(), 0)
        return
    end

    self.Occupant = ply
    ply.zh_ClosetEnt = self

    ply:SetParent(self)
    ply:SetPos(self:GetPeepholePos())
    ply:SetMoveType(MOVETYPE_NONE)
    ply:SetNoDraw(true)

    net.Start("HMCD_Closet_Enter")
    net.WriteEntity(self)
    net.Send(ply)
end

-- ejected: true if the crusher is throwing the occupant out (spawns the
-- fake ragdoll + sound), false for a normal voluntary exit.
function ENT:ExitCloset(ply, ejected)
    if not IsValid(ply) then return end
    if self.Occupant ~= ply then return end

    local exitPos, exitAng = self:GetExitPos()

    ply:SetParent(nil)
    ply:SetMoveType(MOVETYPE_WALK)
    ply:SetNoDraw(false)
    ply:SetPos(exitPos)

    ply.zh_ClosetEnt = nil
    self.Occupant = nil

    net.Start("HMCD_Closet_Exit")
    net.Send(ply)

    if ejected then
        local vel = self:GetForward() * 220 + Vector(0, 0, 140)
        SpawnFakeRagdoll(ply, exitPos, exitAng, vel)
        ply:EmitSound("physics/wood/wood_crate_impact_hard1.wav", 70)
    end
end

function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    if IsCrusher(activator) then
        if IsValid(self.Occupant) then
            self:ExitCloset(self.Occupant, true)
        else
            activator:Notify("No one inside.", 0, "closet_empty_" .. self:EntIndex(), 0)
        end
        return
    end

    -- Normal exit-from-inside is handled by the PlayerUse hook below
    -- (trace-independent), this is just a safety fallback.
    if self.Occupant == activator then
        self:ExitCloset(activator, false)
        return
    end

    self:EnterCloset(activator)
end

function ENT:OnRemove()
    if IsValid(self.Occupant) then
        self:ExitCloset(self.Occupant, false)
    end
end

-- Pressing +use while INSIDE the closet should always exit, regardless
-- of where the player's (overridden) view is actually pointing — the
-- engine's normal use-trace isn't reliable from inside a solid prop.
hook.Add("PlayerUse", "zh_closet_forceexit", function(ply, ent)
    if IsValid(ply.zh_ClosetEnt) then
        ply.zh_ClosetEnt:ExitCloset(ply, false)
        return false
    end
end)

-- Safety nets so a closet can never get permanently stuck "occupied".
hook.Add("PlayerDeath", "zh_closet_deathcleanup", function(ply)
    if IsValid(ply.zh_ClosetEnt) then
        ply.zh_ClosetEnt:ExitCloset(ply, false)
    end
end)

hook.Add("PlayerDisconnected", "zh_closet_disconnectcleanup", function(ply)
    if IsValid(ply.zh_ClosetEnt) then
        ply.zh_ClosetEnt:ExitCloset(ply, false)
    end
end)