require("mw_utils")
AddCSLuaFile()

MW_RIGS = {}
MW_GLOVES = {}

local function loadRigs(dir)
    dir = dir .. "/"
    local File, Directory = file.Find(dir.."*", "LUA")
    for k, v in ipairs(File) do
        if (string.EndsWith(v, ".lua")) then 
            RIG = {} 
            GLOVE = {}
            
            local name = string.Replace(v, ".lua", "")
            if (mw_utils.CompileFile(dir..v)) then
                if (!table.IsEmpty(RIG)) then
                    MW_RIGS[name] = table.Copy(RIG)
                end
                
                if (!table.IsEmpty(GLOVE)) then
                    MW_GLOVES[name] = table.Copy(GLOVE)
                end
            end
            
            RIG = nil
            GLOVE = nil
        end
    end
     
    for k, v in ipairs(Directory) do 
        loadRigs(dir..v)
    end  
end
loadRigs("weapons/mg_base/modules/rigs")