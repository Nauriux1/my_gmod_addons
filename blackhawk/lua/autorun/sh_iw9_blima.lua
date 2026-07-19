if killicon and killicon.Add then
	killicon.Add("iw9_veh_blima", "vgui/killicons/hud_blima")
end

if killicon and killicon.Add then
	killicon.Add("iw9_veh_blima_gship", "vgui/killicons/hud_blima")
end

sound.Add( {
	name = "iw9.fire.kilo121",
	channel = CHAN_STATIC,
	volume = 1.0,
	level = 85,
	pitch = {100,105},
	sound = {"neek0/iw9/wpn/minigun/fire-01.wav",
	         "neek0/iw9/wpn/minigun/fire-02.wav",
			 "neek0/iw9/wpn/minigun/fire-03.wav",
			 "neek0/iw9/wpn/minigun/fire-04.wav",
			 "neek0/iw9/wpn/minigun/fire-05.wav",
			 "neek0/iw9/wpn/minigun/fire-06.wav"
            }
} )

sound.Add( {
	name = "iw9.spinloop.kilo121",
	channel = CHAN_WEAPON,
	volume = 1.0,
	level = 110,
	pitch = {100,105},
	sound = "neek0/iw9/wpn/minigun/whineloop.wav"
            
} )

sound.Add( {
	name = "iw9.spindown.kilo121",
	channel = CHAN_WEAPON,
	volume = 1.0,
	level = 90,
	pitch = {100,105},
	sound = "^neek0/iw9/wpn/minigun/gunstop.wav"
            
} )