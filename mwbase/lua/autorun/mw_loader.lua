CreateConVar("mgbase_precacheatts", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Attachments limit.", 0, 1)
require("mw_utils")

local function IncludeDir(dir) 
    dir = dir .. "/"
    local File, Directory = file.Find(dir.."*", "LUA")
    for k, v in ipairs(File) do
        if string.EndsWith(v, ".lua") then 
            AddCSLuaFile(dir..v)
            include(dir..v) 
        end   
    end
    
    for k, v in ipairs(Directory) do 
        IncludeDir(dir..v)   
    end    
end      
     
CHAN_ATMO = 137 
CHAN_REFLECTION = 138
CHAN_CASINGS = 139 
CHAN_TRIGGER = 140  
CHAN_MINIGUNFIRE = 141 
CHAN_MAGAZINEDROP = 142
CHAN_WPNFOLEY = 143

IncludeDir("weapons/mg_base/modules/sounds")

CUSTOMIZATION_COLOR_COMMON = Color(0, 220, 30, 255)
CUSTOMIZATION_COLOR_LEGENDARY = Color(255, 175, 0, 255)
CUSTOMIZATION_COLOR_EPIC = Color(255, 0, 150, 255)
CUSTOMIZATION_COLOR_RARE = Color(0, 175, 255, 255)

SLOT_CONVERSIONS = -999

include("mw_assets/rigs.lua")
include("mw_assets/attachments.lua")
include("mw_assets/injectors.lua")
include("mw_assets/presets.lua")
include("mw_assets/favorites.lua")

hook.Call("MW19_OnAssetsLoaded")

hook.Add("PreRegisterSWEP", "MW19_PreRegisterSWEP", function(swep, class)
    if (swep.Customization != nil) then

        --give our sweps their tracer names
        if !swep.Bullet.TracerName then
            if swep.SubCategory == "Shotguns" then 
                swep.Bullet.TracerName = "mgbase_tracer_slow"
            elseif swep.SubCategory == "Sniper Rifles" then 
                swep.Bullet.TracerName = "mgbase_tracer_fast"
            elseif swep.SubCategory == "Pistols" || swep.SubCategory == "Submachine Guns" then 
                swep.Bullet.TracerName = "mgbase_tracer_small"
            else 
                swep.Bullet.TracerName = "mgbase_tracer"
            end 
        end

        --check if we have missing attachments and if yes remove em
        for slot, atts in pairs(swep.Customization) do
            if (isstring(slot)) then --old sweps
                mw_utils.ErrorPrint("PreRegisterSWEP: "..swep.Folder.." is using old base! SWEP will not show up in menu...")
                return false --bye
            end

            local newAtts = table.Copy(atts)

            for i, attClass in pairs(atts) do
                if (!isstring(attClass)) then --old sweps
                    mw_utils.ErrorPrint("PreRegisterSWEP: "..swep.Folder.." is using old base! SWEP will not show up in menu...")
                    swep = {}
                    return false --bye
                end

                if (MW_ATTS[attClass] == nil) then
                    mw_utils.ErrorPrint("PreRegisterSWEP: "..swep.Folder.." tried loading an attachment that doesn't exist ("..attClass..")!")
                    table.remove(newAtts, i)
                end
            end

            if (#newAtts <= 0) then
                table.remove(swep.Customization, slot)
            else
                swep.Customization[slot] = newAtts
            end
        end
    end
end)