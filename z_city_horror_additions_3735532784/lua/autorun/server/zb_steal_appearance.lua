if not SERVER then return end


concommand.Add("zb_identity_theft", function(adminPly)
    if not hg or not hg.Appearance.ForceApplyAppearance then
    print("Z-City Appearance module not found")
    return end
    if not IsValid(adminPly) or not adminPly:IsAdmin() then return end

    local tr = util.TraceLine({
        start  = adminPly:EyePos(),
        endpos = adminPly:EyePos() + adminPly:GetAimVector() * 1000,
        filter = function(ent)
            if ent == adminPly then return false end
            if ent:IsPlayer() then return true end
            if ent:IsRagdoll() then return true end
            return false
        end,
        mask   = MASK_SHOT,
    })

    local hitEnt = tr.Entity
    if not IsValid(hitEnt) and not adminPly.StoredIdentity then
        adminPly:ChatPrint("Aim at a player")
        return
    end

    local target = hitEnt
    if hitEnt:IsRagdoll() and hg and hg.RagdollOwner then
        target = hg.RagdollOwner(hitEnt) or hitEnt
    end
    if target == adminPly then return end
    
    if adminPly.StoredIdentity then
        hg.Appearance.ForceApplyAppearance(adminPly, adminPly.StoredIdentity, false)
        adminPly:ChatPrint("You restored your appearance")
        adminPly.StoredIdentity = nil
    elseif (IsValid(target) and target:IsPlayer() and target.CurAppearance and not adminPly.StoredIdentity) then
        adminPly.StoredIdentity = adminPly.CurAppearance
        hg.Appearance.ForceApplyAppearance(adminPly, target.CurAppearance, false)
        -- adminPly:ChatPrint("You stole appearance of " .. target:Nick())
        adminPly:ChatPrint("You stole appearance of " .. target:GetNWString("PlayerName") .. " (" .. target:Nick() .. ")")
    end
end)