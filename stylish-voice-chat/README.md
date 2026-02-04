# Stylish Voice Chat Panel for Garry's Mod

A modern, sleek replacement for the default Garry's Mod voice chat panel.

## Features

- **Modern Design**: Clean, rounded panels with smooth animations
- **Speaking Indicator**: Animated bar that shows voice volume
- **Smooth Fades**: Panels fade in/out smoothly
- **Multiple Speakers**: Shows all talking players at once
- **No Performance Impact**: Lightweight and optimized



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


