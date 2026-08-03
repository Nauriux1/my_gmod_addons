-- Client appearance helpers (minimal port)
if not CLIENT then return end

hg = hg or {}
hg.Appearance = hg.Appearance or {}
hg.Accessories = hg.Accessories or {}

-- Open editor console command
concommand.Add("hg_appearance", function()
	if hg.Appearance.OpenEditor then
		hg.Appearance.OpenEditor()
	else
		chat.AddText(Color(255, 180, 80), "[Tubbycity] Appearance editor not loaded.")
	end
end)

concommand.Add("zb_appearance", function()
	RunConsoleCommand("hg_appearance")
end)

-- Respond to server appearance requests using local cache
net.Receive("Get_Appearance", function()
	local data = cookie.GetString("hg_appearance_save", "")
	local tbl = util.JSONToTable(data) or {}
	net.Start("Get_Appearance")
		net.WriteTable(tbl)
		net.WriteBool(table.IsEmpty(tbl))
	net.SendToServer()
end)

net.Receive("OnlyGet_Appearance", function()
	local data = cookie.GetString("hg_appearance_save", "")
	local tbl = util.JSONToTable(data) or {}
	net.Start("OnlyGet_Appearance")
		net.WriteTable(tbl)
	net.SendToServer()
end)

function hg.Appearance.SaveLocal(tbl)
	cookie.Set("hg_appearance_save", util.TableToJSON(tbl or {}))
end

function hg.Appearance.LoadLocal()
	return util.JSONToTable(cookie.GetString("hg_appearance_save", "")) or {}
end
