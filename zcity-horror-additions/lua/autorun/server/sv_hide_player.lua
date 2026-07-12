if not SERVER then return end

local function IsZCity()
    return engine.ActiveGamemode() == "zcity"
end

local function FindPlayer(search)
    search = string.lower(search)
    for _, ply in player.Iterator() do
        if string.lower(ply:Nick()) == search then return ply end
    end
    for _, ply in player.Iterator() do
        if string.find(string.lower(ply:Nick()), search, 1, true) then return ply end
    end
end

concommand.Add("zb_hide_player", function(adminPly, cmd, args)
    if not IsZCity() then return end
    if IsValid(adminPly) and not adminPly:IsAdmin() then return end

    local state = tonumber(args[1])
    local name  = args[2]

    if name and args[3] then
        name = table.concat(args, " ", 2)
    end

    if state == nil or not name then
        local m = "Usage: zb_hide_player <0|1> <player name>"
        if IsValid(adminPly) then adminPly:ChatPrint(m) else print(m) end
        return
    end

    state = math.Clamp(math.floor(state), 0, 1)

    local target = FindPlayer(name)
    if not IsValid(target) then
        local m = "Player not found: " .. name
        if IsValid(adminPly) then adminPly:ChatPrint(m) else print(m) end
        return
    end

    target:SetNWBool("zb_hidden", state == 1)

    local who    = IsValid(adminPly) and adminPly:Nick() or "Console"
    local action = state == 1 and "hid" or "unhid"
    print("[zb_hide_player] " .. who .. " " .. action .. " " .. target:Nick() .. " from the scoreboard")
end)

hook.Add("PlayerDisconnected", "zb_hide_player_cleanup", function(ply)
    if IsValid(ply) then ply:SetNWBool("zb_hidden", false) end
end)

local function IsValidSpecTarget(ply)
    return IsValid(ply)
        and ply:IsPlayer()
        and ply:Alive()
        and ply:Team() ~= TEAM_SPECTATOR
        and not ply:GetNWBool("zb_hidden", false)
end

local function GetSpecList()
    local list = {}
    for _, ply in player.Iterator() do
        if IsValidSpecTarget(ply) then
            list[#list + 1] = ply
        end
    end
    table.sort(list, function(a, b) return a:EntIndex() < b:EntIndex() end)
    return list
end

local function NextSpecTarget(current)
    local list = GetSpecList()
    if #list == 0 then return nil end

    local idx
    for i, ply in ipairs(list) do
        if ply == current then
            idx = i
            break
        end
    end
    if not idx then return list[1] end

    local nextIdx = idx % #list + 1
    return list[nextIdx]
end

timer.Create("zb_hide_player_spec_guard", 0.1, 0, function()
    if not IsZCity() then return end

    for _, ply in player.Iterator() do
        if ply:Alive() then continue end

        local target = ply:GetNWEntity("spect")
        if not IsValid(target) then continue end

        if target:GetNWBool("zb_hidden", false) then
            local nextTarget = NextSpecTarget(target)
            if IsValid(nextTarget) and nextTarget ~= target
                and not nextTarget:GetNWBool("zb_hidden", false) then
                ply:SetNWEntity("spect", nextTarget)
            end
        end
    end
end)
-- designed and realized by alagri & omnissiah respectively
