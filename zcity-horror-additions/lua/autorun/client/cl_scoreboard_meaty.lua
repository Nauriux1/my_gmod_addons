local function IsZCity()
    return engine.ActiveGamemode() == "zcity"
end

local zb_meaty_active = false

net.Receive("ZB_ScoreboardMeaty", function()
    zb_meaty_active = net.ReadBool()

    if IsValid(scoreBoardMenu) then
        scoreBoardMenu:Remove()
        scoreBoardMenu = nil
    end
end)

hook.Add("ChatText", "zb_meaty_suppress_chat", function(index, name, text, msgtype)
    if not IsZCity() then return end
    if not zb_meaty_active then return end

    if msgtype == "joinleave" or msgtype == "namechange" then return true end
    -- уээ костыли
    if isstring(text) and (
            text:find("changed name to") or
            text:find("joined the game") or
            text:find("left the game") or
            text:find("disconnected") or
            text:find("вступает в игру") or
            text:find("покидает игру") or
            text:find("отключился") or
            text:find("сменил имя на")
        ) then
        return true
    end
end)

ZB_ScoreboardFilter = ZB_ScoreboardFilter or {}
ZB_ScoreboardFilter.predicates = ZB_ScoreboardFilter.predicates or {}
ZB_ScoreboardFilter.Register = ZB_ScoreboardFilter.Register or function(id, fn)
    ZB_ScoreboardFilter.predicates[id] = fn
end

ZB_ScoreboardFilter.Register("meaty", function(ply)
    if not zb_meaty_active then return false end
    if ply:Team() == TEAM_SPECTATOR then return false end
    return not ply:Alive()
end)
-- designed and realized by alagri & omnissiah respectively
