local helpers = require("scripts.helpers")
local M       = {}

local function drain_inventory(src_inv, player_inv)
  if not src_inv then return end
  for i = 1, #src_inv do
    local stack = src_inv[i]
    if stack.valid_for_read then
      player_inv.insert({name = stack.name, count = stack.count})
      stack.clear()
    end
  end
end

-- pcall guards against invalid inventory defines on mismatched vehicle types
local function try_drain(veh, define, player_inv)
  local ok, inv = pcall(function() return veh.get_inventory(define) end)
  if ok and inv then drain_inventory(inv, player_inv) end
end

local function try_get_inventory(veh, define)
  local ok, inv = pcall(function() return veh.get_inventory(define) end)
  if ok and inv then return inv end
  return nil
end

function M.deploy(player, vehicle_item, fuel_item)
  local inv = player.get_main_inventory()
  if not inv then
    player.print("[QuickDrive] No inventory available!")
    return false
  end

  if inv.get_item_count(vehicle_item) < 1 then
    player.print("[QuickDrive] You no longer have a " .. vehicle_item .. " in your inventory!")
    return false
  end

  local item_proto = prototypes.item[vehicle_item]
  if not (item_proto and item_proto.place_result) then
    player.print("[QuickDrive] Cannot place this item.")
    return false
  end
  local entity_name = item_proto.place_result.name

  local surface   = player.surface
  local place_pos = surface.find_non_colliding_position(entity_name, player.position, 5, 0.5)
  if not place_pos then
    player.print("[QuickDrive] No room nearby to place the vehicle!")
    return false
  end

  inv.remove({name = vehicle_item, count = 1})

  local vehicle = surface.create_entity({
    name        = entity_name,
    position    = place_pos,
    force       = player.force,
    raise_built = true,
  })

  if not (vehicle and vehicle.valid) then
    inv.insert({name = vehicle_item, count = 1})
    player.print("[QuickDrive] Failed to create the vehicle entity!")
    return false
  end

  if fuel_item and fuel_item ~= "" then
    local fuel_inv = vehicle.get_fuel_inventory()
    if fuel_inv then
      local available = inv.get_item_count(fuel_item)
      if available > 0 then
        local inserted = fuel_inv.insert({name = fuel_item, count = available})
        if inserted > 0 then inv.remove({name = fuel_item, count = inserted}) end
      end
    end
  end

  -- Auto-load Ammo
  local ammo_inv = try_get_inventory(vehicle, defines.inventory.car_ammo) or try_get_inventory(vehicle, defines.inventory.spider_ammo)
  if ammo_inv then
    local pd = helpers.get_player_data(player.index)
    local selected_ammo = pd.selected_ammo
    if selected_ammo and selected_ammo ~= "" and inv.get_item_count(selected_ammo) > 0 then
      local avail = inv.get_item_count(selected_ammo)
      local inserted = ammo_inv.insert({name = selected_ammo, count = avail})
      if inserted > 0 then inv.remove({name = selected_ammo, count = inserted}) end
    else
      local ammo_list = helpers.get_ammo_for_vehicle(player, entity_name)
      for _, ammo in ipairs(ammo_list) do
        local avail = inv.get_item_count(ammo.name)
        if avail > 0 then
          local inserted = ammo_inv.insert({name = ammo.name, count = avail})
          if inserted > 0 then inv.remove({name = ammo.name, count = inserted}) end
        end
      end
    end
  end

  if player.character and player.character.valid then
    vehicle.orientation = player.character.orientation
    vehicle.set_driver(player.character)
  end

  -- Initial Speed Boost / Auto Launch in player orientation direction
  if vehicle.speed ~= nil then
    vehicle.speed = 0.15
  end

  -- Auto Headlights: Turn headlights on if deploying during dark hours / night
  if surface.darkness and surface.darkness > 0.3 then
    pcall(function() vehicle.enable_headlights = true end)
  end

  local pd = helpers.get_player_data(player.index)
  pd.deployed_vehicle_unit_number = vehicle.unit_number
  pd.deployed_vehicle_item        = vehicle_item

  return true
end

function M.undeploy(player)
  local vehicle = player.vehicle
  if not (vehicle and vehicle.valid) then
    player.print("[QuickDrive] You are not in a vehicle!")
    return false
  end

  local inv = player.get_main_inventory()
  if not inv then return false end

  local veh_orientation = vehicle.orientation

  vehicle.set_driver(nil)

  if player.character and player.character.valid then
    player.character.orientation = veh_orientation
  end

  drain_inventory(vehicle.get_fuel_inventory(), inv)
  try_drain(vehicle, defines.inventory.car_trunk,             inv)
  try_drain(vehicle, defines.inventory.car_ammo,              inv)
  try_drain(vehicle, defines.inventory.spider_trunk,          inv)
  try_drain(vehicle, defines.inventory.spider_ammo,           inv)
  try_drain(vehicle, defines.inventory.artillery_turret_ammo, inv)

  local pd           = helpers.get_player_data(player.index)
  local vehicle_item = pd.deployed_vehicle_item

  if not vehicle_item then
    -- Fallback: scan prototypes if the stored item name was lost
    for name, proto in pairs(prototypes.item) do
      if proto.place_result and proto.place_result.name == vehicle.name then
        vehicle_item = name
        break
      end
    end
  end

  if vehicle_item then inv.insert({name = vehicle_item, count = 1}) end

  vehicle.destroy({raise_destroy = true})

  pd.deployed_vehicle_unit_number = nil
  pd.deployed_vehicle_item        = nil

  player.print("[QuickDrive] Vehicle packed back into your inventory!")
  return true
end

return M
