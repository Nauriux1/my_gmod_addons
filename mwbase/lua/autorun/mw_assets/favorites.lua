AddCSLuaFile()

if (CLIENT) then
    MW_FAVORITES = {}

    --load favs
    if (file.Exists("mwbase/favorites.json", "DATA")) then
        MW_FAVORITES = util.JSONToTable(file.Read("mwbase/favorites.json", "DATA"))
    end
end