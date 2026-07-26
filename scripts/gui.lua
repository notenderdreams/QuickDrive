local helpers = require("scripts.helpers")
local M       = {}

local FRAME_NAME  = "vehicle_deployer_frame"
local VEH_PREFIX  = "vd_vbtn_"
local FUEL_PREFIX = "vd_fbtn_"
local AMMO_PREFIX = "vd_abtn_"

local function create_slot_buttons(flow, items, prefix, selected)
  flow.clear()
  if #items == 0 then
    flow.add({type = "label", caption = "[color=0.7,0.7,0.7]None available in inventory.[/color]"})
    return
  end
  for _, item in ipairs(items) do
    local btn = flow.add({
      type    = "sprite-button",
      name    = prefix .. item.name,
      sprite  = "item/" .. item.name,
      number  = item.count,
      tooltip = {"item-name." .. item.name},
      style   = "slot_button",
    })
    btn.toggled = (item.name == selected)
  end
end

local function set_manual_sections_enabled(frame, vehicle_enabled, fuel_enabled, ammo_enabled)
  if vehicle_enabled == nil then vehicle_enabled = true end
  if fuel_enabled == nil then fuel_enabled = true end
  if ammo_enabled == nil then ammo_enabled = true end

  if frame.vd_vehicle_flow and frame.vd_vehicle_flow.valid then
    for _, child in pairs(frame.vd_vehicle_flow.children) do
      child.enabled = vehicle_enabled
    end
  end

  if frame.vd_fuel_flow and frame.vd_fuel_flow.valid then
    for _, child in pairs(frame.vd_fuel_flow.children) do
      child.enabled = fuel_enabled
    end
  end

  if frame.vd_ammo_flow and frame.vd_ammo_flow.valid then
    for _, child in pairs(frame.vd_ammo_flow.children) do
      child.enabled = ammo_enabled
    end
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

local function update_grid_status_lbl(frame, player, pd)
  local status_lbl = frame.vd_grid_flow and frame.vd_grid_flow.vd_grid_status_lbl
  if not (status_lbl and status_lbl.valid) then return end

  if pd.selected_blueprint_grid and #pd.selected_blueprint_grid > 0 then
    local res = helpers.check_grid_equipment_availability(player, pd.selected_blueprint_grid)
    if res.available == res.total then
      status_lbl.caption = "[font=default-bold][color=0.4,1,0.4]✓ Grid Ready:[/color][/font] " .. res.summary
    else
      status_lbl.caption = "[font=default-bold][color=1,0.7,0.3]⚠ Grid Items Missing:[/color][/font] " .. res.summary
    end
  else
    status_lbl.caption = "[color=0.7,0.7,0.7]Standard vehicle (No blueprint grid)[/color]"
  end
end

