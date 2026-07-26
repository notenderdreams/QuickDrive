local M = {}

local VEHICLE_ENTITY_TYPES = {
  car              = true,
  ["spider-vehicle"] = true,
}

local VEHICLE_WEAPONS = {
  ["car"] = {
    {
      name  = "Vehicle Machine Gun",
      ammos = {"firearm-magazine", "piercing-rounds-magazine", "uranium-rounds-magazine"},
    },
  },
  ["tank"] = {
    {
      name  = "Cannon",
      ammos = {"cannon-shell", "explosive-cannon-shell", "uranium-cannon-shell", "explosive-uranium-cannon-shell"},
    },
    {
      name  = "Vehicle Machine Gun",
      ammos = {"firearm-magazine", "piercing-rounds-magazine", "uranium-rounds-magazine"},
    },
    {
      name  = "Vehicle Flamethrower",
      ammos = {"flamethrower-ammo"},
    },
  },
  ["spidertron"] = {
    {
      name  = "Spidertron Rockets",
      ammos = {"rocket", "explosive-rocket", "atomic-bomb"},
    },
  },
  ["spider-vehicle"] = {
    {
      name  = "Spidertron Rockets",
      ammos = {"rocket", "explosive-rocket", "atomic-bomb"},
    },
  },
}

function M.get_player_data(player_index)
  if not storage.players then storage.players = {} end
  if not storage.players[player_index] then
    storage.players[player_index] = {
      selected_vehicle             = nil,
      selected_fuel                = nil,
      selected_ammo                = nil,
      selected_ammos               = {},
      distribute_ammo              = true,
      selected_blueprint_grid      = nil,
      selected_color               = nil,
      selected_blueprint_label     = nil,
      deployed_vehicle_unit_number = nil,
      deployed_vehicle_item        = nil,
      presets                      = {},
      active_preset                = nil,
    }
  end
  local pd = storage.players[player_index]
  if not pd.presets then pd.presets = {} end
  if not pd.selected_ammos then pd.selected_ammos = {} end
  if pd.distribute_ammo == nil then pd.distribute_ammo = true end
  return pd
end

function M.get_vehicles_in_inventory(player)
  local results, seen = {}, {}
  local inv = player.get_main_inventory()
  if not inv then return results end

  for i = 1, #inv do
    local stack = inv[i]
    if stack.valid_for_read and not seen[stack.name] then
      local item_proto = prototypes.item[stack.name]
      local place_result = item_proto and item_proto.place_result
      if place_result then
        local ent_proto = prototypes.entity[place_result.name]
        if ent_proto and VEHICLE_ENTITY_TYPES[ent_proto.type] then
          seen[stack.name] = true
          table.insert(results, {
            name        = stack.name,
            count       = inv.get_item_count(stack.name),
            entity_name = place_result.name,
          })
        end
      end
    end
  end

  return results
end

function M.get_item_name_for_equipment(eq)
  if not eq then return nil end

  local eq_name = eq
  while type(eq_name) == "table" do
    eq_name = eq_name.name or eq_name.equipment or eq_name[1]
  end

  if type(eq_name) ~= "string" then
    eq_name = tostring(eq_name)
  end

  local ok, eq_proto = pcall(function() return prototypes.equipment[eq_name] end)
  if ok and eq_proto then
    local ok_tr, tr = pcall(function() return eq_proto.take_result end)
    if ok_tr and tr then
      local tr_name = nil
      pcall(function() tr_name = tr.name end)
      if type(tr_name) == "string" and tr_name ~= "" then
        return tr_name
      elseif type(tr) == "string" and tr ~= "" then
        return tr
      end
    end
  end

  return eq_name
end

local function is_qdrive_label(label)
  if not label or label == "" then return false end
  local lower = string.lower(label)
  return string.find(lower, "qdrive") ~= nil or string.find(lower, "quickdrive") ~= nil
end

