util.AddNetworkString("ZB_ScoreboardMeaty")

zb_meaty_active = zb_meaty_active or false

local function SyncMeatyState(target)
    net.Start("ZB_ScoreboardMeaty")
    net.WriteBool(zb_meaty_active)
    if target then
        net.Send(target)
    else
        net.Broadcast()
    end
end

hook.Add("PlayerInitialSpawn", "zb_meaty_sync_on_join", function(ply)
    timer.Simple(1, function()
        if IsValid(ply) then
            SyncMeatyState(ply)
        end
    end)
end)

concommand.Add("zb_scoreboard_meaty", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsAdmin() then return end

    local val = tonumber(args[1])
    if val == nil then
        val = zb_meaty_active and 0 or 1
    end

    val = math.Clamp(math.floor(val), 0, 1)
    zb_meaty_active = val == 1

    SyncMeatyState()

    --local adminName = IsValid(ply) and ply:Name() or "Console"
    --print("[Scoreboard] Meaty mode " .. (zb_meaty_active and "ENABLED" or "DISABLED") .. " by " .. adminName)
end)
-- designed and realized by alagri & omnissiah respectively
