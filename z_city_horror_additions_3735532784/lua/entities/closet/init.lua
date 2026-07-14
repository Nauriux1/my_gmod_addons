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
        phys:SetMass(800) -- heavier = more stable when player is inside
    end

    self.Occupant = nil
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

    ply:SetMoveType(MOVETYPE_NONE)
    ply:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
    
    -- === STRONGER HIDING (fixes ghosting for other players) ===
    ply:SetNoDraw(true)
    ply:SetRenderMode(RENDERMODE_NONE)      -- Very important
    ply:DrawShadow(false)
    ply:SetColor(Color(255, 255, 255, 0))

    ply:SetPos(self:GetPeepholePos())

    net.Start("HMCD_Closet_Enter")
    net.WriteEntity(self)
    net.Send(ply)
end

function ENT:ExitCloset(ply, ejected)
    if not IsValid(ply) then return end
    if self.Occupant ~= ply then return end

    local exitPos, exitAng = self:GetExitPos()

    ply:SetMoveType(MOVETYPE_WALK)
    ply:SetCollisionGroup(COLLISION_GROUP_PLAYER)
    ply:SetNoDraw(false)
    ply:SetPos(exitPos)
    ply:SetEyeAngles(exitAng)

    ply.zh_ClosetEnt = nil
    self.Occupant = nil

    net.Start("HMCD_Closet_Exit")
    net.Send(ply)

    if ejected then
        ply:EmitSound("physics/wood/wood_crate_impact_hard1.wav", 80)

        local ejectVel = self:GetForward() * 420 + Vector(0, 0, 300)

        -- === CORRECT ZCITY/HOMIGRAD WAY ===
        if hg and hg.Fake then
            hg.Fake(ply)                    -- Force fake ragdoll
        else
            ply:ConCommand("force_fake")    -- Fallback
            ply:ConCommand("fake")
        end

        -- Apply velocity to the newly created fake ragdoll
        timer.Simple(0.1, function()
            if not IsValid(ply) then return end

            local rag = ply.fake
                     or ply.ragdoll
                     or ply:GetNWEntity("Ragdoll")
                     or ply:GetNWEntity("FakeRagdoll")
                     or ply:GetNWEntity("zh_fake_ragdoll")

            if IsValid(rag) then
                for i = 0, rag:GetPhysicsObjectCount() - 1 do
                    local phys = rag:GetPhysicsObjectNum(i)
                    if IsValid(phys) then
                        phys:Wake()
                        phys:SetVelocity(ejectVel + VectorRand() * 90)
                        phys:AddAngleVelocity(VectorRand() * 500)
                    end
                end
            else
                ply:SetVelocity(ejectVel)
            end
        end)
    end
end


-- === FIX 3: Much more reliable "follow closet" logic ===
function ENT:Think()
    if IsValid(self.Occupant) then
        local ply = self.Occupant

        if ply:GetPos():DistToSqr(self:GetPeepholePos()) > 9 then
            ply:SetPos(self:GetPeepholePos())
        end

        -- Only force these while inside
        if ply:GetMoveType() ~= MOVETYPE_NONE then
            ply:SetMoveType(MOVETYPE_NONE)
        end
    end

    self:NextThink(CurTime())
    return true
end

-- Rest of the file unchanged (Use, OnRemove, hooks, admin command...)
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

hook.Add("PlayerUse", "zh_closet_forceexit", function(ply, ent)
    if IsValid(ply.zh_ClosetEnt) then
        ply.zh_ClosetEnt:ExitCloset(ply, false)
        return false
    end
end)

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



-- Admin command (unchanged)
concommand.Add("zh_force_closet", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsAdmin() then
        ply:PrintMessage(HUD_PRINTCONSOLE, "[ZH Closet] Access Denied. You must be an admin.")
        return
    end

    if not IsValid(ply) then 
        print("[ZH Closet] Error: Command requires physical player tracing (an admin must aim at the physical entity).")
        return 
    end

    local adminEyeTrace = ply:GetEyeTrace()
    local targetCloset = adminEyeTrace.Entity

    if not IsValid(targetCloset) or not targetCloset.EnterCloset then
        ply:PrintMessage(HUD_PRINTCONSOLE, "[ZH Closet] Error: You must be aiming precisely at a closet to shove somebody into it.")
        return
    end

    local searchStr = string.Trim(table.concat(args, " "))
    if searchStr == "" then
        ply:PrintMessage(HUD_PRINTCONSOLE, "Usage: zh_force_closet <player_name>")
        return
    end

    local targetPlayer = nil
    local targetLower = string.lower(searchStr)
    
    for _, p in ipairs(player.GetAll()) do
        if string.find(string.lower(p:Nick()), targetLower, 1, true) then
            targetPlayer = p
            break
        end
    end

    if not IsValid(targetPlayer) then
        ply:PrintMessage(HUD_PRINTCONSOLE, "[ZH Closet] Could not locate any connected player matching: " .. searchStr)
        return
    end

    if not targetPlayer:Alive() then
        ply:PrintMessage(HUD_PRINTCONSOLE, "[ZH Closet] Cancelled: Cannot push dead bodies/spectators inside a closet.")
        return
    end

    -- === NEW RESTRICTION: Prevent forcing players who are in fake/ragdoll ===
    if IsValid(targetPlayer.fake) 
       or IsValid(targetPlayer.ragdoll) 
       or IsValid(targetPlayer:GetNWEntity("Ragdoll"))
       or IsValid(targetPlayer:GetNWEntity("FakeRagdoll"))
       or IsValid(targetPlayer:GetNWEntity("zh_fake_ragdoll")) then
        
        ply:PrintMessage(HUD_PRINTCONSOLE, "[ZH Closet] Cannot force a player who is currently in fake/ragdoll state.")
        return
    end

    if targetPlayer.zh_ClosetEnt and IsValid(targetPlayer.zh_ClosetEnt) then
        ply:PrintMessage(HUD_PRINTCONSOLE, "[ZH Closet] That player is already inside a closet.")
        return
    end

    if IsCrusher(targetPlayer) then
        ply:PrintMessage(HUD_PRINTCONSOLE, "[ZH Closet] Blocked: Cannot force Crusher into a closet.")
        return
    end

    -- Force the player in
    targetCloset:EnterCloset(targetPlayer)

    ply:PrintMessage(HUD_PRINTCONSOLE, "[ZH Closet] Forced " .. targetPlayer:Nick() .. " into the closet.")
end)
