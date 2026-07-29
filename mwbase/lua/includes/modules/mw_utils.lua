AddCSLuaFile()
module("mw_utils", package.seeall)

local cachedBones = {}

function mw_utils.LookupBoneCached(ent, boneName)
    local model = ent:GetModel()

    if (model == nil) then
        return nil
    end

    cachedBones[model] = cachedBones[model] || {}
    cachedBones[model][boneName] = cachedBones[model][boneName] || ent:LookupBone(boneName)

    return cachedBones[model][boneName]
end

local cachedAttachments = {}

function mw_utils.LookupAttachmentCached(ent, attName)
    local model = ent:GetModel()
    
    if (model == nil) then
        return nil
    end

    cachedAttachments[model] = cachedAttachments[model] || {}
    cachedAttachments[model][attName] = cachedAttachments[model][attName] || ent:LookupAttachment(attName)

    return cachedAttachments[model][attName] > 0 && cachedAttachments[model][attName] || nil
end

local function recmatch(table1, table2)
    for k, v in pairs(table2) do
        if (table1[k] == nil) then
            return false
        end

        if (istable(v)) then
            if (!recmatch(table1[k], v)) then
                return false
            end
        else
            if (v != table1[k]) then
                return false
            end
        end
    end
    for k, v in pairs(table1) do
        if (table2[k] == nil) then
            return false
        end

        if (istable(v)) then
            if (!recmatch(table2[k], v)) then
                return false
            end
        else
            if (v != table2[k]) then
                return false
            end
        end
    end

    return true
end
function mw_utils.CheckMatchingTables(table1, table2)
    return recmatch(table1, table2)
end

function mw_utils.CheckMatchingBones(model1, model2)
    for b = 0, model1:GetBoneCount(), 1 do
        if (mw_utils.LookupBoneCached(model2, model1:GetBoneName(b))) != nil then
            return true
        end
    end

    return false
end

function mw_utils.IsAttachmentBasedOn(current, base)
    while current != nil do
        if (current == base) then
            return true
        end

        if (MW_ATTS[current] == nil) then
            return false
        end
        
        current = MW_ATTS[current].Base
    end

    return false
end

local function requireAttachment(ent, attName)
    ent.m_AttachmentRequests = ent.m_AttachmentRequests || {}
    ent.m_AttachmentDeliveries = ent.m_AttachmentDeliveries || {}

    local attId = mw_utils.LookupAttachmentCached(ent, attName)

    if (ent.m_AttachmentRequests[attId] == nil) then
        ent.m_AttachmentRequests[attId] = Matrix()

        timer.Simple(0, function()
            if (!IsValid(ent)) then
                return
            end

            local attData = ent:GetAttachment(attId)

            local computeMatrix = Matrix()
            computeMatrix:SetTranslation(attData.Pos)
            computeMatrix:SetAngles(attData.Ang)

            local worldMatrix = ent:GetBoneMatrix(0)

            computeMatrix = worldMatrix:GetInverse() * computeMatrix
            ent.m_AttachmentRequests[attId] = computeMatrix
        end)

        ent.m_AttachmentDeliveries[attId] = {Pos = Vector(), Ang = Angle()}
    end

    if (!ent.m_bFastAttachment) then
        if (ent.OnBuildFastAttachments == nil) then
            ent.OnBuildFastAttachments = function() end --to avoid if
        end

        ent:AddCallback("BuildBonePositions", function(ent, numbones)
            local matrix = ent:GetBoneMatrix(0)

            if (matrix == nil) then
                return
            end

            for attId, localMat in pairs(ent.m_AttachmentRequests) do
                local newMatrix = matrix * localMat

                ent.m_AttachmentDeliveries[attId].Pos = newMatrix:GetTranslation()
                ent.m_AttachmentDeliveries[attId].Ang = newMatrix:GetAngles()
                ent:OnBuildFastAttachments()
            end
        end)

        ent.m_bFastAttachment = true
    end
end

