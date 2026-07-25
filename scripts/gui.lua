local helpers = require("scripts.helpers")
local M       = {}

local FRAME_NAME  = "vehicle_deployer_frame"
local VEH_PREFIX  = "vd_vbtn_"
local FUEL_PREFIX = "vd_fbtn_"
local AMMO_PREFIX = "vd_abtn_"

local function populate_vehicle_buttons(flow, vehicles, selected)
  flow.clear()
  for _, v in ipairs(vehicles) do
    local btn = flow.add({
      type    = "sprite-button",
      name    = VEH_PREFIX .. v.name,
      sprite  = "item/" .. v.name,
      number  = v.count,
      tooltip = {"item-name." .. v.name},
      style   = "slot_button",
    })
    btn.toggled = (v.name == selected)
  end
end

local function populate_fuel_buttons(flow, fuels, selected)
  flow.clear()
  if #fuels == 0 then
    flow.add({type = "label", caption = "No fuel required, or none found."})
    return
  end
  for _, f in ipairs(fuels) do
    local btn = flow.add({
      type    = "sprite-button",
      name    = FUEL_PREFIX .. f.name,
      sprite  = "item/" .. f.name,
      number  = f.count,
      tooltip = {"item-name." .. f.name},
      style   = "slot_button",
    })
    btn.toggled = (f.name == selected)
  end
end

local function populate_ammo_buttons(flow, ammos, selected)
  flow.clear()
  if #ammos == 0 then
    flow.add({type = "label", caption = "No weapons/ammo required, or none found."})
    return
  end
  for _, a in ipairs(ammos) do
    local btn = flow.add({
      type    = "sprite-button",
      name    = AMMO_PREFIX .. a.name,
      sprite  = "item/" .. a.name,
      number  = a.count,
      tooltip = {"item-name." .. a.name},
      style   = "slot_button",
    })
    btn.toggled = (a.name == selected)
  end
end

local function update_preset_dropdown(frame, pd)
  local dropdown = frame.vd_preset_flow and frame.vd_preset_flow.vd_preset_dropdown
  if not (dropdown and dropdown.valid) then return end

  local items = {"(Custom / None)"}
  local selected_index = 1
  for i, preset in ipairs(pd.presets) do
    table.insert(items, preset.name)
    if pd.active_preset == preset.name then
      selected_index = i + 1
    end
  end
  dropdown.items = items
  dropdown.selected_index = selected_index
end

