-- Simple Tubbycity appearance editor: model + bodygroups + skin + name + color
if not CLIENT then return end

hg = hg or {}
hg.Appearance = hg.Appearance or {}

local function CollectModels()
	local out = {}
	local pm = hg.Appearance.PlayerModels or {}
	for sex = 1, 2 do
		for name, data in pairs(pm[sex] or {}) do
			out[#out + 1] = { name = name, mdl = data.mdl, tubby = data.tubby, sex = sex }
		end
	end
	table.sort(out, function(a, b)
		if a.tubby ~= b.tubby then return a.tubby == true end
		return a.name < b.name
	end)
	return out
end

function hg.Appearance.OpenEditor()
	if IsValid(hg.Appearance._frame) then hg.Appearance._frame:Remove() end

	local frame = vgui.Create("DFrame")
	hg.Appearance._frame = frame
	frame:SetSize(math.min(ScrW() * 0.55, 720), math.min(ScrH() * 0.7, 560))
	frame:Center()
	frame:SetTitle("Tubbycity Appearance")
	frame:MakePopup()

	local left = vgui.Create("DPanel", frame)
	left:Dock(LEFT)
	left:SetWide(frame:GetWide() * 0.42)
	left:DockMargin(8, 8, 4, 8)

	local modelList = vgui.Create("DComboBox", left)
	modelList:Dock(TOP)
	modelList:SetTall(28)
	modelList:DockMargin(4, 4, 4, 4)

	local models = CollectModels()
	local current = hg.Appearance.LoadLocal and hg.Appearance.LoadLocal() or {}
	for _, m in ipairs(models) do
		modelList:AddChoice((m.tubby and "[Tubby] " or "") .. m.name, m)
		if current.AModel == m.name then modelList:SetValue((m.tubby and "[Tubby] " or "") .. m.name) end
	end
	if modelList:GetValue() == "" and #models > 0 then
		modelList:ChooseOptionID(1)
	end

	local nameEntry = vgui.Create("DTextEntry", left)
	nameEntry:Dock(TOP)
	nameEntry:SetTall(28)
	nameEntry:DockMargin(4, 4, 4, 4)
	nameEntry:SetPlaceholderText("Display name")
	nameEntry:SetText(current.AName or LocalPlayer():Nick())

	local skinSlider = vgui.Create("DNumSlider", left)
	skinSlider:Dock(TOP)
	skinSlider:SetTall(36)
	skinSlider:DockMargin(4, 4, 4, 4)
	skinSlider:SetText("Skin")
	skinSlider:SetMin(0)
	skinSlider:SetMax(16)
	skinSlider:SetDecimals(0)
	skinSlider:SetValue(current.ASkin or 0)

	local bgScroll = vgui.Create("DScrollPanel", left)
	bgScroll:Dock(FILL)
	bgScroll:DockMargin(4, 4, 4, 4)

	local bgSliders = {}

	local preview = vgui.Create("DModelPanel", frame)
	preview:Dock(FILL)
	preview:DockMargin(4, 8, 8, 8)
	preview:SetFOV(40)
	preview:SetCamPos(Vector(60, 40, 50))
	preview:SetLookAt(Vector(0, 0, 35))
	function preview:LayoutEntity(ent)
		ent:SetAngles(Angle(0, RealTime() * 20, 0))
	end

	local function ApplyPreview()
		local _, data = modelList:GetSelected()
		if not data or not data.mdl then return end
		preview:SetModel(data.mdl)
		local ent = preview:GetEntity()
		if not IsValid(ent) then return end
		ent:SetSkin(math.floor(skinSlider:GetValue()))

		bgScroll:Clear()
		bgSliders = {}
		local groups = ent:GetBodyGroups() or {}
		for _, g in ipairs(groups) do
			if (g.num or 0) <= 1 then continue end
			local slider = vgui.Create("DNumSlider", bgScroll)
			slider:Dock(TOP)
			slider:SetTall(36)
			slider:SetText(g.name or ("BG " .. tostring(g.id)))
			slider:SetMin(0)
			slider:SetMax(math.max((g.num or 1) - 1, 0))
			slider:SetDecimals(0)
			local saved = current.ABodygroups and current.ABodygroups[tostring(g.id)]
			slider:SetValue(tonumber(saved) or 0)
			slider.OnValueChanged = function(_, val)
				if IsValid(ent) then ent:SetBodygroup(g.id, math.floor(val)) end
			end
			ent:SetBodygroup(g.id, math.floor(slider:GetValue()))
			bgSliders[g.id] = slider
		end
	end

	modelList.OnSelect = function() ApplyPreview() end
	skinSlider.OnValueChanged = function(_, val)
		local ent = preview:GetEntity()
		if IsValid(ent) then ent:SetSkin(math.floor(val)) end
	end

	ApplyPreview()

	local save = vgui.Create("DButton", frame)
	save:Dock(BOTTOM)
	save:SetTall(36)
	save:DockMargin(8, 0, 8, 8)
	save:SetText("Save Appearance")
	save.DoClick = function()
		local _, data = modelList:GetSelected()
		if not data then return end
		local bodygroups = {}
		for id, slider in pairs(bgSliders) do
			bodygroups[tostring(id)] = math.floor(slider:GetValue())
		end
		local tbl = {
			AName = nameEntry:GetValue(),
			AModel = data.name,
			AColor = Color(255, 255, 255),
			AClothes = { main = "normal", pants = "normal", boots = "normal", hands = "normal" },
			AAttachments = {},
			ABodygroups = bodygroups,
			AFacemap = "",
			ASkin = math.floor(skinSlider:GetValue()),
		}
		if hg.Appearance.SaveLocal then hg.Appearance.SaveLocal(tbl) end
		net.Start("Get_Appearance")
			net.WriteTable(tbl)
			net.WriteBool(false)
		net.SendToServer()
		chat.AddText(Color(100, 255, 140), "[Tubbycity] Appearance saved.")
		frame:Close()
	end
end
