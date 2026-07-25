local M = {}

local VEHICLE_ENTITY_TYPES = {
  car              = true,
  ["spider-vehicle"] = true,
}

function M.get_player_data(player_index)
  if not storage.players then storage.players = {} end
  if not storage.players[player_index] then
    storage.players[player_index] = {
      selected_vehicle             = nil,
      selected_fuel                = nil,
      selected_ammo                = nil,
      deployed_vehicle_unit_number = nil,
      deployed_vehicle_item        = nil,
      presets                      = {},
      active_preset                = nil,
    }
  end
  if not storage.players[player_index].presets then
    storage.players[player_index].presets = {}
  end
  return storage.players[player_index]
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

-- Vehicle entity name to ammo item name mapping for vanilla & popular vehicles
local HARDCODED_VEHICLE_AMMO = {
  ["car"] = {
    ["firearm-magazine"]           = true,
    ["piercing-rounds-magazine"]   = true,
    ["uranium-rounds-magazine"]    = true,
  },
  ["tank"] = {
    ["cannon-shell"]               = true,
    ["explosive-cannon-shell"]     = true,
    ["uranium-cannon-shell"]       = true,
    ["explosive-uranium-cannon-shell"] = true,
    ["firearm-magazine"]           = true,
    ["piercing-rounds-magazine"]   = true,
    ["uranium-rounds-magazine"]    = true,
    ["flamethrower-ammo"]          = true,
  },
  ["spidertron"] = {
    ["rocket"]                     = true,
    ["explosive-rocket"]           = true,
    ["atomic-bomb"]                = true,
  },
}

function M.get_ammo_for_vehicle(player, vehicle_entity_name)
  local results, seen = {}, {}
  local inv = player.get_main_inventory()
  if not inv then return results end

  local allowed_map = HARDCODED_VEHICLE_AMMO[vehicle_entity_name]

  for i = 1, #inv do
    local stack = inv[i]
    if stack.valid_for_read and not seen[stack.name] then
      local is_valid = false
      if allowed_map then
        is_valid = allowed_map[stack.name] == true
      else
        local item_proto = prototypes.item[stack.name]
        if item_proto and item_proto.type == "ammo" then
          is_valid = true
        end
      end

      if is_valid then
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