local function update_blueprint_dropdown(frame, player, pd)
  local dropdown = frame.vd_bp_flow and frame.vd_bp_flow.vd_blueprint_dropdown
  if not (dropdown and dropdown.valid) then return end

  local bps = helpers.get_qdrive_blueprints(player)
  pd._cached_blueprints = bps

  local items = {"(None / Manual Selection)"}
  local selected_index = 1

  if #bps == 0 then
    items = {"(No [qdrive] blueprints found)"}
  else
    for i, bp in ipairs(bps) do
      table.insert(items, bp.label)
      if pd.selected_blueprint_label == bp.label then
        selected_index = i + 1
      end
    end
  end

  dropdown.items = items
  dropdown.selected_index = selected_index

  update_grid_status_lbl(frame, player, pd)
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

  if not helpers.has_item_in_list(fuels, pd.selected_fuel) then
    pd.selected_fuel = #fuels > 0 and fuels[1].name or nil
  end

  if not helpers.has_item_in_list(ammos, pd.selected_ammo) then
    pd.selected_ammo = #ammos > 0 and ammos[1].name or nil
  end

  local frame = player.gui.screen.add({
    type      = "frame",
    name      = FRAME_NAME,
    direction = "vertical",
  })
  frame.style.minimal_width = 330

  -- TITLE BAR
  local title_flow = frame.add({type = "flow", direction = "horizontal"})
  title_flow.style.vertical_align = "center"
  title_flow.style.bottom_margin = 8

  local title_lbl = title_flow.add({
    type    = "label",
    caption = "[item=car] QuickDrive - Vehicle Deployer",
    style   = "frame_title",
  })
  title_lbl.style.font = "default-bold"

  title_flow.add({type = "empty-widget"}).style.horizontally_stretchable = true

  title_flow.add({
    type    = "sprite-button",
    name    = "vd_cancel_btn",
    sprite  = "utility/close",
    style   = "frame_action_button",
    tooltip = "Close (Esc)",
  })

  -- 1. PRESETS ROW (COMPACT DROPDOWN + PLUS BUTTON + DELETE BUTTON)
  local preset_flow = frame.add({type = "flow", name = "vd_preset_flow", direction = "horizontal"})
  preset_flow.style.vertical_align = "center"
  preset_flow.style.horizontal_spacing = 4
  preset_flow.style.bottom_margin = 6
  
  local preset_lbl = preset_flow.add({type = "label", caption = "Preset:"})
  preset_lbl.style.font = "default-bold"

  local dropdown = preset_flow.add({
    type           = "drop-down",
    name           = "vd_preset_dropdown",
    items          = {"(Custom / None)"},
    selected_index = 1,
  })
  dropdown.style.minimal_width = 150

  local add_btn = preset_flow.add({
    type    = "button",
    name    = "vd_save_preset_btn",
    caption = " + ",
    tooltip = "Save current selection as preset",
    style   = "tool_button",
  })

  local del_btn = preset_flow.add({
    type    = "button",
    name    = "vd_delete_preset_btn",
    caption = "Delete",
    tooltip = "Delete selected preset",
    style   = "tool_button_red",
  })
  del_btn.style.minimal_width = 54

  update_preset_dropdown(frame, pd)

  local sep0 = frame.add({type = "line"})
  sep0.style.top_margin    = 4
  sep0.style.bottom_margin = 6

  -- 2. BLUEPRINT SELECTION ROW
  local bp_hdr = frame.add({type = "label", caption = "Select Blueprint ([qdrive])"})
  bp_hdr.style.font          = "default-bold"
  bp_hdr.style.bottom_margin = 4

  local bp_flow = frame.add({type = "flow", name = "vd_bp_flow", direction = "horizontal"})
  bp_flow.style.vertical_align = "center"

  local bp_dd = bp_flow.add({
    type           = "drop-down",
    name           = "vd_blueprint_dropdown",
    items          = {"(None / Manual Selection)"},
    selected_index = 1,
  })
  bp_dd.style.minimal_width = 210

  local grid_flow = frame.add({type = "flow", name = "vd_grid_flow", direction = "horizontal"})
  grid_flow.style.top_margin = 2
  grid_flow.add({
    type    = "label",
    name    = "vd_grid_status_lbl",
    caption = "[color=0.7,0.7,0.7]Standard vehicle (No blueprint grid)[/color]",
  })

  update_blueprint_dropdown(frame, player, pd)

  local sep_bp = frame.add({type = "line"})
  sep_bp.style.top_margin    = 6
  sep_bp.style.bottom_margin = 6

  -- 3. VEHICLE SELECTION ROW
  local veh_hdr = frame.add({type = "label", caption = "Select Vehicle"})
  veh_hdr.style.font         = "default-bold"
  veh_hdr.style.bottom_margin = 4

  local veh_flow = frame.add({type = "flow", name = "vd_vehicle_flow", direction = "horizontal"})
  veh_flow.style.horizontal_spacing = 4
  create_slot_buttons(veh_flow, vehicles, VEH_PREFIX, pd.selected_vehicle)

  local sep1 = frame.add({type = "line"})
  sep1.style.top_margin    = 6
  sep1.style.bottom_margin = 6

  -- 4. FUEL SELECTION ROW
  local fuel_hdr = frame.add({type = "label", caption = "Select Fuel"})
  fuel_hdr.style.font         = "default-bold"
  fuel_hdr.style.bottom_margin = 4

  local fuel_flow = frame.add({type = "flow", name = "vd_fuel_flow", direction = "horizontal"})
  fuel_flow.style.horizontal_spacing = 4
  create_slot_buttons(fuel_flow, fuels, FUEL_PREFIX, pd.selected_fuel)

  local sep2 = frame.add({type = "line"})
  sep2.style.top_margin    = 6
  sep2.style.bottom_margin = 6

  -- 5. AMMO SELECTION ROW
  local ammo_hdr = frame.add({type = "label", caption = "Select Ammo"})
  ammo_hdr.style.font         = "default-bold"
  ammo_hdr.style.bottom_margin = 4

  local ammo_flow = frame.add({type = "flow", name = "vd_ammo_flow", direction = "horizontal"})
  ammo_flow.style.horizontal_spacing = 4
  create_slot_buttons(ammo_flow, ammos, AMMO_PREFIX, pd.selected_ammo)

  local sep3 = frame.add({type = "line"})
  sep3.style.top_margin    = 6
  sep3.style.bottom_margin = 4

  frame.add({
    type    = "label",
    caption = "[color=0.7,0.7,0.7]Shift+Enter to deploy  ·  Esc to cancel[/color]",
  })

  local btn_row = frame.add({type = "flow", name = "vd_btn_row", direction = "horizontal"})
  btn_row.style.top_margin       = 8
  btn_row.style.horizontal_align = "right"

  btn_row.add({type = "empty-widget"}).style.horizontally_stretchable = true
  btn_row.add({type = "button", name = "vd_deploy_btn", caption = "Deploy", style = "confirm_button"})

  -- Apply initial enabled/disabled state based on current blueprint selection
  local bp_dropdown = frame.vd_bp_flow.vd_blueprint_dropdown
  M.on_blueprint_selected(player, bp_dropdown.selected_index)

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

  pd.active_preset            = preset.name
  pd.selected_blueprint_grid  = preset.equipment_grid
  pd.selected_color           = preset.color
  pd.selected_blueprint_label = preset.blueprint_label
  pd.selected_blueprint_fuel  = preset.blueprint_fuel
  pd.selected_blueprint_ammo  = preset.blueprint_ammo

  if preset.vehicle then M.on_vehicle_selected(player, preset.vehicle) end
  if preset.fuel then M.on_fuel_selected(player, preset.fuel) end
  if preset.ammo then M.on_ammo_selected(player, preset.ammo) end
