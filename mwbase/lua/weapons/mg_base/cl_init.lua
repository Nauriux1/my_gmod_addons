AddCSLuaFile()

include("shared.lua")

MWBASE_STENCIL_REFVALUE = 69

CreateClientConVar("mgbase_rig", "chands", true, false, "Change first person arms rig.")
CreateClientConVar("mgbase_rig_skin", "0", true, false, "Change first person arms rig skin.", 0)
CreateClientConVar("mgbase_gloves", "", true, false, "Change first person arms gloves.")
CreateClientConVar("mgbase_gloves_skin", "0", true, false, "Change first person arms gloves.", 0)
CreateClientConVar("mgbase_tacsprint", "1", true, true, "Tac-Sprint input type.", 0, 2)
CreateClientConVar("mgbase_toggleaim", "0", true, true, "Hold to aim.", 0, 1)
CreateClientConVar("mgbase_autoreload", "1", true, true, "Toggle auto reload.", 0, 1)
CreateClientConVar("mgbase_aimassist", "1", true, true, "Toggle aim assist.", 0, 1)
CreateClientConVar("mgbase_manualrechamber", "0", true, true, "Toggle manual rechambering.", 0, 1)
CreateClientConVar("mgbase_underbarrelswitch", "1", true, true, "Remember underbarrels.", 0, 1)
CreateClientConVar("mgbase_fx_blur", "0", true, false, "Toggle first person blur.", 0, 1)
CreateClientConVar("mgbase_fx_laser_weaponcolor", "0", true, false, "Toggle sandbox weapon color usage for lasers.", 0, 1)
CreateClientConVar("mgbase_fx_vmfov", "1", true, false, "Change viewmodel FOV.", 0.1, 2)
CreateClientConVar("mgbase_fx_vmfov_ads", "1", true, false, "Change viewmodel FOV (only when aiming).", 0.1, 2)
CreateClientConVar("mgbase_fx_vmposx", "0", true, false, "Change viewmodel position.", -5, 5)
CreateClientConVar("mgbase_fx_vmposy", "0", true, false, "Change viewmodel position.", -5, 5)
CreateClientConVar("mgbase_fx_vmposz", "0", true, false, "Change viewmodel position.", -5, 5)
CreateClientConVar("mgbase_fx_debris", "1", true, false, "Toggle debris spawn from explosions.")
CreateClientConVar("mgbase_hud_xhaircolor", "255 255 255", true, false, "Crosshair color.", 0, 1)
CreateClientConVar("mgbase_hud_xhair", "1", true, false, "Toggle crosshair.", 0, 2)
CreateClientConVar("mgbase_hud_xhairdot", "1", true, false, "Toggle center dot.", 0, 1)
CreateClientConVar("mgbase_hud_firemode", "1", true, false, "Toggle firemode HUD.", 0, 1)
CreateClientConVar("mgbase_hud_controls", "1", true, false, "Toggle control tips.", 0, 1)
CreateClientConVar("mgbase_debug_freeview", "0", false, false, "Toggle debug free view.", 0, 1)
CreateClientConVar("mgbase_debug_crosshair", "0", true, false, "Toggle debug crosshair for ironsights.", 0, 1)
CreateClientConVar("mgbase_debug_vmrender", "1", true, false, "Toggle viewmodel render.", 0, 1)
CreateClientConVar("mgbase_debug_wmrender", "1", true, false, "Toggle worldmodel render.", 0, 1)
CreateClientConVar("mgbase_presetspawnmethod", "0", true, false, "Spawn preset method: 0 = none, 1 = random, 2 = random default, 3 = random favorite")
CreateClientConVar("mgbase_sensitivity_ads", "1", true, true, "Sensitivity in ADS.", 0.01, 5)
CreateClientConVar("mgbase_sensitivity_tacstance", "1", true, true, "Sensitivity in Tac-Stance.", 0.01, 5)

list.Set( "ContentCategoryIcons", "Modern Warfare", "vgui/mw_logo.png" )

concommand.Add("mgbase_generatepreset", function(p, c, args)
    local w = p:GetActiveWeapon()

    if (args[1] == nil) then
        print("Missing name! Type a name in quotes (eg. \"The Gun\")")
        return
    end

    if (IsValid(w) && weapons.IsBasedOn(w:GetClass(), "mg_base")) then
        local attachmentList = ""

        for _, a in pairs(w:GetAllAttachmentsInUse()) do
            if (a.Index > 1) then
                attachmentList = attachmentList..", \""..a.ClassName.."\""
            end
        end

        attachmentList = string.sub(attachmentList, 3)

        local finalPrint = "PRESET.SWEP = \""..w:GetClass().."\"\n"
        finalPrint = finalPrint.."PRESET.Name = \""..args[1].."\"\n"
        finalPrint = finalPrint.."PRESET.Attachments = {"..attachmentList.."}"

        print("Here's your preset (copied to clipboard already)")
        print("Remember to put this in lua/weapons/mg_base/modules/presets")
        print("From there, create a .lua file with any name you want and paste the contents in there")
        print("=================")
        print(finalPrint)
        SetClipboardText(finalPrint)
    end
end)

concommand.Add("mgbase_printtaskhierarchy", function(p, c, args)
    local w = p:GetActiveWeapon()

    if (!weapons.IsBasedOn(w:GetClass(), "mg_base")) then
        return
    end

    local hierarchy = {}

    for _, task in pairs(w.Tasks) do
        hierarchy[task.Priority] = hierarchy[task.Priority] || {}
        table.insert(hierarchy[task.Priority], task.Name)
    end

    PrintTable(hierarchy)
end)

concommand.Add("mgbase_printflags", function(p, c, args)
    local w = p:GetActiveWeapon()

    if (!weapons.IsBasedOn(w:GetClass(), "mg_base")) then
        return
    end

    PrintTable(w.NetworkedFlags)
    print(table.Count(w.NetworkedFlags) .. " flags")
end)

net.Receive("mgbase_tpanim", function()
    local slot = net.ReadUInt(2)
    local anim = net.ReadInt(12)
    local ply = net.ReadEntity()
    
    if (ply == NULL) then
        return
    end
    
    ply:AnimRestartGesture(slot, anim, true)
end)