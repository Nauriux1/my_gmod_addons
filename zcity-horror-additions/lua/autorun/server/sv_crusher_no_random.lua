if not SERVER then return end

local function IsCrusherOrg(org)
    return org and IsValid(org.owner) and org.owner:GetNWBool("zb_is_crusher", false)
end

timer.Simple(0, function()
    local mod = hg and hg.organism and hg.organism.module and hg.organism.module.random_events
    if not mod then return end

    local realMain = mod[2]
    if realMain then
        mod[2] = function(owner, org, timeValue)
            if IsValid(owner) and owner:GetNWBool("zb_is_crusher", false) then
                org.timeToRandom = CurTime() + math.random(120, 320)
                return
            end
            return realMain(owner, org, timeValue)
        end
    end

    local realTrigger = mod.TriggerRandomEvent
    if realTrigger then
        mod.TriggerRandomEvent = function(owner, eventName)
            if IsValid(owner) and owner:GetNWBool("zb_is_crusher", false) then return end
            return realTrigger(owner, eventName)
        end
    end
end)
