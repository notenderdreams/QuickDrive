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

  local pd = helpers.get_player_data(player.index)

  if player.vehicle then
    if not pd.deployed_vehicle_unit_number or player.vehicle.unit_number == pd.deployed_vehicle_unit_number then
      gui.close(player)
      vehicle.undeploy(player)
    else
      player.print("[QuickDrive] Vehicle was not deployed by QuickDrive.")
    end
    return
  end

  if gui.is_open(player) then gui.close(player) end

  -- Auto-select vehicle or blueprint if nothing is currently selected
  if not pd.selected_vehicle then
    local bps = helpers.get_qdrive_blueprints(player)
    if #bps > 0 then
      local bp = bps[1]
      pd.selected_vehicle          = bp.vehicle_item
      pd.selected_blueprint_grid  = bp.equipment_grid
      pd.selected_color           = bp.color
      pd.selected_blueprint_label = bp.label
    else
      local vehicles = helpers.get_vehicles_in_inventory(player)
      if #vehicles > 0 then
        pd.selected_vehicle = vehicles[1].name
      end
    end
  end

  if pd.selected_vehicle then
    vehicle.deploy(player, pd.selected_vehicle, pd.selected_fuel)
  else
    player.print("[QuickDrive] QuickDrive is not configured. Press Ctrl+Shift+V to configure.")
  end
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
    local rest = string.sub(name, #"vd_abtn_" + 1)
    local s_idx, ammo_item = string.match(rest, "^(%d+)_(.+)$")
    if s_idx and ammo_item then
      gui.on_ammo_selected(player, ammo_item, tonumber(s_idx))
    else
      gui.on_ammo_selected(player, rest)
    end
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
  elseif name == "vd_distribute_checkbox" then
    gui.on_distribute_toggled(player, element.state)
  end
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
  local element = event.element
  if not (element and element.valid) then return end
  local player = game.players[event.player_index]
  if not (player and player.valid) then return end

  if element.name == "vd_distribute_checkbox" then
    gui.on_distribute_toggled(player, element.state)
  end
end)

script.on_event(defines.events.on_gui_selection_state_changed, function(event)
  local element = event.element
  if not (element and element.valid) then return end

  local player = game.players[event.player_index]
  if not (player and player.valid) then return end

  if element.name == "vd_preset_dropdown" then
    gui.on_preset_selected(player, element.selected_index)
  elseif element.name == "vd_blueprint_dropdown" then
    gui.on_blueprint_selected(player, element.selected_index)
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
