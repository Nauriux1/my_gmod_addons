# Stylish Voice Chat Panel for Garry's Mod

A modern, sleek replacement for the default Garry's Mod voice chat panel.

## Features

- **Modern Design**: Clean, rounded panels with smooth animations
- **Player Avatars**: Shows Steam avatars next to player names
- **Speaking Indicator**: Animated bar that shows voice volume
- **Smooth Fades**: Panels fade in/out smoothly
- **Multiple Speakers**: Shows all talking players at once
- **No Performance Impact**: Lightweight and optimized

## Installation

### Method 1: Manual Installation

1. Navigate to your Garry's Mod addons folder:
   - Windows: `C:\Program Files (x86)\Steam\steamapps\common\GarrysMod\garrysmod\addons\`
   - Mac/Linux: `~/.steam/steam/steamapps/common/GarrysMod/garrysmod/addons/`

2. Create a new folder called `stylish-voice-chat`

3. Inside that folder, create this structure:
   ```
   stylish-voice-chat/
   ├── addon.json
   └── lua/
       └── autorun/
           └── client/
               └── cl_voice_panel.lua
   ```

4. Copy the files into their locations:
   - `addon.json` goes in the root folder
   - `cl_voice_panel.lua` goes in `lua/autorun/client/`

5. Restart Garry's Mod

### Method 2: Workshop (if you publish it)

Subscribe to the addon on the Steam Workshop and it will download automatically.

## Customization

You can change the colors and settings by editing the `config` table at the top of `cl_voice_panel.lua`:

```lua
local config = {
    panelWidth = 250,        -- Width of each panel
    panelHeight = 60,        -- Height of each panel
    cornerRadius = 8,        -- Roundness of corners
    
    -- Colors (R, G, B, Alpha)
    bgColor = Color(25, 25, 35, 240),      -- Background color
    accentColor = Color(100, 150, 255),    -- Top bar color
    speakingColor = Color(100, 255, 150),  -- Speaking indicator
    textColor = Color(255, 255, 255),      -- Text color
}
```

## How It Works

- When a player starts talking, a panel appears in the bottom-right corner
- The panel shows their avatar, name, and a speaking indicator
- The speaking indicator bar grows/shrinks based on how loud they're talking
- Multiple players talking will stack vertically
- Panels fade out smoothly when players stop talking

## Troubleshooting

**Panels not showing up:**
- Make sure the file is in the correct location
- Check console for any error messages
- Try restarting Garry's Mod

**Want the old voice chat back:**
- Delete or rename the addon folder

## Credits

Created with Claude