end

function M.on_blueprint_selected(player, selected_index)
  local pd = helpers.get_player_data(player.index)
  local bps = pd._cached_blueprints or helpers.get_qdrive_blueprints(player)

  local frame = player.gui.screen[FRAME_NAME]

  if selected_index <= 1 or #bps == 0 then
    pd.selected_blueprint_grid  = nil
    pd.selected_color           = nil
    pd.selected_blueprint_label = nil
    pd.selected_blueprint_fuel  = nil
    pd.selected_blueprint_ammo  = nil

    if frame and frame.valid then
      set_manual_sections_enabled(frame, true, true, true)
      local deploy_btn = frame.vd_btn_row and frame.vd_btn_row.vd_deploy_btn
      if deploy_btn and deploy_btn.valid then
        deploy_btn.caption = "Deploy"
      end
    end
  else
    local bp = bps[selected_index - 1]
    if bp then
      pd.selected_blueprint_grid  = bp.equipment_grid
      pd.selected_color           = bp.color
      pd.selected_blueprint_label = bp.label
      pd.selected_blueprint_fuel  = bp.fuel
      pd.selected_blueprint_ammo  = bp.ammo

      -- Always update selected vehicle to match the blueprint's vehicle item
      if bp.vehicle_item then
        pd.selected_vehicle = bp.vehicle_item
        if bp.fuel then pd.selected_fuel = bp.fuel end
        if bp.ammo then pd.selected_ammo = bp.ammo end

        if frame and frame.valid then
          local ent_name = prototypes.item[bp.vehicle_item] and prototypes.item[bp.vehicle_item].place_result and prototypes.item[bp.vehicle_item].place_result.name or bp.entity_name
          local fuels    = helpers.get_fuels_for_vehicle(player, ent_name)
          local ammos    = helpers.get_ammo_for_vehicle(player, ent_name)

          if not helpers.has_item_in_list(fuels, pd.selected_fuel) then
            pd.selected_fuel = #fuels > 0 and fuels[1].name or nil
          end
          if not helpers.has_item_in_list(ammos, pd.selected_ammo) then
            pd.selected_ammo = #ammos > 0 and ammos[1].name or nil
          end

          create_slot_buttons(frame.vd_vehicle_flow, helpers.get_vehicles_in_inventory(player), VEH_PREFIX, pd.selected_vehicle)
          create_slot_buttons(frame.vd_fuel_flow, fuels, FUEL_PREFIX, pd.selected_fuel)
          create_slot_buttons(frame.vd_ammo_flow, ammos, AMMO_PREFIX, pd.selected_ammo)
        end
      end

      if frame and frame.valid then
        -- Lock Vehicle selection (false) but keep Fuel & Ammo active/interactable (true, true)
        set_manual_sections_enabled(frame, false, true, true)
        local deploy_btn = frame.vd_btn_row and frame.vd_btn_row.vd_deploy_btn
        if deploy_btn and deploy_btn.valid then
          deploy_btn.caption = "Deploy Blueprint"
        end
      end
    end
  end

  if frame and frame.valid then update_grid_status_lbl(frame, player, pd) end
