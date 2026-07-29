require("mw_utils")
AddCSLuaFile()
MW_ATTS = {} 
  
function GetAttachmentBaseClass(base)
    MW_ATTS[base] = MW_ATTS[base] || {}

    return MW_ATTS[base]
end

function LoadAttachment(path, fileName)
    ATTACHMENT = {} 

    if (mw_utils.CompileFile(path..fileName)) then
        local name = string.Replace(fileName, ".lua", "")

        if (ATTACHMENT.Base == name) then
            mw_utils.ErrorPrint("LoadAttachment: You are inheriting from self (Base = myself)! This would freeze your game. ("..path..fileName..")")
            return
        end

        ATTACHMENT.ClassName = name
        ATTACHMENT.Folder = path
        table.Merge(GetAttachmentBaseClass(name), table.Copy(ATTACHMENT))
    end
end

local oldModel = Model  
function Model(dir) --sorry 
    if (GetConVar("mgbase_precacheatts"):GetInt() > 0) then
        util.PrecacheModel(dir)
    end
    return dir     
end    
     
local function loadAttachments(dir) 
    dir = dir .. "/"    
    local File, Directory = file.Find(dir.."*", "LUA")
    for k, v in ipairs(File) do
        if (string.EndsWith(v, ".lua")) then   
            LoadAttachment(dir, v)
        end  
    end
     
    for k, v in ipairs(Directory) do
        loadAttachments(dir..v)
    end 
end
 
loadAttachments("weapons/mg_base/modules/attachmentss")
Model = oldModel
  
--check baseclass 
local function checkBaseClassInAttachments()
    for name, att in pairs(MW_ATTS) do
        if (istable(name)) then
            mw_utils.ErrorPrint("checkBaseClassInAttachments: You may have defined BaseClass twice! "..(name.Name || "error class"))
            MW_ATTS[name] = nil
        end

        if (name != "att_base") then
            if (att.Base == nil) then
                mw_utils.ErrorPrint("checkBaseClassInAttachments: "..name.." doesn't inherit from anything! This will cause problems...")
                MW_ATTS[name] = nil
            end

            if (MW_ATTS[att.Base] == nil) then
                mw_utils.ErrorPrint("checkBaseClassInAttachments: "..name.." is trying to inherit from missing attachment! ("..(att.Base || "missing class")..")")
                MW_ATTS[name] = nil
            end
        end
    end
end
checkBaseClassInAttachments()

--inherit 
local function inherit(current, base)
    for k, v in pairs(base) do
        if (!istable(v)) then 
            if (current[k] == nil) then 
                current[k] = v 
            end
        else 
            if (current[k] == nil) then
                current[k] = {}
            end
            inherit(current[k], v)
        end
    end
end

function DoAttachmentInheritance(att)
    local baseClass = MW_ATTS[att.Base]
    while (baseClass != nil) do
        inherit(att, baseClass)
        baseClass = MW_ATTS[baseClass.Base]
    end 
end

local function finishAttachments()
    for name, att in pairs(MW_ATTS) do
        DoAttachmentInheritance(att)
    end
end
finishAttachments()