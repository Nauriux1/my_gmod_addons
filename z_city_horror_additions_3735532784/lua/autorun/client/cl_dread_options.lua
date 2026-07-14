if not CLIENT then return end

if not ConVarExists("zb_zh_dread_enabled") then
    CreateConVar("zb_zh_dread_enabled", "1", FCVAR_ARCHIVE + FCVAR_REPLICATED,
        "ZHorror: enable crusher dread (raises heartrate near a crusher)", 0, 1)
end
if not ConVarExists("zb_zh_dread_range") then
    CreateConVar("zb_zh_dread_range", "900", FCVAR_ARCHIVE + FCVAR_REPLICATED,
        "ZHorror: crusher dread range", 25, 1500)
end

hook.Add("PopulateToolMenu", "zb_zh_dread_options", function()
    spawnmenu.AddToolMenuOption("Options", "alagri's ZHorror", "zb_zh_dread",
        "Crusher", "", "", function(panel)
            panel:ClearControls()

            if not LocalPlayer():IsAdmin() then
                panel:Help("Admins only.")
                return
            end

            panel:CheckBox("Dread enabled", "zb_zh_dread_enabled")
            panel:Help("Raises nearby players' heartrate when a crusher is close.")

            local slider = panel:NumSlider("Dread range", "zb_zh_dread_range", 25, 1500, 0)
            panel:Help("Distance at which a crusher starts affecting heartrate.")
            panel:NumSlider("Crusher HP multiplier", "zb_zh_crusher_hpmul", 1, 100, 0)
            panel:Help("Crusher health pool and damage reduction (base HP x this).")

            panel:CheckBox("Crusher demon voice", "zb_zh_crusher_voice_enabled")
            panel:Help("Applies gVOX's Demon voice filter to whoever is the crusher.")
            panel:NumSlider("Crusher voice preset id", "zb_zh_crusher_voice_effect", 0, 14, 0)
            panel:Help("gVOX preset id used for the crusher's voice (6 = Demon by default).")
        end)
end)