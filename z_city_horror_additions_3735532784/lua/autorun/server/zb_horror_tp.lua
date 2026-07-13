if not SERVER then return end

local BEHIND_DIST = 45
local TRACE_RANGE = 8000

concommand.Add("zb_horror_tp", function(adminPly)
    if not IsValid(adminPly) or not adminPly:IsAdmin() then return end

    local tr = util.TraceLine({
        start  = adminPly:EyePos(),
        endpos = adminPly:EyePos() + adminPly:GetAimVector() * TRACE_RANGE,
        filter = function(ent)
            if ent == adminPly then return false end
            if ent:IsPlayer() then return true end
            if ent:IsRagdoll() then return true end
            return false
        end,
        mask   = MASK_SHOT,
    })

    local hitEnt = tr.Entity
    if not IsValid(hitEnt) then
        adminPly:ChatPrint("Aim at a player")
        return
    end

    local target = hitEnt
    if hitEnt:IsRagdoll() and hg and hg.RagdollOwner then
        target = hg.RagdollOwner(hitEnt) or hitEnt
    end
    if not (IsValid(target) and target:IsPlayer()) then
        adminPly:ChatPrint("Nuh-uh")
        return
    end
    if target == adminPly then return end

    local tAng = target:EyeAngles()
    tAng.p, tAng.r = 0, 0
    local origin = target:GetPos() + Vector(0, 0, 8)

    local fwd, right = tAng:Forward(), tAng:Right()
    local dirs = {
        -fwd,
        (-fwd + right * 0.5):GetNormalized(),
        (-fwd - right * 0.5):GetNormalized(),
        right,
        -right,
        fwd,
    }

    local behind
    for _, dir in ipairs(dirs) do
        local wallTr = util.TraceLine({
            start  = origin,
            endpos = origin + dir * BEHIND_DIST,
            filter = { adminPly, target },
            mask   = MASK_SOLID_BRUSHONLY,
        })

        local spot
        if wallTr.Hit then
            if wallTr.Fraction * BEHIND_DIST < 16 then
                spot = nil
            else
                spot = wallTr.HitPos - dir * 16
            end
        else
            spot = origin + dir * BEHIND_DIST
        end

        if spot then
            local hullTr = util.TraceHull({
                start  = spot + Vector(0, 0, 4),
                endpos = spot + Vector(0, 0, 4),
                mins   = adminPly:OBBMins(),
                maxs   = adminPly:OBBMaxs(),
                filter = { adminPly, target },
                mask   = MASK_PLAYERSOLID,
            })
            if not hullTr.StartSolid then
                behind = spot
                break
            end
        end
    end

    if not behind then
        adminPly:ChatPrint("No space to teleport to")
        return
    end

    local floor = util.TraceLine({
        start  = behind + Vector(0, 0, 40),
        endpos = behind - Vector(0, 0, 80),
        filter = { adminPly, target },
        mask   = MASK_SOLID_BRUSHONLY,
    })
    if floor.Hit then behind = floor.HitPos end

    adminPly:SetPos(behind)

    local lookAng = (target:GetPos() - behind):Angle()
    lookAng.p, lookAng.r = 0, 0
    adminPly:SetEyeAngles(lookAng)

    local SEE_DOT   = 0.6
    local SEE_RANGE = 2200

    for _, obs in player.Iterator() do
        if obs == adminPly then continue end
        if not obs:Alive() then continue end

        local doFade = (obs == target)

        if not doFade then
            local obsPos = obs:EyePos()
            local toPos  = behind - obsPos
            local dist   = toPos:Length()
            if dist <= SEE_RANGE and dist > 1 then
                toPos:Normalize()
                if obs:EyeAngles():Forward():Dot(toPos) >= SEE_DOT then
                    local los = util.TraceLine({
                        start  = obsPos,
                        endpos = behind + Vector(0, 0, 36),
                        filter = { obs, adminPly },
                        mask   = MASK_SHOT,
                    })
                    if los.Fraction >= 0.95 then
                        doFade = true
                    end
                end
            end
        end

        if doFade then
            obs:ScreenFade(SCREENFADE.IN, Color(0, 0, 0), 0.7, 0.4)
        end
    end
end)
