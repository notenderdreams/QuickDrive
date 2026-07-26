-- data.lua
-- Vehicle Deployer – custom keybinding definitions

data:extend({

  -- Open/close the vehicle + fuel selector GUI
  -- Binding: Ctrl + Shift + V
  {
    type         = "custom-input",
    name         = "quick-drive-toggle",
    key_sequence = "CONTROL + SHIFT + V",
    consuming    = "game-only",
  },

  -- Deploy (from GUI) or undeploy (from inside vehicle)
  -- Binding: Shift + Enter
  {
    type         = "custom-input",
    name         = "quick-drive-action",
    key_sequence = "SHIFT + RETURN",
    consuming    = "game-only",
  },

})