--this is only really good for static props
--it calculates local offset from root bone, so if the attachment isn't parented to that (or not static), it won't return
--good values
function mw_utils.GetFastAttachment(ent, attName)
    requireAttachment(ent, attName)
    return ent.m_AttachmentDeliveries[mw_utils.LookupAttachmentCached(ent, attName)]
end

local function isInjectorLoadingConversions(inj)
    if (!istable(inj.Attachment)) then
        if (MW_ATTS[inj.Attachment] != nil) then
            return mw_utils.IsAttachmentBasedOn(inj.Attachment, "att_conversion")
        end
    else
        for i, injatt in pairs(inj.Attachment) do
            if (MW_ATTS[injatt] != nil) then
                if (mw_utils.IsAttachmentBasedOn(injatt, "att_conversion")) then
                    return true
                end
            end
        end
    end

    return false
end

function mw_utils.LoadInjectors(swep)
    if (swep.Customization == nil) then
        mw_utils.ErrorPrint("LoadInjectors: Customization is nil! Are you loading before it?")
        return
    end

    local swepClass = string.GetFileFromFilename(swep.Folder)
    
    for className, inj in SortedPairs(MW_ATT_INJECTORS) do
        if (inj.SWEPs != nil && table.HasValue(inj.SWEPs, swepClass)) then
            local slot = isInjectorLoadingConversions(inj) && SLOT_CONVERSIONS || math.max(inj.Slot, SLOT_CONVERSIONS + 1)
            swep.Customization[slot] = swep.Customization[slot] || {}

            if (!istable(inj.Attachment)) then
                if (MW_ATTS[inj.Attachment] != nil && !table.HasValue(swep.Customization[slot], inj.Attachment)) then
                    table.insert(swep.Customization[slot], inj.Attachment)
                end
            else
                for i, injatt in pairs(inj.Attachment) do
                    if (MW_ATTS[injatt] != nil && !table.HasValue(swep.Customization[slot], injatt)) then
                        table.insert(swep.Customization[slot], injatt)
                    end
                end
            end
        end
    end
end

--https://gist.github.com/jrus/3197011
local random = math.random
local function uuid()
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end)
end

function mw_utils.DevPrint(message)
    if (GetConVar("developer"):GetInt() > 0) then
        local str = CLIENT && "Client" || "Server"
        MsgC(Color(120, 220, 100, 255), "(" .. str .. ") MW Base: ", Color(255, 255, 255, 255), message.."\n")
    end
end

function mw_utils.ErrorPrint(message)
    if (GetConVar("developer"):GetInt() > 0) then
        local str = CLIENT && "Client" || "Server"
        MsgC(Color(220, 40, 80, 255), "(" .. str .. ") MW Base ERROR: ", Color(255, 235, 235, 255), message.."\n")
    end
end

function mw_utils.LoadPreset(weapon, preset)
    for slot, atts in SortedPairs(weapon.Customization) do
        local index = 1
        
        for i, att in SortedPairs(atts) do
            if (table.HasValue(preset.Attachments, att)) then
                index = i
            end
        end
        
        if (!weapon:HasAttachment(weapon.Customization[slot][index])) then --just sending what we need
            if (CLIENT) then
                mw_utils.SendAttachmentToServer(weapon, slot, index)
            else
                weapon:CreateAttachmentEntity(weapon.Customization[slot][index])
            end
        end
    end
end

function mw_utils.ReloadAttachment(attachmentClass)
    if (GetConVar("sv_cheats"):GetInt() > 0 && GetConVar("developer"):GetInt() > 0) then
        local currentClass = attachmentClass
        while (currentClass != nil) do
            local folder = MW_ATTS[currentClass].Folder
            MW_ATTS[currentClass] = nil
            LoadAttachment(folder, currentClass..".lua") --mw_loader
            currentClass = MW_ATTS[currentClass].Base
        end

        currentClass = attachmentClass
        while (currentClass != nil) do
            DoAttachmentInheritance(MW_ATTS[currentClass]) --mw_loader
            currentClass = MW_ATTS[currentClass].Base
        end
    end
end