function M.extract_blueprint_vehicle_data(target)
  if not target then return nil end

  local label = nil
  local is_bp = false

  pcall(function()
    if target.valid_for_read then
      if target.is_blueprint and target.is_blueprint_setup() then
        is_bp = true
        label = target.label
      end
    elseif target.valid and target.object_name == "LuaRecord" then
      if target.type == "blueprint" then
        is_bp = true
        label = target.title or target.label
      end
    end
  end)

  if not is_bp then return nil end
  if not is_qdrive_label(label) then return nil end

  local entities = nil
  pcall(function() entities = target.get_blueprint_entities() end)
  if not (entities and #entities > 0) then return nil end

  local veh_ent = nil
  for _, ent in ipairs(entities) do
    local ent_proto = prototypes.entity[ent.name]
    if ent_proto and VEHICLE_ENTITY_TYPES[ent_proto.type] then
      veh_ent = ent
      break
    end
  end

  if not veh_ent then return nil end

  local vehicle_item_name = nil
  for name, proto in pairs(prototypes.item) do
    if proto.place_result and proto.place_result.name == veh_ent.name then
      vehicle_item_name = name
      break
    end
  end

  if not vehicle_item_name then return nil end

  local raw_grid = veh_ent.equipment_grid or veh_ent.grid or veh_ent.equipment or {}
  local equipment_list = {}

  for _, eq in pairs(raw_grid) do
    if type(eq) == "table" then
      local eq_name = eq.equipment or eq.name or (type(eq[1]) == "string" and eq[1])
      while type(eq_name) == "table" do
        eq_name = eq_name.name or eq_name.equipment or eq_name[1]
      end
      if eq_name then
        eq_name = tostring(eq_name)
        local pos = eq.position or eq.pos
        if pos then
          if pos.x and pos.y then
            pos = {x = pos.x, y = pos.y}
          elseif pos[1] and pos[2] then
            pos = {x = pos[1], y = pos[2]}
          end
        end
        table.insert(equipment_list, {
          name     = eq_name,
          position = pos,
        })
      end
    end
  end

  -- Extract fuel & ammo items from blueprint entity containers/inventories
  local bp_fuel = nil
  local bp_ammo = nil

  local function inspect_item_entry(item_name)
    if not item_name or type(item_name) ~= "string" then return end
    local ok, item_proto = pcall(function() return prototypes.item[item_name] end)
    if ok and item_proto then
      if item_proto.fuel_category and not bp_fuel then
        bp_fuel = item_name
      end
      if item_proto.type == "ammo" and not bp_ammo then
        bp_ammo = item_name
      end
    end
  end

  local function scan_items_container(container)
    if not container or type(container) ~= "table" then return end
    for k, v in pairs(container) do
      if type(k) == "string" then inspect_item_entry(k) end
      if type(v) == "string" then
        inspect_item_entry(v)
      elseif type(v) == "table" then
        local name = v.name or (v.id and v.id.name)
        if name then inspect_item_entry(name) end
      end
    end
  end

  scan_items_container(veh_ent.items)
  scan_items_container(veh_ent.ammo_inventory)
  scan_items_container(veh_ent.fuel_inventory)
  scan_items_container(veh_ent.trunk_inventory)
  scan_items_container(veh_ent.inventory)
  scan_items_container(veh_ent.filters)

  return {
    label          = label,
    entity_name    = veh_ent.name,
    vehicle_item   = vehicle_item_name,
    equipment_grid = equipment_list,
    color          = veh_ent.color,
    fuel           = bp_fuel,
    ammo           = bp_ammo,
  }
end

function M.get_qdrive_blueprints(player)
  local results = {}
  local seen_labels = {}

  local function add_bp(data)
    if data and data.label and not seen_labels[data.label] then
      seen_labels[data.label] = true
      table.insert(results, data)
    end
  end

  local function scan_target(target)
    if not target then return end

    local is_bp = false
    pcall(function()
      if target.valid_for_read then
        if target.is_blueprint and target.is_blueprint_setup() then
          is_bp = true
        end
      elseif target.valid and target.object_name == "LuaRecord" then
        if target.type == "blueprint" then
          is_bp = true
        end
      end
    end)

    if is_bp then
      local data = M.extract_blueprint_vehicle_data(target)
      if data then add_bp(data) end
    else
      local is_book = false
      pcall(function()
        if target.valid_for_read and target.is_blueprint_book then
          is_book = true
        end
      end)
      if is_book then
        local book_inv = nil
        pcall(function() book_inv = target.get_inventory(defines.inventory.item_main) end)
        if not book_inv then
          pcall(function() book_inv = target.get_inventory(defines.inventory.blueprint_book) end)
        end
        if book_inv then
          for j = 1, #book_inv do
            scan_target(book_inv[j])
          end
        end
      end
    end
  end

  -- 1. Check cursor_stack
  if player.cursor_stack and player.cursor_stack.valid_for_read then
    scan_target(player.cursor_stack)
  end

  -- 2. Check cursor_record
  pcall(function()
    if player.cursor_record and player.cursor_record.valid then
      local data = M.extract_blueprint_vehicle_data(player.cursor_record)
      if data then add_bp(data) end
    end
  end)

  -- 3. Check main inventory
  local inv = player.get_main_inventory()
  if inv then
    for i = 1, #inv do
      scan_target(inv[i])
    end
  end

  return results
end

function M.check_grid_equipment_availability(player, grid_spec)
  if not grid_spec or #grid_spec == 0 then
    return { total = 0, available = 0, summary = "No equipment grid configured" }
  end

  local inv = player.get_main_inventory()
  if not inv then return { total = #grid_spec, available = 0, summary = "No inventory" } end

  local item_needed = {}
  for _, eq in ipairs(grid_spec) do
    local item_name = M.get_item_name_for_equipment(eq)
    if type(item_name) ~= "string" then
      item_name = tostring(item_name)
    end
    item_needed[item_name] = (item_needed[item_name] or 0) + 1
  end

  local available_count = 0
  for item_name, needed in pairs(item_needed) do
    local item_str = tostring(item_name)
    local has = 0
    pcall(function() has = inv.get_item_count(item_str) end)
    available_count = available_count + math.min(has, needed)
  end

  return {
    total     = #grid_spec,
    available = available_count,
    summary   = available_count .. "/" .. #grid_spec .. " grid items ready in inventory",
  }
end

function M.get_fuels_for_vehicle(player, vehicle_entity_name)
  local results, seen = {}, {}
  local ent_proto = prototypes.entity[vehicle_entity_name]
  if not ent_proto then return results end

  local burner = ent_proto.burner_prototype
  if not burner then return results end

  local fuel_categories = burner.fuel_categories
  if not fuel_categories then return results end

  local inv = player.get_main_inventory()
  if not inv then return results end

  for i = 1, #inv do
    local stack = inv[i]
    if stack.valid_for_read and not seen[stack.name] then
      local item_proto = prototypes.item[stack.name]
      local fc = item_proto and item_proto.fuel_category
      if fc and fuel_categories[fc] then
        seen[stack.name] = true
        table.insert(results, {
          name  = stack.name,
          count = inv.get_item_count(stack.name),
        })
      end
    end
  end

  return results
end

function M.get_weapon_ammos_for_vehicle(player, vehicle_entity_name)
  local inv = player.get_main_inventory()
  if not inv then return {} end

  local pd = M.get_player_data(player.index)
  local ent_proto = prototypes.entity[vehicle_entity_name]
  local weapon_list = {}

  local is_spidertron = (vehicle_entity_name == "spidertron" or vehicle_entity_name == "spider-vehicle")
  if not is_spidertron and ent_proto and ent_proto.type == "spider-vehicle" then
    is_spidertron = true
  end

  -- If vehicle is Spidertron and distribute_ammo is false, list each launcher slot individually
  if is_spidertron and not pd.distribute_ammo and ent_proto and ent_proto.guns and #ent_proto.guns > 1 then
    for i, gun_proto in ipairs(ent_proto.guns) do
      if gun_proto and gun_proto.attack_parameters then
        local ammo_cat = gun_proto.attack_parameters.ammo_category
        if ammo_cat then
          local slot_label = "Launcher Slot " .. i
          local avail_ammos = {}
          local seen_item = {}

          for inv_idx = 1, #inv do
            local stack = inv[inv_idx]
            if stack.valid_for_read and not seen_item[stack.name] then
              local item_proto = prototypes.item[stack.name]
              if item_proto and item_proto.type == "ammo" then
                local is_compat = (item_proto.ammo_category == ammo_cat) or (item_proto.ammo_type and item_proto.ammo_type.category == ammo_cat)
                if is_compat then
                  seen_item[stack.name] = true
                  table.insert(avail_ammos, {
                    name  = stack.name,
                    count = inv.get_item_count(stack.name),
                  })
                end
              end
            end
          end

          if #avail_ammos > 0 then
            table.insert(weapon_list, {
              slot_index    = i,
              name          = slot_label,
              ammo_category = ammo_cat,
              ammos         = avail_ammos,
            })
          end
        end
      end
    end
  end

  -- Default: Deduplicate by ammo_category when distribute_ammo is true
  if #weapon_list == 0 then
    local seen_categories = {}
    if ent_proto and ent_proto.guns then
      for _, gun_proto in pairs(ent_proto.guns) do
        if gun_proto and gun_proto.attack_parameters then
          local ammo_cat = gun_proto.attack_parameters.ammo_category
          if ammo_cat and not seen_categories[ammo_cat] then
            seen_categories[ammo_cat] = true

            local gun_display_name = gun_proto.name:gsub("%-", " "):gsub("^%l", string.upper)
            local avail_ammos = {}
            local seen_item = {}

            for inv_idx = 1, #inv do
              local stack = inv[inv_idx]
              if stack.valid_for_read and not seen_item[stack.name] then
                local item_proto = prototypes.item[stack.name]
                if item_proto and item_proto.type == "ammo" then
                  local is_compat = (item_proto.ammo_category == ammo_cat) or (item_proto.ammo_type and item_proto.ammo_type.category == ammo_cat)
                  if is_compat then
                    seen_item[stack.name] = true
                    table.insert(avail_ammos, {
                      name  = stack.name,
                      count = inv.get_item_count(stack.name),
                    })
                  end
                end
              end
            end

            if #avail_ammos > 0 then
              table.insert(weapon_list, {
                slot_index    = #weapon_list + 1,
                name          = gun_display_name,
                ammo_category = ammo_cat,
                ammos         = avail_ammos,
              })
            end
          end
        end
      end
    end
  end

  -- Fallback to predefined mapping if dynamic prototype inspection returned no items
  if #weapon_list == 0 then
    local defined_weapons = VEHICLE_WEAPONS[vehicle_entity_name] or VEHICLE_WEAPONS["car"]
    if defined_weapons then
      for i, wdef in ipairs(defined_weapons) do
        local avail_ammos = {}
        for _, ammo_name in ipairs(wdef.ammos) do
          local count = inv.get_item_count(ammo_name)
          if count > 0 then
            table.insert(avail_ammos, {
              name  = ammo_name,
              count = count,
            })
          end
        end
        if #avail_ammos > 0 then
          table.insert(weapon_list, {
            slot_index = i,
            name       = wdef.name,
            ammos      = avail_ammos,
          })
        end
      end
    end
  end

  return weapon_list
end

-- Backward compatibility wrapper for single ammo query
function M.get_ammo_for_vehicle(player, vehicle_entity_name)
  local weapons = M.get_weapon_ammos_for_vehicle(player, vehicle_entity_name)
  local results, seen = {}, {}
  for _, w in ipairs(weapons) do
    for _, a in ipairs(w.ammos) do
      if not seen[a.name] then
        seen[a.name] = true
        table.insert(results, a)
      end
    end
  end
  return results
end

function M.has_vehicle(player, vehicle_name)
  local inv = player.get_main_inventory()
  return inv ~= nil and inv.get_item_count(vehicle_name) > 0
end

function M.has_item_in_list(list, item_name)
  if not item_name then return false end
  for _, item in ipairs(list) do
    if item.name == item_name then return true end
  end
  return false
end

M.has_fuel_in_list = M.has_item_in_list

return M
