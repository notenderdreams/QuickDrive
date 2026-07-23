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
      deployed_vehicle_unit_number = nil,
      deployed_vehicle_item        = nil,
    }
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
      if item_proto and item_proto.fuel_category and
         fuel_categories[item_proto.fuel_category] then
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

function M.has_fuel_in_list(fuels, fuel_name)
  if not fuel_name then return false end
  for _, f in ipairs(fuels) do
    if f.name == fuel_name then return true end
  end
  return false
end

return M