if (CLIENT) then
    --used to reparent ents after a fullupdate
    local FullUpdateEntities = {}
    
    function mw_utils.DealWithFullUpdate(ent)
        FullUpdateEntities[ent] = true
    end

    hook.Add("PreRender", "mw_utilsFullUpdatePreRender", function()
        for ent, _ in pairs(FullUpdateEntities) do
            if (!IsValid(ent)) then
                FullUpdateEntities[ent] = nil
                continue
            end

            local fullUpdateParent = ent:GetInternalVariable("m_hNetworkMoveParent")

            if (!IsValid(ent:GetParent()) && IsValid(fullUpdateParent)) then
                ent:SetParent(fullUpdateParent)
            end
        end
    end)

    function mw_utils.SendAttachmentToServer(weapon, slot, index)
        net.Start("mgbase_customize_att")
            net.WriteInt(slot, 32)
            net.WriteInt(index, 32)
            net.WriteEntity(weapon)
        net.SendToServer()
    end

    local function saveFavs()
        file.CreateDir("mwbase")
        file.Write("mwbase/favorites.json", util.TableToJSON(MW_FAVORITES))
    end
    
    function mw_utils.FavoriteAsset(swepClass, assetClass)
        MW_FAVORITES[swepClass] = MW_FAVORITES[swepClass] || {}
    
        if (!table.HasValue(MW_FAVORITES[swepClass], assetClass)) then
            table.insert(MW_FAVORITES[swepClass], assetClass)
            saveFavs()
        end
    end
    
    function mw_utils.UnfavoriteAsset(swepClass, assetClass)
        if (MW_FAVORITES[swepClass] == nil || !table.HasValue(MW_FAVORITES[swepClass], assetClass)) then
            return
        end
    
        table.RemoveByValue(MW_FAVORITES[swepClass], assetClass)
    
        if (#MW_FAVORITES[swepClass] <= 0) then
            MW_FAVORITES[swepClass] = nil
        end
    
        saveFavs()
    end
    
    function mw_utils.IsAssetFavorite(swepClass, assetClass)
        return MW_FAVORITES[swepClass] != nil && table.HasValue(MW_FAVORITES[swepClass], assetClass)
    end

    function mw_utils.GetPresetsForSWEP(swepClass)
        local presets = {}
        
        for _, preset in pairs(MW_PRESETS) do
            if (preset.SWEP == swepClass) then
                presets[#presets + 1] = table.Copy(preset)
            end
        end
    
        return presets
    end

    function mw_utils.SavePreset(swepClass, name, attachmentList)
        local fileName = uuid()
        local preset = {
            SWEP = swepClass,
            Name = name,
            Attachments = attachmentList
        }
    
        file.CreateDir("mwbase/presets")
        file.Write("mwbase/presets/" .. fileName .. ".json", util.TableToJSON(preset, true))
    
        preset.ClassName = fileName
        preset._bUserGenerated = true
    
        MW_PRESETS[fileName] = table.Copy(preset)
    end
    
    function mw_utils.RemovePreset(className)
        local pathAndName = "mwbase/presets/"..className..".json"
    
        if (file.Exists(pathAndName, "DATA")) then
            file.Delete(pathAndName)
            MW_PRESETS[className] = nil
        end
    end
end

function mw_utils.CompileFile(f)
    local content = file.Read(f, "LUA")

    if (content != nil) then
        AddCSLuaFile(f)

        if (string.find(content, "AddCSLuaFile")) then
            mw_utils.DevPrint("safeInclude: Don't run AddCSLuaFile! This is already done for you ("..f..")")
        end

        local incl = CompileString(content, "MWBaseSafeInclude_"..f, false)--RunString(content, "MWBaseSafeInclude", false)

        if (isstring(incl)) then
            mw_utils.ErrorPrint("safeInclude: "..f.." errored! Stack trace below")
            mw_utils.ErrorPrint("... "..incl)
            return false, incl
        end

        incl()
        return true, "no error"
    end

    mw_utils.ErrorPrint("safeInclude: missing file "..f.."!")
    return false, "missing file"
end