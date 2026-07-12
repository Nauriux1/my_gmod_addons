local FLAG      = "zb_noclip_meaty"
local SEE_DOT   = 0.6     -- европейский взгляд
local SEE_RANGE = 2200

local function IsMeatyNoclip(ply)
    return IsValid(ply) and ply:GetNWBool(FLAG, false)
end

hook.Add("EntityEmitSound", "ZB_NoclipMeaty_Silent", function(data)
    local ent = data.Entity
    if IsValid(ent) and ent:IsPlayer() and IsMeatyNoclip(ent) then
        return false
    end
end)

if SERVER then
    local function FindPlayer(search)
        search = string.lower(search)
        for _, ply in player.Iterator() do
            if string.lower(ply:Nick()) == search then return ply end
        end
        for _, ply in player.Iterator() do
            if string.find(string.lower(ply:Nick()), search, 1, true) then return ply end
        end
    end

    local function BlackoutObserversOf(target, pos, fadeTime, holdTime)
        pos = pos or target:EyePos()
        fadeTime = fadeTime or 0.7
        holdTime = holdTime or 0.4
        for _, observer in player.Iterator() do
            if observer == target then continue end
            if not observer:Alive() then continue end
            if IsMeatyNoclip(observer) then continue end

            local obsPos = observer:EyePos()
            local toPos  = pos - obsPos
            local dist   = toPos:Length()
            if dist > SEE_RANGE or dist < 1 then continue end

            toPos:Normalize()
            if observer:EyeAngles():Forward():Dot(toPos) < SEE_DOT then continue end

            local tr = util.TraceLine({
                start  = obsPos,
                endpos = pos,
                filter = { observer, target },
                mask   = MASK_SHOT,
            })
            if tr.Fraction >= 0.95 or tr.Entity == target then
                observer:ScreenFade(SCREENFADE.IN, Color(0, 0, 0), fadeTime, holdTime) -- sv_fear.lua нормальная темка
            end
        end
    end

    local function EnableNoclip(ply)
        if not IsValid(ply) then return end

        BlackoutObserversOf(ply, ply:EyePos())

        ply:SetNWBool(FLAG, true)

        ply.zb_noclip_oldMoveType  = ply:GetMoveType()
        ply.zb_noclip_oldCollision = ply:GetCollisionGroup()

        ply:SetMoveType(MOVETYPE_NOCLIP)
        ply:GodEnable()
        ply:SetCollisionGroup(COLLISION_GROUP_WORLD)
        ply.noSound = true
        ply:DrawShadow(false)
        ply:SetRenderMode(RENDERMODE_TRANSALPHA)
        ply:SetColor(Color(255, 255, 255, 0))
    end

    local function DisableNoclip(ply)
        if not IsValid(ply) then return end

        BlackoutObserversOf(ply, ply:EyePos(), 0.4, 1.2)

        ply:SetMoveType(ply.zb_noclip_oldMoveType or MOVETYPE_WALK)
        ply:GodDisable()
        ply:SetCollisionGroup(ply.zb_noclip_oldCollision or COLLISION_GROUP_PLAYER)
        ply.noSound                = false
        ply.zb_noclip_oldMoveType  = nil
        ply.zb_noclip_oldCollision = nil

        timer.Simple(0.5, function()
            if not IsValid(ply) then return end
            ply:SetNWBool(FLAG, false)
            ply:DrawShadow(true)
            ply:SetRenderMode(RENDERMODE_NORMAL)
            ply:SetColor(Color(255, 255, 255, 255))
        end)
    end

    concommand.Add("zb_noclip_meaty", function(adminPly, cmd, args)
        if IsValid(adminPly) and not adminPly:IsAdmin() then return end

        local state = tonumber(args[1])
        local name  = args[2]
        if name and args[3] then name = table.concat(args, " ", 2) end

        if state == nil or not name then
            local m = "Usage: zb_noclip_meaty <0|1> <player name>"
            if IsValid(adminPly) then adminPly:ChatPrint(m) else print(m) end
            return
        end

        state = math.Clamp(math.floor(state), 0, 1)

        local target = FindPlayer(name)
        if not IsValid(target) then
            local m = "Player not found: " .. name
            if IsValid(adminPly) then adminPly:ChatPrint(m) else print(m) end
            return
        end

        if state == 1 then EnableNoclip(target) else DisableNoclip(target) end

        local who = IsValid(adminPly) and adminPly:Nick() or "Console"
        print("[zb_noclip_meaty] " .. who .. " set horror noclip=" .. state .. " on " .. target:Nick())
    end)

    concommand.Add("zb_noclip_meaty_toggle", function(adminPly)
        if not IsValid(adminPly) then return end
        if not adminPly:IsAdmin() then return end

        if IsMeatyNoclip(adminPly) then
            DisableNoclip(adminPly)
        else
            EnableNoclip(adminPly)
        end
    end)

    hook.Add("EntityTakeDamage", "ZB_NoclipMeaty_NoDamage", function(ent, dmg)
        if IsMeatyNoclip(ent) then return true end
    end)

    hook.Add("PlayerFootstep", "ZB_NoclipMeaty_Silent", function(ply)
        if IsMeatyNoclip(ply) then return true end
    end)

    hook.Add("PlayerDeath", "ZB_NoclipMeaty_Cleanup", function(victim)
        if IsMeatyNoclip(victim) then DisableNoclip(victim) end
    end)
    hook.Add("PlayerDisconnected", "ZB_NoclipMeaty_Cleanup", function(ply)
        if IsMeatyNoclip(ply) then DisableNoclip(ply) end
    end)
