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

function ENT:EnterCloset(ply)
    if not IsValid(ply) or IsCrusher(ply) then return end
    if not ply:Alive() then return end

    if IsValid(self.Occupant) then
        ply:Notify("Someone is already in there..", 0, "closet_occupied_" .. self:EntIndex(), 0)
        return
    end

    self.Occupant = ply
    ply.zh_ClosetEnt = self

    ply:SetPos(self:GetPeepholePos())
    ply:SetMoveType(MOVETYPE_NONE)
    ply:SetNoDraw(true)

    net.Start("HMCD_Closet_Enter")
    net.WriteEntity(self)
    net.Send(ply)
end

-- ejected: true if the crusher is throwing the occupant out 
-- (folds them using true gamemode faking logic), false for voluntary exit.
function ENT:ExitCloset(ply, ejected)
    if not IsValid(ply) then return end
    if self.Occupant ~= ply then return end

    local exitPos, exitAng = self:GetExitPos()

    ply:SetMoveType(MOVETYPE_WALK)
    ply:SetNoDraw(false)
    ply:SetPos(exitPos)

    ply.zh_ClosetEnt = nil
    self.Occupant = nil

    net.Start("HMCD_Closet_Exit")
    net.Send(ply)

    if ejected then
        ply:EmitSound("physics/wood/wood_crate_impact_hard1.wav", 70)
        local ejectVelocity = self:GetForward() * 250 + Vector(0, 0, 160)

        -- Tap into native ZCity/Homigrad framework knockdowns so the REAL player goes limp!
        if type(Faking) == "function" then
            Faking(ply)
        elseif type(ply.Faking) == "function" then
            ply:Faking(true)
        elseif type(ply.Fake) == "function" then 
            ply:Fake()
        end

        -- Wait exactly 1 engine frame for the gamemode to process the knockout and assign their physics prop, 
        -- then brutally fling their real bound ragdoll outwardly. 
        timer.Simple(0, function()
            if not IsValid(ply) then return end
            
            -- Hunt down wherever Homigrad stored the actual bound ragdoll entity reference
            local realRagdoll = ply.fake or ply.ragdoll or ply:GetNWEntity("Ragdoll")
            
            if IsValid(realRagdoll) then
                local bones = realRagdoll:GetPhysicsObjectCount()
                for i = 0, bones - 1 do
                    local rPhys = realRagdoll:GetPhysicsObjectNum(i)
                    if IsValid(rPhys) then
                        rPhys:SetVelocity(ejectVelocity + VectorRand() * 35)
                        rPhys:AddAngleVelocity(VectorRand() * 200)
                    end
                end
            else
                -- Ultimate Fallback: Gamemode failsafe, just fling the upright player physics 
                ply:SetVelocity(ejectVelocity)
            end
        end)
    end
end

-- Keeps the occupant's real position glued to the closet every tick
-- (so it still follows the closet if pushed/rotated) without relying
-- on engine parenting.
function ENT:Think()
    if IsValid(self.Occupant) then
        self.Occupant:SetPos(self:GetPeepholePos())
    end
    self:NextThink(CurTime())
    return true
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


-- ========================================================
-- ADMIN TOOL: FORCE PLAYER INTO VIEWED CLOSET 
-- ========================================================

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

    if IsCrusher(targetPlayer) then
        ply:PrintMessage(HUD_PRINTCONSOLE, "[ZH Closet] Blocked: Cannot force Crusher into a closet.")
        return
    end
    
    if IsValid(targetCloset.Occupant) then 
        ply:PrintMessage(HUD_PRINTCONSOLE, "[ZH Closet] Ejecting current inhabitant (" .. targetCloset.Occupant:Nick() .. ") before moving new user in.")
        targetCloset:ExitCloset(targetCloset.Occupant, false)
    end

    if IsValid(targetPlayer.zh_ClosetEnt) and targetPlayer.zh_ClosetEnt ~= targetCloset then
        targetPlayer.zh_ClosetEnt:ExitCloset(targetPlayer, false)
    end

    targetCloset:EnterCloset(targetPlayer)
    ply:PrintMessage(HUD_PRINTCONSOLE, "[ZH Closet] Successfully pushed " .. targetPlayer:Nick() .. " into target closet!")
end)