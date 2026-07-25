local gui     = require("scripts.gui")
local vehicle = require("scripts.vehicle")
local helpers = require("scripts.helpers")

script.on_event("quick-drive-toggle", function(event)
  local player = game.players[event.player_index]
  if player and player.valid then gui.open(player) end
end)

script.on_event("quick-drive-action", function(event)
  local player = game.players[event.player_index]
  if not (player and player.valid) then return end

  if player.vehicle then
    local pd = helpers.get_player_data(player.index)
    if pd.deployed_vehicle_unit_number and
       player.vehicle.unit_number == pd.deployed_vehicle_unit_number then
      gui.close(player)
      vehicle.undeploy(player)
    else
      player.print("[QuickDrive] This vehicle wasn't deployed by QuickDrive. Use F to exit.")
    end
    return
  end

  local pd = helpers.get_player_data(player.index)

  if gui.is_open(player) then
    if pd.selected_vehicle then
      gui.close(player)
      vehicle.deploy(player, pd.selected_vehicle, pd.selected_fuel)
    else
      player.print("[QuickDrive] Please select a vehicle first.")
    end
    return
  end

  if pd.selected_vehicle then
    vehicle.deploy(player, pd.selected_vehicle, pd.selected_fuel)
    return
  end

  player.print("[QuickDrive] No vehicle configured. Press Ctrl+Shift+V to set one up.")
end)

script.on_event(defines.events.on_gui_click, function(event)
  local element = event.element
  if not (element and element.valid) then return end

  local player = game.players[event.player_index]
  if not (player and player.valid) then return end

  local name = element.name

  if string.sub(name, 1, #"vd_vbtn_") == "vd_vbtn_" then
    gui.on_vehicle_selected(player, string.sub(name, #"vd_vbtn_" + 1))

  elseif string.sub(name, 1, #"vd_fbtn_") == "vd_fbtn_" then
    gui.on_fuel_selected(player, string.sub(name, #"vd_fbtn_" + 1))

  elseif string.sub(name, 1, #"vd_abtn_") == "vd_abtn_" then
    gui.on_ammo_selected(player, string.sub(name, #"vd_abtn_" + 1))

  elseif name == "vd_save_preset_btn" then
    gui.save_current_as_preset(player)

  elseif name == "vd_delete_preset_btn" then
    gui.delete_active_preset(player)

  elseif name == "vd_deploy_btn" then
    local pd = helpers.get_player_data(player.index)
    if pd.selected_vehicle then
      gui.close(player)
      vehicle.deploy(player, pd.selected_vehicle, pd.selected_fuel)
    else
      player.print("[QuickDrive] No vehicle selected.")
    end

  elseif name == "vd_cancel_btn" then
    gui.close(player)
  end
end)

script.on_event(defines.events.on_gui_selection_state_changed, function(event)
  local element = event.element
  if not (element and element.valid) then return end

  local player = game.players[event.player_index]
  if not (player and player.valid) then return end

  if element.name == "vd_preset_dropdown" then
    gui.on_preset_selected(player, element.selected_index)
  end
end)

script.on_event(defines.events.on_gui_closed, function(event)
  if event.element and event.element.name == gui.FRAME_NAME then
    local player = game.players[event.player_index]
    if player and player.valid then gui.close(player) end
  end
end)

script.on_init(function()
  storage.players = {}
end)

script.on_configuration_changed(function()
  if not storage.players then storage.players = {} end
  for _, player in pairs(game.players) do
    helpers.get_player_data(player.index)
  end
end)

script.on_event(defines.events.on_player_created, function(event)
  helpers.get_player_data(event.player_index)
end)

script.on_event(defines.events.on_player_removed, function(event)
  if storage.players then storage.players[event.player_index] = nil end
end)