function M.open(player)
  if player.gui.screen[FRAME_NAME] then
    M.close(player)
    return
  end

  local pd       = helpers.get_player_data(player.index)
  local vehicles = helpers.get_vehicles_in_inventory(player)

  if #vehicles == 0 then
    player.print("[QuickDrive] No deployable vehicles found in your inventory!")
    return
  end

  if not pd.selected_vehicle or not helpers.has_vehicle(player, pd.selected_vehicle) then
    pd.selected_vehicle = vehicles[1].name
  end

  local ent_name = prototypes.item[pd.selected_vehicle].place_result.name
  local fuels    = helpers.get_fuels_for_vehicle(player, ent_name)
  local ammos    = helpers.get_ammo_for_vehicle(player, ent_name)

  if not helpers.has_fuel_in_list(fuels, pd.selected_fuel) then
    pd.selected_fuel = #fuels > 0 and fuels[1].name or nil
  end

  if not helpers.has_fuel_in_list(ammos, pd.selected_ammo) then
    pd.selected_ammo = #ammos > 0 and ammos[1].name or nil
  end

  local frame = player.gui.screen.add({
    type      = "frame",
    name      = FRAME_NAME,
    caption   = {"", "[item=car] QuickDrive"},
    direction = "vertical",
  })
  frame.style.minimal_width = 340

  -- Presets Header & Controls
  local preset_flow = frame.add({type = "flow", name = "vd_preset_flow", direction = "horizontal"})
  preset_flow.style.vertical_align = "center"
  preset_flow.style.bottom_margin = 6
  
  local preset_lbl = preset_flow.add({type = "label", caption = "Preset:"})
  preset_lbl.style.font = "default-bold"
  preset_lbl.style.right_margin = 6

  local dropdown = preset_flow.add({
    type = "drop-down",
    name = "vd_preset_dropdown",
    items = {"(Custom / None)"},
    selected_index = 1,
  })

  preset_flow.add({
    type = "button",
    name = "vd_save_preset_btn",
    caption = "Save Preset",
    tooltip = "Save current Vehicle, Fuel, and Ammo selection as a preset",
    style = "tool_button",
  })

  preset_flow.add({
    type = "button",
    name = "vd_delete_preset_btn",
    caption = "Delete",
    tooltip = "Delete selected preset",
    style = "tool_button_red",
  })

  update_preset_dropdown(frame, pd)

  local sep0 = frame.add({type = "line"})
  sep0.style.top_margin    = 2
  sep0.style.bottom_margin = 4

  local veh_hdr = frame.add({type = "label", caption = "Select Vehicle"})
  veh_hdr.style.font         = "default-bold"
  veh_hdr.style.bottom_margin = 4

  local veh_flow = frame.add({type = "flow", name = "vd_vehicle_flow", direction = "horizontal"})
  veh_flow.style.horizontal_spacing = 4
  populate_vehicle_buttons(veh_flow, vehicles, pd.selected_vehicle)

  local sep1 = frame.add({type = "line"})
  sep1.style.top_margin    = 6
  sep1.style.bottom_margin = 4

  local fuel_hdr = frame.add({type = "label", caption = "Select Fuel"})
  fuel_hdr.style.font         = "default-bold"
  fuel_hdr.style.bottom_margin = 4

  local fuel_flow = frame.add({type = "flow", name = "vd_fuel_flow", direction = "horizontal"})
  fuel_flow.style.horizontal_spacing = 4
  populate_fuel_buttons(fuel_flow, fuels, pd.selected_fuel)

  local sep2 = frame.add({type = "line"})
  sep2.style.top_margin    = 6
  sep2.style.bottom_margin = 4

  local ammo_hdr = frame.add({type = "label", caption = "Select Ammo"})
  ammo_hdr.style.font         = "default-bold"
  ammo_hdr.style.bottom_margin = 4

  local ammo_flow = frame.add({type = "flow", name = "vd_ammo_flow", direction = "horizontal"})
  ammo_flow.style.horizontal_spacing = 4
  populate_ammo_buttons(ammo_flow, ammos, pd.selected_ammo)

  local sep3 = frame.add({type = "line"})
  sep3.style.top_margin    = 6
  sep3.style.bottom_margin = 2

  frame.add({
    type    = "label",
    caption = "Shift+Enter to deploy  ·  Esc to cancel",
  }).style.font = "default-semibold"

  local btn_row = frame.add({type = "flow", direction = "horizontal"})
  btn_row.style.top_margin       = 8
  btn_row.style.horizontal_align = "right"

  btn_row.add({type = "empty-widget"}).style.horizontally_stretchable = true
  btn_row.add({type = "button", name = "vd_deploy_btn", caption = "Deploy", style = "confirm_button"})
  btn_row.add({type = "button", name = "vd_cancel_btn", caption = "Cancel", style = "back_button"})

  frame.force_auto_center()
  player.opened = frame
end

function M.close(player)
  local f = player.gui.screen[FRAME_NAME]
  if f and f.valid then f.destroy() end
end

function M.is_open(player)
  local f = player.gui.screen[FRAME_NAME]
  return f ~= nil and f.valid
end

function M.on_preset_selected(player, selected_index)
  local pd = helpers.get_player_data(player.index)
  if selected_index <= 1 then
    pd.active_preset = nil
    return
  end

  local preset = pd.presets[selected_index - 1]
  if not preset then return end

  pd.active_preset = preset.name
  if preset.vehicle then
    M.on_vehicle_selected(player, preset.vehicle)
  end
  if preset.fuel then
    M.on_fuel_selected(player, preset.fuel)
  end
  if preset.ammo then
    M.on_ammo_selected(player, preset.ammo)
  end
