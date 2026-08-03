-- 
util.AddNetworkString("Get_Appearance")
util.AddNetworkString("OnlyGet_Appearance")
hg.Appearance = hg.Appearance or {}
local APmodule = hg.Appearance

hg.PointShop = hg.PointShop or {}
local PSmodule = hg.PointShop

local function CheckAttachments(ply,tbl)
    if !IsValid(ply) or !ply:IsPlayer() then return tbl end
    if not istable(tbl) then return tbl end
    tbl.AAttachments = tbl.AAttachments or {}
    if hg.Appearance.GetAccessToAll and hg.Appearance.GetAccessToAll(ply) then return tbl end
    for i = 1, #tbl.AAttachments do
        local uid = tbl.AAttachments[i]
        if PSmodule.Items and PSmodule.Items[uid] and ply.PS_HasItem and (!ply:PS_HasItem(uid)) then
            tbl.AAttachments[i] = ""
            ply:ChatPrint(uid .. " - not bought, removed")
        end
        if hg.Accessories and hg.Accessories[uid] and hg.Accessories[uid].disallowinappearance then
            tbl.AAttachments[i] = ""
        end
    end
    return tbl
end

local function ForceApplyAppearance(ply, tbl, noModelChange)
    if not IsValid(ply) or not istable(tbl) then return end

    local tMdl = APmodule.PlayerModels[1][tbl.AModel] or APmodule.PlayerModels[2][tbl.AModel] or tbl.AModel
    local mdl = istable(tMdl) and tMdl.mdl or tMdl
    if isstring(mdl) and mdl ~= "" and mdl ~= ply:GetModel() and !noModelChange then
        ply:SetModel(mdl)
    end

    local clr = tbl.AColor or Color(255, 255, 255)
    if ply.SetPlayerColor then
        ply:SetPlayerColor(Vector(clr.r / 255, clr.g / 255, clr.b / 255))
    end
    ply:SetNWVector("PlayerColor", Vector(clr.r / 255, clr.g / 255, clr.b / 255))

    ply:SetSubMaterial()

    if tbl.AName then ply:SetNWString("PlayerName", tbl.AName) end

    -- Reset then apply bodygroups (numeric id map from editor, or named registry)
    ply:SetBodyGroups("00000000000000000000")
    tbl.ABodygroups = tbl.ABodygroups or {}

    for id, val in pairs(tbl.ABodygroups) do
        local gid = tonumber(id)
        local gval = tonumber(val)
        if gid and gval then
            pcall(function() ply:SetBodygroup(gid, gval) end)
        end
    end

    if tbl.ASkin ~= nil then
        pcall(function() ply:SetSkin(tonumber(tbl.ASkin) or 0) end)
    end

    if ply.SetNetVar then
        ply:SetNetVar("Accessories", tbl.AAttachments or {})
    end

    ply.CurAppearance = {}
    table.CopyFromTo(tbl, ply.CurAppearance)

    hook.Run("ZB_AppearancePostApply", ply, tbl)
end

local function WearAppearance(ply, tbl)
    local checked = CheckAttachments(ply, tbl)
    ForceApplyAppearance(ply, checked)
end

APmodule.ForceApplyAppearance = ForceApplyAppearance

local tWaitResponse = {}

function ApplyAppearance(Client, tAppearance, bRandom, bResponeIsValid, bUseCahsed)
    if not IsValid(Client) then return end
    if bRandom or (Client.IsBot and Client:IsBot()) or (Client.IsRagdoll and Client:IsRagdoll()) then
        tAppearance = APmodule.GetRandomAppearance and APmodule.GetRandomAppearance() or {}
        WearAppearance(Client, tAppearance)
        return
    end
    if bUseCahsed then
        tAppearance = Client.CachedAppearance or (APmodule.GetRandomAppearance and APmodule.GetRandomAppearance()) or {}
        if APmodule.AppearanceValidater and not APmodule.AppearanceValidater(tAppearance) then
            tAppearance = APmodule.GetRandomAppearance()
        end
        net.Start("OnlyGet_Appearance")
        net.Send(Client)
        WearAppearance(Client, tAppearance)
        return
    end

    if not bResponeIsValid then
        tWaitResponse[Client] = CurTime() + 3
        net.Start("Get_Appearance")
        net.Send(Client)
        return
    end
    if not tWaitResponse[Client] then return end
    if tWaitResponse[Client] > CurTime() then
        ApplyAppearance(Client, nil, true)
        return
    end

    if not tAppearance then ApplyAppearance(Client, nil, true) return end
    if APmodule.AppearanceValidater and not APmodule.AppearanceValidater(tAppearance) then
        ApplyAppearance(Client, nil, true)
        return
    end

    WearAppearance(Client, tAppearance)
end

net.Receive("Get_Appearance", function(len, client)
    local tAppearance = net.ReadTable()
    local bRandom = net.ReadBool()
    if APmodule.AppearanceValidater and not APmodule.AppearanceValidater(tAppearance) then bRandom = true end
    ApplyAppearance(client, tAppearance, table.IsEmpty(tAppearance) and true or bRandom, true)
end)

net.Receive("OnlyGet_Appearance", function(len, client)
    local tAppearance = net.ReadTable()
    local bRandom = not tAppearance or table.IsEmpty(tAppearance)
    client.CachedAppearance = bRandom and (APmodule.GetRandomAppearance and APmodule.GetRandomAppearance()) or tAppearance
end)

APmodule.ApplyAppearance = ApplyAppearance

function ApplyAppearanceRagdoll(ent, ply)
    local Appearance = ply.CurAppearance
    if not Appearance then return end
    ent:SetNWString("PlayerName", ply:GetNWString("PlayerName", Appearance.AName))
    if ent.SetNetVar then
        ent:SetNetVar("Accessories", ply.GetNetVar and ply:GetNetVar("Accessories", "") or "")
    end
end