end

if CLIENT then
    hook.Add("PrePlayerDraw", "ZB_NoclipMeaty_Hide", function(ply)
        if IsMeatyNoclip(ply) then
            return true
        end
    end)

    local function ApplyHide(ent, hide)
        if not IsValid(ent) then return end
        if hide then
            if ent:GetMaterial() ~= "NULL" then
                ent.zb_noclip_oldMat = ent:GetMaterial()
                ent:SetMaterial("NULL")
                ent:SetNoDraw(true)
                ent:DrawShadow(false)
            end
            ent.NotSeen = true
            ent.zb_noclip_wasHidden = true
        elseif ent.zb_noclip_wasHidden then
            ent:SetMaterial(ent.zb_noclip_oldMat or "")
            ent:SetNoDraw(false)
            ent:DrawShadow(true)
            ent.NotSeen = nil
            ent.zb_noclip_oldMat = nil
            ent.zb_noclip_wasHidden = false
        end
    end

    hook.Add("PreDrawOpaqueRenderables", "ZB_NoclipMeaty_HideRagdolls", function()
        for _, ply in player.Iterator() do
            local hide = IsMeatyNoclip(ply)

            ApplyHide(ply.FakeRagdoll, hide)
            ApplyHide(ply.OldRagdoll, hide)

            local char = ply.GetCurrentCharacter and hg.GetCurrentCharacter(ply)
            if IsValid(char) and char ~= ply then
                ApplyHide(char, hide)
            end

            if IsValid(ply) then
                if hide then
                    ply.NotSeen = true
                    ply.zb_noclip_plyNotSeen = true
                elseif ply.zb_noclip_plyNotSeen then
                    ply.NotSeen = nil
                    ply.zb_noclip_plyNotSeen = false
                end
            end
        end
    end)

    timer.Simple(0, function()
        if _G.DrawAccesories and not _G.zb_noclip_DrawAccWrapped then
            local realDrawAcc = _G.DrawAccesories
            _G.DrawAccesories = function(ply, ent, accessories, accessData, islply, force, setup)
                local owner = ply
                if IsValid(owner) and owner.IsRagdoll and owner:IsRagdoll() and hg.RagdollOwner then
                    owner = hg.RagdollOwner(owner) or owner
                end

                if (IsValid(ply) and IsMeatyNoclip(ply))
                    or (IsValid(owner) and owner:IsPlayer() and IsMeatyNoclip(owner)) then
                    return
                end

                return realDrawAcc(ply, ent, accessories, accessData, islply, force, setup)
            end
            _G.zb_noclip_DrawAccWrapped = true
        end
    end)
end
-- designed and realized by alagri & omnissiah respectively