end

function M.save_current_as_preset(player)
  local pd = helpers.get_player_data(player.index)
  if not pd.selected_vehicle then
    player.print("[QuickDrive] Select a vehicle before saving a preset.")
    return
  end

  local veh_proto = prototypes.item[pd.selected_vehicle]
  local name = veh_proto and veh_proto.localised_name or pd.selected_vehicle
  local preset_name = "Preset " .. (#pd.presets + 1) .. " (" .. pd.selected_vehicle .. ")"

  table.insert(pd.presets, {
    name = preset_name,
    vehicle = pd.selected_vehicle,
    fuel = pd.selected_fuel,
    ammo = pd.selected_ammo,
  })

  pd.active_preset = preset_name

  local frame = player.gui.screen[FRAME_NAME]
  if frame and frame.valid then
    update_preset_dropdown(frame, pd)
  end
  player.print("[QuickDrive] Preset saved: " .. preset_name)
end

function M.delete_active_preset(player)
  local pd = helpers.get_player_data(player.index)
  if not pd.active_preset then
    player.print("[QuickDrive] No active preset selected to delete.")
    return
  end

  for i, p in ipairs(pd.presets) do
    if p.name == pd.active_preset then
      table.remove(pd.presets, i)
      break
    end
  end

  player.print("[QuickDrive] Deleted preset: " .. pd.active_preset)
  pd.active_preset = nil

  local frame = player.gui.screen[FRAME_NAME]
  if frame and frame.valid then
    update_preset_dropdown(frame, pd)
  end
end

function M.on_vehicle_selected(player, vehicle_name)
  local pd = helpers.get_player_data(player.index)
  pd.selected_vehicle = vehicle_name

  local frame = player.gui.screen[FRAME_NAME]
  if not (frame and frame.valid) then return end

  for _, child in pairs(frame.vd_vehicle_flow.children) do
    if string.sub(child.name, 1, #VEH_PREFIX) == VEH_PREFIX then
      child.toggled = (string.sub(child.name, #VEH_PREFIX + 1) == vehicle_name)
    end
  end

  local ent_name = prototypes.item[vehicle_name].place_result.name
  local fuels    = helpers.get_fuels_for_vehicle(player, ent_name)
  local ammos    = helpers.get_ammo_for_vehicle(player, ent_name)

  if not helpers.has_fuel_in_list(fuels, pd.selected_fuel) then
    pd.selected_fuel = #fuels > 0 and fuels[1].name or nil
  end

  if not helpers.has_fuel_in_list(ammos, pd.selected_ammo) then
    pd.selected_ammo = #ammos > 0 and ammos[1].name or nil
  end

  populate_fuel_buttons(frame.vd_fuel_flow, fuels, pd.selected_fuel)
  populate_ammo_buttons(frame.vd_ammo_flow, ammos, pd.selected_ammo)
end

function M.on_fuel_selected(player, fuel_name)
  local pd = helpers.get_player_data(player.index)
  pd.selected_fuel = fuel_name

  local frame = player.gui.screen[FRAME_NAME]
  if not (frame and frame.valid) then return end

  for _, child in pairs(frame.vd_fuel_flow.children) do
    if string.sub(child.name, 1, #FUEL_PREFIX) == FUEL_PREFIX then
      child.toggled = (string.sub(child.name, #FUEL_PREFIX + 1) == fuel_name)
    end
  end
end

function M.on_ammo_selected(player, ammo_name)
  local pd = helpers.get_player_data(player.index)
  pd.selected_ammo = ammo_name

  local frame = player.gui.screen[FRAME_NAME]
  if not (frame and frame.valid) then return end

  for _, child in pairs(frame.vd_ammo_flow.children) do
    if string.sub(child.name, 1, #AMMO_PREFIX) == AMMO_PREFIX then
      child.toggled = (string.sub(child.name, #AMMO_PREFIX + 1) == ammo_name)
    end
  end
end

M.FRAME_NAME = FRAME_NAME

return M

