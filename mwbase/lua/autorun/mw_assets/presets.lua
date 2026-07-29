require("mw_utils")
AddCSLuaFile()

MW_PRESETS = {}

local function loadPresets(dir)
    dir = dir .. "/"
    local File, Directory = file.Find(dir.."*", "LUA")
    for k, v in ipairs(File) do
        if (string.EndsWith(v, ".lua")) then 
            PRESET = {}
                
            local name = string.Replace(v, ".lua", "")
            if (mw_utils.CompileFile(dir..v)) then
                PRESET.ClassName = name
                PRESET._bUserGenerated = false

                if (!table.IsEmpty(PRESET)) then
                    MW_PRESETS[name] = table.Copy(PRESET)
                end
            end
        end 
    end
        
    for k, v in ipairs(Directory) do
        loadPresets(dir..v) 
    end 
end
loadPresets("weapons/mg_base/modules/presets")

if (CLIENT) then 
    local function loadPresetsFromData(dir)
        dir = dir .. "/"  
        local File, Directory = file.Find(dir.."*", "DATA")
        for k, v in ipairs(File) do
            if (string.EndsWith(v, ".json")) then  
                local name = string.Replace(v, ".json", "") 
                local preset = util.JSONToTable(file.Read(dir..v))

                if (preset == nil || table.IsEmpty(preset)) then
                    continue 
                end 

                if (preset.Name == nil || preset.SWEP == nil || preset.Attachments == nil) then
                    continue
                end

                if (!isstring(preset.Name) || !isstring(preset.SWEP)) then
                    continue
                end

                if (!istable(preset.Attachments)) then
                    continue
                end

                preset.ClassName = name
                preset._bUserGenerated = true

                MW_PRESETS[name] = table.Copy(preset)
            end 
        end
            
        for k, v in ipairs(Directory) do
            loadPresetsFromData(dir..v) 
        end 
    end
    loadPresetsFromData("mwbase/presets")
end