end

function M.save_current_as_preset(player)
  local pd = helpers.get_player_data(player.index)
  if not pd.selected_vehicle then
    player.print("[QuickDrive] Select a vehicle before saving a preset.")
    return
  end

  local suffix = ""
  if pd.selected_blueprint_grid and #pd.selected_blueprint_grid > 0 then
    suffix = " + Grid (" .. #pd.selected_blueprint_grid .. " eq)"
  end

  local preset_name = "Preset " .. (#pd.presets + 1) .. " (" .. pd.selected_vehicle .. suffix .. ")"
  table.insert(pd.presets, {
    name            = preset_name,
    vehicle         = pd.selected_vehicle,
    fuel            = pd.selected_fuel,
    ammo            = pd.selected_ammo,
    equipment_grid  = pd.selected_blueprint_grid,
    color           = pd.selected_color,
    blueprint_label = pd.selected_blueprint_label,
    blueprint_fuel  = pd.selected_blueprint_fuel,
    blueprint_ammo  = pd.selected_blueprint_ammo,
  })

  pd.active_preset = preset_name

  local frame = player.gui.screen[FRAME_NAME]
  if frame and frame.valid then update_preset_dropdown(frame, pd) end
  player.print("[QuickDrive] Saved preset: " .. preset_name)
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
  if frame and frame.valid then update_preset_dropdown(frame, pd) end
end

local function reset_preset_to_custom(frame, pd)
  pd.active_preset = nil
  if frame and frame.valid and frame.vd_preset_flow and frame.vd_preset_flow.vd_preset_dropdown then
    frame.vd_preset_flow.vd_preset_dropdown.selected_index = 1
  end
end

function M.on_vehicle_selected(player, vehicle_name)
  local pd = helpers.get_player_data(player.index)
  pd.selected_vehicle = vehicle_name

  local frame = player.gui.screen[FRAME_NAME]
  if not (frame and frame.valid) then return end

  reset_preset_to_custom(frame, pd)

  for _, child in pairs(frame.vd_vehicle_flow.children) do
    if string.sub(child.name, 1, #VEH_PREFIX) == VEH_PREFIX then
      child.toggled = (string.sub(child.name, #VEH_PREFIX + 1) == vehicle_name)
    end
  end

  local ent_name = prototypes.item[vehicle_name] and prototypes.item[vehicle_name].place_result and prototypes.item[vehicle_name].place_result.name or vehicle_name
  local fuels    = helpers.get_fuels_for_vehicle(player, ent_name)
  local ammos    = helpers.get_ammo_for_vehicle(player, ent_name)

  if not helpers.has_item_in_list(fuels, pd.selected_fuel) then
    pd.selected_fuel = #fuels > 0 and fuels[1].name or nil
  end

  if not helpers.has_item_in_list(ammos, pd.selected_ammo) then
    pd.selected_ammo = #ammos > 0 and ammos[1].name or nil
  end

  create_slot_buttons(frame.vd_fuel_flow, fuels, FUEL_PREFIX, pd.selected_fuel)
  create_slot_buttons(frame.vd_ammo_flow, ammos, AMMO_PREFIX, pd.selected_ammo)
end

function M.on_fuel_selected(player, fuel_name)
  local pd = helpers.get_player_data(player.index)
  pd.selected_fuel = fuel_name

  local frame = player.gui.screen[FRAME_NAME]
  if not (frame and frame.valid) then return end

  reset_preset_to_custom(frame, pd)

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

  reset_preset_to_custom(frame, pd)

  for _, child in pairs(frame.vd_ammo_flow.children) do
    if string.sub(child.name, 1, #AMMO_PREFIX) == AMMO_PREFIX then
      child.toggled = (string.sub(child.name, #AMMO_PREFIX + 1) == ammo_name)
    end
  end
end

M.FRAME_NAME = FRAME_NAME

return M
