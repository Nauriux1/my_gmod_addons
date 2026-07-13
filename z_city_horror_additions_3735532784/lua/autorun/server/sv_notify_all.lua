if not SERVER then return end

concommand.Add("zb_notify_all", function(adminPly, cmd, args)
    if IsValid(adminPly) and not adminPly:IsAdmin() then return end

    local text = table.concat(args, " ")
    if text == "" then
        local m = "Usage: zb_notify_all <message>"
        if IsValid(adminPly) then adminPly:ChatPrint(m) else print(m) end
        return
    end

    for _, ply in player.Iterator() do
        if IsValid(ply) and ply.Notify then
            ply:Notify(text, 0)
        end
    end

    -- local who = IsValid(adminPly) and adminPly:Nick() or "Console"
    -- print(who .. " notified everyone: " .. text)
end)
