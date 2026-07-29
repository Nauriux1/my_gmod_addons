AddCSLuaFile()
module("mw_input", package.seeall)

local registeredBinds = {}
local delegates = {}
local pressCallbacks = {}

local function cvar(bindName)
    return "mgbase_binds_" .. bindName
end

function RegisterBind(bindName, sourceCmd)
    if (!table.HasValue(registeredBinds, bindName)) then
        if (CLIENT) then
            sourceCmd = sourceCmd != nil && input.LookupBinding(sourceCmd) || nil
            local convar = CreateClientConVar(cvar(bindName), sourceCmd != nil && input.GetKeyCode(sourceCmd) || 0, true, true)
            
            --check if we have old dbinder method
            if (convar:GetInt() < BUTTON_CODE_COUNT) then
                PackInputs(bindName, convar:GetInt(), 0)
            end
        end

        table.insert(registeredBinds, bindName)
    end
end

function GetUnpackedInputs(ply, bindName)
    local inputs = ply:GetInfoNum(cvar(bindName), 0)
    local inputPack = { math.floor(inputs / 65536) % 256, math.floor(inputs / 256) % 256 }
    
    for i = #inputPack, 1, -1 do
        if (inputPack[i] == 0) then
            table.remove(inputPack, i)
        end
    end

    return inputPack
end

if (CLIENT) then
    function PackInputs(bindName, b1, b2)
        GetConVar(cvar(bindName)):SetInt(b1 * 65536 + b2 * 256)
    end
end

local function packButtons(ply, buttons)
    if (!IsValid(ply:GetActiveWeapon()) || ply:GetActiveWeapon().SetButtons == nil) then
        return
    end

    ply:GetActiveWeapon():SetButtons(buttons[1] * 256^3 + buttons[2] * 256^2 + buttons[3] * 256 + buttons[4])
end

local function unpackButtons(ply)
    local buttonsPack = { 0, 0, 0, 0 }

    if (!IsValid(ply:GetActiveWeapon()) || ply:GetActiveWeapon().GetButtons == nil) then
        return buttonsPack
    end

    local buttons = ply:GetActiveWeapon():GetButtons()

    buttonsPack[1] = buttons % 256
    buttons = math.floor(buttons / 256)
    buttonsPack[2] = buttons % 256
    buttons = math.floor(buttons / 256)
    buttonsPack[3] = buttons % 256
    buttons = math.floor(buttons / 256)
    buttonsPack[4] = buttons
    
    return buttonsPack
end

local function setPressTime(ply, time)
    if (!IsValid(ply:GetActiveWeapon()) || ply:GetActiveWeapon().SetButtonPressTime == nil) then
        return
    end

    ply:GetActiveWeapon():SetButtonPressTime(time)
end

local function getPressTime(ply)
    if (!IsValid(ply:GetActiveWeapon()) || ply:GetActiveWeapon().GetButtonPressTime == nil) then
        return 0
    end

    return ply:GetActiveWeapon():GetButtonPressTime()
end

local function getPressCallbacksResult(ply, bind)
    for _, callback in pairs(pressCallbacks) do
        if (callback(ply, bind) == false) then
            return false
        end
    end

    return true --can be pressed
end

local function fireDelegates(ply)
    local sortedBinds = {}

    for _, bindName in pairs(registeredBinds) do
        table.insert(sortedBinds, {bindName, ply:GetInfoNum(cvar(bindName), 0)})
    end
    
    table.sort(sortedBinds, function(a, b) return a[2] < b[2] end)

    local bindForDelegate = nil
    local dtDelay = ply:GetInfoNum("mgbase_binds_doubletap_delay", 0.3)

    if (CurTime() > getPressTime(ply) + dtDelay * 2) then
        setPressTime(ply, 0)
    end

    for _, sortedBind in pairs(sortedBinds) do
        local bindName = sortedBind[1]
        local bDown = IsBindPressed(ply, bindName)

        if (bDown) then
            if (!getPressCallbacksResult(ply, bindName)) then
                continue
            end

            local unpackedInputs = GetUnpackedInputs(ply, bindName)

            if (unpackedInputs[1] != unpackedInputs[2]) then
                --we are not a double tap bind, go ahead
                bindForDelegate = bindName
            else
                if (getPressTime(ply) == 0) then --first press
                    setPressTime(ply, CurTime())
                    bindForDelegate = nil
                    --double taps by logic are sorted last, so ^ this ^ makes sure the single press binds
                    --on the same button do not get sent
                else
                    if (CurTime() <= getPressTime(ply) + dtDelay) then
                        bindForDelegate = bindName
                    end

                    setPressTime(ply, 0)
                end
            end
        end
    end

    if (bindForDelegate != nil) then
        for _, d in pairs(delegates) do
            d(ply, bindForDelegate)
        end
    end
end

function ButtonDown(ply, button)
    if (!IsButtonTakenByAnyBind(ply, button)) then
        return
    end

    local buttons = unpackButtons(ply)

    for i, b in pairs(buttons) do
        if (b == 0) then
            buttons[i] = button
            break
        end
    end

    packButtons(ply, buttons)
    fireDelegates(ply)
end

function ButtonUp(ply, button)
    local buttons = unpackButtons(ply)

    for i, b in pairs(buttons) do
        if (b == button) then
            buttons[i] = 0
            break
        end
    end

    packButtons(ply, buttons)
    --fireDelegates(ply)
end

function IsBindPressed(ply, bindName)
    local unpacked = GetUnpackedInputs(ply, bindName)
    local buttons = unpackButtons(ply)

    for _, input in pairs(unpacked) do
        if (!table.HasValue(buttons, input)) then
            return false
        end 
    end

    return #unpacked > 0
end

function IsButtonTakenByAnyBind(ply, button)
    for _, bindName in pairs(registeredBinds) do
        if (table.HasValue(GetUnpackedInputs(ply, bindName), button)) then
            return true
        end
    end

    return false
end

if (CLIENT) then
    --todo: probably cache this
    function GetBindKeyString(bindName)
        local inputs = GetUnpackedInputs(LocalPlayer(), bindName)

        if (#inputs == 0) then
            return nil
        end

        local key = language.GetPhrase(input.GetKeyName(inputs[1]))

        if (inputs[2] != nil) then
            key = key .. " + " .. language.GetPhrase(input.GetKeyName(inputs[2]))
        end

        return key
    end
end

function AddDelegate(ind, func, callback)
    delegates[ind] = func
    pressCallbacks[ind] = callback
end