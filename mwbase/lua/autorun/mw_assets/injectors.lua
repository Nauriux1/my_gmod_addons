require("mw_utils")
AddCSLuaFile()

MW_ATT_INJECTORS = {}

local function loadInjectors(dir)
    dir = dir .. "/"
    local File, Directory = file.Find(dir.."*", "LUA")
    for k, v in ipairs(File) do
        if (string.EndsWith(v, ".lua")) then 
            INJECTOR = {}
            
            local name = string.Replace(v, ".lua", "")
            if (mw_utils.CompileFile(dir..v)) then
            
                INJECTOR.ClassName = name

                if (!table.IsEmpty(INJECTOR)) then
                    MW_ATT_INJECTORS[name] = table.Copy(INJECTOR)
                end
            end
        end 
    end
    
    for k, v in ipairs(Directory) do
        loadInjectors(dir..v) 
    end 
end
loadInjectors("weapons/mg_base/modules/injectors")